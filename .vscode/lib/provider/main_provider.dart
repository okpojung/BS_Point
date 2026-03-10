import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../res/constants.dart';

// 로그인 상태 관리
class AuthState {
  final bool isLoggedIn;
  final String? userPhone;
  final Map<String, dynamic>? userInfo;

  const AuthState({required this.isLoggedIn, this.userPhone, this.userInfo});

  AuthState copyWith({
    bool? isLoggedIn,
    String? userPhone,
    Map<String, dynamic>? userInfo,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userPhone: userPhone ?? this.userPhone,
      userInfo: userInfo ?? this.userInfo,
    );
  }
}

// 인증 상태 관리 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoggedIn: false)) {
    _loadAuthState();
  }

  // 로그인 상태 로드
  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(Constants.keyIsLoggedIn) ?? false;
    final userPhone = prefs.getString(Constants.keyUserPhone);

    if (isLoggedIn && userPhone != null) {
      state = AuthState(isLoggedIn: true, userPhone: userPhone);
    }
  }

  // 로그인 처리
  Future<void> login(String phoneNumber, Map<String, dynamic>? userInfo) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(Constants.keyIsLoggedIn, true);
    await prefs.setString(Constants.keyUserPhone, phoneNumber);

    state = AuthState(
      isLoggedIn: true,
      userPhone: phoneNumber,
      userInfo: userInfo,
    );
  }

  // 로그아웃 처리
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(Constants.keyIsLoggedIn, false);
    await prefs.remove(Constants.keyUserPhone);
    await prefs.remove(Constants.keyUserInfo);

    state = const AuthState(isLoggedIn: false);
  }

  // 웹뷰 URL 생성
  String getWebViewUrl() {
    if (state.userPhone != null) {
      // 하이픈 제거
      final phoneNumber = state.userPhone!.replaceAll('-', '');
      return '${Constants.webViewBaseUrl}?number=$phoneNumber';
    }
    return Constants.webViewBaseUrl;
  }
}

// Provider 정의
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
