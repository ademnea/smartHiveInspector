import 'dart:async';
import 'package:HPGM/getstarted.dart';
import 'package:HPGM/login.dart';
import 'package:HPGM/dashboard_screen.dart';
import 'package:HPGM/Services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      await TokenStorage.clearLoginData();
      await prefs.setBool('isFirstTime', false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => GetStarted()),
      );
    } else {
      final hasSession = await TokenStorage.hasValidSession();
      final token = await TokenStorage.getToken();
      if (!mounted) return;

      if (hasSession && token != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(token: token),
          ),
        );
      } else {
        // Expired or missing: drop any stale token before asking to log in.
        await TokenStorage.clearLoginData();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Image.asset(
            'lib/images/log-1.png',
            height: 200,
          ),
        ),
      ),
    );
  }
}