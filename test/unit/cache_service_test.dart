import 'package:HPGM/Services/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveFarms and loadFarms persist farm cache data', () async {
    await CacheService.saveFarms([
      {'id': 1, 'name': 'North Apiary'},
      {'id': 2, 'name': 'South Apiary'},
    ]);

    final farms = await CacheService.loadFarms();
    final updatedAt = await CacheService.getLastUpdateTime('farms');

    expect(farms, hasLength(2));
    expect(farms?.first['name'], 'North Apiary');
    expect(updatedAt, isNotNull);
  });

  test('saveHives and loadHives persist per-farm hive cache data', () async {
    await CacheService.saveHives(7, [
      {'id': 12, 'farm_id': 7},
    ]);

    final hives = await CacheService.loadHives(7);

    expect(hives, hasLength(1));
    expect(hives?.first['id'], 12);
  });

  test('saveData loadData hasCachedData and clearCache manage generic cache', () async {
    await CacheService.saveData('dashboard', {'hives': 12});

    expect(await CacheService.hasCachedData('dashboard'), isTrue);
    expect(await CacheService.loadData('dashboard'), {'hives': 12});
    expect(await CacheService.getLastUpdateTime('dashboard'), isNotNull);

    await CacheService.clearCache();

    expect(await CacheService.hasCachedData('dashboard'), isFalse);
    expect(await CacheService.loadData('dashboard'), isNull);
  });

  test('load methods return null for malformed cached JSON', () async {
    SharedPreferences.setMockInitialValues({
      'cached_farms': '{bad json',
      'cached_hives_farm_3': '{bad json',
      'cached_dashboard': '{bad json',
    });

    expect(await CacheService.loadFarms(), isNull);
    expect(await CacheService.loadHives(3), isNull);
    expect(await CacheService.loadData('dashboard'), isNull);
  });
}
