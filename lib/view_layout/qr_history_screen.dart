import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/my_app_store.dart';
import '../services/qr_history_store.dart';
import 'my_app_picker_screen.dart';

/// 테스트에서 외부 앱 실행을 대체하기 위한 훅. 기본은 외부 애플리케이션 모드.
@visibleForTesting
Future<bool> Function(Uri uri) qrHistoryLauncher = (uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

String formatQrDateTime(DateTime value) {
  final t = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

enum _EntryAction { copy, openUrl, openExternal }

class QrHistoryScreen extends StatefulWidget {
  const QrHistoryScreen({super.key, this.store});

  final QrHistoryStore? store;

  @override
  State<QrHistoryScreen> createState() => _QrHistoryScreenState();
}

class _QrHistoryScreenState extends State<QrHistoryScreen> {
  late final QrHistoryStore _store = widget.store ?? QrHistoryStore();
  List<QrHistoryEntry> _entries = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final list = List<QrHistoryEntry>.of(await _store.load());
      list.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String body, String ok) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(body)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(ok),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showEntry(QrHistoryEntry entry) async {
    final action = await showModalBottomSheet<_EntryAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EntrySheet(entry: entry),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _EntryAction.copy:
        await Clipboard.setData(ClipboardData(text: entry.value));
        if (mounted) _toast('클립보드에 복사했습니다.');
      case _EntryAction.openUrl:
        if (safeWebUri(entry.value) == null) return;
        if (!await confirmWebUrl(context, entry.value)) return;
        if (!mounted) return;
        Navigator.pop(context, entry.value);
      case _EntryAction.openExternal:
        final uri = qrExternalUri(entry.value);
        if (uri == null) return;
        final ok = await _confirm(
          _externalLabel(entry.type),
          '${entry.value}\n\n위 내용으로 앱을 엽니다. 전화는 바로 걸리지 않고 전화 앱에서 확인 후 직접 거셔야 합니다.',
          '열기',
        );
        if (!ok || !mounted) return;
        try {
          final launched = await qrHistoryLauncher(uri);
          if (!launched && mounted) _toast('앱을 열 수 없습니다.');
        } catch (_) {
          if (mounted) _toast('앱을 열 수 없습니다.');
        }
    }
  }

  Future<void> _remove(QrHistoryEntry entry) async {
    try {
      await _store.remove(entry.id);
      if (!mounted) return;
      setState(
        () => _entries = _entries.where((e) => e.id != entry.id).toList(),
      );
      _toast('기록을 삭제했습니다.');
    } catch (_) {
      if (mounted) _toast('삭제하지 못했습니다.');
    }
  }

  Future<void> _clearAll() async {
    final ok = await _confirm(
      '전체 삭제',
      'QR 스캔 기록 ${_entries.length}건을 모두 삭제할까요?',
      '삭제',
    );
    if (!ok || !mounted) return;
    try {
      await _store.clear();
      if (!mounted) return;
      setState(() => _entries = const []);
      _toast('모든 기록을 삭제했습니다.');
    } catch (_) {
      if (mounted) _toast('삭제하지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR 스캔 기록'),
        actions: [
          if (!_loading && !_error && _entries.isNotEmpty)
            IconButton(
              tooltip: '전체 삭제',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('기록을 불러오지 못했습니다.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('스캔한 QR 기록이 없습니다.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = _entries[i];
        return ListTile(
          key: ValueKey('qr-entry-${e.id}'),
          onTap: () => _showEntry(e),
          title: Row(
            children: [
              _TypeChip(type: e.type),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatQrDateTime(e.scannedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          trailing: IconButton(
            tooltip: '기록 삭제',
            icon: const Icon(Icons.close),
            onPressed: () => _remove(e),
          ),
        );
      },
    );
  }
}

String _externalLabel(QrHistoryType type) => switch (type) {
  QrHistoryType.tel => '전화 앱 열기',
  QrHistoryType.email => '메일 앱 열기',
  QrHistoryType.sms => '문자 앱 열기',
  _ => '앱 열기',
};

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final QrHistoryType type;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(type.label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.entry});
  final QrHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final canWeb = safeWebUri(entry.value) != null;
    final canExternal =
        !canWeb &&
        entry.type != QrHistoryType.url &&
        entry.type != QrHistoryType.text &&
        qrExternalUri(entry.value) != null;
    final maxH = MediaQuery.of(context).size.height * 0.8;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeChip(type: entry.type),
                  const SizedBox(width: 8),
                  Expanded(child: Text(formatQrDateTime(entry.scannedAt))),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(entry.value),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, _EntryAction.copy),
                icon: const Icon(Icons.copy),
                label: const Text('복사'),
              ),
              if (canWeb) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _EntryAction.openUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('이 주소로 이동'),
                ),
              ],
              if (canExternal) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, _EntryAction.openExternal),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(_externalLabel(entry.type)),
                ),
              ],
              if (!canWeb && !canExternal)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('안전하게 열 수 없는 형식이라 복사만 가능합니다.'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
