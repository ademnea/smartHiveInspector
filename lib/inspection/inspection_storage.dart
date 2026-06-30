//this stores the inspection records
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'inspection_model.dart';

class InspectionStorage {
  static String _keyForHive(String hiveId) => 'inspection_records_$hiveId';

  static Future<void> saveInspection(InspectionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForHive(record.hiveId);
    final existing = prefs.getStringList(key) ?? [];
    existing.add(json.encode(record.toJson()));
    await prefs.setStringList(key, existing);
  }

  static Future<List<InspectionRecord>> getInspections(String hiveId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForHive(hiveId);
    final stored = prefs.getStringList(key) ?? [];
    return stored
        .map((s) => InspectionRecord.fromJson(json.decode(s)))
        .toList();
  }

  static Future<DateTime?> getLastInspectionDate(String hiveId) async {
    final records = await getInspections(hiveId);
    if (records.isEmpty) return null;
    records.sort((a, b) => b.date.compareTo(a.date));
    return records.first.date;
  }
}
