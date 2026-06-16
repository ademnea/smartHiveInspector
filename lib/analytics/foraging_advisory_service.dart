// This file contains all foraging analysis models and services
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================
// ENUMS
// ============================================
enum Season { spring, summer, fall, winter }
enum Priority { critical, high, medium, low }
enum RecommendationType { immediate, environmental, optimization, urgent, seasonal }

// ============================================
// DATA MODELS
// ============================================
class PlantRecommendation {
  final String name;
  final String plantingTime;
  final String bloomPeriod;
  final String nectarValue;
  final String pollenValue;
  final String scientificBasis;
  final String plantingInstructions;

  const PlantRecommendation({
    required this.name,
    required this.plantingTime,
    required this.bloomPeriod,
    required this.nectarValue,
    required this.pollenValue,
    required this.scientificBasis,
    required this.plantingInstructions,
  });
}

class TimestampedParameter {
  final DateTime timestamp;
  final double value;
  final String type;

  TimestampedParameter({
    required this.timestamp,
    required this.value,
    required this.type,
  });
}

class HourlyBeeActivity {
  final int hour;
  final int beesEntering;
  final int beesExiting;
  final int totalActivity;
  final int netChange;
  final double confidence;
  final int videoCount;
  final DateTime timestamp;

  HourlyBeeActivity({
    required this.hour,
    required this.beesEntering,
    required this.beesExiting,
    required this.totalActivity,
    required this.netChange,
    required this.confidence,
    required this.videoCount,
    required this.timestamp,
  });
}

class DailyRecommendation {
  final String id;
  final String priority;
  final String title;
  final String description;
  final List<String> actionItems;
  final String scientificBasis;
  final String expectedOutcome;
  final String timeRelevance;
  final String foragingImpact;

  DailyRecommendation({
    required this.id,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionItems,
    required this.scientificBasis,
    required this.expectedOutcome,
    required this.timeRelevance,
    required this.foragingImpact,
  });
}

class ForageDistanceIndicator {
  final int hour;
  final double enteringRatio;
  final double exitingRatio;
  final String distanceAssessment;
  final String reasoning;
  final double confidence;

  ForageDistanceIndicator({
    required this.hour,
    required this.enteringRatio,
    required this.exitingRatio,
    required this.distanceAssessment,
    required this.reasoning,
    required this.confidence,
  });
}

class NectarFlowAnalysis {
  final String status;
  final String intensity;
  final List<int> peakHours;
  final String reasoning;

  NectarFlowAnalysis({
    required this.status,
    required this.intensity,
    required this.peakHours,
    required this.reasoning,
  });
}

class ForagingPatternAnalysis {
  final Map<int, ForageDistanceIndicator> foragingDistanceIndicators;
  final int peakActivityHour;
  final NectarFlowAnalysis nectarFlowAnalysis;
  final String overallForagingAssessment;

  ForagingPatternAnalysis({
    required this.foragingDistanceIndicators,
    required this.peakActivityHour,
    required this.nectarFlowAnalysis,
    required this.overallForagingAssessment,
  });
}

class TimeSyncedCorrelations {
  final double temperatureActivity;
  final double temperatureEntering;
  final double temperatureExiting;
  final double humidityActivity;
  final double humidityEntering;
  final double humidityExiting;
  final Map<int, double> hourlyTemperature;
  final Map<int, double> hourlyHumidity;

  TimeSyncedCorrelations({
    required this.temperatureActivity,
    required this.temperatureEntering,
    required this.temperatureExiting,
    required this.humidityActivity,
    required this.humidityEntering,
    required this.humidityExiting,
    required this.hourlyTemperature,
    required this.hourlyHumidity,
  });
}

class WeightAnalysis {
  final double currentWeight;
  final double dailyChange;
  final String interpretation;
  final String activityCorrelation;
  final List<String> recommendations;

  WeightAnalysis({
    required this.currentWeight,
    required this.dailyChange,
    required this.interpretation,
    required this.activityCorrelation,
    required this.recommendations,
  });
}

class WeeklyTrendAnalysis {
  final double averageDailyActivity;
  final double trendPercentage;
  final int maxDayActivity;
  final int minDayActivity;
  final double consistency;
  final int daysWithData;
  final int totalWeeklyActivity;

  WeeklyTrendAnalysis({
    required this.averageDailyActivity,
    required this.trendPercentage,
    required this.maxDayActivity,
    required this.minDayActivity,
    required this.consistency,
    required this.daysWithData,
    required this.totalWeeklyActivity,
  });

  factory WeeklyTrendAnalysis.empty() {
    return WeeklyTrendAnalysis(
      averageDailyActivity: 0.0,
      trendPercentage: 0.0,
      maxDayActivity: 0,
      minDayActivity: 0,
      consistency: 0.0,
      daysWithData: 0,
      totalWeeklyActivity: 0,
    );
  }
}

