import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _periodicCheck;

  bool _isOnline = true;
  bool _isInitialized = false;
  bool _isChecking = false;

  bool get isOnline => _isOnline;
  Stream<bool> get connectionStream => _connectionStatusController.stream;

  Future<void> initialize() async {
    if (_isInitialized) {
      await refreshStatus(forceEmit: false);
      return;
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('Connectivity monitoring error: $error');
      },
    );

    _startPeriodicCheck();
    _isInitialized = true;

    await refreshStatus(forceEmit: true);
    print('Connectivity service initialized - Online: $_isOnline');
  }

  Future<void> refreshStatus({bool forceEmit = false}) async {
    await _updateConnectionStatus(forceEmit: forceEmit);
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    print('Connectivity changed to: $result');
    unawaited(refreshStatus());
  }

  Future<void> _updateConnectionStatus({required bool forceEmit}) async {
    if (_isChecking) {
      return;
    }

    _isChecking = true;
    final wasOnline = _isOnline;

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _isOnline = false;
      } else {
        _isOnline = await _hasInternetConnection();
      }
    } catch (e) {
      print('Error checking connectivity: $e');
      _isOnline = false;
    } finally {
      _isChecking = false;
    }

    if (forceEmit || wasOnline != _isOnline) {
      print('Connection status changed: ${_isOnline ? "Online" : "Offline"}');
      _connectionStatusController.add(_isOnline);
    }
  }

  Future<bool> _hasInternetConnection() async {
    const endpoints = <String>[
      'https://clients3.google.com/generate_204',
      'https://connectivitycheck.gstatic.com/generate_204',
      'https://www.google.com/generate_204',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.get(
          Uri.parse(endpoint),
          headers: const {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 204 ||
            (response.statusCode >= 200 && response.statusCode < 400)) {
          return true;
        }
      } catch (_) {
        // Try the next endpoint.
      }
    }

    return false;
  }

  Future<bool> hasInternetConnection() async {
    await refreshStatus(forceEmit: false);
    return _isOnline;
  }

  void _startPeriodicCheck() {
    _periodicCheck?.cancel();
    _periodicCheck = Timer.periodic(const Duration(seconds: 30), (timer) {
      unawaited(refreshStatus());
    });
  }

  void dispose() {
    _periodicCheck?.cancel();
    _connectivitySubscription?.cancel();
    _isInitialized = false;
  }
}
