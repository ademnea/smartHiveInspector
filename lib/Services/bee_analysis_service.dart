import 'dart:io';

import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BeeAnalysisService {
  static final BeeAnalysisService _instance = BeeAnalysisService._internal();
  factory BeeAnalysisService() => _instance;
  BeeAnalysisService._internal();
  static BeeAnalysisService get instance => _instance;

  static const String disabledReason =
      'Automatic bee video analysis is disabled in model-free mode.';

  bool _isInitialized = false;

  bool get isModelBasedAnalysisEnabled => false;

  Future<bool> initialize() async {
    _isInitialized = true;
    print('BeeAnalysisService initialized in model-free mode');
    return true;
  }

  Future<BeeCount?> analyzeVideoWithML(
    String hiveId,
    String videoId,
    String videoPath, {
    Function(double)? onProgress,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    onProgress?.call(0.0);
    print(
      'Skipping automatic video analysis for $videoId in hive $hiveId: $disabledReason',
    );
    return null;
  }

  Future<String?> downloadVideo(
    String url, {
    Function(double)? onProgress,
  }) async {
    final client = http.Client();
    try {
      print('Downloading video from $url');

      if (!url.startsWith('http')) {
        throw Exception('Invalid URL: $url');
      }

      onProgress?.call(0.0);

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final request = http.Request('GET', Uri.parse(url));
          final response = await client
              .send(request)
              .timeout(const Duration(seconds: 30));

          if (response.statusCode != 200) {
            print(
              'Failed to download video: HTTP ${response.statusCode}, retrying...',
            );
            continue;
          }

          final contentLength = response.contentLength ?? 0;
          final directory = await getTemporaryDirectory();
          final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          final sink = file.openWrite();

          int downloadedBytes = 0;
          await for (final chunk in response.stream) {
            sink.add(chunk);
            downloadedBytes += chunk.length;

            if (contentLength > 0) {
              onProgress?.call((downloadedBytes / contentLength) * 0.9);
            }
          }

          await sink.close();
          onProgress?.call(1.0);

          return filePath;
        } catch (e) {
          if (attempt == 3) {
            rethrow;
          }

          print('Video download attempt $attempt failed: $e');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      return null;
    } catch (e) {
      print('Error downloading video: $e');
      return null;
    } finally {
      client.close();
    }
  }

  void dispose() {
    _isInitialized = false;
    print('Disposing BeeAnalysisService resources');
  }
}