class DailyForagingAnalysis {
  final String hiveId;
  final DateTime date;
  final List<TimestampedParameter> temperatureData;
  final List<TimestampedParameter> humidityData;
  final List<TimestampedParameter> weightData;
  final List<HourlyBeeActivity> beeCountData;
  final ForagingPatternAnalysis foragingPatterns;
  final TimeSyncedCorrelations correlations;
  final WeightAnalysis weightAnalysis;
  final List<DailyRecommendation> recommendations;
  final DateTime lastUpdated;
  final WeeklyTrendAnalysis weeklyTrends;

  DailyForagingAnalysis({
    required this.hiveId,
    required this.date,
    required this.temperatureData,
    required this.humidityData,
    required this.weightData,
    required this.beeCountData,
    required this.foragingPatterns,
    required this.correlations,
    required this.weightAnalysis,
    required this.recommendations,
    required this.lastUpdated,
    required this.weeklyTrends,
  });
}

// ============================================
// MAIN SERVICE
// ============================================
class EnhancedForagingAdvisoryService {
  static final EnhancedForagingAdvisoryService _instance =
      EnhancedForagingAdvisoryService._internal();
  factory EnhancedForagingAdvisoryService() => _instance;
  EnhancedForagingAdvisoryService._internal();

  List<DailyRecommendation> _recommendations = [];
  List<DailyRecommendation> get recommendations => _recommendations;

  final String baseUrl = 'http://196.43.168.57/api/v1';

  static const Map<String, Map<String, double>> enhancedThresholds = {
    'temperature': {
      'optimalMin': 15.0,
      'optimalMax': 30.0,
      'peakForagingMin': 20.0,
      'peakForagingMax': 25.0,
      'criticalHigh': 35.0,
      'criticalLow': 10.0,
      'heatStressThreshold': 32.0,
    },
    'humidity': {
      'optimalMin': 40.0,
      'optimalMax': 70.0,
      'foragingMin': 30.0,
      'foragingMax': 80.0,
      'flightImpairment': 85.0,
    },
    'weight': {
      'dailyGainForaging': 0.2,
      'dailyLossThreshold': -0.1,
      'hourlyGainPeak': 0.05,
      'honeyRipening': -0.02,
    },
    'activity': {
      'lowActivity': 20.0,
      'moderateActivity': 50.0,
      'highActivity': 100.0,
      'peakActivity': 150.0,
      'weeklyDeclineThreshold': -25.0,
      'weeklyGrowthTarget': 10.0,
    },
    'foraging_patterns': {
      'closeForageRatio': 1.5,
      'distantForageRatio': 0.8,
      'scoutingActivity': 0.3,
      'nectarFlowRatio': 2.0,
    },
  };

  static const Map<String, List<PlantRecommendation>> seasonalPlants = {
    'spring': [
      PlantRecommendation(
        name: 'Willow (Salix spp.)',
        plantingTime: 'Early Spring',
        bloomPeriod: 'March-April',
        nectarValue: 'High',
        pollenValue: 'Excellent',
        scientificBasis: 'Early pollen source crucial for brood development',
        plantingInstructions: 'Plant near water sources, space 3-5m apart',
      ),
      PlantRecommendation(
        name: 'Dandelion (Taraxacum officinale)',
        plantingTime: 'Fall or Early Spring',
        bloomPeriod: 'April-June',
        nectarValue: 'Good',
        pollenValue: 'Excellent',
        scientificBasis: 'Provides 25% of spring pollen needs in temperate regions',
        plantingInstructions: 'Allow natural growth in designated areas',
      ),
      PlantRecommendation(
        name: 'Apple Trees (Malus domestica)',
        plantingTime: 'Fall or Early Spring',
        bloomPeriod: 'April-May',
        nectarValue: 'Excellent',
        pollenValue: 'Good',
        scientificBasis: 'Single tree can support 2-3 colonies during bloom',
        plantingInstructions: 'Plant multiple varieties for extended bloom',
      ),
    ],
    'summer': [
      PlantRecommendation(
        name: 'Linden/Basswood (Tilia americana)',
        plantingTime: 'Spring',
        bloomPeriod: 'June-July',
        nectarValue: 'Outstanding',
        pollenValue: 'Good',
        scientificBasis: 'Can produce 40kg honey per tree in good years',
        plantingInstructions: 'Long-term investment, plant in groups',
      ),
      PlantRecommendation(
        name: 'White Clover (Trifolium repens)',
        plantingTime: 'Spring',
        bloomPeriod: 'May-September',
        nectarValue: 'Excellent',
        pollenValue: 'Good',
        scientificBasis: 'Primary honey source, produces 200kg/hectare',
        plantingInstructions: 'Seed in pastures and field margins',
      ),
      PlantRecommendation(
        name: 'Sunflower (Helianthus annuus)',
        plantingTime: 'Late Spring',
        bloomPeriod: 'July-September',
        nectarValue: 'Good',
        pollenValue: 'Excellent',
        scientificBasis: 'High protein pollen essential for late season brood',
        plantingInstructions: 'Plant succession crops every 2 weeks',
      ),
    ],
    'fall': [
      PlantRecommendation(
        name: 'Goldenrod (Solidago spp.)',
        plantingTime: 'Spring',
        bloomPeriod: 'August-October',
        nectarValue: 'Good',
        pollenValue: 'Excellent',
        scientificBasis: 'Critical for winter bee protein stores',
        plantingInstructions: 'Allow natural establishment in field edges',
      ),
      PlantRecommendation(
        name: 'Asters (Symphyotrichum spp.)',
        plantingTime: 'Spring',
        bloomPeriod: 'September-October',
        nectarValue: 'Good',
        pollenValue: 'Very Good',
        scientificBasis: 'Late season pollen for winter bee development',
        plantingInstructions: 'Plant diverse species for extended bloom',
      ),
    ],
  };

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> getToken() async {
    return _getToken();
  }

