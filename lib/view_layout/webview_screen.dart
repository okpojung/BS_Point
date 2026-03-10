import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/main_provider.dart';
import '../res/custom_colors.dart';

class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key});

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  InAppWebViewController? _webViewController;

  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';

  /// 운영용 임시 SSL 허용 호스트
  /// 서버 인증서 구성이 완전히 정상화되면 제거 권장
  static const Set<String> _allowedSslHosts = {
    'pb.barosvc.com',
    'barosvc.com',
    'e.brt.so',
  };

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _updateNavigationState(
    InAppWebViewController controller, [
    WebUri? url,
  ]) async {
    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();
    final currentUrl = url?.toString() ?? (await controller.getUrl())?.toString() ?? '';

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentUrl = currentUrl;
      _canGoForward = canGoForward;
      _canGoBack = _isMainPage(currentUrl) ? false : canGoBack;
    });
  }

  Future<bool> _handleBackPressed() async {
    if (_webViewController == null) return true;

    final canGoBack = await _webViewController!.canGoBack();

    if (canGoBack && !_isMainPage(_currentUrl)) {
      await _webViewController!.goBack();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final webViewUrl = ref.read(authProvider.notifier).getWebViewUrl();

    if (webViewUrl.trim().isEmpty) {
      return Scaffold(
        backgroundColor: CustomColors.background,
        body: const SafeArea(
          child: Center(
            child: Text(
              '접속할 페이지 주소가 없습니다.',
              style: TextStyle(
                fontSize: 16,
                color: CustomColors.greyDark,
              ),
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _handleBackPressed,
      child: Scaffold(
        backgroundColor: CustomColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(webViewUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  useHybridComposition: true,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  supportZoom: false,
                  transparentBackground: false,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  if (!mounted) return;

                  setState(() {
                    _isLoading = true;
                    _currentUrl = url?.toString() ?? '';
                  });
                },
                onLoadStop: (controller, url) async {
                  await _updateNavigationState(controller, url);
                },

                /// 네트워크/웹뷰 로딩 오류
                /// 운영용에서는 별도 오류 문구를 띄우지 않고 로딩만 해제
                onReceivedError: (controller, request, error) {
                  if (!mounted) return;

                  setState(() {
                    _isLoading = false;
                  });
                },

                /// redirect/intro 과정에서 404 등이 발생할 수 있으므로 무시
                onReceivedHttpError: (controller, request, errorResponse) {
                  if (!mounted) return;

                  setState(() {
                    _isLoading = false;
                  });
                },

                /// 운영용 임시 SSL 허용 처리
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  final host = challenge.protectionSpace.host;

                  if (_allowedSslHosts.contains(host)) {
                    return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.PROCEED,
                    );
                  }

                  return ServerTrustAuthResponse(
                    action: ServerTrustAuthResponseAction.CANCEL,
                  );
                },

                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },

                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
              ),

              if (_isLoading)
                Container(
                  color: CustomColors.background.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CustomColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: CustomColors.surface,
              border: Border(
                top: BorderSide(
                  color: CustomColors.greyLight,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: _canGoBack
                        ? CustomColors.primary
                        : CustomColors.grey,
                  ),
                  onPressed: _canGoBack
                      ? () async {
                          await _webViewController?.goBack();
                          if (_webViewController != null) {
                            await _updateNavigationState(_webViewController!);
                          }
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: CustomColors.primary,
                  ),
                  onPressed: () async {
                    if (_webViewController == null) return;

                    if (mounted) {
                      setState(() {
                        _isLoading = true;
                      });
                    }

                    await _webViewController!.reload();
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: _canGoForward
                        ? CustomColors.primary
                        : CustomColors.grey,
                  ),
                  onPressed: _canGoForward
                      ? () async {
                          await _webViewController?.goForward();
                          if (_webViewController != null) {
                            await _updateNavigationState(_webViewController!);
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isMainPage(String url) {
    if (url.isEmpty) return false;

    final normalizedUrl = url.toLowerCase();

    return normalizedUrl.contains('/main.php') ||
        normalizedUrl.endsWith('/main.php') ||
        normalizedUrl.endsWith('/main');
  }
}