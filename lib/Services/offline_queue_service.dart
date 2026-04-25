import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'auth_manager.dart';
import 'cache_service.dart';

enum OperationType {
  CREATE_FARM,
  UPDATE_FARM,
  DELETE_FARM,
  CREATE_HIVE,
  UPDATE_HIVE,
  DELETE_HIVE,
  CREATE_RECORD,
  UPDATE_RECORD,
  DELETE_RECORD,
}

class QueuedOperation {
  final String id;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
  final String? parentId; // For operations that depend on other objects

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.parentId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
    'parentId': parentId,
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) =>
      QueuedOperation(
        id: json['id'],
        type: OperationType.values.firstWhere(
          (e) => e.toString() == json['type'],
        ),
        data: Map<String, dynamic>.from(json['data']),
        timestamp: DateTime.parse(json['timestamp']),
        retryCount: json['retryCount'] ?? 0,
        parentId: json['parentId'],
      );

  QueuedOperation copyWithRetry() => QueuedOperation(
    id: id,
    type: type,
    data: data,
    timestamp: timestamp,
    retryCount: retryCount + 1,
    parentId: parentId,
  );
}

class SyncResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? responseData;

  SyncResult({required this.success, this.error, this.responseData});
}

class OfflineQueueService {
  static const String _queueKey = 'offline_operations_queue';
  static const String _syncStatusKey = 'sync_status';
  static const int _maxRetries = 3;

  // Singleton pattern
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  // Queue management
  static Future<List<QueuedOperation>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? [];

