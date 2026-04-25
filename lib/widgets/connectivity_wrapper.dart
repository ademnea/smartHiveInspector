import 'dart:async';

import 'package:HPGM/Services/connectivity_service.dart';
import 'package:flutter/material.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final bool showBanner;
  final bool showAlerts;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showBanner = true,
    this.showAlerts = true,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isOnline = true;
  bool _isAlertShowing = false;
  BuildContext? _dialogContext;
  late StreamSubscription<bool> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.connectionStream.listen((
      bool isOnline,
    ) {
      print(
        'Connectivity listener received: ${isOnline ? "Online" : "Offline"}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = isOnline;
      });

      if (!widget.showAlerts) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (!isOnline && !_isAlertShowing) {
          _showConnectivityAlert();
        } else if (isOnline && _isAlertShowing) {
          _dismissConnectivityAlert();
          _showBriefSuccessMessage();
        }
      });
    });

    _isOnline = _connectivityService.isOnline;
    print('Initial connectivity state: ${_isOnline ? "Online" : "Offline"}');

    if (widget.showAlerts && !_isOnline && !_isAlertShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showConnectivityAlert();
        }
      });
    }
  }

  void _showBriefSuccessMessage() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Connection restored',
              style: TextStyle(
                fontFamily: 'Sans',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  void _showConnectivityAlert() {
    if (_isAlertShowing || !mounted) {
      return;
    }

    _isAlertShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          title: const Row(
            children: [
              Icon(Icons.signal_wifi_off, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontFamily: 'Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Please check your internet connection. Some features may not work properly while offline.',
            style: TextStyle(
              fontFamily: 'Sans',
              fontSize: 16,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await _connectivityService.refreshStatus(forceEmit: true);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontFamily: 'Sans',
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _dismissConnectivityAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Continue Offline',
                    style: TextStyle(
                      fontFamily: 'Sans',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        );
      },
    ).then((_) {
      _dialogContext = null;
      _isAlertShowing = false;
    });
  }

  void _dismissConnectivityAlert() {
    if (!_isAlertShowing || _dialogContext == null) {
      return;
    }

    Navigator.of(_dialogContext!, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showBanner && !_isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[600]!, Colors.orange[700]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: const SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.signal_wifi_off, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Sans',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
