import 'package:flutter/material.dart';
import '../services/my_app_store.dart';

Future<bool> confirmWebUrl(BuildContext context, String url) async {
  final uri = safeWebUri(url);
  if (uri == null) return false;
  if (uri.scheme == 'https') return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('암호화되지 않은 사이트'),
          content: Text('${uri.host}\nHTTP 연결에서는 입력한 정보가 보호되지 않습니다. 계속할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('열기'),
            ),
          ],
        ),
      ) ??
      false;
}

class MyAppPickerScreen extends StatefulWidget {
  const MyAppPickerScreen({super.key});
  @override
  State<MyAppPickerScreen> createState() => _MyAppPickerScreenState();
}

class _MyAppPickerScreenState extends State<MyAppPickerScreen> {
  final _store = MyAppStore();
  late Future<List<MyAppEntry>> _items;
  String _query = '';
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _items = _store.catalog();
  }

  Future<void> _select(MyAppEntry? item) async {
    if (_saving) return;
    if (item != null && !await confirmWebUrl(context, item.url)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      if (item == null) {
        await _store.reset();
      } else {
        await _store.select(item);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정을 저장하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('마이앱 선택'),
      actions: [
        IconButton(
          tooltip: '목록 새로고침',
          onPressed: _saving
              ? null
              : () => setState(() => _items = _store.catalog()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '관리자가 지정한 링크주소1을 엽니다. 선택한 앱은 다음 실행에도 유지되며 URL 변경사항은 앱 시작·복귀 시 확인합니다.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.home_outlined),
          title: const Text('BS Point 기본 화면'),
          subtitle: const Text('기존 포인트 서비스로 돌아가기'),
          onTap: _saving ? null : () => _select(null),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: '앱 이름 검색',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
        ),
        if (_saving) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<List<MyAppEntry>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('마이앱 목록을 가져오지 못했습니다.'),
                      TextButton(
                        onPressed: () =>
                            setState(() => _items = _store.catalog()),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                );
              }
              final entries = (snapshot.data ?? [])
                  .where((item) => item.name.toLowerCase().contains(_query))
                  .toList();
              if (entries.isEmpty) {
                return const Center(child: Text('사용 가능한 웹뷰 앱이 없습니다.'));
              }
              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return ListTile(
                    leading: Icon(
                      item.url.startsWith('https:')
                          ? Icons.apps
                          : Icons.warning_amber,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      item.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _saving ? null : () => _select(item),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
