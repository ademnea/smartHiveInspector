import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _displayNameKey = 'display_name';
  static const String _roleKey = 'user_role';
  static const String _profileKey = 'user_profile';
  static const String _loginTimeKey = 'login_time';
  static const String _refreshTokenKey = 'refresh_token';

  // Save login credentials
  static Future<void> saveLoginData({
    required String token,
    String? userId,
    String? username,
    String? displayName,
    String? role,
    Map<String, dynamic>? profile,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());

    if (userId != null) await prefs.setString(_userIdKey, userId);
    if (username != null) await prefs.setString(_usernameKey, username);
    if (displayName != null) {
      await prefs.setString(_displayNameKey, displayName);
    }
    if (role != null) await prefs.setString(_roleKey, role);
    if (profile != null) await prefs.setString(_profileKey, jsonEncode(profile));
    if (refreshToken != null)
      await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // Get saved token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get saved refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Get saved user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get saved username
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

  // Update locally cached user info without touching auth timestamps
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

  // Get login time
  static Future<DateTime?> getLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_loginTimeKey);
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  // Check if token is expired (assuming 24 hour expiry)
  static Future<bool> isTokenExpired() async {
    final loginTime = await getLoginTime();
    if (loginTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(loginTime);

    // Consider token expired after 23 hours (1 hour buffer)
    return difference.inHours >= 23;
  }

  // Validate token with server
  static Future<bool> validateTokenWithServer() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        print('❌ No token found');
        return false;
      }

      print('🔍 Validating token with server...');

      // Try a simple API call to validate token using farms endpoint
      final response = await http
          .get(
            Uri.parse(
              'http://196.43.168.57/api/v1/farms',
            ), // Use farms endpoint which exists
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Token is valid');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Token is invalid/expired (401)');
        return false;
      } else {
        print('⚠️ Unexpected response: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Token validation failed: $e');
      return false;
    }
  }

  // Attempt to refresh token
  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ No refresh token found');
        return false;
      }

      print('🔄 Attempting to refresh token...');

      final response = await http
          .post(
            Uri.parse('http://196.43.168.57/api/v1/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['access_token'] ?? data['token'];
        final newRefreshToken = data['refresh_token'];

        if (newToken != null) {
          // Save new tokens
          await saveLoginData(token: newToken, refreshToken: newRefreshToken);

          print('✅ Token refreshed successfully');
          return true;
        }
      }

      print('❌ Token refresh failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Token refresh error: $e');
      return false;
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all login data (logout)
  static Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_profileKey);
    await prefs.remove(_loginTimeKey);
    await prefs.remove(_refreshTokenKey);
    print('🚪 User logged out - all tokens cleared');
  }

  // Helper method for testing - reset first time flag
  static Future<void> resetFirstTimeFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', true);
    await clearLoginData();
  }

  // ===== FIXES FOR AUTH_SERVICES =====
  
  // ADD THIS METHOD - Save token (for backward compatibility with auth_services.dart)
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // ADD THIS METHOD - Get user profile (for backward compatibility with auth_services.dart)
  static Future<Map<String, dynamic>?> getUserProfile() async {
    return await getStoredProfile();
  }
}