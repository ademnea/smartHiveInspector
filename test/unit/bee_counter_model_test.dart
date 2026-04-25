import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ServerVideo.fromJson extracts timestamp from filename', () {
    final video = ServerVideo.fromJson({
      'name': '1_2025-05-23_073137.mp4',
      'url': 'https://example.com/video.mp4',
      'size': 2048,
      'mime_type': 'video/mp4',
    });

    expect(video.id, '1_2025-05-23_073137.mp4');
    expect(video.url, 'https://example.com/video.mp4');
    expect(video.timestamp, DateTime(2025, 5, 23, 7, 31, 37));
    expect(video.matchesTimeInterval(8), isTrue);
    expect(video.matchesTimeInterval(13), isFalse);
  });

  test('ServerVideo.fromJson falls back to lastModified timestamp', () {
    final video = ServerVideo.fromJson({
      'name': 'video.mp4',
      'url': 'https://example.com/video.mp4',
      'last_modified': 1714032000,
    });

    expect(video.timestamp, DateTime.fromMillisecondsSinceEpoch(1714032000000));
  });

  test('BeeCount calculates activity and serializes JSON', () {
    final timestamp = DateTime(2026, 4, 25, 10, 30);
    final count = BeeCount(
      id: 'count-1',
      hiveId: 'hive-1',
      videoId: 'video-1',
      beesEntering: 42,
      beesExiting: 30,
      timestamp: timestamp,
      notes: 'Clear day',
      confidence: 0.91,
    );

    expect(count.netChange, 12);
    expect(count.totalActivity, 72);

    final json = count.toJson();
    expect(json['hive_id'], 'hive-1');
    expect(json['timestamp'], timestamp.toIso8601String());

    final parsed = BeeCount.fromJson(json);
    expect(parsed.netChange, 12);
    expect(parsed.confidence, 0.91);
  });

  test('BeeCount.copyWith replaces selected fields only', () {
    final original = BeeCount(
      hiveId: 'hive-1',
      beesEntering: 10,
      beesExiting: 5,
      timestamp: DateTime(2026, 4, 25),
    );

    final updated = original.copyWith(beesEntering: 20, notes: 'Updated');

    expect(updated.hiveId, 'hive-1');
    expect(updated.beesEntering, 20);
    expect(updated.beesExiting, 5);
    expect(updated.notes, 'Updated');
  });

  test('BeeAnalysisResult maps to and from JSON', () {
    final timestamp = DateTime(2026, 4, 25, 11);
    final result = BeeAnalysisResult.fromJson({
      'id': 'result-1',
      'video_id': 'video-1',
      'bees_in': 50,
      'bees_out': 35,
      'net_change': 15,
      'total_activity': 85,
      'detection_confidence': 92.5,
      'processing_time': 4.2,
      'frames_analyzed': 120,
      'model_version': 'v1',
      'timestamp': timestamp.toIso8601String(),
      'video_path': '/tmp/video.mp4',
    });

    expect(result.netChange, 15);
    expect(result.totalActivity, 85);
    expect(result.toJson()['model_version'], 'v1');
    expect(result.toString(), contains('beesIn: 50'));
  });
}
