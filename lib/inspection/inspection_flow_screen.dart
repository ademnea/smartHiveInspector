import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'inspection_model.dart';
import 'inspection_storage.dart';
import '../Services/open_meteo_service.dart';
import 'recommendation_engine.dart';

class InspectionFlowScreen extends StatefulWidget {
  final String hiveId;
  const InspectionFlowScreen({super.key, required this.hiveId});

  @override
  State<InspectionFlowScreen> createState() => _InspectionFlowScreenState();
}

InspectionEvaluation? _evaluation;

class _InspectionFlowScreenState extends State<InspectionFlowScreen> {
  final TextEditingController _recommendationController =
      TextEditingController();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<String, dynamic> _answers = {};
  double? _currentTemperature;
  // Labels shown under each help image, keyed by field id
  static const Map<String, List<String>> _helpImageLabels = {
    'inspectionTools': ['Smoker, hive tool, brush, frame grip and feeder'],
    'queenPresent': [
      'The queen (longer body, bigger abdomen) among worker bees',
    ],
    'freshEggs': ['Tiny white eggs standing upright in cell bottoms'],
    'queenCellsPresent': ['Large peanut-shaped queen cells on the frame'],
    'larvaeColour': ['Healthy white larvae curled in open cells'],
    'broodCapCondition': [
      'Flat healthy caps (left)',
      'Sunken/diseased caps (right)',
    ],
    'broodPattern': [
      'Tight solid brood pattern (healthy)',
      'Patchy scattered brood pattern (problem)',
    ],
    'pestTypes': ['Varroa mite on a bee — reddish-brown oval dot'],
  };
  @override
  void initState() {
    super.initState();
    _loadTemperature();
  }

  @override
  void dispose() {
    _recommendationController.dispose();
    super.dispose();
  }

  Future<void> _loadTemperature() async {
    final temp = await OpenMeteoService().fetchCurrentTemperature();
    if (mounted) {
      setState(() {
        _currentTemperature = temp;
        _answers['temperatureC'] = temp;
      });
    }
  }

