enum FieldType { checkboxGroup, singleSelect, yesNo, text, number, date, label }

class InspectionField {
  final String id;
  final String question;
  final FieldType type;
  final List<String>? options;
  final String? showIfFieldId;
  final String? showIfValue;
  final bool hasOtherOption; // shows a text box if "Other" is selected
  final String? helpText; // shown in the info popup
  final String? helpImageAsset; // asset path for the info popup image

  InspectionField({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    this.showIfFieldId,
    this.showIfValue,
    this.hasOtherOption = false,
    this.helpText,
    this.helpImageAsset,
  });
}

class InspectionPage {
  final String title;
  final List<InspectionField> fields;
  InspectionPage({required this.title, required this.fields});
}

class InspectionRecord {
  final String hiveId;
  final DateTime date;
  final Map<String, dynamic> answers;
  final List<String> recommendations;
  final String healthStatus;

  InspectionRecord({
    required this.hiveId,
    required this.date,
    required this.answers,
    this.recommendations = const [],
    this.healthStatus = 'Not evaluated',
  });

  Map<String, dynamic> toJson() => {
    'hiveId': hiveId,
    'date': date.toIso8601String(),
    'answers': answers,
    'recommendations': recommendations,
    'healthStatus': healthStatus,
  };

  factory InspectionRecord.fromJson(Map<String, dynamic> json) {
    return InspectionRecord(
      hiveId: json['hiveId'],
      date: DateTime.parse(json['date']),
      answers: Map<String, dynamic>.from(json['answers']),
      recommendations: (json['recommendations'] as List?)?.cast<String>() ?? [],
      healthStatus: json['healthStatus'] ?? 'Not evaluated',
    );
  }
}

const Map<String, String> weatherRecommendations = {
  'Sunny':
      'Perfect weather for inspection. Bees are calm and active — proceed confidently.',
  'Cloudy':
      'Conditions are fair. You can inspect if it\'s warm and not windy. Proceed gently and keep the hive open briefly.',
  'Windy':
      'Not ideal for inspection. Wind can chill brood and irritate bees. If you must proceed, shield the hive from wind and work quickly.',
  'Rain':
      'Avoid inspection during rain. Bees are defensive and moisture can harm brood. If urgent, inspect under shelter and minimize hive exposure.',
};

const List<String> unsuitableWeatherOptions = ['Windy', 'Rain'];

