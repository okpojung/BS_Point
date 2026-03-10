import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../res/constants.dart';

class AuthState {
  final bool isLoggedIn;
  final String? userPhone;
  final Map<String, dynamic>? userInfo;

  const AuthState({
    required this.isLoggedIn,
    this.userPhone,
    this.userInfo,
  });

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

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoggedIn: false)) {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(Constants.keyIsLoggedIn) ?? false;
    final userPhone = prefs.getString(Constants.keyUserPhone);
    final rawUserInfo = prefs.getString(Constants.keyUserInfo);

    if (isLoggedIn && userPhone != null) {
      state = AuthState(
        isLoggedIn: true,
        userPhone: userPhone,
        userInfo: _decodeUserInfo(rawUserInfo),
      );
    }
  }

  Future<void> login(String phoneNumber, Map<String, dynamic>? userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitizedUserInfo = _sanitizeUserInfo(userInfo);

    await prefs.setBool(Constants.keyIsLoggedIn, true);
    await prefs.setString(Constants.keyUserPhone, phoneNumber);

    if (sanitizedUserInfo != null) {
      await prefs.setString(
        Constants.keyUserInfo,
        jsonEncode(sanitizedUserInfo),
      );
    } else {
      await prefs.remove(Constants.keyUserInfo);
    }

    state = AuthState(
      isLoggedIn: true,
      userPhone: phoneNumber,
      userInfo: sanitizedUserInfo,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(Constants.keyIsLoggedIn, false);
    await prefs.remove(Constants.keyUserPhone);
    await prefs.remove(Constants.keyUserInfo);

    state = const AuthState(isLoggedIn: false);
  }

  String getWebViewUrl() {
    if (state.userPhone != null) {
      final phoneNumber = state.userPhone!.replaceAll('-', '');
      return '${Constants.webViewBaseUrl}?number=$phoneNumber';
    }

    return Constants.webViewBaseUrl;
  }

  Map<String, dynamic>? _decodeUserInfo(String? rawUserInfo) {
    if (rawUserInfo == null || rawUserInfo.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUserInfo);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Map<String, dynamic>? _sanitizeUserInfo(Map<String, dynamic>? userInfo) {
    if (userInfo == null) {
      return null;
    }

    final sanitized = <String, dynamic>{};
    userInfo.forEach((key, value) {
      sanitized[key] = value?.toString();
    });
    return sanitized;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
