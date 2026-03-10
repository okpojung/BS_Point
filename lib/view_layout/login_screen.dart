import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ars_login/ars_login.dart';
import '../provider/main_provider.dart';
import '../res/custom_colors.dart';
import '../res/constants.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LoginARS(
      useOnlyCallPermission: true, // v1.1.0+ 권한 최소화
      onAuthStart: () {
        // 인증 시작 시 호출
        if (Constants.isDebugMode) {
          print('🚀 ARS 인증 시작');
        }
      },
      onAuthComplete: (userInfo) async {
        // 인증 완료 시 호출 (v1.1.0+ 콜백 필수)
        if (Constants.isDebugMode) {
          print('✅ ARS 인증 완료');
          print('전화번호: ${userInfo['app_cid']}');
          print('앱 UUID: ${userInfo['appuuid']}');
          print('세션 ID: ${userInfo['appsid']}');
          print('인증 시간: ${userInfo['now']}');
          print('추천인: ${userInfo['prnts_phone_no'] ?? '없음'}');
        }

        // v1.1.0+ 직접 데이터 저장 (SharedPreferences 사용)
        await ref
            .read(authProvider.notifier)
            .login(userInfo['app_cid'] ?? '', userInfo);

        // 로그인 완료 후 자동으로 웹뷰 화면으로 전환됨 (AuthWrapper에서 처리)
      },
      onAuthFailure: (error) {
        // 인증 실패 시 호출
        if (Constants.isDebugMode) {
          print('❌ ARS 인증 실패: $error');
        }

        // 실패 시 스낵바 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인에 실패했습니다: $error'),
            backgroundColor: CustomColors.error,
          ),
        );
      },
      onManualInputRequired: () {
        // 수동 입력 필요 시 호출
        if (Constants.isDebugMode) {
          print('📝 수동 입력 필요');
        }
      },
    );
  }
}
