import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/my_app_store.dart';
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
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );
  String? _value;
  bool _opening = false;
  bool _returningFromSettings = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || _value != null) return;
    try {
      await _controller.start();
      if (mounted) setState(() => _cameraError = null);
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = '카메라를 사용할 수 없습니다. 카메라 권한을 허용해 주세요.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    if (_value != null) return;
    final values = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => v.isNotEmpty);
    if (values.isEmpty) return;
    setState(() => _value = values.first);
    unawaited(_controller.stop());
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
      final uri = Uri.tryParse(value);
      if (uri != null && {'tel', 'mailto', 'sms'}.contains(uri.scheme)) {
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
    final uri = Uri.tryParse(_value ?? '');
    final canOpen =
        _value != null &&
        (safeWebUri(_value!) != null ||
            (uri != null && {'tel', 'mailto', 'sms'}.contains(uri.scheme)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR 코드 스캔'),
        actions: [
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
                    onPressed: () {
                      setState(() => _value = null);
                      unawaited(_start());
                    },
                    child: const Text('다시 스캔'),
                  ),
                ],
              ),
            ),
    );
  }
}
