import 'dart:async';

import 'package:HPGM/analytics/foraging_advisory_service.dart';

class MainAppServiceBridge {
  static final MainAppServiceBridge _instance =
      MainAppServiceBridge._internal();
  factory MainAppServiceBridge() => _instance;
  MainAppServiceBridge._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
    print('Main app service bridge initialized in model-free mode');
  }

  Future<void> onAppResumed() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<void> onAppPaused() async {
    print('Main app paused');
  }

  Future<bool> isServiceActive() async {
    return false;
  }

  Future<bool> hasNewRecommendations() async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      final data = await advisoryService.getDailyForagingAnalysis(
        '1',
        DateTime.now(),
      );

      if (data == null || data.recommendations.isEmpty) {
        return false;
      }

      final criticalRecommendations = data.recommendations
          .where((r) => r.priority == 'Critical' || r.priority == 'High')
          .length;

      print(
        'Found $criticalRecommendations critical/high priority recommendations',
      );
      return criticalRecommendations > 0;
    } catch (e) {
      print('Error checking recommendations: $e');
      return false;
    }
  }

  Future<List<DailyRecommendation>?> getCurrentRecommendations({
    String? hiveId,
  }) async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      final data = await advisoryService.getDailyForagingAnalysis(
        hiveId ?? '1',
        DateTime.now(),
      );
      return data?.recommendations;
    } catch (e) {
      print('Error getting current recommendations: $e');
      return null;
    }
  }

  Future<DailyForagingAnalysis?> getForagingAnalysis({
    required String hiveId,
    DateTime? date,
  }) async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      return await advisoryService.getDailyForagingAnalysis(
        hiveId,
        date ?? DateTime.now(),
      );
    } catch (e) {
      print('Error getting foraging analysis: $e');
      return null;
    }
  }

  Future<void> triggerManualCheck() async {
    if (!_isInitialized) {
      print('Bridge not initialized');
      return;
    }

    print('Manual video checks are disabled in model-free mode');
  }

  Future<bool> hasCriticalAlerts() async {
    try {
      final recommendations = await getCurrentRecommendations();
      return recommendations?.any((r) => r.priority == 'Critical') ?? false;
    } catch (e) {
      print('Error checking critical alerts: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTodaysSummary({String? hiveId}) async {
    try {
      final data = await getForagingAnalysis(hiveId: hiveId ?? '1');

      if (data == null) {
        return null;
      }

      final totalActivity = data.beeCountData.fold<int>(
        0,
        (sum, hour) => sum + hour.totalActivity,
      );
      final totalEntering = data.beeCountData.fold<int>(
        0,
        (sum, hour) => sum + hour.beesEntering,
      );
      final totalExiting = data.beeCountData.fold<int>(
        0,
        (sum, hour) => sum + hour.beesExiting,
      );
      final criticalRecommendations =
          data.recommendations.where((r) => r.priority == 'Critical').length;
      final highRecommendations =
          data.recommendations.where((r) => r.priority == 'High').length;

      return {
        'date': data.date.toIso8601String(),
        'totalActivity': totalActivity,
        'totalEntering': totalEntering,
        'totalExiting': totalExiting,
        'netChange': totalEntering - totalExiting,
        'peakActivityHour': data.foragingPatterns.peakActivityHour,
        'weightChange': data.weightAnalysis.dailyChange,
        'criticalRecommendations': criticalRecommendations,
        'highRecommendations': highRecommendations,
        'totalRecommendations': data.recommendations.length,
        'foragingAssessment':
            data.foragingPatterns.overallForagingAssessment,
        'nectarFlowStatus': data.foragingPatterns.nectarFlowAnalysis.status,
        'lastUpdated': data.lastUpdated.toIso8601String(),
      };
    } catch (e) {
      print("Error getting today's summary: $e");
      return null;
    }
  }

  Stream<List<DailyRecommendation>> get recommendationStream {
    return Stream.periodic(const Duration(minutes: 15), (_) async {
      return await getCurrentRecommendations();
    }).asyncMap((future) => future).where((recommendations) {
      return recommendations != null;
    }).cast<List<DailyRecommendation>>();
  }

  void dispose() {
    print('Disposing main app service bridge');
    _isInitialized = false;
  }
}
