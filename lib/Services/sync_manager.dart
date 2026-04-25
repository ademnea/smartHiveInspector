import 'dart:async';

import 'package:HPGM/Services/connectivity_service.dart';

import 'offline_queue_service.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isInitialized = false;
  bool _wasOffline = false;
  Timer? _syncTimer;

  Function(int)? onSyncProgress;
  Function(bool)? onSyncStatusChanged;
  Function(int)? onQueueCountChanged;
  Function(String)? onSyncFailed;

  static Future<void> initialize() async {
    await _instance._initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) {
      return;
    }

    print('Initializing SyncManager...');

    try {
      await ConnectivityService().initialize();

      _connectivitySubscription = ConnectivityService().connectionStream.listen(
        _onConnectivityChanged,
        onError: (error) {
          print('Connectivity monitoring error: $error');
        },
      );

      final isOnline = await ConnectivityService().hasInternetConnection();
      _wasOffline = !isOnline;

      print(
        'Initial connectivity state: ${_wasOffline ? "Offline" : "Online"}',
      );

      _startPeriodicSync();

      _isInitialized = true;
      print('SyncManager initialized successfully');
    } catch (e) {
      print('Failed to initialize SyncManager: $e');
      _isInitialized = true;
    }
  }

  void _onConnectivityChanged(bool isOnline) async {
    final isCurrentlyOffline = !isOnline;

    print(
      'Connectivity changed: ${isCurrentlyOffline ? "Offline" : "Online"}',
    );

    if (_wasOffline && !isCurrentlyOffline) {
      print('Device came online - triggering sync...');
      await triggerSync();
    }

    _wasOffline = isCurrentlyOffline;
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final queueCount = await OfflineQueueService.getQueueCount();
      if (queueCount > 0) {
        print('Periodic sync check - $queueCount operations queued');
        await triggerSync();
      }
    });
  }

  static Future<void> triggerSync() async {
    await _instance._performSync();
  }

  Future<void> _performSync() async {
    try {
      final queueCount = await OfflineQueueService.getQueueCount();
      if (queueCount == 0) {
        print('No operations to sync');
        return;
      }

      final isOnline = await ConnectivityService().hasInternetConnection();
      if (!isOnline) {
        print('Skipping sync because the device is offline');
        return;
      }

      print('Triggering sync for $queueCount operations...');

      onSyncStatusChanged?.call(true);
      onQueueCountChanged?.call(queueCount);

      final syncedCount = await OfflineQueueService.syncQueuedOperations();
      final remainingCount = await OfflineQueueService.getQueueCount();

      onSyncStatusChanged?.call(false);
      onQueueCountChanged?.call(remainingCount);

      if (syncedCount > 0) {
        print('Sync completed: $syncedCount operations synced');
        if (remainingCount == 0) {
          print('All operations synced successfully');
        } else {
          print('$remainingCount operations remaining (will retry)');
        }
      } else {
        print('Sync failed - no operations were processed');
        onSyncFailed?.call(
          'Sync failed. Your changes could not be sent to the server.',
        );
      }
    } catch (e) {
      print('Sync error: $e');
      onSyncStatusChanged?.call(false);
    }
  }

  static Future<Map<String, dynamic>> getQueueStatus() async {
    final queueCount = await OfflineQueueService.getQueueCount();
    final isSyncing = await OfflineQueueService.isSyncing();

    return {
      'queueCount': queueCount,
      'isSyncing': isSyncing,
      'hasQueuedOperations': queueCount > 0,
    };
  }

  static void setCallbacks({
    Function(int)? onSyncProgress,
    Function(bool)? onSyncStatusChanged,
    Function(int)? onQueueCountChanged,
    Function(String)? onSyncFailed,
  }) {
    _instance.onSyncProgress = onSyncProgress;
    _instance.onSyncStatusChanged = onSyncStatusChanged;
    _instance.onQueueCountChanged = onQueueCountChanged;
    _instance.onSyncFailed = onSyncFailed;
  }

  static void dispose() {
    _instance._dispose();
  }

  void _dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _isInitialized = false;
    print('SyncManager disposed');
  }

  static Future<void> forceSyncAll() async {
    print('Force syncing all queued operations...');
    await _instance._performSync();
  }

  static Future<void> clearQueue() async {
    await OfflineQueueService.clearQueue();
    _instance.onQueueCountChanged?.call(0);
    print('Queue cleared');
  }

  static Future<List<QueuedOperation>> getOperationsByType(
    OperationType type,
  ) async {
    return await OfflineQueueService.getQueuedOperationsByType(type);
  }

  static bool get isInitialized => _instance._isInitialized;
}