final List<InspectionPage> inspectionPages = [
  InspectionPage(
    title: 'General Information & Weather',
    fields: [
      InspectionField(
        id: 'weatherCondition',
        question: 'Current Weather Condition',
        type: FieldType.singleSelect,
        options: ['Rain', 'Sunny', 'Windy', 'Cloudy'],
      ),
      InspectionField(
        id: 'weatherRecommendation',
        question: 'Recommendation (if weather is unsuitable)',
        type: FieldType.text,
      ),
    ],
  ),
  InspectionPage(
    title: 'Preparation (Before Inspection)',
    fields: [
      InspectionField(
        id: 'protectiveEquipment',
        question: 'Which protective equipment do you have on?',
        type: FieldType.checkboxGroup,
        options: ['Protective suit', 'Gloves', 'Veil', 'Boots'],
      ),
      InspectionField(
        id: 'inspectionTools',
        question: 'Which inspection tools do you have?',
        type: FieldType.checkboxGroup,
        options: ['Smoker', 'Hive tool', 'Brush', 'Frame grip', 'Feeder'],
        helpText:
            'Smoker: calms bees with smoke. Hive tool: pries open boxes/frames. Frame grip: lifts frames without crushing bees. Feeder: holds sugar syrup for feeding.',
        helpImageAsset: 'assets/help/inspection_tools.png',
      ),
      InspectionField(
        id: 'toolsClean',
        question:
            'Are all inspection tools and equipment clean and ready for use?',
        type: FieldType.yesNo,
      ),
    ],
  ),
  InspectionPage(
    title: 'Hive External Condition',
    fields: [
      InspectionField(
        id: 'standStable',
        question: 'Is the hive stand stable and secure?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'beeActivity',
        question:
            'Is there visible bee activity at the hive entrance (bees entering and leaving normally)?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'beeActivityRange',
        question: 'How many bees do you see flying in and out?',
        type: FieldType.singleSelect,
        options: [
          'None (0)',
          'Few (1–50)',
          'Normal (51–500)',
          'Extremely many (more than 500)',
        ],
        showIfFieldId: 'beeActivity',
        showIfValue: 'Yes',
      ),
      InspectionField(
        id: 'entranceBlocked',
        question:
            'Is the hive entrance blocked by debris, wax, dead bees, or pests?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'blockageType',
        question: 'What is blocking the entrance?',
        type: FieldType.checkboxGroup,
        options: ['Debris', 'Wax', 'Dead bees', 'Pests'],
        showIfFieldId: 'entranceBlocked',
        showIfValue: 'Yes',
      ),
      InspectionField(
        id: 'deadBeesPresent',
        question: 'Are dead bees present at the hive entrance?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'deadBeesCount',
        question: 'Estimated number observed',
        type: FieldType.number,
        showIfFieldId: 'deadBeesPresent',
        showIfValue: 'Yes',
      ),
      InspectionField(
        id: 'hiveDamage',
        question: 'Is there visible physical damage to the hive box?',
        type: FieldType.yesNo,
      ),
    ],
  ),
  InspectionPage(
    title: 'Bee Behaviour Outside',
    fields: [
      InspectionField(
        id: 'aggressiveBehaviour',
        question:
            'Do bees show aggressive behaviour when approaching the hive?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'behaviourDescription',
        question: 'General behaviour of bees outside the hive',
        type: FieldType.singleSelect,
        options: ['Calm', 'Alert', 'Aggressive', 'Active', 'Inactive'],
      ),
    ],
  ),
  InspectionPage(
    title: 'Internal Hive Condition',
    fields: [
      InspectionField(
        id: 'framesArranged',
        question:
            'Are the frames properly arranged and evenly spaced inside the hive?',
        type: FieldType.yesNo,
      ),

      InspectionField(
        id: 'hiveClean',
        question:
            'Is the inside of the hive clean (free from dirt, mold, excess wax, or dead bees)?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'uncleanCauses',
        question: 'What makes it unclean?',
        type: FieldType.checkboxGroup,
        options: ['Dirt', 'Mold', 'Excess wax', 'Dead bees'],
        showIfFieldId: 'hiveClean',
        showIfValue: 'No',
      ),
      InspectionField(
        id: 'badSmell',
        question: 'Is there any unusual or bad smell coming from the hive?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'smellDescription',
        question: 'What does the smell most resemble?',
        type: FieldType.singleSelect,
        options: [
          'Sour or vinegar-like',
          'Rotten or foul, like rotting meat',
          'Moldy or musty',
          'Sweet or fermented',
        ],
        showIfFieldId: 'badSmell',
        showIfValue: 'Yes',
      ),
    ],
  ),
  InspectionPage(
    title: 'Queen Status',
    fields: [
      InspectionField(
        id: 'queenPresent',
        question: 'Is the queen bee present in the hive?',
        type: FieldType.yesNo,
        helpText:
            'The queen is the largest bee in the colony, with a long body and longer abdomen than worker bees.',
        helpImageAsset: 'assets/help/queen_bee.png',
      ),
      InspectionField(
        id: 'freshEggs',
        question: 'Are fresh eggs (white dots) visible in the comb cells?',
        type: FieldType.yesNo,
        helpText:
            'Fresh eggs look like tiny white grains of rice standing upright in the bottom of empty cells.',
        helpImageAsset: 'assets/help/bee_eggs.png',
      ),
      InspectionField(
        id: 'queenCondition',
        question: 'What does the queen look like? (Select all that apply)',
        type: FieldType.checkboxGroup,
        options: [
          'Large body size',
          'Long abdomen',
          'Broad thorax',
          'Curved smooth stinger',
          'Small body size',
          'Short abdomen',
          'Damaged body parts',
        ],
        showIfFieldId: 'queenPresent',
        showIfValue: 'Yes',
      ),
      InspectionField(
        id: 'queenCellsPresent',
        question: 'Are queen cells present in the hive?',
        type: FieldType.yesNo,
        helpText:
            'Queen cells are large, peanut-shaped cells hanging off the frame, much bigger than regular cells.',
        helpImageAsset: 'assets/help/queen_cells.png',
      ),
      InspectionField(
        id: 'multipleEggsPerCell',
        question: 'Are there multiple eggs in a single cell?',
        type: FieldType.yesNo,
      ),
    ],
  ),
  InspectionPage(
    title: 'Brood Condition (Young Bees)',
    fields: [
      InspectionField(
        id: 'larvaeColour',
        question: 'What is the colour of the larvae?',
        type: FieldType.singleSelect,
        options: ['White', 'Yellow', 'Brown', 'Grey'],
        helpText:
            'Larvae are small white grub-like shapes curled in the bottom of open cells.',
        helpImageAsset: 'assets/help/larvae.png',
      ),
      InspectionField(
        id: 'broodCapCondition',
        question: 'What is the condition of brood caps?',
        type: FieldType.singleSelect,
        options: ['Flat', 'Sunken'],
        helpText:
            'Brood caps are the wax coverings sealing developing bees inside their cells. Healthy caps are flat; sunken or dented caps can signal disease.',
        helpImageAsset: 'assets/help/brood_caps.png',
      ),
      InspectionField(
        id: 'damagedBrood',
        question: 'Is there damaged or dead brood present?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'broodPattern',
        question: 'How tightly packed is the brood pattern?',
        type: FieldType.singleSelect,
        options: [
          'Tightly packed, almost no gaps',
          'Some empty cells scattered around',
          'Mostly gaps, very patchy',
          'No brood seen',
        ],
        helpText:
            'Brood pattern refers to how closely packed capped brood cells are on a frame. A tight, solid pattern is a sign of a healthy, productive queen.',
        helpImageAsset: 'assets/help/brood_pattern.png',
      ),
    ],
  ),
  InspectionPage(
    title: 'Food Stores (Honey & Pollen)',
    fields: [
      InspectionField(
        id: 'honeyPresent',
        question: 'Is honey present in the hive?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'honeyCoverage',
        question: 'Honey coverage',
        type: FieldType.singleSelect,
        options: ['Full', 'Partial', 'Scattered', 'Low'],
        showIfFieldId: 'honeyPresent',
        showIfValue: 'Yes',
      ),
      InspectionField(
        id: 'honeyFrameCount',
        question: 'How many frames contain honey stores?',
        type: FieldType.number,
      ),
      InspectionField(
        id: 'pollenPresent',
        question: 'Is pollen present in the hive?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'pollenDistribution',
        question: 'Pollen distribution',
        type: FieldType.singleSelect,
        options: [
          'None',
          'A little, near the brood',
          'Spread across several frames',
          'Heavy on most frames',
        ],
        showIfFieldId: 'pollenPresent',
        showIfValue: 'Yes',
      ),
      InspectionField(
        id: 'pollenFrameCount',
        question: 'How many frames contain pollen stores?',
        type: FieldType.number,
      ),
    ],
  ),
  InspectionPage(
    title: 'Pests and Diseases',
    fields: [
      InspectionField(
        id: 'pestsPresent',
        question: 'Are pests present in the hive?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'pestTypes',
        question: 'Which pests do you see?',
        type: FieldType.checkboxGroup,
        options: ['Ants', 'Mites', 'Beetles', 'Wax moths', 'Other'],
        hasOtherOption: true,
        showIfFieldId: 'pestsPresent',
        showIfValue: 'Yes',
        helpText:
            'Varroa mites are small reddish-brown oval pests attached to bees or visible in brood cells — a major threat to colony health.',
        helpImageAsset: 'assets/help/varroa_mites.png',
      ),
      InspectionField(
        id: 'pestOtherText',
        question: 'Please specify the other pest',
        type: FieldType.text,
        showIfFieldId: 'pestTypes',
        showIfValue: 'Other',
      ),
      InspectionField(
        id: 'otherInsects',
        question:
            'Are there other insects present in the hive apart from bees?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'diseaseSigns',
        question: 'Are there visible signs of disease in the colony?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'diseaseSymptoms',
        question: 'Which signs do you see?',
        type: FieldType.checkboxGroup,
        options: ['Weak bees', 'Dead larvae', 'Bad smell', 'Missing queen'],
        showIfFieldId: 'diseaseSigns',
        showIfValue: 'Yes',
      ),
      InspectionField(
        id: 'deformedBees',
        question: 'Are deformed-wing or weak bees present?',
        type: FieldType.yesNo,
      ),
      InspectionField(
        id: 'affectedBeesCount',
        question: 'Number of affected bees observed',
        type: FieldType.number,
      ),
    ],
  ),
  InspectionPage(
    title: 'Colony Strength',
    fields: [
      InspectionField(
        id: 'framesOccupied',
        question: 'How many frames are occupied by bees?',
        type: FieldType.number,
      ),
      InspectionField(
        id: 'frameCoverageLevel',
        question: 'Level of frame coverage by bees',
        type: FieldType.singleSelect,
        options: ['Fully Covered', 'Partially Covered', 'Minimally Covered'],
      ),
      InspectionField(
        id: 'hiveActivityLevel',
        question: 'Hive activity during inspection',
        type: FieldType.singleSelect,
        options: [
          'Very active — steady stream of bees moving constantly',
          'Moderately active — regular but spaced-out movement',
          'Low activity — only occasional bee movement',
          'No activity — bees not moving at all',
        ],
      ),
    ],
  ),
  InspectionPage(
    title: 'Final Inspection Summary',
    fields:
        [], // built dynamically from the recommendation engine, not user input
  ),
];

