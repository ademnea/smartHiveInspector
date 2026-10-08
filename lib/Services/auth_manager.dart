import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:HPGM/Services/token_storage.dart';
import 'package:HPGM/login.dart';
import 'package:HPGM/api/farmer_api.dart';
import 'package:HPGM/config/api_config.dart';
import 'package:HPGM/Services/auth_services.dart';

/// Authenticated requests for screens not yet moved to [FarmerApi].
/// Handles token expiry and redirects to login on 401.
class AuthManager {
  static bool _isValidating = false;
  static http.Client _client = http.Client();

  @visibleForTesting
  static void setHttpClientForTesting(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  static void resetHttpClientForTesting() {
    _client = http.Client();
  }

  /// Make authenticated HTTP request with automatic token handling
  static Future<http.Response?> authenticatedRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    BuildContext? context,
  }) async {
    try {
      // First, ensure we have a valid token
      final hasValidToken = await ensureValidToken(context: context);
      if (!hasValidToken) {
        print('❌ No valid token available');
        return null;
      }

      final token = await TokenStorage.getToken();
      if (token == null) {
        print('❌ Token is null after validation');
        return null;
      }

      // Prepare headers
      final requestHeaders = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };

      // Make the request
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client
              .get(Uri.parse(url), headers: requestHeaders)
              .timeout(Duration(seconds: 30));
          break;
        case 'POST':
          response = await _client
              .post(
                Uri.parse(url),
                headers: requestHeaders,
                body: body is String ? body : jsonEncode(body),
              )
              .timeout(Duration(seconds: 30));
          break;
        case 'PUT':
          response = await _client
              .put(
                Uri.parse(url),
                headers: requestHeaders,
                body: body is String ? body : jsonEncode(body),
              )
              .timeout(Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await _client
              .delete(Uri.parse(url), headers: requestHeaders)
              .timeout(Duration(seconds: 30));
          break;
        default:
          throw UnsupportedError('HTTP method $method not supported');
      }

      // No refresh endpoint: a 401 from the farmer API means the session is
      // over. Screens not yet migrated still call the old server, which
      // rejects the new token; that must not log the farmer out.
      if (response.statusCode == 401 && url.startsWith(ApiConfig.baseUrl)) {
        print('❌ Got 401, session expired');
        await _handleAuthenticationFailure(context);
        return null;
      }

      return response;
    } catch (e) {
      print('❌ Authenticated request failed: $e');
      return null;
    }
  }

  /// Convenient methods for different HTTP verbs
  static Future<http.Response?> get(
    String url, {
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'GET',
      url: url,
      context: context,
      headers: headers,
    );
  }

  static Future<http.Response?> post(
    String url, {
    dynamic body,
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'POST',
      url: url,
      body: body,
      context: context,
      headers: headers,
    );
  }

  static Future<http.Response?> put(
    String url, {
    dynamic body,
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'PUT',
      url: url,
      body: body,
      context: context,
      headers: headers,
    );
  }

  static Future<http.Response?> delete(
    String url, {
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'DELETE',
      url: url,
      context: context,
      headers: headers,
    );
  }

  /// Ensure we have a stored, unexpired token
  static Future<bool> ensureValidToken({BuildContext? context}) async {
    if (_isValidating) {
      // Wait for current validation to complete
      while (_isValidating) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return await TokenStorage.isLoggedIn();
    }

    _isValidating = true;

    try {
      // Check if user is logged in
      if (!await TokenStorage.isLoggedIn()) {
        print('❌ User not logged in');
        await _handleAuthenticationFailure(context);
        return false;
      }

      // There is no refresh endpoint, so an expired token means log in again.
      if (await TokenStorage.isTokenExpired()) {
        print('⏰ Token expired');
        await _handleAuthenticationFailure(context);
        return false;
      }

      print('✅ Token is valid');
      return true;
    } finally {
      _isValidating = false;
    }
  }

  /// Validate token on app startup
  static Future<void> validateOnStartup() async {
    try {
      print('🚀 Validating authentication on app startup...');

      if (!await TokenStorage.isLoggedIn()) {
        print('ℹ️ User not logged in');
        return;
      }

      if (await TokenStorage.isTokenExpired()) {
        print('⏰ Stored token expired, clearing session');
        await TokenStorage.clearLoginData();
      }
    } catch (e) {
      print('❌ Startup token validation error: $e');
    }
  }

  /// Handle authentication failure by clearing tokens and redirecting to login
  static Future<void> _handleAuthenticationFailure(
    BuildContext? context,
  ) async {
    print('🚪 Handling authentication failure...');

    // Clear all stored tokens
    await TokenStorage.clearLoginData();

    if (context == null || !context.mounted) {
      FarmerApi.onUnauthorized?.call();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔐 Session expired. Please log in again.',
          style: TextStyle(fontFamily: "Sans"),
        ),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 4),
      ),
    );

    // Redirect to login screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  /// Logout user and clear all data
  static Future<void> logout({BuildContext? context}) async {
    print('👋 User logging out...');

    await AuthService.logout();

    if (context != null && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await TokenStorage.isLoggedIn();
  }
}