    return queueJson
        .map((jsonStr) {
          try {
            final json = jsonDecode(jsonStr);
            return QueuedOperation.fromJson(json);
          } catch (e) {
            print('❌ Error parsing queued operation: $e');
            return null;
          }
        })
        .where((op) => op != null)
        .cast<QueuedOperation>()
        .toList();
  }

  static Future<void> _saveQueue(List<QueuedOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = queue.map((op) => jsonEncode(op.toJson())).toList();
    await prefs.setStringList(_queueKey, queueJson);

    print('💾 Saved ${queue.length} operations to offline queue');
  }

  static Future<String> _generateUniqueId() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'offline_${timestamp}_$random';
  }

  // Add operations to queue
  static Future<String> queueOperation({
    required OperationType type,
    required Map<String, dynamic> data,
    String? parentId,
  }) async {
    final operation = QueuedOperation(
      id: await _generateUniqueId(),
      type: type,
      data: Map<String, dynamic>.from(data),
      timestamp: DateTime.now(),
      parentId: parentId,
    );

    final queue = await getQueue();
    queue.add(operation);
    await _saveQueue(queue);

    print('📥 Queued ${type.toString()} operation: ${operation.id}');
    return operation.id;
  }

  // Queue specific operations
  static Future<String> queueCreateFarm(Map<String, dynamic> farmData) async {
    return await queueOperation(
      type: OperationType.CREATE_FARM,
      data: farmData,
    );
  }

  static Future<String> queueUpdateFarm(
    int farmId,
    Map<String, dynamic> farmData,
  ) async {
    return await queueOperation(
      type: OperationType.UPDATE_FARM,
      data: {'id': farmId, ...farmData},
    );
  }

  static Future<String> queueDeleteFarm(int farmId) async {
    return await queueOperation(
      type: OperationType.DELETE_FARM,
      data: {'id': farmId},
    );
  }

  static Future<String> queueCreateHive(Map<String, dynamic> hiveData) async {
    return await queueOperation(
      type: OperationType.CREATE_HIVE,
      data: hiveData,
    );
  }

  static Future<String> queueUpdateHive(
    int hiveId,
    Map<String, dynamic> hiveData,
  ) async {
    return await queueOperation(
      type: OperationType.UPDATE_HIVE,
      data: {'id': hiveId, ...hiveData},
    );
  }

  static Future<String> queueDeleteHive(int hiveId) async {
    return await queueOperation(
      type: OperationType.DELETE_HIVE,
      data: {'id': hiveId},
    );
  }

  static Future<String> queueCreateRecord(
    Map<String, dynamic> recordData,
  ) async {
    return await queueOperation(
      type: OperationType.CREATE_RECORD,
      data: recordData,
    );
  }

  // Get queue status
  static Future<int> getQueueCount() async {
    final queue = await getQueue();
    return queue.length;
  }

  static Future<bool> hasQueuedOperations() async {
    return (await getQueueCount()) > 0;
  }

  static Future<List<QueuedOperation>> getQueuedOperationsByType(
    OperationType type,
  ) async {
    final queue = await getQueue();
    return queue.where((op) => op.type == type).toList();
  }

  // Clear queue
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    print('🗑️ Cleared offline queue');
  }

  static Future<void> removeOperation(String operationId) async {
    final queue = await getQueue();
    queue.removeWhere((op) => op.id == operationId);
    await _saveQueue(queue);
    print('🗑️ Removed operation $operationId from queue');
  }

  // Sync status management
  static Future<void> setSyncStatus(bool isSyncing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncStatusKey, isSyncing);
  }

  static Future<bool> isSyncing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncStatusKey) ?? false;
  }

  // Execute single operation
  static Future<SyncResult> _executeOperation(QueuedOperation operation) async {
    try {
      print('🔄 Executing ${operation.type} operation: ${operation.id}');

      switch (operation.type) {
        case OperationType.CREATE_FARM:
          return await _executeCreateFarm(operation);
        case OperationType.UPDATE_FARM:
          return await _executeUpdateFarm(operation);
        case OperationType.DELETE_FARM:
          return await _executeDeleteFarm(operation);
        case OperationType.CREATE_HIVE:
          return await _executeCreateHive(operation);
        case OperationType.UPDATE_HIVE:
          return await _executeUpdateHive(operation);
        case OperationType.DELETE_HIVE:
          return await _executeDeleteHive(operation);
        case OperationType.CREATE_RECORD:
          return await _executeCreateRecord(operation);
        case OperationType.UPDATE_RECORD:
          return await _executeUpdateRecord(operation);
        case OperationType.DELETE_RECORD:
          return await _executeDeleteRecord(operation);
      }
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    }
  }

  // Execute farm operations
  static Future<SyncResult> _executeCreateFarm(
    QueuedOperation operation,
  ) async {
    final response = await AuthManager.post(
      'http://196.43.168.57/api/v1/farms',
      body: operation.data,
    );

    if (response != null && response.statusCode == 201) {
      final responseData = jsonDecode(response.body);

      // Update local cache with the new farm
      final farms = await CacheService.loadFarms() ?? [];
      farms.add(responseData);
      await CacheService.saveFarms(farms);

      return SyncResult(success: true, responseData: responseData);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to create farm: ${response?.statusCode}',
      );
    }
  }

  static Future<SyncResult> _executeUpdateFarm(
    QueuedOperation operation,
  ) async {
    final farmId = operation.data['id'];
    final updateData = Map<String, dynamic>.from(operation.data);
    updateData.remove('id');

    final response = await AuthManager.put(
      'http://196.43.168.57/api/v1/farms/$farmId',
      body: updateData,
    );

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 201)) {
      final responseData = jsonDecode(response.body);

      // Update local cache
      final farms = await CacheService.loadFarms() ?? [];
      final farmIndex = farms.indexWhere((farm) => farm['id'] == farmId);
      if (farmIndex != -1) {
        farms[farmIndex] = responseData;
        await CacheService.saveFarms(farms);
      }

      return SyncResult(success: true, responseData: responseData);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to update farm: ${response?.statusCode}',
      );
    }
  }

  static Future<SyncResult> _executeDeleteFarm(
    QueuedOperation operation,
  ) async {
    final farmId = operation.data['id'];

    final response = await AuthManager.delete(
      'http://196.43.168.57/api/v1/farms/$farmId',
    );

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 204)) {
      // Remove from local cache
      final farms = await CacheService.loadFarms() ?? [];
      farms.removeWhere((farm) => farm['id'] == farmId);
      await CacheService.saveFarms(farms);

      return SyncResult(success: true);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to delete farm: ${response?.statusCode}',
      );
    }
  }

  // Execute hive operations
  static Future<SyncResult> _executeCreateHive(
    QueuedOperation operation,
  ) async {
    final response = await AuthManager.post(
      'http://196.43.168.57/api/v1/hives',
      body: operation.data,
    );

    if (response != null && response.statusCode == 201) {
      final responseData = jsonDecode(response.body);

      // Update local cache with the new hive
      final farmId = operation.data['farm_id'];
      if (farmId != null) {
        final hives = await CacheService.loadHives(farmId) ?? [];
        hives.add(responseData);
        await CacheService.saveHives(farmId, hives);
      }

      return SyncResult(success: true, responseData: responseData);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to create hive: ${response?.statusCode}',
      );
    }
  }

  static Future<SyncResult> _executeUpdateHive(
    QueuedOperation operation,
  ) async {
    final hiveId = operation.data['id'];
    final updateData = Map<String, dynamic>.from(operation.data);
    updateData.remove('id');

    final response = await AuthManager.put(
      'http://196.43.168.57/api/v1/hives/$hiveId',
      body: updateData,
    );

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 201)) {
      final responseData = jsonDecode(response.body);

      // Update local cache
      final farmId = operation.data['farm_id'];
      if (farmId != null) {
        final hives = await CacheService.loadHives(farmId) ?? [];
        final hiveIndex = hives.indexWhere((hive) => hive['id'] == hiveId);
        if (hiveIndex != -1) {
          hives[hiveIndex] = responseData;
          await CacheService.saveHives(farmId, hives);
        }
      }

      return SyncResult(success: true, responseData: responseData);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to update hive: ${response?.statusCode}',
      );
    }
  }

  static Future<SyncResult> _executeDeleteHive(
    QueuedOperation operation,
  ) async {
    final hiveId = operation.data['id'];

    final response = await AuthManager.delete(
      'http://196.43.168.57/api/v1/hives/$hiveId',
    );

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 204)) {
      // Remove from local cache
      final farmId = operation.data['farm_id'];
      if (farmId != null) {
        final hives = await CacheService.loadHives(farmId) ?? [];
        hives.removeWhere((hive) => hive['id'] == hiveId);
        await CacheService.saveHives(farmId, hives);
      }

      return SyncResult(success: true);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to delete hive: ${response?.statusCode}',
      );
    }
  }

  // Execute record operations
  static Future<SyncResult> _executeCreateRecord(
    QueuedOperation operation,
  ) async {
    final response = await AuthManager.post(
      'http://196.43.168.57/api/v1/records',
      body: operation.data,
    );

    if (response != null && response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return SyncResult(success: true, responseData: responseData);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to create record: ${response?.statusCode}',
      );
    }
  }

  static Future<SyncResult> _executeUpdateRecord(
    QueuedOperation operation,
  ) async {
    final recordId = operation.data['id'];
    final updateData = Map<String, dynamic>.from(operation.data);
    updateData.remove('id');

    final response = await AuthManager.put(
      'http://196.43.168.57/api/v1/records/$recordId',
      body: updateData,
    );

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 201)) {
      final responseData = jsonDecode(response.body);
      return SyncResult(success: true, responseData: responseData);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to update record: ${response?.statusCode}',
      );
    }
  }

  static Future<SyncResult> _executeDeleteRecord(
    QueuedOperation operation,
  ) async {
    final recordId = operation.data['id'];

    final response = await AuthManager.delete(
      'http://196.43.168.57/api/v1/records/$recordId',
    );

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 204)) {
      return SyncResult(success: true);
    } else {
      return SyncResult(
        success: false,
        error: 'Failed to delete record: ${response?.statusCode}',
      );
    }
  }

  // Main sync function
  static Future<int> syncQueuedOperations() async {
    if (await isSyncing()) {
      print('⏳ Sync already in progress, skipping...');
      return 0;
    }

    // Check connectivity
    final isOnline = await CacheService.isOnline();
    if (!isOnline) {
      print('📴 Device is offline, cannot sync');
      return 0;
    }

    await setSyncStatus(true);

    try {
      final queue = await getQueue();
      if (queue.isEmpty) {
        print('✅ No operations to sync');
        return 0;
      }

      print('🚀 Starting sync of ${queue.length} operations...');

      int successCount = 0;
      final failedOperations = <QueuedOperation>[];

      // Process operations in order
      for (final operation in queue) {
        final result = await _executeOperation(operation);

        if (result.success) {
          print('✅ Successfully synced operation: ${operation.id}');
          successCount++;
        } else {
          print(
            '❌ Failed to sync operation: ${operation.id} - ${result.error}',
          );

          // Retry logic
          if (operation.retryCount < _maxRetries) {
            failedOperations.add(operation.copyWithRetry());
            print(
              '🔄 Will retry operation: ${operation.id} (attempt ${operation.retryCount + 1}/$_maxRetries)',
            );
          } else {
            print('💀 Max retries exceeded for operation: ${operation.id}');
          }
        }
      }

      // Update queue with failed operations
      await _saveQueue(failedOperations);

      print(
        '🎯 Sync completed: $successCount/${queue.length} operations successful',
      );
      return successCount;
    } catch (e) {
      print('❌ Sync error: $e');
      return 0;
    } finally {
      await setSyncStatus(false);
    }
  }
}
