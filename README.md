# BS Point

BS Point는 Flutter 기반 모바일 앱입니다.  
앱에서 ARS 인증을 수행한 뒤, 인증된 전화번호를 포함한 URL로 포인트 서비스를 인앱 웹뷰에서 엽니다.

## 개요

- ARS 기반 사용자 인증
- `SharedPreferences`를 이용한 로그인 상태 저장
- 인증된 전화번호를 기반으로 웹뷰 진입 URL 생성
- 뒤로가기, 새로고침, 앞으로가기, 설정 버튼을 포함한 하단 웹뷰 네비게이션 제공
- 일부 호스트에 대한 임시 SSL 예외 허용 처리 포함

## 주요 기능

### 인증 및 웹뷰

- 앱 시작 시 로그인 상태를 확인해 로그인 화면 또는 웹뷰 화면으로 분기
- ARS 인증 성공 시 전화번호와 인증 정보를 로컬에 저장
- 저장된 전화번호에서 `-`를 제거한 뒤 `number` 쿼리 파라미터로 웹뷰 URL 생성

### 앱 정보 화면

- 웹뷰 하단 설정 아이콘으로 진입
- 앱 버전, 빌드 번호, 패키지명 표시
- ARS 인증 정보 중 주요 항목만 표시
  - 인증 전화번호
  - 인증 시각
  - 인증 번호(ars2fa 세션 ID)
  - (1.0.4 이하에서 저장된 정보는 앱 UUID, 추천인 전화번호도 표시)
- Android/iOS 기기 정보 표시
- Android에서 통신사(Carrier) 정보 표시


## ARS 인증 (ars2fa, ars_login 2.x)

