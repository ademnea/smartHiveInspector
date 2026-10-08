import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the farmer session.
///
/// The bearer token and its expiry live in secure storage (Keystore /
/// Keychain / libsecret). Non-secret display fields stay in
/// SharedPreferences.
class TokenStorage {
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _expiresAtKey = 'token_expires_at';

  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _displayNameKey = 'display_name';
  static const String _roleKey = 'user_role';
  static const String _profileKey = 'user_profile';

  // Tokens written by older builds lived in SharedPreferences.
  static const String _legacyTokenKey = 'auth_token';
  static const String _legacyLoginTimeKey = 'login_time';
  static const String _legacyRefreshTokenKey = 'refresh_token';

  // Save login credentials
  static Future<void> saveLoginData({
    required String token,
    DateTime? expiresAt,
    String? userId,
    String? username,
    String? displayName,
    String? role,
    Map<String, dynamic>? profile,
  }) async {
    await _secure.write(key: _tokenKey, value: token);
    if (expiresAt != null) {
      await _secure.write(
        key: _expiresAtKey,
        value: expiresAt.toUtc().toIso8601String(),
      );
    } else {
      await _secure.delete(key: _expiresAtKey);
    }

    await updateStoredUserInfo(
      userId: userId,
      username: username,
      displayName: displayName,
      role: role,
      profile: profile,
    );
  }

  // Get saved token
  static Future<String?> getToken() => _secure.read(key: _tokenKey);

  static Future<DateTime?> getExpiresAt() async {
    final raw = await _secure.read(key: _expiresAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  // Get saved user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get saved username (the farmer's email)
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // Get saved display name
  static Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<Map<String, dynamic>?> getStoredProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final rawProfile = prefs.getString(_profileKey);
    if (rawProfile == null || rawProfile.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawProfile);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed cached profile data.
    }

    return null;
  }

  // Update locally cached user info without touching the token
  static Future<void> updateStoredUserInfo({
    String? userId,
    String? username,
    String? displayName,
    String? role,
    Map<String, dynamic>? profile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) {
      await prefs.setString(_userIdKey, userId);
    }
    if (username != null) {
      await prefs.setString(_usernameKey, username);
    }
    if (displayName != null) {
      await prefs.setString(_displayNameKey, displayName);
    }
    if (role != null) {
      await prefs.setString(_roleKey, role);
    }
    if (profile != null) {
      await prefs.setString(_profileKey, jsonEncode(profile));
    }
  }

  /// True when there is no expiry on record or it has passed. There is no
  /// refresh endpoint, so an expired session means logging in again.
  static Future<bool> isTokenExpired() async {
    final expiresAt = await getExpiresAt();
    if (expiresAt == null) return true;
    return !expiresAt.isAfter(DateTime.now());
  }

  /// A token is stored and has not expired.
  static Future<bool> hasValidSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    return !await isTokenExpired();
  }

  // Check if a token is stored (does not check expiry)
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all login data (logout)
  static Future<void> clearLoginData() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _expiresAtKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_profileKey);
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_legacyLoginTimeKey);
    await prefs.remove(_legacyRefreshTokenKey);
  }

  // Helper method for testing - reset first time flag
  static Future<void> resetFirstTimeFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', true);
    await clearLoginData();
  }

  static Future<Map<String, dynamic>?> getUserProfile() => getStoredProfile();
}
