class Constants {
  static const String appName = 'BS Point';
  static const String appVersion = '1.0.6';

  static const String webViewBaseUrl = 'https://pb.barosvc.com/bsp/';

  static const String keyIsLoggedIn = 'isLoggedIn';
  static const String keyUserPhone = 'userPhone';
  static const String keyUserInfo = 'userInfo';

  static const int debounceMilliseconds = 300;
  static const int networkTimeoutSeconds = 30;

  static const bool isDebugMode = true;

  // ars2fa (https://ars2fa.baro.me) 휴대폰 인증
  // API 키는 소스에 넣지 않고 빌드할 때 넣습니다: flutter run/build --dart-define=ARS2FA_API_KEY=...
  static const String ars2faApiKey = String.fromEnvironment('ARS2FA_API_KEY');
  // ars2fa 콘솔에 등록한 값과 글자까지 같아야 합니다.
  static const String ars2faAppName = 'BS Point';
  static const String ars2faPackageName = 'com.hnglife.bspoint'; // Android applicationId
  static const String ars2faBundleId = 'com.hnglife.bspoint'; // iOS Bundle ID
  // 통화 방식: 0 = 1번 누르기 없음, 1 = 1번 누르기. null이면 ars2fa 콘솔의 앱 설정을 따릅니다.
  static const int? ars2faType = null;
}
