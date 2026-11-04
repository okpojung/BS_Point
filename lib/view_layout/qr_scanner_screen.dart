import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/my_app_store.dart';
import '../services/qr_history_store.dart';
import 'qr_history_screen.dart';
import 'my_app_picker_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.qrCode],
  );
  String? _value;
  bool _opening = false;
  bool _historyOpen = false;
  bool _savingHistory = false;
  String? _historyError;
  Future<void> _historyWrite = Future<void>.value();
  final _historyStore = QrHistoryStore();
  bool _returningFromSettings = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || _value != null || _historyOpen) return;
    try {
      await _controller.start();
      if (_historyOpen) {
        await _controller.stop();
        return;
      }
      if (mounted) setState(() => _cameraError = null);
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = '카메라를 사용할 수 없습니다. 카메라 권한을 허용해 주세요.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_historyOpen) return;
    if (state == AppLifecycleState.resumed && _returningFromSettings) {
      _returningFromSettings = false;
      unawaited(_start());
      return;
    }
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && _value == null) {
      unawaited(_start());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    if (!mounted || _historyOpen || _value != null) return;
    final values = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => v.isNotEmpty);
    if (values.isEmpty) return;
    setState(() => _value = values.first);
    unawaited(_controller.stop());
    _historyWrite = _saveHistory(values.first);
  }

  Future<void> _saveHistory(String value) async {
    setState(() {
      _savingHistory = true;
      _historyError = null;
    });
    try {
      await _historyStore.add(value);
    } catch (_) {
      if (mounted) {
        setState(() => _historyError = '스캔 이력을 저장하지 못했습니다. 저장 공간을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _savingHistory = false);
    }
  }

  Future<void> _showHistory() async {
    if (_historyOpen || _opening) return;
    _historyOpen = true;
    try {
      try {
        await _controller.stop();
      } catch (_) {}
      await _historyWrite;
      if (!mounted) return;
      final url = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const QrHistoryScreen()),
      );
      if (!mounted) return;
      if (url != null && safeWebUri(url) != null) {
        _value = url;
        Navigator.pop(context, url);
        return;
      }
    } finally {
      _historyOpen = false;
      if (mounted && _value == null) unawaited(_start());
    }
  }

  Future<void> _open() async {
    if (_opening || _value == null) return;
    setState(() => _opening = true);
    final value = _value!;
    if (safeWebUri(value) != null) {
      final approved = await confirmWebUrl(context, value);
      if (mounted && approved) {
        Navigator.pop(context, value);
        return;
      }
    } else {
      final uri = qrExternalUri(value);
      if (uri != null) {
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('연결 앱 열기'),
            content: Text('다음 내용을 연결 앱에서 열까요?\n$value'),
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
        );
        if (!mounted) return;
        if (approved != true) {
          setState(() => _opening = false);
          return;
        }
        try {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('연결할 앱이 없습니다.')));
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('연결할 앱을 열지 못했습니다.')));
          }
        }
      }
    }
    if (mounted) setState(() => _opening = false);
  }

  Widget _error() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _cameraError ?? '카메라를 사용할 수 없습니다. 카메라 권한을 확인해 주세요.',
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: _start, child: const Text('다시 시도')),
          TextButton(
            onPressed: () async {
              _returningFromSettings = true;
              await openAppSettings();
            },
            child: const Text('앱 설정 열기'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final uri = qrExternalUri(_value ?? '');
    final canOpen =
        _value != null && (safeWebUri(_value!) != null || (uri != null));
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR 코드 스캔'),
        actions: [
          TextButton.icon(
            onPressed: _showHistory,
            icon: const Icon(Icons.history),
            label: const Text('스캔 이력'),
          ),
          IconButton(
            tooltip: '손전등 켜기/끄기',
            icon: const Icon(Icons.flashlight_on),
            onPressed: _value == null
                ? () async {
                    try {
                      await _controller.toggleTorch();
                    } catch (_) {}
                  }
                : null,
          ),
        ],
      ),
      body: _value == null
          ? Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _detected,
                  errorBuilder: (context, error) => _error(),
                ),
                if (_cameraError != null)
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _error(),
                  ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'QR 코드를 카메라에 비춰 주세요.\n인식 후 내용을 확인하고 열 수 있습니다.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '인식한 내용',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(_value!),
                  if (_savingHistory) const LinearProgressIndicator(),
                  if (_historyError != null)
                    Text(
                      _historyError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (canOpen)
                    FilledButton(
                      onPressed: _opening ? null : _open,
                      child: Text(
                        safeWebUri(_value!) != null
                            ? '웹뷰에서 열기'
                            : '연결 앱 열기 (직접 실행)',
                      ),
                    ),
                  if (!canOpen)
                    const Text('이 내용은 자동 실행하지 않습니다. 필요하면 복사해 사용하세요.'),
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _value!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('복사했습니다.')),
                        );
                      }
                    },
                    child: const Text('복사'),
                  ),
                  TextButton(
                    onPressed: _savingHistory
                        ? null
                        : () {
                            setState(() => _value = null);
                            unawaited(_start());
                          },
                    child: const Text('다시 스캔'),
                  ),
                  TextButton.icon(
                    onPressed: _showHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('스캔 이력 보기'),
                  ),
                ],
              ),
            ),
    );
  }
}