  // ============================================
  // MAIN ANALYSIS METHOD
  // ============================================
  Future<DailyForagingAnalysis?> getDailyForagingAnalysis(
    String hiveId,
    DateTime date,
  ) async {
    try {
      print(' GENERATING ENHANCED DAILY FORAGING ANALYSIS ');
      print('Hive: $hiveId, Date: ${DateFormat('yyyy-MM-dd').format(date)}');

      final token = await _getToken();
      if (token == null) {
        print('No authentication token found');
        return null;
      }

      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final temperatureData = await _fetchLatestTemperatureData(
        hiveId, token, startDate, endDate
      );
      final humidityData = await _fetchLatestHumidityData(
        hiveId, token, startDate, endDate
      );
      final weightData = await _fetchLatestWeightData(hiveId, token);
      final beeCountData = await _fetchHourlyBeeCountData(hiveId, date);
      final weeklyTrendData = await _fetchWeeklyTrendData(hiveId, date);

      print(
        'Enhanced data retrieved for ${DateFormat('yyyy-MM-dd').format(date)}: '
        'temp=${temperatureData.length}, humidity=${humidityData.length}, '
        'weight=${weightData.length}, beeCount=${beeCountData.length}',
      );

      if (beeCountData.isEmpty && temperatureData.isEmpty && humidityData.isEmpty) {
        print('No data available for analysis');
        return null;
      }

      final foragingPatterns = _analyzeForagingPatterns(
        beeCountData, temperatureData, humidityData
      );

      final correlations = _calculateTimeSyncedCorrelations(
        temperatureData, humidityData, weightData, beeCountData, date
      );

      final weightAnalysis = _analyzeWeightChanges(weightData, beeCountData, date);

      final recommendations = _generateEnhancedDailyRecommendations(
        date,
        beeCountData,
        temperatureData,
        humidityData,
        weightAnalysis,
        foragingPatterns,
        correlations,
        weeklyTrendData,
      );

      _recommendations = recommendations;

      return DailyForagingAnalysis(
        hiveId: hiveId,
        date: date,
        temperatureData: temperatureData,
        humidityData: humidityData,
        weightData: weightData,
        beeCountData: beeCountData,
        foragingPatterns: foragingPatterns,
        correlations: correlations,
        weightAnalysis: weightAnalysis,
        recommendations: recommendations,
        lastUpdated: DateTime.now(),
        weeklyTrends: weeklyTrendData,
      );
    } catch (e, stack) {
      print('Error generating enhanced daily foraging analysis: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  // ============================================
  // DATA FETCHING METHODS
  // ============================================
  Future<List<TimestampedParameter>> _fetchLatestTemperatureData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      final response = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/temperature/$startDateStr/$endDateStr'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(
                dataPoint['date'] ?? dataPoint['timestamp'],
              );
              final temperature = double.tryParse(
                dataPoint['temperature']?.toString() ?? '0'
              );
              if (temperature != null && temperature > -50 && temperature < 100) {
                parameters.add(TimestampedParameter(
                  timestamp: timestamp,
                  value: temperature,
                  type: 'temperature',
                ));
              }
            } catch (e) {
              print('Error parsing temperature data point: $e');
            }
          }
        }
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return parameters;
      }
    } catch (e) {
      print('Error fetching temperature data: $e');
    }
    return [];
  }

  Future<List<TimestampedParameter>> _fetchLatestHumidityData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      final response = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/humidity/$startDateStr/$endDateStr'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(
                dataPoint['date'] ?? dataPoint['timestamp'],
              );
              final humidity = double.tryParse(
                dataPoint['humidity']?.toString() ?? '0'
              );
              if (humidity != null && humidity >= 0 && humidity <= 100) {
                parameters.add(TimestampedParameter(
                  timestamp: timestamp,
                  value: humidity,
                  type: 'humidity',
                ));
              }
            } catch (e) {
              print('Error parsing humidity data point: $e');
            }
          }
        }
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return parameters;
      }
    } catch (e) {
      print('Error fetching humidity data: $e');
    }
    return [];
  }

  Future<List<TimestampedParameter>> _fetchLatestWeightData(
    String hiveId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/latest-weight'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final latestData = jsonDecode(response.body);
        double? weight;
        if (latestData['record'] != null) {
          weight = double.tryParse(latestData['record'].toString());
        }
        DateTime? timestamp;
        if (latestData['date_collected'] != null) {
          try {
            timestamp = DateTime.parse(latestData['date_collected'].toString());
          } catch (e) {
            timestamp = DateTime.now();
          }
        } else {
          timestamp = DateTime.now();
        }
        if (weight != null && weight > 0) {
          return [TimestampedParameter(
            timestamp: timestamp!,
            value: weight,
            type: 'weight',
          )];
        }
      }
    } catch (e) {
      print('Error fetching weight data: $e');
    }
    return [];
  }

  Future<List<HourlyBeeActivity>> _fetchHourlyBeeCountData(
    String hiveId,
    DateTime date,
  ) async {
    try {
      final beeCounts = await BeeCountDatabase.instance.readBeeCountsByDate(date);
      final hiveCounts = beeCounts.where((count) => count.hiveId == hiveId).toList();

      if (hiveCounts.isEmpty) return [];

      final hourlyData = <int, List<BeeCount>>{};
      for (final count in hiveCounts) {
        final hour = count.timestamp.hour;
        if (!hourlyData.containsKey(hour)) {
          hourlyData[hour] = [];
        }
        hourlyData[hour]!.add(count);
      }

      final List<HourlyBeeActivity> hourlyActivities = [];
      for (int hour = 0; hour < 24; hour++) {
        final hourData = hourlyData[hour] ?? [];
        int totalEntering = 0;
        int totalExiting = 0;
        double avgConfidence = 0.0;

        for (final count in hourData) {
          totalEntering += count.beesEntering;
          totalExiting += count.beesExiting;
          avgConfidence += count.confidence;
        }

        if (hourData.isNotEmpty) {
          avgConfidence /= hourData.length;
          hourlyActivities.add(HourlyBeeActivity(
            hour: hour,
            beesEntering: totalEntering,
            beesExiting: totalExiting,
            totalActivity: totalEntering + totalExiting,
            netChange: totalEntering - totalExiting,
            confidence: avgConfidence,
            videoCount: hourData.length,
            timestamp: DateTime(date.year, date.month, date.day, hour),
          ));
        }
      }
      hourlyActivities.sort((a, b) => a.hour.compareTo(b.hour));
      return hourlyActivities;
    } catch (e) {
      print('Error fetching hourly bee count data: $e');
      return [];
    }
  }

  Future<WeeklyTrendAnalysis> _fetchWeeklyTrendData(
    String hiveId,
    DateTime currentDate,
  ) async {
    try {
      final endDate = currentDate;
      final startDate = currentDate.subtract(Duration(days: 7));

      final weeklyBeeCounts = await BeeCountDatabase.instance
          .getBeeCountsForDateRange(hiveId, startDate, endDate);

      if (weeklyBeeCounts.isEmpty) {
        return WeeklyTrendAnalysis.empty();
      }

      final Map<DateTime, int> dailyTotals = {};
      for (final count in weeklyBeeCounts) {
        final day = DateTime(count.timestamp.year, count.timestamp.month, count.timestamp.day);
        dailyTotals[day] = (dailyTotals[day] ?? 0) + count.beesEntering + count.beesExiting;
      }

      final sortedDays = dailyTotals.keys.toList()..sort();
      final dailyValues = sortedDays.map((day) => dailyTotals[day]!).toList();

      if (dailyValues.length < 2) {
        return WeeklyTrendAnalysis.empty();
      }

      final firstHalfAvg = dailyValues.take(dailyValues.length ~/ 2).reduce((a, b) => a + b) / (dailyValues.length ~/ 2);
      final secondHalfAvg = dailyValues.skip(dailyValues.length ~/ 2).reduce((a, b) => a + b) / (dailyValues.length - dailyValues.length ~/ 2);
      final trendChange = ((secondHalfAvg - firstHalfAvg) / firstHalfAvg) * 100;

      final weeklyAverage = dailyValues.reduce((a, b) => a + b) / dailyValues.length;
      final maxDay = dailyValues.reduce((a, b) => a > b ? a : b);
      final minDay = dailyValues.reduce((a, b) => a < b ? a : b);
      final variance = _calculateVariance(dailyValues);

      return WeeklyTrendAnalysis(
        averageDailyActivity: weeklyAverage,
        trendPercentage: trendChange,
        maxDayActivity: maxDay,
        minDayActivity: minDay,
        consistency: 100 - (variance / weeklyAverage * 100),
        daysWithData: dailyValues.length,
        totalWeeklyActivity: dailyValues.reduce((a, b) => a + b),
      );
    } catch (e) {
      print('Error fetching weekly trend data: $e');
      return WeeklyTrendAnalysis.empty();
    }
  }

  double _calculateVariance(List<int> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((value) => pow(value - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  // ============================================
  // ANALYSIS METHODS
  // ============================================
  ForagingPatternAnalysis _analyzeForagingPatterns(
    List<HourlyBeeActivity> beeData,
    List<TimestampedParameter> temperatureData,
    List<TimestampedParameter> humidityData,
  ) {
    if (beeData.isEmpty) {
      return ForagingPatternAnalysis(
        foragingDistanceIndicators: {},
        peakActivityHour: 12,
        nectarFlowAnalysis: NectarFlowAnalysis(
          status: 'No Data',
          intensity: 'Unknown',
          peakHours: [],
          reasoning: 'No bee activity data available',
        ),
        overallForagingAssessment: 'Insufficient data for analysis',
      );
    }

    int peakActivityHour = 12;
    int maxActivity = 0;
    for (final activity in beeData) {
      if (activity.totalActivity > maxActivity) {
        maxActivity = activity.totalActivity;
        peakActivityHour = activity.hour;
      }
    }

    final Map<int, ForageDistanceIndicator> distanceIndicators = {};
    for (final activity in beeData) {
      if (activity.totalActivity > 0) {
        final enteringRatio = activity.beesEntering / activity.totalActivity;
        final exitingRatio = activity.beesExiting / activity.totalActivity;

        String distanceAssessment;
        String reasoning;

        if (enteringRatio > enhancedThresholds['foraging_patterns']!['closeForageRatio']!) {
          distanceAssessment = 'Close Forage';
          reasoning = 'High entering ratio suggests bees returning from nearby sources';
        } else if (enteringRatio < enhancedThresholds['foraging_patterns']!['distantForageRatio']!) {
          distanceAssessment = 'Distant Forage';
          reasoning = 'Low entering ratio suggests long foraging trips';
        } else if (exitingRatio > enhancedThresholds['foraging_patterns']!['scoutingActivity']!) {
          distanceAssessment = 'Scouting Activity';
          reasoning = 'High exiting ratio indicates exploration for new sources';
        } else {
          distanceAssessment = 'Mixed Activity';
          reasoning = 'Balanced entering/exiting ratios suggest varied forage sources';
        }

        distanceIndicators[activity.hour] = ForageDistanceIndicator(
          hour: activity.hour,
          enteringRatio: enteringRatio,
          exitingRatio: exitingRatio,
          distanceAssessment: distanceAssessment,
          reasoning: reasoning,
          confidence: activity.confidence,
        );
      }
    }

    final nectarFlowAnalysis = _analyzeNectarFlow(beeData);

    String overallAssessment;
    if (maxActivity > enhancedThresholds['activity']!['peakActivity']!) {
      overallAssessment = 'Excellent foraging conditions with peak activity';
    } else if (maxActivity > enhancedThresholds['activity']!['highActivity']!) {
      overallAssessment = 'Good foraging activity levels';
    } else if (maxActivity > enhancedThresholds['activity']!['moderateActivity']!) {
      overallAssessment = 'Moderate foraging activity';
    } else {
      overallAssessment = 'Low foraging activity - investigation needed';
    }

    return ForagingPatternAnalysis(
      foragingDistanceIndicators: distanceIndicators,
      peakActivityHour: peakActivityHour,
      nectarFlowAnalysis: nectarFlowAnalysis,
      overallForagingAssessment: overallAssessment,
    );
  }

  NectarFlowAnalysis _analyzeNectarFlow(List<HourlyBeeActivity> beeData) {
    if (beeData.isEmpty) {
      return NectarFlowAnalysis(
        status: 'No Data',
        intensity: 'Unknown',
        peakHours: [],
        reasoning: 'No activity data available',
      );
    }

    final sortedActivities = beeData.map((b) => b.totalActivity).toList()..sort();
    final baselineCount = (sortedActivities.length * 0.25).ceil();
    final baseline = baselineCount > 0
        ? sortedActivities.take(baselineCount).reduce((a, b) => a + b) / baselineCount
        : 0.0;

    final peakThreshold = baseline * enhancedThresholds['foraging_patterns']!['nectarFlowRatio']!;
    final List<int> peakHours = [];

    for (final activity in beeData) {
      if (activity.totalActivity > peakThreshold) {
        peakHours.add(activity.hour);
      }
    }

    String status, intensity, reasoning;

    if (peakHours.isEmpty) {
      status = 'No Nectar Flow';
      intensity = 'None';
      reasoning = 'No significant peaks in activity detected';
    } else if (peakHours.length <= 2) {
      status = 'Limited Nectar Flow';
      intensity = 'Low';
      reasoning = 'Short duration peaks suggest limited nectar sources';
    } else if (peakHours.length <= 4) {
      status = 'Moderate Nectar Flow';
      intensity = 'Moderate';
      reasoning = 'Several peak hours indicate decent nectar availability';
    } else {
      status = 'Strong Nectar Flow';
      intensity = 'High';
      reasoning = 'Extended peak activity suggests abundant nectar sources';
    }

    return NectarFlowAnalysis(
      status: status,
      intensity: intensity,
      peakHours: peakHours,
      reasoning: reasoning,
    );
  }

  TimeSyncedCorrelations _calculateTimeSyncedCorrelations(
    List<TimestampedParameter> temperatureData,
    List<TimestampedParameter> humidityData,
    List<TimestampedParameter> weightData,
    List<HourlyBeeActivity> beeData,
    DateTime date,
  ) {
    final Map<int, double> hourlyTemperature = {};
    final Map<int, double> hourlyHumidity = {};

    for (final temp in temperatureData) {
      if (temp.timestamp.day == date.day) {
        hourlyTemperature[temp.timestamp.hour] = temp.value;
      }
    }

    for (final humidity in humidityData) {
      if (humidity.timestamp.day == date.day) {
        hourlyHumidity[humidity.timestamp.hour] = humidity.value;
      }
    }

    final tempActivityCorr = _calculateCorrelation(
      beeData.map((b) => hourlyTemperature[b.hour]).where((t) => t != null).cast<double>().toList(),
      beeData.where((b) => hourlyTemperature[b.hour] != null).map((b) => b.totalActivity.toDouble()).toList(),
    );

    final tempEnteringCorr = _calculateCorrelation(
      beeData.map((b) => hourlyTemperature[b.hour]).where((t) => t != null).cast<double>().toList(),
      beeData.where((b) => hourlyTemperature[b.hour] != null).map((b) => b.beesEntering.toDouble()).toList(),
    );

    final tempExitingCorr = _calculateCorrelation(
      beeData.map((b) => hourlyTemperature[b.hour]).where((t) => t != null).cast<double>().toList(),
      beeData.where((b) => hourlyTemperature[b.hour] != null).map((b) => b.beesExiting.toDouble()).toList(),
    );

    final humidityActivityCorr = _calculateCorrelation(
      beeData.map((b) => hourlyHumidity[b.hour]).where((h) => h != null).cast<double>().toList(),
      beeData.where((b) => hourlyHumidity[b.hour] != null).map((b) => b.totalActivity.toDouble()).toList(),
    );

    final humidityEnteringCorr = _calculateCorrelation(
      beeData.map((b) => hourlyHumidity[b.hour]).where((h) => h != null).cast<double>().toList(),
      beeData.where((b) => hourlyHumidity[b.hour] != null).map((b) => b.beesEntering.toDouble()).toList(),
    );

    final humidityExitingCorr = _calculateCorrelation(
      beeData.map((b) => hourlyHumidity[b.hour]).where((h) => h != null).cast<double>().toList(),
      beeData.where((b) => hourlyHumidity[b.hour] != null).map((b) => b.beesExiting.toDouble()).toList(),
    );

    return TimeSyncedCorrelations(
      temperatureActivity: tempActivityCorr,
      temperatureEntering: tempEnteringCorr,
      temperatureExiting: tempExitingCorr,
      humidityActivity: humidityActivityCorr,
      humidityEntering: humidityEnteringCorr,
      humidityExiting: humidityExitingCorr,
      hourlyTemperature: hourlyTemperature,
      hourlyHumidity: hourlyHumidity,
    );
  }

  double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;
    final n = x.length;
    final sumX = x.reduce((a, b) => a + b);
    final sumY = y.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
    final sumX2 = x.map((v) => v * v).reduce((a, b) => a + b);
    final sumY2 = y.map((v) => v * v).reduce((a, b) => a + b);
    final numerator = (n * sumXY) - (sumX * sumY);
    final denominator = sqrt(((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)));
    if (denominator == 0) return 0.0;
    return numerator / denominator;
  }

  WeightAnalysis _analyzeWeightChanges(
    List<TimestampedParameter> weightData,
    List<HourlyBeeActivity> beeData,
    DateTime date,
  ) {
    if (weightData.isEmpty) {
      return WeightAnalysis(
        currentWeight: 0.0,
        dailyChange: 0.0,
        interpretation: 'No weight data available',
        activityCorrelation: 'Cannot assess without weight data',
        recommendations: ['Install or repair hive scale for weight monitoring'],
      );
    }

    final currentWeight = weightData.first.value;
    double dailyChange = 0.0;
    if (weightData.length > 1) {
      dailyChange = weightData.first.value - weightData.last.value;
    }

    String interpretation;
    if (dailyChange > enhancedThresholds['weight']!['dailyGainForaging']!) {
      interpretation = 'Excellent daily weight gain indicates strong nectar flow and successful foraging';
    } else if (dailyChange > 0) {
      interpretation = 'Positive weight gain shows productive foraging activity';
    } else if (dailyChange > enhancedThresholds['weight']!['dailyLossThreshold']!) {
      interpretation = 'Small weight loss may indicate honey ripening or normal daily fluctuation';
    } else {
      interpretation = 'Significant weight loss suggests poor foraging conditions or colony stress';
    }

    final totalActivity = beeData.isNotEmpty
        ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b)
        : 0;

    String activityCorrelation;
    if (totalActivity > enhancedThresholds['activity']!['highActivity']! && dailyChange > 0) {
      activityCorrelation = 'High activity with weight gain confirms excellent foraging conditions';
    } else if (totalActivity > enhancedThresholds['activity']!['moderateActivity']! && dailyChange < 0) {
      activityCorrelation = 'Moderate activity with weight loss suggests distant forage or poor nectar quality';
    } else if (totalActivity < enhancedThresholds['activity']!['lowActivity']! && dailyChange < 0) {
      activityCorrelation = 'Low activity with weight loss indicates serious foraging problems';
    } else {
      activityCorrelation = 'Activity and weight patterns suggest normal colony behavior';
    }

    List<String> recommendations = [];
    if (dailyChange <= enhancedThresholds['weight']!['dailyLossThreshold']!) {
      recommendations.addAll([
        'Begin emergency feeding with 1:1 or 2:1 sugar syrup',
        'Inspect hive for disease, pests, or queen problems',
        'Check local forage availability within 2km radius',
        'Monitor for robbing behavior from other colonies',
      ]);
    } else if (dailyChange > enhancedThresholds['weight']!['dailyGainForaging']!) {
      recommendations.addAll([
        'Consider adding supers if weight gain continues',
        'Monitor for potential swarming due to rapid population growth',
        'Document successful forage sources for future reference',
      ]);
    }

    return WeightAnalysis(
      currentWeight: currentWeight,
      dailyChange: dailyChange,
      interpretation: interpretation,
      activityCorrelation: activityCorrelation,
      recommendations: recommendations,
    );
  }

  Season _getCurrentSeason(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return Season.spring;
    if (month >= 6 && month <= 8) return Season.summer;
    if (month >= 9 && month <= 11) return Season.fall;
    return Season.winter;
  }

  // ============================================
  // RECOMMENDATION GENERATION
  // ============================================
  List<DailyRecommendation> _generateEnhancedDailyRecommendations(
    DateTime date,
    List<HourlyBeeActivity> beeData,
    List<TimestampedParameter> temperatureData,
    List<TimestampedParameter> humidityData,
    WeightAnalysis weightAnalysis,
    ForagingPatternAnalysis foragingPatterns,
    TimeSyncedCorrelations correlations,
    WeeklyTrendAnalysis weeklyTrends,
  ) {
    final List<DailyRecommendation> recommendations = [];
    final now = DateTime.now();

    final avgActivity = beeData.isNotEmpty
        ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b) / beeData.length
        : 0.0;

    final totalDailyActivity = beeData.isNotEmpty
        ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b)
        : 0;

    final currentTemp = temperatureData.isNotEmpty ? temperatureData.first.value : null;

    print('Generating enhanced daily recommendations...');

    // Weekly trend-based recommendations
    if (weeklyTrends.daysWithData >= 5) {
      if (weeklyTrends.trendPercentage <= enhancedThresholds['activity']!['weeklyDeclineThreshold']!) {
        recommendations.add(DailyRecommendation(
          id: 'weekly_decline_${now.millisecondsSinceEpoch}',
          priority: 'Critical',
          title: 'Significant Weekly Activity Decline Detected',
          description: 'Activity has declined ${weeklyTrends.trendPercentage.abs().toStringAsFixed(1)}% over the past week.',
          actionItems: [
            'Conduct immediate hive inspection for disease, pests, or queen issues',
            'Check local forage availability within 3km radius',
            'Monitor for robbing behavior from other colonies',
            'Consider emergency supplemental feeding if weight is declining',
          ],
          scientificBasis: 'Weekly activity decline >25% typically indicates colony stress or disease onset.',
          expectedOutcome: 'Activity stabilization within 5-7 days',
          timeRelevance: 'Immediate - inspect within 24 hours',
          foragingImpact: 'Critical - colony viability at risk',
        ));
      }
    }

    // Temperature-based recommendations
    if (currentTemp != null && currentTemp > enhancedThresholds['temperature']!['criticalHigh']!) {
      recommendations.add(DailyRecommendation(
        id: 'extreme_heat_${now.millisecondsSinceEpoch}',
        priority: 'Critical',
        title: 'Extreme Heat Alert',
        description: 'Current temperature (${currentTemp.toStringAsFixed(1)}°C) is causing severe heat stress.',
        actionItems: [
          'Provide immediate shade for hives',
          'Ensure multiple water sources within 50m',
          'Add emergency ventilation',
          'Avoid any hive disturbance during heat',
        ],
        scientificBasis: 'Above 35°C, bee flight muscles cease function.',
        expectedOutcome: 'Temperature regulation within 2-4 hours',
        timeRelevance: 'EMERGENCY - within 1 hour',
        foragingImpact: 'Severe - complete foraging cessation',
      ));
    }

    // Low activity recommendations
    if (totalDailyActivity < enhancedThresholds['activity']!['lowActivity']! && weeklyTrends.daysWithData > 0) {
      recommendations.add(DailyRecommendation(
        id: 'low_activity_${now.millisecondsSinceEpoch}',
        priority: 'High',
        title: 'Low Activity Alert',
        description: 'Current activity (${totalDailyActivity} bees today) is critically low.',
        actionItems: [
          'Immediate hive inspection for queen presence',
          'Check for disease signs',
          'Survey 2km radius for available flowering plants',
          'Begin emergency feeding with 1:1 sugar syrup',
        ],
        scientificBasis: 'Activity <20 bees/day indicates colony stress or failing queen.',
        expectedOutcome: 'Activity increase within 3-7 days',
        timeRelevance: 'Urgent - inspect today',
        foragingImpact: 'Critical - colony survival threatened',
      ));
    }

    // Weight loss recommendations
    if (weightAnalysis.dailyChange <= enhancedThresholds['weight']!['dailyLossThreshold']!) {
      recommendations.add(DailyRecommendation(
        id: 'weight_loss_${now.millisecondsSinceEpoch}',
        priority: 'Critical',
        title: 'Weight Loss Detected',
        description: 'Weight loss of ${weightAnalysis.dailyChange.toStringAsFixed(2)}kg detected.',
        actionItems: [
          'Begin immediate emergency feeding with 2:1 sugar syrup',
          'Provide protein supplement (pollen patties)',
          'Check for robbing behavior',
          'Assess local forage availability',
        ],
        scientificBasis: 'Daily weight loss >0.1kg indicates negative energy balance.',
        expectedOutcome: 'Weight stabilization within 3-5 days',
        timeRelevance: 'Emergency - begin feeding immediately',
        foragingImpact: 'Critical - colony survival at immediate risk',
      ));
    }

    // Seasonal recommendations
    final season = _getCurrentSeason(date);
    if (season == Season.spring) {
      recommendations.add(DailyRecommendation(
        id: 'spring_buildup_${now.millisecondsSinceEpoch}',
        priority: 'High',
        title: 'Spring Buildup - Prepare for Swarming',
        description: 'Spring activity increase indicates strong colony buildup requiring swarm management.',
        actionItems: [
          'Add supers immediately for growing population',
          'Check for queen cells weekly',
          'Ensure adequate ventilation',
          'Consider making splits if overcrowded',
        ],
        scientificBasis: 'Rapid spring growth often leads to swarming without space management.',
        expectedOutcome: 'Controlled expansion without swarming',
        timeRelevance: 'Immediate - space management critical',
        foragingImpact: 'Critical - prevents loss of foragers through swarming',
      ));
    }

    if (season == Season.fall && weeklyTrends.trendPercentage < -10) {
      recommendations.add(DailyRecommendation(
        id: 'fall_prep_${now.millisecondsSinceEpoch}',
        priority: 'Critical',
        title: 'Fall Activity Decline - Winter Preparation',
        description: 'Activity declining ${weeklyTrends.trendPercentage.abs().toStringAsFixed(1)}% weekly.',
        actionItems: [
          'Assess honey stores - minimum 25kg needed',
          'Begin heavy feeding with 2:1 sugar syrup',
          'Treat for varroa mites',
          'Reduce hive entrance',
        ],
        scientificBasis: 'Rapid fall decline indicates inadequate winter preparation.',
        expectedOutcome: 'Successful overwintering with 85%+ survival rate',
        timeRelevance: 'Emergency - complete within 3 weeks',
        foragingImpact: 'Critical - last opportunity for store building',
      ));
    }

    return recommendations;
  }

  List<DailyRecommendation> _getEnhancedSeasonalRecommendations(
    Season season,
    WeeklyTrendAnalysis weeklyTrends,
    double avgActivity,
    double? currentTemp,
  ) {
    // This method is called from _generateEnhancedDailyRecommendations
    // Return empty list as recommendations are generated there
    return [];
  }

  // Public wrapper methods for UI
  Future<List<TimestampedParameter>> fetchLatestTemperatureData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _fetchLatestTemperatureData(hiveId, token, startDate, endDate);
  }

  Future<List<TimestampedParameter>> fetchLatestHumidityData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _fetchLatestHumidityData(hiveId, token, startDate, endDate);
  }
}
