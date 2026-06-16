import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:HPGM/navbar.dart';
import '../services/token_storage.dart';

class AuthService {
  static String _token = '';
  static int _userId = 0;
  static Map<String, dynamic> _userData = {};

  // API Configuration - CHANGE THIS TO YOUR ACTUAL SERVER IP
  static const String _baseUrl = 'http://196.43.168.57';

  // LOGIN METHOD
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Extract token and user data
        _token = responseData['token'] ?? '';
        final userData = responseData['user'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(responseData['user'])
            : <String, dynamic>{};
        
        _userId = userData['id'] ?? responseData['id'] ?? 0;
        _userData = userData;

        print('Login successful - User ID: $_userId, Token: $_token');

        // Save to TokenStorage
        await TokenStorage.saveLoginData(
          token: _token,
          userId: _userId.toString(),
          username: userData['email'] ?? email,
          displayName: userData['name'] ?? '',
          role: userData['role'] ?? 'beekeeper',
          profile: responseData,
        );

        return {
          'success': true,
          'token': _token,
          'user': userData,
        };
      } else {
        String errorMessage = 'Login failed';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? 'Invalid credentials';
        } catch (e) {
          errorMessage = 'Server error: ${response.statusCode}';
        }
        
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'error': 'Network error: Cannot connect to server',
      };
    }
  }

  // ORIGINAL logmein METHOD - KEPT FOR COMPATIBILITY
  static Future<void> logmein(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final result = await login(email: email, password: password);
      
      if (result['success'] == true) {
        final token = result['token'];
        Fluttertoast.showToast(
          msg: "Login Successful!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => NavBar(token: token),
            ),
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: result['error'] ?? "Wrong Credentials!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Network error: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // REGISTER METHOD
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String role = 'beekeeper',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // If token is returned, auto-login
        if (responseData['token'] != null) {
          _token = responseData['token'];
          final userData = responseData['user'] as Map<String, dynamic>? ?? {};
          _userId = userData['id'] ?? 0;
          _userData = userData;
          
          await TokenStorage.saveLoginData(
            token: _token,
            userId: _userId.toString(),
            username: email,
            displayName: name,
            role: role,
            profile: responseData,
          );
        }
        
        return {
          'success': true,
          'token': responseData['token'],
          'user': responseData['user'],
          'message': 'Registration successful',
        };
      } else {
        String errorMessage = 'Registration failed';
        try {
          final errorData = json.decode(response.body);
          if (errorData['errors'] != null) {
            final errors = errorData['errors'] as Map;
            if (errors['email'] != null) {
              errorMessage = errors['email'][0];
            } else if (errors['password'] != null) {
              errorMessage = errors['password'][0];
            } else {
              errorMessage = errors.values.first[0];
            }
          } else {
            errorMessage = errorData['message'] ?? errorData['error'] ?? 'Registration failed';
          }
        } catch (e) {
          errorMessage = 'Server error: ${response.statusCode}';
        }
        
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      print('Register error: $e');
      return {
        'success': false,
        'error': 'Network error: Cannot connect to server',
      };
    }
  }

  // LOGOUT METHOD
  static Future<bool> logout() async {
    try {
      // Try to call logout endpoint if token exists
      if (_token.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('$_baseUrl/api/v1/logout'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          // Ignore logout endpoint errors
          print('Logout endpoint error: $e');
        }
      }
      
      // Clear all data
      _token = '';
      _userId = 0;
      _userData = {};
      
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
      return false;
    }
  }

  // GET TOKEN
  static Future<String> getToken() async {
    if (_token.isNotEmpty) {
      return _token;
    }
    
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      _token = token;
      // Also restore user data
      final userId = await TokenStorage.getUserId();
      if (userId != null) {
        _userId = int.tryParse(userId) ?? 0;
      }
      return token;
    }
    
    return '';
  }

  // GET USER ID
  static int getUserId() {
    return _userId;
  }

  // GET USER DATA
  static Future<Map<String, dynamic>?> getUserData() async {
    if (_userData.isNotEmpty) {
      return _userData;
    }
    return await TokenStorage.getUserProfile();
  }

  // CHECK IF LOGGED IN
  static Future<bool> isLoggedIn() async {
    if (_token.isNotEmpty) {
      return true;
    }
    final token = await TokenStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  // SAVE TOKEN (for use after registration)
  static Future<void> saveToken(String token) async {
    _token = token;
    await TokenStorage.saveToken(token);
  }

  // LAUNCH SUPPORT URL
  static Future<void> launchSupportUrl() async {
    final Uri url = Uri.parse('http://wa.me/+256755088321');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}