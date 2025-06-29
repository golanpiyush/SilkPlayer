import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class YtDlpServices {
  static const MethodChannel _channel = MethodChannel(
    'com.example.sinkplayer/ytdlp',
  );

  /// Get detailed information about a video
  static Future<Map<String, dynamic>?> getVideoInfo(String url) async {
    try {
      developer.log('Getting video info for: $url', name: 'YtDlpServices');
      final result = await _channel.invokeMethod('getVideoInfo', {'url': url});
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in getVideoInfo: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log('Exception in getVideoInfo: $e', name: 'YtDlpServices');
      return null;
    }
  }

  /// Search for videos
  static Future<List<Map<String, dynamic>>?> searchVideos(
    String query, {
    int maxResults = 10,
  }) async {
    try {
      developer.log(
        'Searching videos for: $query, maxResults: $maxResults',
        name: 'YtDlpServices',
      );
      final result = await _channel.invokeMethod('searchVideos', {
        'query': query,
        'maxResults': maxResults,
      });
      return List<Map<String, dynamic>>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in searchVideos: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log('Exception in searchVideos: $e', name: 'YtDlpServices');
      return null;
    }
  }

  static Future<Map<String, String>?> getBestStreamUrls(String videoId) async {
    try {
      final result = await _channel.invokeMethod('getBestStreams', {
        'url': 'https://youtu.be/$videoId',
      });
      return result != null ? Map<String, String>.from(result) : null;
    } on PlatformException catch (e) {
      developer.log(
        'Failed to get streams: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAdaptiveStreams() async {
    try {
      final result = await _channel.invokeMethod('getAdaptiveStreams', {
        'url': 'https://youtu.be/$this.id',
      });

      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('Failed to get adaptive streams: ${e.message}');
      return null;
    }
  }

  // Helper method to get combined stream URL
  static Future<String?> getPlayableUrl(
    String videoId, {
    bool preferM4a = true,
  }) async {
    try {
      final streams = await getBestStreamUrls(videoId);
      if (streams == null) return null;

      // If audio-only stream is available and we prefer m4a
      if (preferM4a && streams.containsKey('audioUrl')) {
        return streams['audioUrl'];
      }

      // Fallback to video stream (which usually contains audio)
      return streams['videoUrl'] ?? streams['audioUrl'];
    } catch (e) {
      print('Error getting playable URL: $e');
      return null;
    }
  }

  /// Get high quality streams for a video
  static Future<Map<String, dynamic>?> getHQStreams(String url) async {
    try {
      developer.log('Getting HQ streams for: $url', name: 'YtDlpServices');
      final result = await _channel.invokeMethod('getHQStreams', {'url': url});
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in getHQStreams: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log('Exception in getHQStreams: $e', name: 'YtDlpServices');
      return null;
    }
  }

  /// Get stream by specific video quality
  static Future<Map<String, dynamic>?> getStreamByVideoQuality(
    String url,
    VideoQuality quality,
  ) async {
    try {
      developer.log(
        'Getting stream by video quality: ${quality.description}',
        name: 'YtDlpServices',
      );
      final result = await _channel.invokeMethod('getStreamByVideoQuality', {
        'url': url,
        'qualityHeight': quality.height,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in getStreamByVideoQuality: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log(
        'Exception in getStreamByVideoQuality: $e',
        name: 'YtDlpServices',
      );
      return null;
    }
  }

  /// Get stream by specific audio quality
  static Future<Map<String, dynamic>?> getStreamByAudioQuality(
    String url,
    AudioQuality quality,
  ) async {
    try {
      developer.log(
        'Getting stream by audio quality: ${quality.description}',
        name: 'YtDlpServices',
      );
      final result = await _channel.invokeMethod('getStreamByAudioQuality', {
        'url': url,
        'qualityBitrate': quality.bitrate,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in getStreamByAudioQuality: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log(
        'Exception in getStreamByAudioQuality: $e',
        name: 'YtDlpServices',
      );
      return null;
    }
  }

  /// Get custom quality streams (specify both video and audio quality)
  static Future<Map<String, dynamic>?> getCustomQualityStreams(
    String url,
    VideoQuality videoQuality,
    AudioQuality audioQuality,
  ) async {
    try {
      developer.log(
        'Getting custom quality streams - Video: ${videoQuality.description}, Audio: ${audioQuality.description}',
        name: 'YtDlpServices',
      );
      final result = await _channel.invokeMethod('getCustomQualityStreams', {
        'url': url,
        'videoQualityHeight': videoQuality.height,
        'audioQualityBitrate': audioQuality.bitrate,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in getCustomQualityStreams: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log(
        'Exception in getCustomQualityStreams: $e',
        name: 'YtDlpServices',
      );
      return null;
    }
  }

  /// Get channel information
  static Future<Map<String, dynamic>?> getChannelInfo(String channelUrl) async {
    try {
      developer.log(
        'Getting channel info for: $channelUrl',
        name: 'YtDlpServices',
      );
      final result = await _channel.invokeMethod('getChannelInfo', {
        'channelUrl': channelUrl,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in getChannelInfo: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log('Exception in getChannelInfo: $e', name: 'YtDlpServices');
      return null;
    }
  }

  /// Batch get thumbnails for multiple videos
  static Future<Map<String, String>?> batchGetThumbnails(
    List<String> videoIds, {
    String quality = 'maxres',
  }) async {
    try {
      developer.log(
        'Batch getting thumbnails for ${videoIds.length} videos with quality: $quality',
        name: 'YtDlpServices',
      );
      final result = await _channel.invokeMethod('batchGetThumbnails', {
        'videoIds': videoIds,
        'quality': quality,
      });
      return Map<String, String>.from(result);
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in batchGetThumbnails: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log(
        'Exception in batchGetThumbnails: $e',
        name: 'YtDlpServices',
      );
      return null;
    }
  }

  /// Clear thumbnail cache
  static Future<String?> clearThumbnailCache() async {
    try {
      developer.log('Clearing thumbnail cache', name: 'YtDlpServices');
      final result = await _channel.invokeMethod('clearThumbnailCache');
      return result;
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in clearThumbnailCache: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log(
        'Exception in clearThumbnailCache: $e',
        name: 'YtDlpServices',
      );
      return null;
    }
  }

  /// Get thumbnail cache size
  static Future<int?> getThumbnailCacheSize() async {
    try {
      developer.log('Getting thumbnail cache size', name: 'YtDlpServices');
      final result = await _channel.invokeMethod('getThumbnailCacheSize');
      return result;
    } on PlatformException catch (e) {
      developer.log(
        'Platform exception in getThumbnailCacheSize: ${e.message}',
        name: 'YtDlpServices',
      );
      return null;
    } catch (e) {
      developer.log(
        'Exception in getThumbnailCacheSize: $e',
        name: 'YtDlpServices',
      );
      return null;
    }
  }
}

/// Video quality enum matching Kotlin implementation
enum VideoQuality {
  quality144p(144, '144p'),
  quality240p(240, '240p'),
  quality360p(360, '360p'),
  quality480p(480, '480p'),
  quality720p(720, '720p HD'),
  quality1080p(1080, '1080p Full HD'),
  quality1440p(1440, '1440p 2K'),
  quality2160p(2160, '2160p 4K'),
  quality4320p(4320, '4320p 8K'),
  qualityBest(-1, 'Best Available'),
  qualityWorst(-2, 'Worst Available');

  const VideoQuality(this.height, this.description);
  final int height;
  final String description;
}

/// Audio quality enum matching Kotlin implementation
enum AudioQuality {
  quality48k(48, '48 kbps'),
  quality64k(64, '64 kbps'),
  quality96k(96, '96 kbps'),
  quality128k(128, '128 kbps'),
  quality160k(160, '160 kbps'),
  quality192k(192, '192 kbps'),
  quality256k(256, '256 kbps'),
  quality320k(320, '320 kbps'),
  qualityBest(-1, 'Best Available'),
  qualityWorst(-2, 'Worst Available');

  const AudioQuality(this.bitrate, this.description);
  final int bitrate;
  final String description;
}
