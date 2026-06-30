class InspectionEvaluation {
  final List<String> recommendations;
  final String healthStatus; // Healthy, Warning, Critical
  final int riskScore;

  InspectionEvaluation({
    required this.recommendations,
    required this.healthStatus,
    required this.riskScore,
  });
}

class RecommendationEngine {
  static InspectionEvaluation evaluate(Map<String, dynamic> a) {
    final List<String> recs = [];
    int score = 0;

    bool isYes(String key) => a[key] == 'Yes';
    bool isNo(String key) => a[key] == 'No';
    List<String> listOf(String key) => (a[key] as List?)?.cast<String>() ?? [];

    // Weather
    final weather = listOf('weatherCondition');
    if (weather.any((w) => unsuitableWeatherList.contains(w))) {
      recs.add(
        'Weather is unsuitable for inspection (${weather.join(", ")}). Consider rescheduling if not urgent.',
      );
      score += 2;
    }

    // Bee activity at entrance
    final activity = a['beeActivityRange'];
    if (isNo('beeActivity') || activity == 'None (0)') {
      recs.add(
        'No bee activity detected at the entrance. This could indicate the colony has absconded or died — investigate urgently.',
      );
      score += 5;
    } else if (activity == 'Few (1–50)') {
      recs.add(
        'Low bee traffic at the entrance. Monitor closely over the next few days.',
      );
      score += 2;
    } else if (activity == 'Extremely many (more than 500)') {
      recs.add(
        'Very high entrance traffic — could indicate robbing or an unusually strong colony. Observe behaviour closely.',
      );
      score += 1;
    }

    // Entrance blockage
    if (isYes('entranceBlocked')) {
      final blockage = listOf('blockageType');
      recs.add(
        'Entrance blocked by: ${blockage.join(", ")}. Clear the entrance to maintain healthy airflow and bee movement.',
      );
      score += 2;
    }

    // Dead bees
    final deadCount = int.tryParse(a['deadBeesCount']?.toString() ?? '') ?? 0;
    if (deadCount > 20) {
      recs.add(
        'A large number of dead bees ($deadCount) observed at the entrance — possible pesticide exposure or disease. Investigate further.',
      );
      score += 3;
    }

    // Hive damage
    if (isYes('hiveDamage')) {
      recs.add(
        'Physical damage to the hive box detected. Repair or replace damaged parts to protect the colony from weather and pests.',
      );
      score += 2;
    }

    // Aggressive behaviour
    if (isYes('aggressiveBehaviour') ||
        a['behaviourDescription'] == 'Aggressive') {
      recs.add(
        'Colony is showing aggressive/defensive behaviour. Wear full protective gear and consider checking for a missing queen or recent disturbance.',
      );
      score += 2;
    }

    // Internal cleanliness
    if (isNo('hiveClean')) {
      final causes = listOf('uncleanCauses');
      recs.add(
        'Hive interior is unclean (${causes.join(", ")}). Clean the hive to reduce disease risk.',
      );
      score += 2;
    }

    // Bad smell
    if (isYes('badSmell')) {
      recs.add(
        'Unusual smell detected: ${a['smellDescription'] ?? 'unspecified'}. This can be an early sign of brood disease — inspect brood closely.',
      );
      score += 3;
    }

    // Frames not arranged
    if (isNo('framesArranged')) {
      recs.add(
        'Frames are not properly arranged. Rearrange frames to maintain proper bee space and comb structure.',
      );
      score += 1;
    }

    // Queen
    if (isNo('queenPresent')) {
      recs.add(
        'Queen not seen — combined with other signs (eggs, larvae), this may mean the colony is queenless. Consider requeening if confirmed.',
      );
      score += 5;
    } else {
      final queenTraits = listOf('queenCondition');
      final weakTraits = [
        'Small body size',
        'Short abdomen',
        'Damaged body parts',
      ];
      if (queenTraits.any((t) => weakTraits.contains(t))) {
        recs.add(
          'Queen shows signs of poor condition (${queenTraits.where((t) => weakTraits.contains(t)).join(", ")}). Monitor egg-laying performance and consider requeening if it declines.',
        );
        score += 3;
      }
    }

    if (isNo('freshEggs') && isNo('queenPresent')) {
      recs.add(
        'No fresh eggs and no queen seen — strong indication the colony is queenless. Urgent action recommended.',
      );
      score += 3;
    }

    if (isYes('multipleEggsPerCell')) {
      recs.add(
        'Multiple eggs per cell detected — possible laying worker problem. This usually means the colony has been queenless for some time.',
      );
      score += 4;
    }

    if (isYes('queenCellsPresent')) {
      recs.add(
        'Queen cells present — the colony may be preparing to swarm or replace the queen. Monitor closely over the next 1–2 weeks.',
      );
      score += 2;
    }

    // Brood
    if (isYes('damagedBrood')) {
      recs.add(
        'Damaged or dead brood observed. Inspect closely for signs of disease (foulbrood, chalkbrood) and isolate the hive if uncertain.',
      );
      score += 3;
    }

    final broodPattern = a['broodPattern'];
    if (broodPattern == 'Mostly gaps, very patchy' ||
        broodPattern == 'No brood seen') {
      recs.add(
        'Brood pattern is poor or absent. This can indicate queen problems or disease — re-check in 5–7 days.',
      );
      score += 3;
    }

    // Food stores
    if (isNo('honeyPresent') || a['honeyCoverage'] == 'Low') {
      recs.add(
        'Honey stores are low. Supplement feeding (sugar syrup) is recommended, especially if natural forage is scarce.',
      );
      score += 2;
    }
    if (isNo('pollenPresent')) {
      recs.add(
        'No pollen stores detected. Consider providing a pollen substitute, especially during dearth periods.',
      );
      score += 1;
    }

    // Pests
    if (isYes('pestsPresent')) {
      final pests = listOf('pestTypes');
      recs.add(
        'Pests detected: ${pests.join(", ")}. Apply appropriate pest control measures promptly.',
      );
      score += pests.contains('Mites') ? 4 : 2;
    }

    // Disease
    if (isYes('diseaseSigns')) {
      final symptoms = listOf('diseaseSymptoms');
      recs.add(
        'Signs of disease present (${symptoms.join(", ")}). Isolate the hive from others if possible and seek further diagnosis.',
      );
      score += 4;
    }

    if (isYes('deformedBees')) {
      final count = int.tryParse(a['affectedBeesCount']?.toString() ?? '') ?? 0;
      recs.add(
        'Deformed-wing bees observed ($count affected) — commonly linked to Varroa mite infestation. Test and treat for mites.',
      );
      score += 3;
    }

    // Colony strength
    if (a['frameCoverageLevel'] == 'Minimally Covered') {
      recs.add(
        'Bee coverage on frames is minimal — colony may be weak or declining. Monitor population trend at next inspection.',
      );
      score += 3;
    }
    if (a['hiveActivityLevel'] != null &&
        (a['hiveActivityLevel'] as String).startsWith('No activity')) {
      recs.add(
        'No hive activity observed during inspection — combined with other findings, this is a serious warning sign.',
      );
      score += 4;
    }

    if (recs.isEmpty) {
      recs.add(
        'No issues detected. Hive appears to be in good condition — continue routine monitoring.',
      );
    }

    String status;
    if (score >= 10) {
      status = 'Critical';
    } else if (score >= 5) {
      status = 'Warning';
    } else {
      status = 'Healthy';
    }

    return InspectionEvaluation(
      recommendations: recs,
      healthStatus: status,
      riskScore: score,
    );
  }

  static const List<String> unsuitableWeatherList = ['Windy', 'Rain'];
}
