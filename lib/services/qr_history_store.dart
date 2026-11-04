import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_app_store.dart';

enum QrHistoryType {
  url('URL'),
  tel('TEL://'),
  email('MAILTO'),
  sms('SMS'),
  text('TEXT');

  const QrHistoryType(this.label);
  final String label;
}

/// Only explicit, non-executable external actions are accepted. TEL:// is
/// normalized to tel: for the dialer, never the direct-call API.
Uri? qrExternalUri(String value) {
  if (value != value.trim() || value.contains(RegExp(r'[\x00-\x1f\x7f\\]'))) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme == 'tel') {
    final phone = value.replaceFirst(
      RegExp(r'^tel:(?://)?', caseSensitive: false),
      '',
    );
    if (!RegExp(r'^\+?[0-9 ()\.\-]{2,30}$').hasMatch(phone)) return null;
    final normalized = phone.replaceAll(RegExp(r'[ ()\.\-]'), '');
    if (!RegExp(r'^\+?[0-9]{2,20}$').hasMatch(normalized)) return null;
    return Uri(scheme: 'tel', path: normalized);
  }
  if (!{'mailto', 'sms'}.contains(uri.scheme) ||
      uri.hasAuthority ||
      uri.path.isEmpty) {
    return null;
  }
  // Reject encoded controls too; neither CRLF email headers nor USSD actions
  // should become executable through the history menu.
  try {
    final decoded = Uri.decodeComponent(value);
    if (decoded.contains(RegExp(r'[\x00-\x1f\x7f]'))) return null;
  } on FormatException {
    return null;
  }
  if (uri.scheme == 'sms' &&
      !RegExp(r'^\+?[0-9 ()\.\-]{2,30}$').hasMatch(uri.path)) {
    return null;
  }
  return uri;
}

class QrHistoryEntry {
  const QrHistoryEntry({
    required this.id,
    required this.value,
    required this.scannedAt,
  });
  final String id;
  final String value;
  final DateTime scannedAt;
  QrHistoryType get type {
    if (safeWebUri(value) != null) return QrHistoryType.url;
    final scheme = Uri.tryParse(value)?.scheme;
    return switch (scheme) {
      'tel' => QrHistoryType.tel,
      'mailto' => QrHistoryType.email,
      'sms' => QrHistoryType.sms,
      _ => QrHistoryType.text,
    };
  }

  Map<String, Object> toJson() => {
    'id': id,
    'value': value,
    'scannedAt': scannedAt.toUtc().toIso8601String(),
  };
  static QrHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['value'] is! String ||
        raw['scannedAt'] is! String) {
      return null;
    }
    final id = raw['id'] as String, value = raw['value'] as String;
    final time = DateTime.tryParse(raw['scannedAt'] as String);
    if (id.isEmpty ||
        id.length > 100 ||
        value.isEmpty ||
        value.length > QrHistoryStore.maxValueLength ||
        time == null) {
      return null;
    }
    return QrHistoryEntry(id: id, value: value, scannedAt: time);
  }
}

class QrHistoryStore {
  static const key = 'qr_scan_history_v1';
  static const maxEntries = 200;
  static const maxValueLength = 8192;
  static Future<void> _queue = Future<void>.value();
  static int _sequence = 0;

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final next = _queue.then((_) => operation());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<List<QrHistoryEntry>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('QR history format is invalid');
    }
    final result = <QrHistoryEntry>[];
    final ids = <String>{};
    for (final item in decoded) {
      final entry = QrHistoryEntry.fromJson(item);
      if (entry != null && ids.add(entry.id)) result.add(entry);
    }
    result.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return result.take(maxEntries).toList();
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<QrHistoryEntry> entries,
  ) async {
    if (!await prefs.setString(
      key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    )) {
      throw StateError('QR history save failed');
    }
  }

  Future<List<QrHistoryEntry>> load() =>
      _serialized(() async => _read(await SharedPreferences.getInstance()));
  Future<QrHistoryEntry> add(String value, {DateTime? scannedAt}) =>
      _serialized(() async {
        if (value.isEmpty || value.length > maxValueLength) {
          throw ArgumentError('QR value length is invalid');
        }
        final prefs = await SharedPreferences.getInstance();
        final rows = await _read(prefs);
        final time = scannedAt ?? DateTime.now();
        final entry = QrHistoryEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
          value: value,
          scannedAt: time,
        );
        rows.insert(0, entry);
        rows.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
        await _write(prefs, rows.take(maxEntries).toList());
        return entry;
      });
  Future<void> remove(String id) => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await _read(prefs);
    rows.removeWhere((e) => e.id == id);
    await _write(prefs, rows);
  });
  Future<void> clear() => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(key)) throw StateError('QR history clear failed');
  });
}
