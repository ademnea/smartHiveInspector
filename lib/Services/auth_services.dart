import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:HPGM/dashboard_screen.dart';
import '../services/token_storage.dart';

class AuthService {
  static String _token = '';
  static int _userId = 0;

  static Future<void> logmein(
    BuildContext context,
    String email,
    String password,
  ) async {
    var headers = {'Accept': 'application/json'};
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://196.43.168.57/api/v1/login'),
    );
    request.fields.addAll({'email': email, 'password': password});
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      Map<String, dynamic> responseData = jsonDecode(responseBody);
      final userData =
          responseData['user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(responseData['user'])
              : <String, dynamic>{};
      _token = responseData['token'];
      _userId = userData['id'] ?? responseData['id'] ?? 0;

      final resolvedName =
          userData['name']?.toString() ??
          userData['full_name']?.toString() ??
          userData['username']?.toString();
      final resolvedEmail =
          userData['email']?.toString() ??
          userData['username']?.toString() ??
          email;
      final resolvedRole =
          userData['role']?.toString() ??
          responseData['role']?.toString() ??
          'user';

      final storedProfile = <String, dynamic>{
        ...responseData,
        'user': {
          ...userData,
          'id': _userId,
          'name': resolvedName,
          'email': resolvedEmail,
          'role': resolvedRole,
        },
      };

      print('Login successful - User ID: $_userId, Token: $_token');

      // Use TokenStorage instead of direct SharedPreferences
      await TokenStorage.saveLoginData(
        token: _token,
        userId: _userId.toString(),
        username: resolvedEmail,
        displayName: resolvedName,
        role: resolvedRole,
        profile: storedProfile,
      );

      Fluttertoast.showToast(
        msg: "Successful!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Navigate to Dashboard (remove token parameter if possible)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(token: _token)),
      );
    } else {
      Fluttertoast.showToast(
        msg: "Wrong Credentials!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  // Update logout method to use TokenStorage
  static Future<bool> logout() async {
    try {
      // Clear the token in memory
      _token = '';
      _userId = 0;

      // Use TokenStorage to clear all login data
      await TokenStorage.clearLoginData();

      Fluttertoast.showToast(
        msg: "Logged out successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      return true;
    } catch (e) {
      print('Logout error: $e');

      Fluttertoast.showToast(
        msg: "Logout failed: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      return false;
    }
  }

  static Future<void> launchSupportUrl() async {
    final Uri url = Uri.parse('http://wa.me/+256755088321');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  // Update getToken to use TokenStorage
  static Future<String> getToken() async {
    if (_token.isNotEmpty) {
      return _token;
    }

    // Get from TokenStorage if not in memory
    final token = await TokenStorage.getToken();
    if (token != null) {
      _token = token;
      return token;
    }

    return '';
  }

  static int getUserId() {
    return _userId;
  }

  // Update isLoggedIn to use TokenStorage
  static Future<bool> isLoggedIn() async {
    if (_token.isNotEmpty) {
      return true;
    }

    // Use TokenStorage instead of direct SharedPreferences
    return await TokenStorage.isLoggedIn();
  }
}