// enum FieldType { checkboxGroup, yesNo, text, number, date, label }

// class InspectionField {
//   final String id;
//   final String question;
//   final FieldType type;
//   final List<String>? options; // for checkboxGroup / multiple choice
//   final String?
//   showIfFieldId; // conditional field: only show if another field == showIfValue
//   final String? showIfValue;
//   final bool
//   singleSelect; // if true, only one option in the group can be selected at a time

//   InspectionField({
//     required this.id,
//     required this.question,
//     required this.type,
//     this.options,
//     this.showIfFieldId,
//     this.showIfValue,
//     this.singleSelect = false,
//   });
// }

// class InspectionPage {
//   final String title;
//   final List<InspectionField> fields;

//   InspectionPage({required this.title, required this.fields});
// }

// const Map<String, String> weatherRecommendations = {
//   'Sunny':
//       'Perfect weather for inspection. Bees are calm and active — proceed confidently.',
//   'Cloudy':
//       'Conditions are fair. You can inspect if it\'s warm and not windy. Proceed gently and keep the hive open briefly.',
//   'Windy':
//       'Not ideal for inspection. Wind can chill brood and irritate bees. If you must proceed, shield the hive from wind and work quickly.',
//   'Rain':
//       'Avoid inspection during rain. Bees are defensive and moisture can harm brood. If urgent, inspect under shelter and minimize hive exposure.',
// };

