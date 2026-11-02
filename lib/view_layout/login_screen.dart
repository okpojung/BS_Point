import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ars_login/ars_login.dart';
import '../provider/main_provider.dart';
import '../res/custom_colors.dart';
import '../res/constants.dart';

/// ars2fa 발신 ARS 휴대폰 인증 (ars_login 2.x).
/// [ARS 인증] → 앱이 인증 번호로 바로 전화 → 통신사 기록으로 확인된 번호로 로그인.
const _arsConfig = Ars2faConfig(
  apiKey: Constants.ars2faApiKey,
  mobileAppName: Constants.ars2faAppName,
  packageName: Constants.ars2faPackageName,
  bundleId: Constants.ars2faBundleId,
  purpose: '로그인',
  type: Constants.ars2faType,
);

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Constants.ars2faApiKey.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'ARS 인증 키가 설정되지 않았습니다.\n빌드할 때 --dart-define=ARS2FA_API_KEY=... 를 넣어 주세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return LoginARS(
      config: _arsConfig,
      title: '휴대폰 인증',
      // 로그인 화면이 첫 화면이므로 닫지 않고, 로그인 상태가 바뀌면 AuthWrapper가 웹뷰로 넘어갑니다.
      popOnFinish: false,
      onAuthStart: () {
        if (Constants.isDebugMode) debugPrint('ARS 인증 시작');
      },
      onAuthComplete: (r) async {
        final phone = r.phone ?? '';
        if (Constants.isDebugMode) debugPrint('ARS 인증 완료: ${r.phoneMasked}');
        // 앱 정보 화면에 보이는 인증 정보 (전체 번호는 로그에 남기지 않습니다)
        final info = <String, dynamic>{
          'app_cid': phone,
          'now': DateTime.now().toString().substring(0, 19),
          'session_id': r.sessionId,
          'provider': 'ars2fa',
        };
        await ref.read(authProvider.notifier).login(phone, info);
      },
      onAuthFailure: (r) {
        if (Constants.isDebugMode) debugPrint('ARS 인증 실패: $r');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(r.message),
            backgroundColor: CustomColors.error,
          ),
        );
      },
    );
  }
}
