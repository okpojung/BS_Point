import 'dart:convert';
import 'package:bs_point/services/qr_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('new history is empty', () async {
    expect(await QrHistoryStore().load(), isEmpty);
  });
  test('persist exact content/time and classify URL/TEL', () async {
    final store = QrHistoryStore();
    final at = DateTime.utc(2026, 11, 4, 13, 10, 12);
    await store.add('https://example.com/path?a=1', scannedAt: at);
    await store.add(
      'tel://01012345678',
      scannedAt: at.add(const Duration(seconds: 1)),
    );
    final entries = await QrHistoryStore().load();
    expect(entries.length, 2);
    expect(entries.first.type, QrHistoryType.tel);
    expect(entries.first.type.label, 'TEL://');
    expect(entries.last.type, QrHistoryType.url);
    expect(entries.last.value, 'https://example.com/path?a=1');
    expect(entries.last.scannedAt, at);
  });
  test('deliberate duplicate scans retain separate IDs', () async {
    final store = QrHistoryStore();
    await store.add('same');
    await store.add('same');
    final entries = await store.load();
    expect(entries.length, 2);
    expect(entries.first.id, isNot(entries.last.id));
  });
  test('concurrent instances serialize writes and retain all scans', () async {
    await Future.wait(List.generate(20, (i) => QrHistoryStore().add('QR $i')));
    expect((await QrHistoryStore().load()).length, 20);
  });
  test('capacity keeps newest 200 and removal/clear work', () async {
    final store = QrHistoryStore();
    final start = DateTime.utc(2026);
    for (var i = 0; i < 205; i++) {
      await store.add('QR $i', scannedAt: start.add(Duration(seconds: i)));
    }
    final rows = await store.load();
    expect(rows.length, 200);
    expect(rows.first.value, 'QR 204');
    expect(rows.last.value, 'QR 5');
    await store.remove(rows.first.id);
    expect((await store.load()).length, 199);
    await store.clear();
    expect(await store.load(), isEmpty);
  });
  test('malformed individual rows skipped, valid entries preserved', () async {
    SharedPreferences.setMockInitialValues({
      QrHistoryStore.key: jsonEncode([
        {'bad': true},
        {
          'id': 'a',
          'value': 'https://example.com',
          'scannedAt': '2026-11-04T13:00:00Z',
        },
        {
          'id': 'a',
          'value': 'duplicate ID',
          'scannedAt': '2026-11-04T13:01:00Z',
        },
      ]),
    });
    expect((await QrHistoryStore().load()).single.value, 'https://example.com');
  });
  test(
    'corrupt full history is not silently overwritten; queue recovers',
    () async {
      SharedPreferences.setMockInitialValues({QrHistoryStore.key: '{broken'});
      final store = QrHistoryStore();
      await expectLater(store.load(), throwsFormatException);
      await expectLater(store.add('new'), throwsFormatException);
      expect(
        (await SharedPreferences.getInstance()).getString(QrHistoryStore.key),
        '{broken',
      );
      await store.clear();
      await store.add('recovered');
      expect((await store.load()).single.value, 'recovered');
    },
  );
  test('size bounds reject oversize payload', () async {
    await expectLater(QrHistoryStore().add(''), throwsArgumentError);
    await expectLater(QrHistoryStore().add('x' * 8193), throwsArgumentError);
  });
  test(
    'external actions normalize tel:// and block USSD/control/unsafe schemes',
    () {
      expect(
        qrExternalUri('TEL://+82-10-1234-5678').toString(),
        'tel:+821012345678',
      );
      expect(qrExternalUri('tel:01012345678')?.scheme, 'tel');
      expect(qrExternalUri('mailto:a@example.com')?.scheme, 'mailto');
      expect(qrExternalUri('sms:01012345678?body=hello')?.scheme, 'sms');
      for (final value in [
        'tel:*123%23',
        'tel:01012345678\n',
        'tel:123;456',
        'tel://evil.com',
        'mailto:a@example.com?subject=x%0d%0abcc:b@example.com',
        'javascript:alert(1)',
        'intent://x',
        'file:///x',
      ]) {
        expect(qrExternalUri(value), isNull, reason: value);
      }
      expect(
        QrHistoryEntry(
          id: 'x',
          value: 'javascript:alert(1)',
          scannedAt: DateTime.now(),
        ).type,
        QrHistoryType.text,
      );
    },
  );
}
