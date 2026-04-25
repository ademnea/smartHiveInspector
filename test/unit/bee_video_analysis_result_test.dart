import 'package:HPGM/bee_counter/bee_video_analysis_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BeeAnalysisResult serializes all video analysis fields', () {
    final timestamp = DateTime(2026, 4, 25, 12);
    final result = BeeAnalysisResult(
      id: 'analysis-1',
      videoId: 'video-1',
      beesIn: 18,
      beesOut: 11,
      netChange: 7,
      totalActivity: 29,
      detectionConfidence: 88.2,
      processingTime: 2.7,
      framesAnalyzed: 64,
      modelVersion: 'model-a',
      timestamp: timestamp,
      videoPath: '/videos/a.mp4',
    );

    final json = result.toJson();

    expect(json['id'], 'analysis-1');
    expect(json['video_id'], 'video-1');
    expect(json['timestamp'], timestamp.toIso8601String());
    expect(json['video_path'], '/videos/a.mp4');
  });

  test('BeeAnalysisResult.fromJson restores all values', () {
    final timestamp = DateTime(2026, 4, 25, 12);

    final result = BeeAnalysisResult.fromJson({
      'id': 'analysis-1',
      'video_id': 'video-1',
      'bees_in': 18,
      'bees_out': 11,
      'net_change': 7,
      'total_activity': 29,
      'detection_confidence': 88.2,
      'processing_time': 2.7,
      'frames_analyzed': 64,
      'model_version': 'model-a',
      'timestamp': timestamp.toIso8601String(),
      'video_path': '/videos/a.mp4',
    });

    expect(result.id, 'analysis-1');
    expect(result.beesIn, 18);
    expect(result.detectionConfidence, 88.2);
    expect(result.timestamp, timestamp);
    expect(result.toString(), contains('netChange: 7'));
  });
}
