import 'dart:convert';

import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:http/http.dart' as http;

class ServerVideoService {
  final String baseUrl = 'http://196.43.168.57/api/v1';
  final http.Client _client = http.Client();

  final int _maxRetries = 5;
  final Duration _retryDelay = const Duration(seconds: 3);

  Future<List<ServerVideo>> fetchVideosFromServer(
    String hiveId, {
    DateTime? specificDate,
  }) async {
    print('Hive ID: $hiveId');
    print('Date: ${specificDate?.toString() ?? "today"}');

    try {
      List<ServerVideo> allVideos = await _fetchAllVideosFromServer(hiveId);

      if (allVideos.isEmpty) {
        print('No videos available from server');
        return [];
      }

      if (specificDate != null) {
        allVideos = _filterVideosByDate(allVideos, specificDate);
      }

      print('Returning ${allVideos.length} videos');
      return allVideos;
    } catch (e, stack) {
      print('Error fetching videos from server: $e');
      print('Stack trace: $stack');
      return [];
    }
  }

  List<ServerVideo> _filterVideosByDate(
    List<ServerVideo> videos,
    DateTime targetDate,
  ) {
    final dateVideos = videos.where((video) {
      if (video.timestamp == null) {
        return false;
      }

      return video.timestamp!.year == targetDate.year &&
          video.timestamp!.month == targetDate.month &&
          video.timestamp!.day == targetDate.day;
    }).toList();

    print(
      'Filtered ${videos.length} videos to ${dateVideos.length} for date ${targetDate.toString().split(' ')[0]}',
    );
    return dateVideos;
  }

  Future<List<ServerVideo>> _fetchAllVideosFromServer(String hiveId) async {
    List<ServerVideo> allVideos = [];

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        print('Fetch attempt ${attempt + 1}/$_maxRetries');

        final endpoints = ['$baseUrl/vids/latest', '$baseUrl/vids'];

        for (final endpoint in endpoints) {
          try {
            print('Trying endpoint: $endpoint');

            final response = await _client
                .get(
                  Uri.parse(endpoint),
                  headers: {'Accept': 'application/json'},
                )
                .timeout(const Duration(seconds: 15));

            print('Response status: ${response.statusCode}');

            if (response.statusCode != 200) {
              continue;
            }

            final responseData = json.decode(response.body);
            if (responseData is Map && responseData.containsKey('video')) {
              try {
                final videoData = responseData['video'];
                final video = ServerVideo.fromJson(
                  Map<String, dynamic>.from(videoData),
                );
                allVideos.add(video);
              } catch (e) {
                print('Error parsing "video" object: $e');
              }
            }

            if (allVideos.isNotEmpty) {
              print(
                'Successfully fetched ${allVideos.length} videos from $endpoint',
              );
              return allVideos;
            }
          } catch (e) {
            print('Error with endpoint $endpoint: $e');
          }
        }

        if (attempt < _maxRetries - 1) {
          print(
            'No videos found, retrying in ${_retryDelay.inSeconds} seconds...',
          );
          await Future.delayed(_retryDelay);
        }
      } catch (e) {
        print('Attempt ${attempt + 1} failed: $e');
      }
    }

    print('Total videos fetched: ${allVideos.length}');
    return allVideos;
  }

  Future<ServerVideo?> fetchLatestVideoFromServer(String hiveId) async {
    print('Hive ID: $hiveId');
    try {
      final endpoint = '$baseUrl/vids/latest';
      print('Trying endpoint: $endpoint');

      final response = await _client
          .get(
            Uri.parse(endpoint),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map && responseData.containsKey('video')) {
            final videoData = responseData['video'];
            final video = ServerVideo.fromJson(
              Map<String, dynamic>.from(videoData),
            );
            print('Successfully parsed latest video: ${video.id}');
            return video;
          }
        } catch (e, stack) {
          print('Error parsing latest video response: $e');
          print('Stack trace: $stack');
        }
      } else {
        print('Endpoint returned status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      print('Falling back to fetching all videos and finding the latest');
      final allVideos = await fetchVideosFromServer(hiveId);
      if (allVideos.isNotEmpty) {
        allVideos.sort(
          (a, b) => (b.timestamp ?? DateTime(1970)).compareTo(
            a.timestamp ?? DateTime(1970),
          ),
        );
        return allVideos.first;
      }

      return null;
    } catch (e, stack) {
      String errorMsg;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('Connection failed')) {
        errorMsg = 'No internet connection available for video checking';
      } else if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        errorMsg = 'Video server connection timeout';
      } else {
        errorMsg = 'Unable to connect to video server';
      }

      print('Error fetching latest video from server: $errorMsg');
      print('Technical details: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  Future<BeeCount?> processServerVideo(
    ServerVideo video, {
    required String hiveId,
    required Function(String) onStatusUpdate,
  }) async {
    onStatusUpdate('Automatic bee counting is currently disabled.');
    print(
      'Skipping automatic processing for ${video.id} in hive $hiveId because model-free mode is enabled.',
    );
    return null;
  }

  Future<List<BeeCount>> getBeeCountsForDate(
    String hiveId,
    DateTime date,
  ) async {
    final counts = await BeeCountDatabase.instance.readBeeCountsByDate(date);
    return counts.where((count) => count.hiveId == hiveId).toList();
  }

  void dispose() {
    print('Disposing ServerVideoService resources');
    _client.close();
  }
}
