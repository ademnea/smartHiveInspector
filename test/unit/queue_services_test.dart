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

  test('SyncResult stores success, error, and response data', () {
    final success = SyncResult(success: true, responseData: {'id': 1});
    final failure = SyncResult(success: false, error: 'Network error');

    expect(success.success, isTrue);
    expect(success.responseData?['id'], 1);
    expect(failure.success, isFalse);
    expect(failure.error, 'Network error');
  });
}
