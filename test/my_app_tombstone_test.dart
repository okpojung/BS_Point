import 'dart:convert';
import 'package:bs_point/services/my_app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('삭제 확인 후 오프라인 캐시 부활 금지, 서버 재활성화로 복구', () async {
    var phase = 0;
    final store = MyAppStore(
      client: MockClient((_) async {
        if (phase == 1) return http.Response('', 503);
        return http.Response(
          jsonEncode(
            phase == 0
                ? {}
                : {
                    'baro': {
                      'ad_code': '55',
                      'ad_name': 'Baro',
                      'is_webview': 'Y',
                      'link_url1': 'https://new.example.com',
                    },
                  },
          ),
          200,
        );
      }),
    );
    await store.select(
      const MyAppEntry(
        key: 'baro',
        name: 'Baro',
        url: 'https://old.example.com',
      ),
    );
    expect((await store.resolve()).unavailable, isTrue);
    phase = 1;
    final offline = await store.resolve();
    expect(offline.unavailable, isTrue);
    expect(offline.entry, isNull);
    phase = 2;
    final recovered = await store.resolve();
    expect(recovered.unavailable, isFalse);
    expect(recovered.entry!.url, 'https://new.example.com');
    phase = 1;
    expect((await store.resolve()).offline, isTrue);
  });
  test('서버 error 응답은 삭제가 아닌 통신 오류', () async {
    final store = MyAppStore(
      client: MockClient(
        (_) async => http.Response('{"error":"Permission denied"}', 200),
      ),
    );
    await store.select(
      const MyAppEntry(
        key: 'baro',
        name: 'Baro',
        url: 'https://cached.example.com',
      ),
    );
    expect((await store.resolve()).offline, isTrue);
  });
  test('DEL 문자 및 비활성 값 0/false 처리', () {
    expect(safeWebUri('https://example.com/\x7f'), isNull);
    for (final disabled in [0, '0', 'N', 'n', false]) {
      expect(
        MyAppEntry.parseCatalog({
          'baro': {
            'ad_code': 55,
            'ad_name': 'Baro',
            'is_webview': 'Y',
            'link_url1': 'https://example.com',
            'use_yn': disabled,
          },
        }),
        isEmpty,
      );
    }
  });
}
