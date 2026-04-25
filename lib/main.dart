import 'dart:convert';
import 'dart:async';

import 'package:HPGM/Services/apiary_queue_service.dart';
import 'package:HPGM/Services/auth_manager.dart';
import 'package:HPGM/Services/connectivity_service.dart';
import 'package:HPGM/Services/notifi_service.dart';
import 'package:HPGM/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/sync_manager.dart';
import 'services/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService().initNotification();
    print('Notification service initialized');
  } catch (e) {
    print('Warning: Could not initialize notifications: $e');
  }

  try {
    await ConnectivityService().initialize();
    print('Connectivity service initialized');
  } catch (e) {
    print('Warning: Could not initialize connectivity service: $e');
  }

  try {
    await AuthManager.validateOnStartup();
    print('Authentication validation completed');
  } catch (e) {
    print('Warning: Authentication validation failed: $e');
  }

  try {
    await SyncManager.initialize();
    print('Sync manager initialized for offline queue');
  } catch (e) {
    print('Warning: Could not initialize sync manager: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<bool>? _apiaryQueueSubscription;

  @override
  void initState() {
    super.initState();
    _setupApiaryQueueSync();
  }

  void _setupApiaryQueueSync() {
    _syncApiaryQueueIfOnline();

    _apiaryQueueSubscription = ConnectivityService().connectionStream.listen((isOnline) async {
      if (!isOnline) {
        return;
      }

      await _syncApiaryQueueIfOnline();
    });
  }

  @override
  void dispose() {
    _apiaryQueueSubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncApiaryQueueIfOnline() async {
    final isOnline = await ConnectivityService().hasInternetConnection();
    if (!isOnline) {
      return;
    }

    await _syncApiaryQueue();
  }

  Future<void> _syncApiaryQueue() async {
    final queue = await ApiaryQueueService.getQueue();
    for (int i = 0; i < queue.length;) {
      final item = queue[i];
      try {
        final token = await TokenStorage.getToken();
        if (token == null || token.isEmpty) {
          break;
        }

        http.Response response;
        String? endpoint;
        Map<String, dynamic> body = {};

        if (item.data.containsKey('endpoint')) {
          endpoint = item.data['endpoint'];
        }

        if (endpoint != null && endpoint.contains('/hives/inspections')) {
          body = item.data['inspection'] ?? {};
          response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          );
        } else if (endpoint != null &&
            endpoint.contains('/hives') &&
            item.actionType == ApiaryActionType.add) {
          body = item.data['hive'] ?? {};
          response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          );
        } else if (endpoint != null &&
            endpoint.contains('/hives') &&
            item.actionType == ApiaryActionType.edit) {
          body = item.data['hive'] ?? {};
          response = await http.put(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          );
        } else if (item.actionType == ApiaryActionType.add &&
            endpoint != null &&
            endpoint.contains('/farms')) {
          response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(item.data),
          );
        } else if (item.actionType == ApiaryActionType.edit &&
            endpoint != null &&
            endpoint.contains('/farms')) {
          response = await http.put(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(item.data),
          );
        } else {
          print('Unknown queue item type or missing endpoint, skipping');
          i++;
          continue;
        }

        if (response.statusCode == 201 || response.statusCode == 200) {
          await ApiaryQueueService.removeFromQueue(i);
          print('Queued action synced successfully');
        } else {
          print('Failed to sync queued action: ${response.statusCode}');
          i++;
        }
      } catch (e) {
        print('Error syncing queued action: $e');
        i++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Splashscreen(),
    );
  }
}
