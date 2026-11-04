import 'dart:convert';
import 'package:bs_point/provider/main_provider.dart';
import 'package:bs_point/services/my_app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object> item({
  String url = 'https://example.com/home',
  String code = '55',
  String enabled = 'Y',
}) => {
  'ad_code': code,
  'ad_name': '테스트앱',
  'is_webview': enabled,
  'link_url1': url,
  'app_order': '2',
};
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('HTTP(S)만 허용하고 위험 스킴·자격증명·공백·역슬래시 차단', () {
    for (final invalid in [
      'javascript:alert(1)',
      'data:text/html,x',
      'file:///tmp/a',
      'intent://x',
      'https://u:p@example.com',
      'https:///path',
      ' https://example.com',
      'https://example.com/a b',
      'https://example.com\\@evil.com',
    ]) {
      expect(safeWebUri(invalid), isNull, reason: invalid);
    }
    expect(safeWebUri('https://example.com/a?q=%ED%95%9C#b'), isNotNull);
    expect(safeWebUri('http://example.com'), isNotNull);
  });
  test('Firebase 객체 키 사용, sentinel/중지/잘못된 항목 제외', () {
    final entries = MyAppEntry.parseCatalog({
      'baro': item(),
      'dummy': item(code: '101010'),
      'disabled': item(enabled: 'N'),
      'badurl': item(url: 'javascript:alert(1)'),
      'broken': 3,
    });
    expect(entries, hasLength(1));
    expect(entries.single.key, 'baro');
    expect(entries.single.key, isNot('55'));
  });
  test('Firebase 리스트 및 null 처리', () {
    expect(MyAppEntry.parseCatalog([null, item()]).single.key, '1');
    expect(MyAppEntry.parseCatalog(null), isEmpty);
    expect(MyAppEntry.parseCatalog('bad'), isEmpty);
  });
  test('선택 저장·서버 URL 변경 반영·기본 앱 복귀', () async {
    final store = MyAppStore(
      client: MockClient((request) async {
        expect(request.url.toString(), MyAppStore.catalogUrl);
        expect(request.url.queryParameters, isEmpty);
        return http.Response(
          jsonEncode({'baro': item(url: 'https://new.example.com')}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await store.select(
      const MyAppEntry(
        key: 'baro',
        name: '바로앱',
        url: 'https://old.example.com',
      ),
    );
    final result = await store.resolve();
    expect(result.entry!.url, 'https://new.example.com');
    expect((await store.selected())!.key, 'baro');
    expect((await store.selected())!.url, 'https://new.example.com');
    await store.reset();
    expect((await store.resolve()).entry, isNull);
  });
  test('오프라인은 저장 URL 명시, 삭제/중지는 캐시 재사용 금지', () async {
    final offline = MyAppStore(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await offline.select(
      const MyAppEntry(
        key: 'baro',
        name: '바로앱',
        url: 'https://cached.example.com',
      ),
    );
    final cached = await offline.resolve();
    expect(cached.offline, isTrue);
    expect(cached.entry!.url, 'https://cached.example.com');
    for (final catalog in [
      <String, Object>{},
      {'baro': item(enabled: 'N')},
      {'baro': item(url: 'file:///etc/a')},
    ]) {
      final store = MyAppStore(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(catalog),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final result = await store.resolve();
      expect(result.unavailable, isTrue);
      expect(result.entry, isNull);
      expect(result.offline, isFalse);
    }
  });
  test('선택 설정은 로그인과 독립, 임의 URL에 인증 전화번호 추가 안 함', () async {
    final auth = AuthNotifier();
    await Future<void>.delayed(Duration.zero);
    await auth.login('01000001111', null);
    expect(
      auth.getWebViewUrl(),
      'https://pb.barosvc.com/bsp/?number=01000001111',
    );
    final store = MyAppStore();
    await store.select(
      const MyAppEntry(
        key: 'custom',
        name: '커스텀',
        url: 'https://example.com/?x=1',
      ),
    );
    expect((await store.selected())!.url, 'https://example.com/?x=1');
    await auth.logout();
    expect((await store.selected())!.key, 'custom');
    auth.dispose();
  });
  test('저장값 손상은 기본 화면으로 묵시적 우회 금지', () async {
    SharedPreferences.setMockInitialValues({
      MyAppStore.preferenceKey: '{broken',
    });
    expect(MyAppStore().resolve(), throwsFormatException);
  });
}
