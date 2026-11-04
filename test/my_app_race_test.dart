import 'dart:async';
import 'package:bs_point/services/my_app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final reset in [false, true]) {
    for (final outcome in ['updated', 'missing', 'offline']) {
      test('늦은 $outcome 응답은 ${reset ? "초기화" : "새 선택"}를 덮지 않는다', () async {
        final started = Completer<void>();
        final response = Completer<http.Response>();
        final store = MyAppStore(
          client: MockClient((_) {
            started.complete();
            return response.future;
          }),
        );
        await store.select(
          const MyAppEntry(
            key: 'old',
            name: 'Old',
            url: 'https://old.example.com',
          ),
        );
        final resolving = store.resolve();
        await started.future;
        // 다른 Store 인스턴스에서 UI 선택/초기화 발생.
        final picker = MyAppStore();
        if (reset) {
          await picker.reset();
        } else {
          await picker.select(
            const MyAppEntry(
              key: 'new',
              name: 'New',
              url: 'https://new.example.com',
            ),
          );
        }
        response.complete(
          outcome == 'offline'
              ? http.Response('', 503)
              : http.Response(
                  outcome == 'missing'
                      ? '{}'
                      : '{"old":{"ad_code":55,"ad_name":"Old","is_webview":"Y","link_url1":"https://changed.example.com"}}',
                  200,
                ),
        );
        final result = await resolving;
        expect(result.stale, isTrue);
        expect(result.entry, isNull);
        expect((await picker.selected())?.key, reset ? isNull : 'new');
        expect(
          (await SharedPreferences.getInstance()).getString(
            MyAppStore.unavailableKey,
          ),
          isNull,
        );
      });
    }
  }
}