// const List<String> unsuitableWeatherOptions = ['Windy', 'Rain'];

// class InspectionRecord {
//   final String hiveId;
//   final DateTime date;
//   final Map<String, dynamic> answers;

//   InspectionRecord({
//     required this.hiveId,
//     required this.date,
//     required this.answers,
//   });

//   Map<String, dynamic> toJson() => {
//     'hiveId': hiveId,
//     'date': date.toIso8601String(),
//     'answers': answers,
//   };

//   factory InspectionRecord.fromJson(Map<String, dynamic> json) {
//     return InspectionRecord(
//       hiveId: json['hiveId'],
//       date: DateTime.parse(json['date']),
//       answers: Map<String, dynamic>.from(json['answers']),
//     );
//   }
// }

// // ---- The full 11-page checklist, matching your document exactly ----
// final List<InspectionPage> inspectionPages = [
//   InspectionPage(
//     title: 'General Information & Weather',
//     fields: [
//       InspectionField(
//         id: 'weatherCondition',
//         question: 'Current Weather Condition',
//         type: FieldType.checkboxGroup,
//         options: ['Rain', 'Sunny', 'Windy', 'Cloudy'],
//         singleSelect: true,
//       ),
//       InspectionField(
//         id: 'weatherRecommendation',
//         question: 'Recommendation',
//         type: FieldType.text,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Preparation (Before Inspection)',
//     fields: [
//       InspectionField(
//         id: 'protectiveEquipment',
//         question: 'Which protective equipment do you have on?',
//         type: FieldType.checkboxGroup,
//         options: ['Protective suit', 'Gloves', 'Veil', 'Boots'],
//       ),
//       InspectionField(
//         id: 'inspectionTools',
//         question: 'Which inspection tools do you have?',
//         type: FieldType.checkboxGroup,
//         options: ['Smoker', 'Hive tool', 'Brush', 'Frame grip', 'Feeder'],
//       ),
//       InspectionField(
//         id: 'toolsClean',
//         question:
//             'Are all inspection tools and equipment clean and ready for use?',
//         type: FieldType.yesNo,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Hive External Condition',
//     fields: [
//       InspectionField(
//         id: 'standStable',
//         question: 'Is the hive stand stable and secure?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'beeActivity',
//         question: 'Is there visible bee activity at the hive entrance?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'beeActivityDescription',
//         question: 'Describe bee activity',
//         type: FieldType.text,
//         showIfFieldId: 'beeActivity',
//         showIfValue: 'Yes',
//       ),
//       InspectionField(
//         id: 'entranceBlocked',
//         question:
//             'Is the hive entrance blocked by debris, wax, dead bees, or pests?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'blockageDescription',
//         question: 'Describe blockage',
//         type: FieldType.text,
//         showIfFieldId: 'entranceBlocked',
//         showIfValue: 'Yes',
//       ),
//       InspectionField(
//         id: 'deadBeesPresent',
//         question: 'Are dead bees present at the hive entrance?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'deadBeesCount',
//         question: 'Estimated number observed',
//         type: FieldType.number,
//         showIfFieldId: 'deadBeesPresent',
//         showIfValue: 'Yes',
//       ),
//       InspectionField(
//         id: 'hiveDamage',
//         question: 'Is there visible physical damage to the hive box?',
//         type: FieldType.yesNo,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Bee Behaviour Outside',
//     fields: [
//       InspectionField(
//         id: 'aggressiveBehaviour',
//         question:
//             'Do bees show aggressive behaviour when approaching the hive?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'behaviourDescription',
//         question: 'Describe the general behaviour of the bees outside the hive',
//         type: FieldType.text,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Internal Hive Condition',
//     fields: [
//       InspectionField(
//         id: 'framesArranged',
//         question:
//             'Are the frames properly arranged and evenly spaced inside the hive?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'frameIssue',
//         question: 'Describe the problem',
//         type: FieldType.text,
//         showIfFieldId: 'framesArranged',
//         showIfValue: 'No',
//       ),
//       InspectionField(
//         id: 'hiveClean',
//         question: 'Is the inside of the hive clean?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'badSmell',
//         question: 'Is there any unusual or bad smell coming from the hive?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'smellDescription',
//         question: 'Describe the smell',
//         type: FieldType.text,
//         showIfFieldId: 'badSmell',
//         showIfValue: 'Yes',
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Queen Status',
//     fields: [
//       InspectionField(
//         id: 'queenPresent',
//         question: 'Is the queen bee present in the hive?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'freshEggs',
//         question: 'Are fresh eggs (white dots) visible in the comb cells?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'queenCondition',
//         question: 'What is the condition of the queen bee?',
//         type: FieldType.checkboxGroup,
//         options: ['Healthy', 'Weak'],
//       ),
//       InspectionField(
//         id: 'queenCellsPresent',
//         question: 'Are queen cells present in the hive?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'multipleEggsPerCell',
//         question: 'Are there multiple eggs in a single cell?',
//         type: FieldType.yesNo,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Brood Condition (Young Bees)',
//     fields: [
//       InspectionField(
//         id: 'larvaeColour',
//         question: 'What is the colour of the larvae?',
//         type: FieldType.checkboxGroup,
//         options: ['White', 'Yellow', 'Brown', 'Grey'],
//       ),
//       InspectionField(
//         id: 'broodCapCondition',
//         question: 'What is the condition of brood caps?',
//         type: FieldType.checkboxGroup,
//         options: ['Flat', 'Sunken'],
//       ),
//       InspectionField(
//         id: 'damagedBrood',
//         question: 'Is there damaged or dead brood present?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'broodPatternDescription',
//         question: 'Describe the brood pattern and condition',
//         type: FieldType.text,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Food Stores (Honey & Pollen)',
//     fields: [
//       InspectionField(
//         id: 'honeyPresent',
//         question: 'Is honey present in the hive?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'honeyCoverage',
//         question: 'Describe honey coverage (full, partial, scattered, low)',
//         type: FieldType.text,
//       ),
//       InspectionField(
//         id: 'honeyFrameCount',
//         question: 'How many frames contain honey stores?',
//         type: FieldType.number,
//       ),
//       InspectionField(
//         id: 'pollenPresent',
//         question: 'Is pollen present in the hive?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'pollenDistribution',
//         question: 'Describe pollen distribution in the hive',
//         type: FieldType.text,
//       ),
//       InspectionField(
//         id: 'pollenFrameCount',
//         question: 'How many frames contain pollen stores?',
//         type: FieldType.number,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Pests and Diseases',
//     fields: [
//       InspectionField(
//         id: 'pestsPresent',
//         question:
//             'Are pests present in the hive (ants, mites, beetles, wax moths)?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'otherInsects',
//         question:
//             'Are there other insects present in the hive apart from bees?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'diseaseSigns',
//         question: 'Are there visible signs of disease in the colony?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'deformedBees',
//         question: 'Are deformed-wing or weak bees present?',
//         type: FieldType.yesNo,
//       ),
//       InspectionField(
//         id: 'affectedBeesCount',
//         question: 'Number of affected bees observed',
//         type: FieldType.number,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Colony Strength',
//     fields: [
//       InspectionField(
//         id: 'framesOccupied',
//         question: 'How many frames are occupied by bees?',
//         type: FieldType.number,
//       ),
//       InspectionField(
//         id: 'frameCoverageLevel',
//         question: 'What is the level of frame coverage by bees?',
//         type: FieldType.checkboxGroup,
//         options: ['Fully Covered', 'Partially Covered', 'Minimally Covered'],
//       ),
//       InspectionField(
//         id: 'hiveActivityDescription',
//         question: 'Describe hive activity during inspection',
//         type: FieldType.text,
//       ),
//     ],
//   ),
//   InspectionPage(
//     title: 'Final Inspection Summary',
//     fields: [
//       InspectionField(
//         id: 'requiredAction',
//         question: 'What action is required after inspection?',
//         type: FieldType.text,
//       ),
//       InspectionField(
//         id: 'overallHealthStatus',
//         question: 'What is the overall health status of the colony?',
//         type: FieldType.text,
//       ),
//       InspectionField(
//         id: 'nextInspectionDate',
//         question: 'When should the next inspection be conducted?',
//         type: FieldType.date,
//       ),
//     ],
//   ),
// ];
