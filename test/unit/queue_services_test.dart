import 'package:HPGM/Services/apiary_queue_service.dart';
import 'package:HPGM/Services/offline_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ApiaryQueueItem serializes add and edit actions', () {
    final item = ApiaryQueueItem(
      actionType: ApiaryActionType.edit,
      data: {'name': 'North Apiary'},
      apiaryId: 7,
    );

    final parsed = ApiaryQueueItem.fromJson(item.toJson());

    expect(parsed.actionType, ApiaryActionType.edit);
    expect(parsed.data['name'], 'North Apiary');
    expect(parsed.apiaryId, 7);
  });

  test('ApiaryQueueService adds, reads, removes, and clears queued items', () async {
    await ApiaryQueueService.addToQueue(
      ApiaryQueueItem(
        actionType: ApiaryActionType.add,
        data: {'name': 'New Apiary'},
      ),
    );
    await ApiaryQueueService.addToQueue(
      ApiaryQueueItem(
        actionType: ApiaryActionType.edit,
        data: {'name': 'Edited Apiary'},
        apiaryId: 2,
      ),
    );

    var queue = await ApiaryQueueService.getQueue();
    expect(queue, hasLength(2));
    expect(queue.first.actionType, ApiaryActionType.add);

    await ApiaryQueueService.removeFromQueue(0);
    queue = await ApiaryQueueService.getQueue();
    expect(queue, hasLength(1));
    expect(queue.first.apiaryId, 2);

    await ApiaryQueueService.clearQueue();
    expect(await ApiaryQueueService.getQueue(), isEmpty);
  });

  test('QueuedOperation serializes and increments retry count', () {
    final timestamp = DateTime(2026, 4, 25, 10);
    final operation = QueuedOperation(
      id: 'op-1',
      type: OperationType.CREATE_FARM,
      data: {'name': 'North Apiary'},
      timestamp: timestamp,
      parentId: 'parent-1',
    );

    final parsed = QueuedOperation.fromJson(operation.toJson());
    final retried = parsed.copyWithRetry();

    expect(parsed.id, 'op-1');
    expect(parsed.type, OperationType.CREATE_FARM);
    expect(parsed.data['name'], 'North Apiary');
    expect(parsed.timestamp, timestamp);
    expect(parsed.parentId, 'parent-1');
    expect(retried.retryCount, 1);
  });

  test('OfflineQueueService queues typed operations and reports queue state', () async {
    final createFarmId = await OfflineQueueService.queueCreateFarm({
      'name': 'North Apiary',
    });
    final updateFarmId = await OfflineQueueService.queueUpdateFarm(7, {
      'name': 'Updated Apiary',
    });
    final deleteHiveId = await OfflineQueueService.queueDeleteHive(12);
    final createRecordId = await OfflineQueueService.queueCreateRecord({
      'hive_id': 12,
      'notes': 'Healthy',
    });

    final queue = await OfflineQueueService.getQueue();
    final farmUpdates = await OfflineQueueService.getQueuedOperationsByType(
      OperationType.UPDATE_FARM,
    );

    expect(createFarmId, startsWith('offline_'));
    expect(updateFarmId, startsWith('offline_'));
    expect(deleteHiveId, startsWith('offline_'));
    expect(createRecordId, startsWith('offline_'));
    expect(await OfflineQueueService.getQueueCount(), 4);
    expect(await OfflineQueueService.hasQueuedOperations(), isTrue);
    expect(queue.map((operation) => operation.type), contains(OperationType.CREATE_FARM));
    expect(farmUpdates, hasLength(1));
    expect(farmUpdates.first.data['id'], 7);
  });

  test('OfflineQueueService removes one operation and clears the queue', () async {
    final firstId = await OfflineQueueService.queueCreateFarm({'name': 'One'});
    await OfflineQueueService.queueCreateFarm({'name': 'Two'});

    await OfflineQueueService.removeOperation(firstId);

    var queue = await OfflineQueueService.getQueue();
    expect(queue, hasLength(1));
    expect(queue.first.data['name'], 'Two');

    await OfflineQueueService.clearQueue();
    queue = await OfflineQueueService.getQueue();
    expect(queue, isEmpty);
    expect(await OfflineQueueService.hasQueuedOperations(), isFalse);
  });

  test('OfflineQueueService stores and reads sync status', () async {
    expect(await OfflineQueueService.isSyncing(), isFalse);

    await OfflineQueueService.setSyncStatus(true);
    expect(await OfflineQueueService.isSyncing(), isTrue);

    await OfflineQueueService.setSyncStatus(false);
    expect(await OfflineQueueService.isSyncing(), isFalse);
  });

  test('OfflineQueueService skips malformed queued operation JSON', () async {
    SharedPreferences.setMockInitialValues({
      'offline_operations_queue': [
        '{bad json',
        '{"id":"op-1","type":"OperationType.DELETE_FARM","data":{"id":9},"timestamp":"2026-04-25T10:00:00.000"}',
      ],
    });

    final queue = await OfflineQueueService.getQueue();

    expect(queue, hasLength(1));
    expect(queue.first.type, OperationType.DELETE_FARM);
    expect(queue.first.data['id'], 9);
  });

  test('syncQueuedOperations does not run when already syncing', () async {
    await OfflineQueueService.setSyncStatus(true);
    await OfflineQueueService.queueCreateFarm({'name': 'North Apiary'});

    final synced = await OfflineQueueService.syncQueuedOperations();

    expect(synced, 0);
    expect(await OfflineQueueService.getQueueCount(), 1);
  });

  test('SyncResult stores success, error, and response data', () {
    final success = SyncResult(success: true, responseData: {'id': 1});
    final failure = SyncResult(success: false, error: 'Network error');

    expect(success.success, isTrue);
    expect(success.responseData?['id'], 1);
    expect(failure.success, isFalse);
    expect(failure.error, 'Network error');
  });
}
