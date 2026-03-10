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
  - 인증전화번호
  - 앱 UUID
  - 인증 시각
  - 추천인 전화번호
- Android/iOS 기기 정보 표시
- Android에서 통신사(Carrier) 정보 표시

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
