import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:HPGM/Services/notifi_service.dart';
import 'package:HPGM/components/pop_up.dart';
import 'package:HPGM/navbar.dart';
import 'package:HPGM/login.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'services/token_storage.dart';
import 'services/auth_services.dart';

class Home extends StatefulWidget {
  final String token;
  final bool notify;

  const Home({super.key, required this.token, required this.notify});

  @override
  State<Home> createState() => _HomeState();
}

class HomeData {
  final int farms;
  final int hives;
  final String apiaryName;
  final double averageHoneyPercentage;
  final double averageWeight;
  final double daysToEndSeason;
  final double percentage_time_left;

  HomeData({
    required this.farms,
    required this.hives,
    required this.apiaryName,
    required this.averageHoneyPercentage,
    required this.averageWeight,
    required this.daysToEndSeason,
    required this.percentage_time_left,
  });

  factory HomeData.fromJson(
    Map<String, dynamic> countJson,
    Map<String, dynamic> productiveJson,
    Map<String, dynamic> seasonJson,
    Map<String, dynamic> supplementData,
  ) {
    return HomeData(
      farms: countJson['total_farms'] ?? 0,
      hives: countJson['total_hives'] ?? 0,
      apiaryName: productiveJson['most_productive_farm']?['name'] ?? 'Unknown',
      averageHoneyPercentage: (productiveJson['average_honey_percentage'] ?? 0).toDouble(),
      averageWeight: (productiveJson['average_weight'] ?? 0).toDouble(),
      daysToEndSeason: (seasonJson['time_until_harvest']?['days'] ?? 0).toDouble(),
      percentage_time_left: (seasonJson['time_until_harvest']?['percentage_time_left'] ?? 0).toDouble(),
    );
  }
}

class _HomeState extends State<Home> {
  HomeData? homeData;
  bool isLoading = true;
  String _errorMessage = '';

  // API Configuration - CHANGE THIS TO YOUR ACTUAL SERVER IP
  static const String _baseUrl = 'http://196.43.168.57';

  @override
  void initState() {
    super.initState();
    getData();
    startPeriodicTemperatureCheck();
  }

  Future<void> getData() async {
    setState(() {
      isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get token - first try from widget, then from storage
      String? token = widget.token;
      if (token.isEmpty || token == 'null') {
        token = await TokenStorage.getToken();
      }

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
          _errorMessage = 'Please login again';
        });
        
        // Navigate to login after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        });
        return;
      }

      String sendToken = "Bearer $token";

      var headers = {
        'Accept': 'application/json',
        'Authorization': sendToken,
        'Content-Type': 'application/json',
      };

