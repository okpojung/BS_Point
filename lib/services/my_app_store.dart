import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 관리자/Intra가 발행하는 기존 Firebase myApp 카탈로그를 읽기만 합니다.
/// URL에 전화번호·세션·키를 추가하지 않습니다.
Uri? safeWebUri(String value) {
  if (value.trim() != value || value.contains(RegExp(r'[\x00-\x20\x7f\\]'))) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

class MyAppEntry {
  const MyAppEntry({
    required this.key,
    required this.name,
    required this.url,
    this.order = 0,
  });
  final String key;
  final String name;
  final String url;
  final int order;

  static bool _disabled(Object? value) =>
      const {'N', '0', 'FALSE'}.contains('$value'.toUpperCase());

  static List<MyAppEntry> parseCatalog(Object? raw) {
    final Iterable<MapEntry<dynamic, dynamic>> entries = raw is Map
        ? raw.entries
        : raw is List
        ? raw.asMap().entries
        : const <MapEntry<Object?, Object?>>[];
    final result = <MyAppEntry>[];
    for (final row in entries) {
      final value = row.value;
      if (value is! Map ||
          '${value['ad_code']}' == '101010' ||
          value['is_webview'] != 'Y' ||
          _disabled(value['use_yn']) ||
          _disabled(value['is_use'])) {
        continue;
      }
      final name = value['ad_name'];
      final url = value['link_url1'];
      if (name is! String ||
          name.trim().isEmpty ||
          url is! String ||
          safeWebUri(url) == null) {
        continue;
      }
      result.add(
        MyAppEntry(
          key: '${row.key}',
          name: name,
          url: url,
          order: int.tryParse('${value['app_order']}') ?? 0,
        ),
      );
    }
    result.sort((a, b) {
      final order = a.order.compareTo(b.order);
      return order == 0 ? a.name.compareTo(b.name) : order;
    });
    return result;
  }
}

class MyAppResolution {
  const MyAppResolution({
    this.entry,
    this.offline = false,
    this.unavailable = false,
    this.stale = false,
  });
  final MyAppEntry? entry;
  final bool offline;
  final bool unavailable;
  final bool stale;
}

class MyAppStore {
  MyAppStore({http.Client? client}) : _client = client;
  final http.Client? _client;
  // 서로 다른 화면/Store 인스턴스의 선택 변경도 같은 세대로 추적한다.
  static int _selectionRevision = 0;
  static const catalogUrl = 'https://ad-test-6828b.firebaseio.com/myApp.json';
  static const preferenceKey = 'myAppSelectionV1';
  static const unavailableKey = 'myAppSelectionUnavailableV1';

  Future<List<MyAppEntry>> catalog() async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(catalogUrl))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const FormatException('catalog unavailable');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data.containsKey('error')) {
        throw const FormatException('catalog error');
      }
      if (data != null && data is! Map && data is! List) {
        throw const FormatException('invalid catalog');
      }
      return MyAppEntry.parseCatalog(data);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<MyAppEntry?> selected() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(preferenceKey);
    if (saved == null) return null;
    try {
      final data = jsonDecode(saved);
      if (data is! Map ||
          data['key'] is! String ||
          data['name'] is! String ||
          data['url'] is! String ||
          safeWebUri(data['url']) == null) {
        throw const FormatException('invalid selection');
      }
      return MyAppEntry(key: data['key'], name: data['name'], url: data['url']);
    } catch (_) {
      // 손상된 선택값을 기본 앱으로 오인해 조용히 전환하지 않는다.
      throw const FormatException('저장된 마이앱 설정을 다시 선택해 주세요.');
    }
  }

  String _encode(MyAppEntry entry) =>
      jsonEncode({'key': entry.key, 'name': entry.name, 'url': entry.url});

  Future<void> select(MyAppEntry entry) async {
    if (safeWebUri(entry.url) == null) {
      throw const FormatException('invalid URL');
    }
    final revision = ++_selectionRevision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _selectionRevision) return;
    // 동기 메모리 갱신 두 개 사이에 await를 두지 않는다.
    final write = prefs.setString(preferenceKey, _encode(entry));
    final clear = prefs.remove(unavailableKey);
    await Future.wait([write, clear]);
  }

  Future<void> reset() async {
    final revision = ++_selectionRevision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _selectionRevision) return;
    final remove = prefs.remove(preferenceKey);
    final clear = prefs.remove(unavailableKey);
    await Future.wait([remove, clear]);
  }

  Future<MyAppResolution> resolve() async {
    final revision = _selectionRevision;
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(preferenceKey);
    final saved = await selected();
    bool isCurrent() =>
        revision == _selectionRevision &&
        prefs.getString(preferenceKey) == savedJson;
    if (!isCurrent()) return const MyAppResolution(stale: true);
    if (saved == null) return const MyAppResolution();
    List<MyAppEntry> entries;
    try {
      entries = await catalog();
    } catch (_) {
      if (!isCurrent()) return const MyAppResolution(stale: true);
      if (prefs.getString(unavailableKey) == saved.key) {
        return const MyAppResolution(unavailable: true);
      }
      return MyAppResolution(entry: saved, offline: true);
    }
    // 늦게 도착한 응답은 새 사용자 선택/초기화에 대해 저장·중지 처리를 하지 않는다.
    if (!isCurrent()) return const MyAppResolution(stale: true);
    final matches = entries.where((entry) => entry.key == saved.key);
    if (matches.isEmpty) {
      final appliedRevision = ++_selectionRevision;
      await prefs.setString(unavailableKey, saved.key);
      if (appliedRevision != _selectionRevision) {
        return const MyAppResolution(stale: true);
      }
      return const MyAppResolution(unavailable: true);
    }
    final fresh = matches.first;
    final appliedRevision = ++_selectionRevision;
    final write = prefs.setString(preferenceKey, _encode(fresh));
    final clear = prefs.remove(unavailableKey);
    await Future.wait([write, clear]);
    if (appliedRevision != _selectionRevision) {
      return const MyAppResolution(stale: true);
    }
    return MyAppResolution(entry: fresh);
  }
}
