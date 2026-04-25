import 'dart:typed_data';

import 'package:HPGM/models/video_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VideoFile stores local video metadata', () {
    final timestamp = DateTime(2026, 4, 25, 9);
    final thumbnail = Uint8List.fromList([1, 2, 3]);

    final video = VideoFile(
      id: 'video-1',
      filePath: '/videos/video-1.mp4',
      size: 4096,
      thumbnail: thumbnail,
      timestamp: timestamp,
      analysisStatus: 'pending',
    );

    expect(video.id, 'video-1');
    expect(video.filePath, '/videos/video-1.mp4');
    expect(video.size, 4096);
    expect(video.thumbnail, thumbnail);
    expect(video.timestamp, timestamp);
    expect(video.analysisStatus, 'pending');
  });
}