  void _nextPage() async {
    // Check for unsuitable weather warning, only on page 0
    if (_currentPage == 0) {
      final selectedWeather =
          (_answers['weatherCondition'] as List?)?.cast<String>() ?? [];
      final hasUnsuitable = selectedWeather.any(
        (w) => unsuitableWeatherOptions.contains(w),
      );

      if (hasUnsuitable) {
        final shouldContinue = await _showUnsuitableWeatherDialog();
        if (shouldContinue != true) {
          return; // user cancelled, stay on this page
        }
      }
    }

    if (_currentPage < inspectionPages.length - 1) {
      // If moving onto the final summary page, run evaluation first
      if (_currentPage == inspectionPages.length - 2) {
        setState(() {
          _evaluation = RecommendationEngine.evaluate(_answers);
        });
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      _finishInspection();
    }
  }

  Future<bool?> _showUnsuitableWeatherDialog() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Weather May Be Unsuitable'),
            content: const Text(
              'The current weather conditions may not be ideal for a hive inspection. '
              'Do you want to continue anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  Future<void> _finishInspection() async {
    final evaluation = _evaluation ?? RecommendationEngine.evaluate(_answers);
    final record = InspectionRecord(
      hiveId: widget.hiveId,
      date: DateTime.now(),
      answers: _answers,
      recommendations: evaluation.recommendations,
      healthStatus: evaluation.healthStatus,
    );
    await InspectionStorage.saveInspection(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection saved successfully')),
      );
      Navigator.pop(context, true); // true = inspection completed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hive ${widget.hiveId} Inspection (${_currentPage + 1}/${inspectionPages.length})',
        ),
        backgroundColor: Colors.amber[800],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentPage + 1) / inspectionPages.length,
            backgroundColor: Colors.grey[300],
            color: Colors.amber[800],
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inspectionPages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final page = inspectionPages[index];
                return _buildPageContent(page);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _currentPage == inspectionPages.length - 1
                          ? 'Finish'
                          : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(InspectionPage page) {
    if (page.title == 'Final Inspection Summary') {
      return _buildSummaryPage();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (page.title == 'General Information & Weather')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _currentTemperature != null
                    ? 'Current temperature: ${_currentTemperature!.toStringAsFixed(1)}°C'
                    : 'Fetching current temperature...',
                style: const TextStyle(fontSize: 14, color: Colors.brown),
              ),
            ),
          const SizedBox(height: 16),
          ...page.fields.map((field) => _buildField(field)),
          if (page.title == 'General Information & Weather')
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: OutlinedButton.icon(
                onPressed: _showInspectionHistory,
                icon: const Icon(Icons.history),
                label: const Text('View Past Inspections'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionLabel(InspectionField field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            field.question,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (field.helpText != null)
          GestureDetector(
            onTap: () => _showHelpDialog(field),
            child: const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.help_outline, size: 18, color: Colors.brown),
            ),
          ),
      ],
    );
  }

  void _showHelpDialog(InspectionField field) {
    final images = field.helpImageAssets ?? [];
    final labels = _helpImageLabels[field.id] ?? [];

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    field.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: SingleChildScrollView(
                      child: Column(
                        children: List.generate(images.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    images[i],
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 80,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Text('Image not found'),
                                              ),
                                            ),
                                  ),
                                ),
                                if (i < labels.length)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      labels[i],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSummaryPage() {
    final evaluation = _evaluation ?? RecommendationEngine.evaluate(_answers);
    Color statusColor;
    switch (evaluation.healthStatus) {
      case 'Critical':
        statusColor = Colors.red;
        break;
      case 'Warning':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.green;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Final Inspection Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              border: Border.all(color: statusColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.health_and_safety, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Overall Health Status: ${evaluation.healthStatus}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recommended Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...evaluation.recommendations.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Text('• '), Expanded(child: Text(r))],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'When should the next inspection be conducted?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _answers['nextInspectionDate'] = picked.toIso8601String();
                });
              }
            },
            child: Text(
              _answers['nextInspectionDate'] != null
                  ? DateFormat(
                    'MMM d, yyyy',
                  ).format(DateTime.parse(_answers['nextInspectionDate']))
                  : 'Select date',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInspectionHistory() async {
    final records = await InspectionStorage.getInspections(widget.hiveId);
    records.sort((a, b) => b.date.compareTo(a.date)); // most recent first

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            if (records.isEmpty) {
              return const Center(child: Text('No past inspections yet.'));
            }
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final health =
                    record.answers['overallHealthStatus'] ?? 'Not recorded';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.fact_check, color: Colors.amber),
                    title: Text(
                      DateFormat('MMM d, yyyy – h:mm a').format(record.date),
                    ),
                    subtitle: Text('Overall health: $health'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context); // close the sheet
                      _showInspectionDetail(record);
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showInspectionDetail(InspectionRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(DateFormat('MMM d, yyyy – h:mm a').format(record.date)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  record.answers.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('${entry.key}: ${entry.value}'),
                    );
                  }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildField(InspectionField field) {
    // Conditional visibility
    if (field.showIfFieldId != null) {
      final controllingValue = _answers[field.showIfFieldId];
      bool matches;
      if (controllingValue is List) {
        matches = controllingValue.contains(field.showIfValue);
      } else {
        matches = controllingValue == field.showIfValue;
      }
      if (!matches) {
        return const SizedBox.shrink();
      }
    }

    switch (field.type) {
      case FieldType.checkboxGroup:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestionLabel(field),
              Wrap(
                spacing: 8,
                children:
                    field.options!.map((option) {
                      final selected =
                          (_answers[field.id] as List?)?.contains(option) ??
                          false;
                      return FilterChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            final list =
                                (_answers[field.id] as List?)?.cast<String>() ??
                                <String>[];
                            if (val) {
                              list.add(option);
                            } else {
                              list.remove(option);
                              if (option == 'Other') {
                                _answers.remove('${field.id}_otherCleared');
                              }
                            }
                            _answers[field.id] = list;
                          });
                        },
                      );
                    }).toList(),
              ),
            ],
          ),
        );

      case FieldType.singleSelect:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestionLabel(field),
              Wrap(
                spacing: 8,
                children:
                    field.options!.map((option) {
                      final selected =
                          _answers[field.id] == option ||
                          ((_answers[field.id] as List?)?.contains(option) ??
                              false);
                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            _answers[field.id] = val ? [option] : <String>[];
                            if (field.id == 'weatherCondition' && val) {
                              _answers['weatherRecommendation'] =
                                  weatherRecommendations[option] ?? '';
                              _recommendationController.text =
                                  weatherRecommendations[option] ?? '';
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
            ],
          ),
        );

      case FieldType.yesNo:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestionLabel(field),
              Row(
                children:
                    ['Yes', 'No'].map((option) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(
                            value: option,
                            groupValue: _answers[field.id],
                            onChanged: (val) {
                              setState(() => _answers[field.id] = val);
                            },
                          ),
                          Text(option),
                          const SizedBox(width: 12),
                        ],
                      );
                    }).toList(),
              ),
            ],
          ),
        );

      case FieldType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestionLabel(field),
              TextField(
                controller:
                    field.id == 'weatherRecommendation'
                        ? _recommendationController
                        : null,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLines: 2,
                onChanged: (val) => _answers[field.id] = val,
              ),
            ],
          ),
        );
      case FieldType.number:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestionLabel(field),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onChanged: (val) => _answers[field.id] = val,
              ),
            ],
          ),
        );
      case FieldType.date:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestionLabel(field),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _answers[field.id] = picked.toIso8601String();
                    });
                  }
                },
                child: Text(
                  _answers[field.id] != null
                      ? DateFormat(
                        'MMM d, yyyy',
                      ).format(DateTime.parse(_answers[field.id]))
                      : 'Select date',
                ),
              ),
            ],
          ),
        );

      case FieldType.label:
        return Text(field.question);
    }
  }
}
