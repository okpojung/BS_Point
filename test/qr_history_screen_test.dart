import 'package:bs_point/services/qr_history_store.dart';
import 'package:bs_point/view_layout/qr_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStore extends QrHistoryStore {
  FakeStore(this.items, {this.fail = false});
  List<QrHistoryEntry> items;
  final bool fail;
  int clearCalls = 0;

  @override
  Future<List<QrHistoryEntry>> load() async {
    if (fail) throw Exception('x');
    return items;
  }

  @override
  Future<void> remove(String id) async =>
      items = items.where((e) => e.id != id).toList();

  @override
  Future<void> clear() async {
    clearCalls++;
    items = [];
  }
}

QrHistoryEntry entry(String id, String value, DateTime t) =>
    QrHistoryEntry(id: id, value: value, scannedAt: t);

Future<void> pumpScreen(
  WidgetTester tester,
  FakeStore store, {
  List<Object?>? popped,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final r = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => QrHistoryScreen(store: store),
                ),
              );
              popped?.add(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final older = DateTime(2026, 1, 2, 3, 4, 5);
  final newer = DateTime(2026, 5, 6, 7, 8, 9);

  testWidgets('shows newest first with timestamp and type', (tester) async {
    await pumpScreen(
      tester,
      FakeStore([
        entry('a', 'tel://01012345678', older),
        entry('b', 'https://example.com/x', newer),
      ]),
    );
    expect(find.text('2026-05-06 07:08:09'), findsOneWidget);
    expect(find.text('2026-01-02 03:04:05'), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);
    expect(find.text('TEL://'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2026-05-06 07:08:09')).dy,
      lessThan(tester.getTopLeft(find.text('2026-01-02 03:04:05')).dy),
    );
  });

  testWidgets('empty state', (tester) async {
    await pumpScreen(tester, FakeStore([]));
    expect(find.text('스캔한 QR 기록이 없습니다.'), findsOneWidget);
  });

  testWidgets('error state', (tester) async {
    await pumpScreen(tester, FakeStore([], fail: true));
    expect(find.text('기록을 불러오지 못했습니다.'), findsOneWidget);
  });

  testWidgets('copy from sheet', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await pumpScreen(
      tester,
      FakeStore([entry('b', 'https://example.com/x', newer)]),
    );
    await tester.tap(find.text('https://example.com/x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복사'));
    await tester.pumpAndSettle();
    expect(copied, 'https://example.com/x');
    expect(find.text('클립보드에 복사했습니다.'), findsOneWidget);
  });

  testWidgets('https URL action pops with raw url', (tester) async {
    final popped = <Object?>[];
    await pumpScreen(
      tester,
      FakeStore([entry('b', 'https://example.com/x', newer)]),
      popped: popped,
    );
    await tester.tap(find.text('https://example.com/x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 주소로 이동'));
    await tester.pumpAndSettle();
    expect(popped, ['https://example.com/x']);
    expect(find.byType(QrHistoryScreen), findsNothing);
  });

  testWidgets('unsafe scheme has copy only', (tester) async {
    await pumpScreen(
      tester,
      FakeStore([entry('c', 'javascript:alert(1)', newer)]),
    );
    await tester.tap(find.text('javascript:alert(1)'));
    await tester.pumpAndSettle();
    expect(find.text('복사'), findsOneWidget);
    expect(find.text('이 주소로 이동'), findsNothing);
    expect(find.text('전화 앱 열기'), findsNothing);
  });

  testWidgets('tap does not launch; explicit action confirms then launches', (
    tester,
  ) async {
    final launched = <Uri>[];
    qrHistoryLauncher = (u) async {
      launched.add(u);
      return true;
    };
    await pumpScreen(tester, FakeStore([entry('t', 'tel:01012345678', newer)]));
    await tester.tap(find.text('tel:01012345678'));
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    await tester.tap(find.text('전화 앱 열기'));
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(launched.length, 1);
    expect(launched.single.scheme, 'tel');
  });

  testWidgets('clear all confirmation cancel keeps entries', (tester) async {
    final store = FakeStore([entry('b', 'https://example.com/x', newer)]);
    await pumpScreen(tester, store);
    await tester.tap(find.byTooltip('전체 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(store.clearCalls, 0);
    expect(find.text('https://example.com/x'), findsOneWidget);
    await tester.tap(find.byTooltip('전체 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(store.clearCalls, 1);
    expect(find.text('스캔한 QR 기록이 없습니다.'), findsOneWidget);
  });

  testWidgets('huge payload does not overflow', (tester) async {
    await pumpScreen(tester, FakeStore([entry('h', 'x' * 20000, newer)]));
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