      // Concurrent requests
      var responses = await Future.wait([
        http.get(
          Uri.parse('$_baseUrl/api/v1/farms/count'),
          headers: headers,
        ).timeout(const Duration(seconds: 30)),
        http.get(
          Uri.parse('$_baseUrl/api/v1/farms/most-productive'),
          headers: headers,
        ).timeout(const Duration(seconds: 30)),
        http.get(
          Uri.parse('$_baseUrl/api/v1/farms/time-until-harvest'),
          headers: headers,
        ).timeout(const Duration(seconds: 30)),
        http.get(
          Uri.parse('$_baseUrl/api/v1/farms/supplementary-feeding'),
          headers: headers,
        ).timeout(const Duration(seconds: 30)),
      ]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200 &&
          responses[3].statusCode == 200) {
        
        Map<String, dynamic> countData = jsonDecode(responses[0].body);
        Map<String, dynamic> productiveData = jsonDecode(responses[1].body);
        Map<String, dynamic> seasonData = jsonDecode(responses[2].body);
        
        // Fix supplementData parsing
        Map<String, dynamic> supplementData = {};
        try {
          final supplementList = jsonDecode(responses[3].body);
          if (supplementList is List && supplementList.isNotEmpty) {
            supplementData = supplementList[0] as Map<String, dynamic>? ?? {};
          }
        } catch (e) {
          print('Supplement data parse error: $e');
        }

        setState(() {
          homeData = HomeData.fromJson(
            countData,
            productiveData,
            seasonData,
            supplementData,
          );
          isLoading = false;
        });
      } else if (responses[0].statusCode == 401) {
        // Token expired
        setState(() {
          isLoading = false;
          _errorMessage = 'Session expired. Please login again.';
        });
        
        await AuthService.logout();
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        });
      } else {
        setState(() {
          isLoading = false;
          _errorMessage = 'Failed to load dashboard data. Please try again.';
        });
      }
    } catch (error) {
      print('Home data error: $error');
      setState(() {
        isLoading = false;
        _errorMessage = 'Network error: Cannot connect to server';
      });
    }
  }

  Timer? _timer;

  void startPeriodicTemperatureCheck() {
    // Wait for data to load first
    Future.delayed(const Duration(seconds: 5), () {
      _checkNotifications();
    });
    
    _timer = Timer.periodic(const Duration(minutes: 60), (timer) {
      _checkNotifications();
    });
  }

  Future<void> _checkNotifications() async {
    if (homeData == null) return;
    
    try {
      double daystoseason = homeData?.daysToEndSeason ?? 0.0;

      if (daystoseason <= 10 && daystoseason > 0 && !widget.notify) {
        NotificationService().showNotification(
          id: 1,
          title: 'Honey harvest season',
          body: 'The Honey harvest season is here, check your hives and harvest the honey.',
        );
      }

      // Temperature check - using apiary name
      String apiaryName = homeData?.apiaryName ?? 'Your apiary';
      
      // You would need actual temperature data here
      // This is a placeholder check
      if (daystoseason <= 5 && !widget.notify) {
        NotificationService().showNotification(
          id: 2,
          title: "Supplementary Feeding",
          body: '$apiaryName may require supplementary feeding soon. Please check the hives.',
        );
      }
    } catch (error) {
      print('Error checking notifications: $error');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateToDashboard() async {
    final token = await TokenStorage.getToken();
    if (token != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NavBar(token: token)),
      );
    }
  }

  void _retry() {
    getData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 206, 109, 40),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.orange.withOpacity(0.8),
                                Colors.orange.withOpacity(0.6),
                                Colors.orange.withOpacity(0.4),
                                Colors.orange.withOpacity(0.2),
                                Colors.orange.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 50.0),
                          child: Row(
                            children: [
                              Container(
                                child: Image.asset(
                                  'lib/images/log-1.png',
                                  height: 65,
                                  width: 65,
                                ),
                              ),
                              const Spacer(),
                              // Dashboard button
                              IconButton(
                                icon: Icon(
                                  Icons.dashboard,
                                  color: const Color.fromARGB(255, 206, 109, 40),
                                  size: 30,
                                ),
                                onPressed: _navigateToDashboard,
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.person,
                                color: Color.fromARGB(255, 206, 109, 40),
                                size: 50,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 150.0),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 20.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Apiaries: ${homeData?.farms ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: "Sans",
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(right: 20.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Hives: ${homeData?.hives ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: "Sans",
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Most productive apiary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Sans',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      height: 250,
                      width: 300,
                      child: LiquidLinearProgressIndicator(
                        value: (homeData?.averageHoneyPercentage != null
                            ? homeData!.averageHoneyPercentage / 100
                            : 0.0).clamp(0.0, 1.0),
                        valueColor: const AlwaysStoppedAnimation(Colors.amber),
                        backgroundColor: Colors.amber[100]!,
                        borderColor: Colors.brown,
                        borderWidth: 5.0,
                        borderRadius: 12.0,
                        direction: Axis.vertical,
                        center: TextButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => buildHoneySheet(
                                "Average Honey Levels for ${homeData?.apiaryName} apiary",
                                homeData?.averageHoneyPercentage ?? 0,
                              ),
                            );
                          },
                          child: Text(
                            "${homeData?.apiaryName ?? '--'} apiary\n${(homeData?.averageHoneyPercentage.toStringAsFixed(2) ?? '--')}%\n${homeData?.averageWeight.toStringAsFixed(1) ?? '--'}Kg",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                              fontFamily: "Sans",
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Apiaries requiring supplementary feeding',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: "Sans",
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: SizedBox(
                        width: 350,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          color: Colors.orange[100],
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 22,
                                    bottom: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.brightness_1,
                                        color: Colors.black,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${homeData?.apiaryName ?? '--'} - Monitor temperature',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.normal,
                                          fontSize: 16,
                                          fontFamily: "Sans",
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Honey Harvest Season',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: "Sans",
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: CircularPercentIndicator(
                      animation: true,
                      animationDuration: 1000,
                      radius: 130,
                      lineWidth: 30,
                      percent: ((homeData?.percentage_time_left ?? 0) / 100).clamp(0.0, 1.0),
                      progressColor: Colors.amber,
                      backgroundColor: Colors.amber[100] ?? Colors.amber,
                      circularStrokeCap: CircularStrokeCap.round,
                      center: Text(
                        homeData?.daysToEndSeason != null &&
                                homeData!.daysToEndSeason <= 10
                            ? "In Season"
                            : "${homeData?.daysToEndSeason.toStringAsFixed(0)} days \nto \nharvest season",
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: "Sans",
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}