import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/main_provider.dart';
import '../res/custom_colors.dart';
import '../services/my_app_store.dart';
import 'app_info_screen.dart';
import 'my_app_picker_screen.dart';
import 'qr_scanner_screen.dart';

class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key});
  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen>
    with WidgetsBindingObserver {
  final _store = MyAppStore();
  final _approvedHttpHosts = <String>{};
  InAppWebViewController? _controller;
  String? _homeUrl;
  String? _status;
  bool _initializing = true;
  bool _loading = true;
  bool _back = false;
  bool _forward = false;
  bool _childScreen = false;
  bool _checking = false;
  bool _httpDialog = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_childScreen &&
        !_checking &&
        !_httpDialog) {
      unawaited(_resolve());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<bool> _approveUrl(String url) async {
    final uri = safeWebUri(url);
    if (uri == null) return false;
    if (uri.scheme == 'https' || _approvedHttpHosts.contains(uri.host)) {
      return true;
    }
    if (_httpDialog) return false;
    _httpDialog = true;
    final ok = await confirmWebUrl(context, url);
    _httpDialog = false;
    if (ok) _approvedHttpHosts.add(uri.host);
    return ok;
  }

  Future<void> _resolve({bool navigate = false}) async {
    final epoch = ++_epoch;
    _checking = true;
    try {
      final result = await _store.resolve();
      if (!mounted || epoch != _epoch || result.stale) return;
      if (result.unavailable) {
        setState(() {
          _homeUrl = null;
          _controller = null;
          _status = '선택한 마이앱이 삭제·중지되었거나 웹뷰 URL이 유효하지 않습니다. 다른 앱을 선택해 주세요.';
          _initializing = false;
        });
        return;
      }
      final url =
          result.entry?.url ?? ref.read(authProvider.notifier).getWebViewUrl();
      if (!await _approveUrl(url)) {
        if (mounted && epoch == _epoch) {
          setState(() {
            _homeUrl = null;
            _controller = null;
            _initializing = false;
            _status = '페이지를 열지 않았습니다. 마이앱을 선택하거나 다시 시도해 주세요.';
          });
        }
        return;
      }
      if (!mounted || epoch != _epoch) return;
      final changed = _homeUrl != url;
      setState(() {
        _homeUrl = url;
        _initializing = false;
        _status = result.offline
            ? '설정 서버에 연결하지 못해 저장된 URL을 사용 중입니다. 최신 변경은 아직 확인하지 못했습니다.'
            : null;
      });
      // 변경이 없으면 QR 화면이나 현재 웹 탐색을 방해하지 않는다.
      if ((changed || navigate) && _controller != null) {
        await _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _initializing = false;
          _homeUrl = null;
          _controller = null;
          _status = '마이앱 설정을 읽지 못했습니다. 다시 선택해 주세요.';
        });
      }
    } finally {
      if (epoch == _epoch) _checking = false;
    }
  }

  Future<void> _pick() async {
    ++_epoch; // 선택 화면 진입 시 기존 조회 결과의 화면 적용 취소
    _checking = false;
    _childScreen = true;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MyAppPickerScreen()),
    );
    _childScreen = false;
    if (mounted) await _resolve(navigate: changed == true);
  }

  Future<void> _scan() async {
    _childScreen = true;
    final url = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    _childScreen = false;
    if (!mounted || url == null || safeWebUri(url) == null) return;
    final uri = Uri.parse(url);
    // QR 화면에서 사용자가 열기/HTTP 경고를 이미 확인했다.
    if (uri.scheme == 'http') _approvedHttpHosts.add(uri.host);
    if (_controller != null) {
      await _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
  }

  Future<void> _navigation(InAppWebViewController controller) async {
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (mounted) {
      setState(() {
        _back = back;
        _forward = forward;
        _loading = false;
      });
    }
  }

  Future<void> _close() async {
    if (await _controller?.canGoBack() ?? false) {
      await _controller!.goBack();
      return;
    }
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_close());
    },
    child: Scaffold(
      backgroundColor: CustomColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_status != null)
              MaterialBanner(
                content: Text(_status!),
                actions: [
                  TextButton(onPressed: _resolve, child: const Text('재시도')),
                  TextButton(onPressed: _pick, child: const Text('마이앱')),
                ],
              ),
            Expanded(
              child: _initializing
                  ? const Center(child: CircularProgressIndicator())
                  : _homeUrl == null
                  ? Center(
                      child: FilledButton(
                        onPressed: _pick,
                        child: const Text('마이앱 선택'),
                      ),
                    )
                  : Stack(
                      children: [
                        InAppWebView(
                          initialUrlRequest: URLRequest(url: WebUri(_homeUrl!)),
                          initialSettings: InAppWebViewSettings(
                            useShouldOverrideUrlLoading: true,
                            javaScriptEnabled: true,
                            javaScriptCanOpenWindowsAutomatically: false,
                            mediaPlaybackRequiresUserGesture: true,
                            useHybridComposition: true,
                            allowsInlineMediaPlayback: true,
                            iframeAllowFullscreen: true,
                            supportZoom: false,
                          ),
                          onWebViewCreated: (controller) =>
                              _controller = controller,
                          onLoadStart: (controller, url) {
                            if (mounted) setState(() => _loading = true);
                          },
                          onLoadStop: (controller, url) =>
                              _navigation(controller),
                          onUpdateVisitedHistory: (controller, url, isReload) =>
                              _navigation(controller),
                          onReceivedError: (controller, request, error) {
                            if (mounted && request.isForMainFrame == true) {
                              setState(() {
                                _loading = false;
                                _status = '페이지를 불러오지 못했습니다. 네트워크와 주소를 확인해 주세요.';
                              });
                            }
                          },
                          onReceivedHttpError: (controller, request, response) {
                            if (mounted && request.isForMainFrame == true) {
                              setState(() {
                                _loading = false;
                                _status = '사이트에서 오류를 반환했습니다. 잠시 후 새로고침해 주세요.';
                              });
                            }
                          },
                          // 임의 QR/마이앱 사이트에 카메라·마이크나 잘못된 인증서를 허용하지 않는다.
                          onReceivedServerTrustAuthRequest:
                              (controller, challenge) async =>
                                  ServerTrustAuthResponse(
                                    action:
                                        ServerTrustAuthResponseAction.CANCEL,
                                  ),
                          onPermissionRequest: (controller, request) async =>
                              PermissionResponse(
                                resources: request.resources,
                                action: PermissionResponseAction.DENY,
                              ),
                          shouldOverrideUrlLoading: (controller, action) async {
                            final url = action.request.url?.toString() ?? '';
                            if (safeWebUri(url) == null) {
                              return NavigationActionPolicy.CANCEL;
                            }
                            if (action.isForMainFrame &&
                                !await _approveUrl(url)) {
                              return NavigationActionPolicy.CANCEL;
                            }
                            return NavigationActionPolicy.ALLOW;
                          },
                        ),
                        if (_loading)
                          const Align(
                            alignment: Alignment.topCenter,
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: '뒤로',
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _back ? () => _controller?.goBack() : null,
              ),
              IconButton(
                tooltip: '새로고침',
                icon: const Icon(Icons.refresh),
                onPressed: _controller == null
                    ? null
                    : () => _controller?.reload(),
              ),
              IconButton(
                tooltip: '앞으로',
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _forward ? () => _controller?.goForward() : null,
              ),
              IconButton(
                tooltip: '마이앱 선택',
                icon: const Icon(Icons.apps),
                onPressed: _pick,
              ),
              IconButton(
                tooltip: '앱 정보',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () async {
                  _childScreen = true;
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const AppInfoScreen()),
                  );
                  _childScreen = false;
                },
              ),
              IconButton(
                tooltip: 'QR 코드 스캔',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _homeUrl == null ? null : _scan,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