1.0.5부터 휴대폰 인증은 [ars2fa](https://ars2fa.baro.me)를 씁니다. [ARS 인증]을 누르면 앱이 인증 번호로 바로 전화를 걸고(번호는 화면에 표시하지 않음), 통신사 기록으로 확인된 번호로 로그인합니다.

| 항목 | 값 (`lib/res/constants.dart`) |
|---|---|
| 앱 이름 (`mobile_app_name`) | `BS Point` |
| Android 패키지 | `com.hnglife.bspoint` |
| iOS Bundle ID | `com.hnglife.bspoint` |
| 통화 방식 (`type`) | `null` = 콘솔 앱 설정, `0` = 1번 누르기 없음, `1` = 1번 누르기 |

API 키는 소스에 넣지 않고 빌드할 때 넣습니다.

```bash
flutter run --dart-define=ARS2FA_API_KEY=<콘솔에서 발급한 키>
flutter build apk --release --dart-define=ARS2FA_API_KEY=<키>
flutter build ipa --release --dart-define=ARS2FA_API_KEY=<키>
```

- Android 권한은 `CALL_PHONE` 하나입니다. 처음 인증할 때 전화 권한 창이 뜨고, 허용하면 바로 발신합니다.
- 1.0.4 이하(구 PHP 서버)에서 주던 앱 UUID, 추천인 전화번호는 ars2fa가 주지 않습니다.

## 기술 스택

- Flutter
- Riverpod
- `shared_preferences`
- `flutter_inappwebview`
- `package_info_plus`
- `device_info_plus`
- Git 의존성 패키지 `ars_login`

## 앱 동작 흐름

1. 앱 실행
2. `SharedPreferences`에 저장된 로그인 상태 확인
3. 비로그인 상태이면 ARS 로그인 화면 표시
4. 인증 성공 시 전화번호와 인증 정보 저장
5. `https://pb.barosvc.com/bsp/?number={phone}` 형식의 URL을 웹뷰로 오픈
6. 하단 설정 버튼으로 앱/기기/인증 정보 확인

## 프로젝트 구조

```text
lib/
  main.dart
  provider/main_provider.dart
  view_layout/login_screen.dart
  view_layout/webview_screen.dart
  view_layout/app_info_screen.dart
  res/constants.dart
```

## 실행 환경

- Flutter SDK 3.8.x 이상
- Dart SDK 3.8.x 이상
- Android Studio 또는 Xcode
- ARS 인증 테스트를 위한 실제 단말 권장

## 설치 및 실행

```bash
flutter pub get
flutter run
```

`ars_login`은 Git 저장소에서 내려받는 의존성입니다. 네트워크 환경에서 Git 접근이 가능한지 먼저 확인해야 합니다.

## 빌드

```bash
flutter build apk
flutter build ios
```

OneStore 업로드용 APK 예시:

```bash
flutter build apk --release
```

## 로컬 저장 값

앱은 아래 값을 로컬에 저장합니다.

- `isLoggedIn`
- `userPhone`
- `userInfo`

앱을 다시 실행하면 저장된 로그인 상태와 인증 정보를 읽어 로그인 화면을 건너뛸 수 있습니다.

## 권한 설정

### Android

`android/app/src/main/AndroidManifest.xml`에 아래 권한이 선언되어 있습니다.

- `android.permission.CALL_PHONE`
- `android.permission.READ_PHONE_STATE`
- `android.permission.INTERNET`

### iOS

`ios/Runner/Info.plist`에 아래 권한 설명이 선언되어 있습니다.

- `NSMicrophoneUsageDescription`
- `NSContactsUsageDescription`

배포 전에는 실제 앱 동작과 스토어 심사 기준에 맞게 권한 사용 목적 및 설명 문구를 다시 점검하는 것이 좋습니다.

## 설정 포인트

기본 웹뷰 URL은 `lib/res/constants.dart`에 정의되어 있습니다.

```dart
static const String webViewBaseUrl = 'https://pb.barosvc.com/bsp/';
```

## 운영 시 주의사항

- 현재 웹뷰는 일부 호스트에 대해 임시 SSL 예외를 허용합니다.
- `Constants.isDebugMode`가 `true`로 설정되어 있어 인증 관련 로그가 디버그 출력에 남습니다.
- 앱 버전은 현재 `1.0.4+4`입니다.

## 최근 변경사항

- 웹뷰 하단 설정 아이콘 추가
- 앱 정보 화면 추가
- ARS 인증 정보 표시 항목 정리
- Android 통신사 정보 표시 추가
- 기본 위젯 테스트를 현재 앱 구조에 맞게 정리

## 테스트

```bash
flutter analyze
flutter test
```

현재 `flutter analyze` 결과에서는 `login_screen.dart`의 `print` 사용에 대한 기존 경고만 남아 있습니다.

## 1.0.6: QR 스캔 / 마이앱 웹뷰

- 하단 가장 오른쪽 **QR 코드 스캔**: 카메라 권한 → QR 인식 → 내용 확인 → **웹뷰에서 열기**.
  중복 인식을 막고 인식 시 카메라를 멈춥니다. 손전등, 재스캔, 권한 재시도/앱 설정, 복사를 지원합니다.
  URL은 HTTP(S)만 웹뷰에서 열며 HTTP는 경고 확인이 필요합니다. `tel:`, `mailto:`, `sms:`는 사용자가 연결 앱 열기를 눌러야만 실행됩니다.
  임의 intent/javascript/data/file 스킴은 실행하지 않습니다. 일반 텍스트는 확인/복사만 제공합니다.
  바로앱의 특수 QR 로그인·NFC·Wi-Fi 설정·연락처 등록·스캔 이력은 이 버전에 포함하지 않습니다.
- **마이앱 선택**(하단 앱 모양 아이콘): 기존 바로앱의 Firebase `myApp` 목록에서 웹뷰 앱을 선택합니다.
  선택한 Firebase 키를 로컬에 저장하고 **링크주소1**을 자동으로 엽니다. 앱 시작/복귀 때 최신 설정을 읽습니다.
  URL이 같으면 현재 웹 탐색이나 QR로 연 화면을 유지합니다. 기본 BS Point는 기존 전화번호 쿼리 흐름을 그대로 유지합니다.
  **선택 앱/QR URL에는 전화번호, ars2fa 세션 또는 API 키를 추가하지 않습니다.**
- 관리 원본: https://intra.barosvc.com/intra2/baro_my_app_list
  앱 수정에서 `웹뷰 사용여부=사용함`, `링크주소1=접속 URL`로 저장합니다.
  관리자 통합 진입점: https://admin.baro.me (Mobile APP 관리 메뉴는 별도 관리자 저장소에서 반영).
  카탈로그는 기존 바로앱과 동일한 `https://ad-test-6828b.firebaseio.com/myApp.json`을 읽기만 합니다.
  Firebase 객체 키가 앱 코드이며 `ad_code` 숫자와 다릅니다. 더미 `ad_code=101010`은 제외합니다.
- 통신 실패 시 저장 URL로 열되 **저장된 URL 사용 중** 안내/재시도를 제공합니다.
  정상 조회 결과 선택 앱이 삭제·중지·잘못된 URL이면 캐시로 우회하지 않고 다시 선택하게 합니다.
  **BS Point 기본 화면**을 선택하면 기존 포인트 서비스로 돌아갑니다. 로그인과 앱 선택 저장은 독립입니다.
- 보안: 기존 SSL 인증서 예외 허용과 웹 페이지 카메라/마이크 일괄 허용을 제거했습니다.
  QR 스캐너만 네이티브 카메라 권한을 사용하며 웹 페이지 권한은 기본 거부합니다.
  기존 HTTP 마이앱 호환을 위해 Android cleartext / iOS WebContent ATS 예외가 있으나 사용자가 HTTP 경고를 확인해야 합니다.
  유효하지 않은 TLS 인증서는 차단되므로 해당 사이트 인증서는 운영 측에서 수정해야 합니다.
- 검증: `flutter analyze`, `flutter test`, `flutter build apk --debug`.
  카메라 인식·권한 거부·백그라운드 복귀는 실기기에서 추가 시험이 필요합니다. iOS는 macOS에서 별도 빌드해야 합니다.
