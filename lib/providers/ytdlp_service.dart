import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_ytdlp_plugin/flutter_ytdlp_plugin.dart';

/// Enhanced YT-DLP Service with improved error handling and timeout management
class YtdlpService {
  // Singleton pattern for better resource management
  static final YtdlpService _instance = YtdlpService._internal();
  factory YtdlpService() => _instance;
  YtdlpService._internal();

  // More aggressive timeout configurations for faster failures
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const Duration _quickTimeout = Duration(seconds: 10);
  static const Duration _statusTimeout = Duration(seconds: 5); // Much shorter
  static const Duration _retryDelay = Duration(milliseconds: 500);

  // Cache for video availability to avoid repeated checks
  final Map<String, bool> _availabilityCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 3); // Shorter cache

  // Track failed attempts to avoid repeated failures
  final Map<String, int> _failureCount = {};
  final Map<String, DateTime> _lastFailure = {};
  static const int _maxFailures = 2;
  static const Duration _failureCooldown = Duration(minutes: 5);

  /// Get unified streams with better error recovery
  Future<Map<String, dynamic>> getUnifiedStreams({
    required String videoId,
    String videoQuality = '1080p',
    int audioBitrate = 240,
    String? audioCodec,
    String? videoCodec,
    bool includeVideo = true,
    bool includeAudio = true,
    Duration? timeout,
  }) async {
    final cleanVideoId = _extractVideoId(videoId);
    final actualTimeout = timeout ?? _defaultTimeout;

    try {
      print('🎬 YT-DLP: Getting unified streams for $cleanVideoId');
      print(
        '🎬 YT-DLP: Quality: $videoQuality, Audio bitrate: ${audioBitrate}kbps',
      );

      // Skip availability check if we're in failure cooldown
      if (_isInFailureCooldown(cleanVideoId)) {
        throw Exception('Video in failure cooldown, skipping YT-DLP attempt');
      }

      // Direct extraction - plugin handles fallbacks automatically
      final result = await FlutterYtdlpPlugin.getMuxedStreams(
        cleanVideoId,
        videoQuality: _normalizeQuality(videoQuality),
        audioBitrate: audioBitrate,
        includeVideo: includeVideo,
        includeAudio: includeAudio,
        audioCodec: audioCodec ?? 'opus', // Default to opus instead of 'best'
        videoCodec: videoCodec ?? 'avc1', // Default to avc1 instead of 'best'
      ).timeout(actualTimeout);

      // Clear failure count on success
      _resetFailureCount(cleanVideoId);

      return _processUnifiedStreams(result, videoQuality);
    } on TimeoutException catch (e) {
      print('⏰ YT-DLP unified streams timeout: ${e.duration}');
      _recordFailure(cleanVideoId);
      throw TimeoutException('YT-DLP stream extraction timeout', actualTimeout);
    } catch (e) {
      print('❌ YT-DLP unified streams failed: $e');
      _recordFailure(cleanVideoId);
      rethrow;
    }
  }

  /// Get video streams with retry logic
  Future<List<Map<String, dynamic>>> getVideoStreams({
    required String videoId,
    String quality = '1080p',
    Duration? timeout,
    int maxRetries = 2,
  }) async {
    final cleanVideoId = _extractVideoId(videoId);

    if (_isInFailureCooldown(cleanVideoId)) {
      throw Exception('Video in failure cooldown');
    }

    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🎥 YT-DLP: Getting video streams for $cleanVideoId (attempt $attempt)',
        );

        final result = await FlutterYtdlpPlugin.getVideoStreams(
          cleanVideoId,
          quality: _normalizeQuality(quality),
        ).timeout(timeout ?? _quickTimeout);

        // Clear failure count on success
        _resetFailureCount(cleanVideoId);

        return _processVideoStreams(result);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('❌ Video streams attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          await Future.delayed(_retryDelay * attempt);
        }
      }
    }

    _recordFailure(cleanVideoId);
    throw lastException ??
        Exception('Failed to get video streams after $maxRetries attempts');
  }

  /// Get audio streams with retry logic
  Future<List<Map<String, dynamic>>> getAudioStreams({
    required String videoId,
    int bitrate = 192,
    String? codec,
    Duration? timeout,
    int maxRetries = 2,
  }) async {
    final cleanVideoId = _extractVideoId(videoId);

    if (_isInFailureCooldown(cleanVideoId)) {
      throw Exception('Video in failure cooldown');
    }

    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🎵 YT-DLP: Getting audio streams for $cleanVideoId (attempt $attempt)',
        );

        final result = await FlutterYtdlpPlugin.getAudioStreams(
          cleanVideoId,
          bitrate: bitrate,
          codec: codec ?? 'opus', // Default codec instead of 'best'
        ).timeout(timeout ?? _quickTimeout);

        // Clear failure count on success
        _resetFailureCount(cleanVideoId);

        return _processAudioStreams(result);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('❌ Audio streams attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          await Future.delayed(_retryDelay * attempt);
        }
      }
    }

    _recordFailure(cleanVideoId);
    throw lastException ??
        Exception('Failed to get audio streams after $maxRetries attempts');
  }

  // ============================================================================
  // FAILURE TRACKING METHODS
  // ============================================================================

  /// Record a failure for a video
  void _recordFailure(String videoId) {
    _failureCount[videoId] = (_failureCount[videoId] ?? 0) + 1;
    _lastFailure[videoId] = DateTime.now();
    print('📊 Video $videoId failure count: ${_failureCount[videoId]}');
  }

  /// Check if video is in failure cooldown
  bool _isInFailureCooldown(String videoId) {
    final failures = _failureCount[videoId] ?? 0;
    if (failures < _maxFailures) return false;

    final lastFailureTime = _lastFailure[videoId];
    if (lastFailureTime == null) return false;

    final timeSinceFailure = DateTime.now().difference(lastFailureTime);
    return timeSinceFailure < _failureCooldown;
  }

  /// Reset failure count for a video (call this on success)
  void _resetFailureCount(String videoId) {
    _failureCount.remove(videoId);
    _lastFailure.remove(videoId);
  }

  // ============================================================================
  // EXISTING HELPER METHODS (unchanged)
  // ============================================================================

  String _extractVideoId(String input) {
    final patterns = [
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/v\/)([a-zA-Z0-9_-]{11})',
      r'^([a-zA-Z0-9_-]{11})$',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(input);
      if (match != null) {
        return match.group(1)!;
      }
    }

    return input;
  }

  String _normalizeQuality(String quality) {
    switch (quality.toLowerCase()) {
      case 'auto':
        return 'best';
      case '2k':
      case '1440p':
        return '1440p';
      case '4k':
      case '2160p':
        return '2160p';
      default:
        if (!quality.endsWith('p') && quality != 'best' && quality != 'worst') {
          return '${quality}p';
        }
        return quality;
    }
  }

  bool _isAvailabilityCached(String videoId) {
    if (!_availabilityCache.containsKey(videoId)) return false;

    final timestamp = _cacheTimestamps[videoId];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  Map<String, dynamic> _processUnifiedStreams(
    Map<String, dynamic> result,
    String requestedQuality,
  ) {
    try {
      final processedResult = <String, dynamic>{};

      if (result.containsKey('duration')) {
        processedResult['duration'] = result['duration'];
      }

      if (result.containsKey('video') && result['video'] is List) {
        final videoStreams = (result['video'] as List)
            .cast<Map<String, dynamic>>()
            .where(
              (stream) =>
                  stream['url'] != null && stream['url'].toString().isNotEmpty,
            )
            .map(_enhanceVideoStream)
            .toList();
        processedResult['video'] = videoStreams;
        print('✅ YT-DLP: Found ${videoStreams.length} video stream(s)');
      }

      if (result.containsKey('audio') && result['audio'] is List) {
        final audioStreams = (result['audio'] as List)
            .cast<Map<String, dynamic>>()
            .where(
              (stream) =>
                  stream['url'] != null && stream['url'].toString().isNotEmpty,
            )
            .map(_enhanceAudioStream)
            .toList();
        processedResult['audio'] = audioStreams;
        print('✅ YT-DLP: Found ${audioStreams.length} audio stream(s)');
      }

      // Validate that we have at least some streams
      final hasVideo = (processedResult['video'] as List?)?.isNotEmpty ?? false;
      final hasAudio = (processedResult['audio'] as List?)?.isNotEmpty ?? false;

      if (!hasVideo && !hasAudio) {
        throw Exception('No valid streams found in result');
      }

      return processedResult;
    } catch (e) {
      print('❌ Error processing unified streams: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _processVideoStreams(
    List<Map<String, dynamic>> streams,
  ) {
    return streams
        .where(
          (stream) =>
              stream['url'] != null && stream['url'].toString().isNotEmpty,
        )
        .map(_enhanceVideoStream)
        .toList();
  }

  List<Map<String, dynamic>> _processAudioStreams(
    List<Map<String, dynamic>> streams,
  ) {
    return streams
        .where(
          (stream) =>
              stream['url'] != null && stream['url'].toString().isNotEmpty,
        )
        .map(_enhanceAudioStream)
        .toList();
  }

  Map<String, dynamic> _enhanceVideoStream(Map<String, dynamic> stream) {
    final enhanced = Map<String, dynamic>.from(stream);

    enhanced['url'] = stream['url'] ?? '';
    enhanced['quality'] =
        _normalizeStreamQuality(stream['quality']) ?? 'unknown';
    enhanced['codec'] = stream['vcodec'] ?? stream['codec'] ?? 'unknown';
    enhanced['fps'] = _safeParseDouble(stream['fps']) ?? 30.0;
    enhanced['width'] = _safeParseInt(stream['width']) ?? 0;
    enhanced['height'] = _safeParseInt(stream['height']) ?? 0;
    enhanced['filesize'] = _safeParseInt(stream['filesize']) ?? 0;
    enhanced['format'] = stream['ext'] ?? 'mp4';
    enhanced['format_id'] = stream['format_id'] ?? 'unknown';

    return enhanced;
  }

  Map<String, dynamic> _enhanceAudioStream(Map<String, dynamic> stream) {
    final enhanced = Map<String, dynamic>.from(stream);

    enhanced['url'] = stream['url'] ?? '';
    enhanced['codec'] = stream['acodec'] ?? stream['codec'] ?? 'unknown';
    enhanced['bitrate'] =
        _safeParseDouble(stream['abr']) ??
        _safeParseDouble(stream['bitrate']) ??
        128.0;
    enhanced['sample_rate'] = _safeParseInt(stream['asr']) ?? 44100;
    enhanced['filesize'] = _safeParseInt(stream['filesize']) ?? 0;
    enhanced['format'] = stream['ext'] ?? 'mp4';
    enhanced['format_id'] = stream['format_id'] ?? 'unknown';

    return enhanced;
  }

  String? _normalizeStreamQuality(dynamic quality) {
    if (quality == null) return null;
    final qualityStr = quality.toString();
    final match = RegExp(r'(\d+)p?').firstMatch(qualityStr);
    if (match != null) {
      return '${match.group(1)}p';
    }
    return qualityStr;
  }

  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Clear all caches and reset failure tracking
  void clearCache() {
    _availabilityCache.clear();
    _cacheTimestamps.clear();
    _failureCount.clear();
    _lastFailure.clear();
    print('🧹 YT-DLP: All caches cleared');
  }

  /// Get comprehensive cache and failure statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_videos': _availabilityCache.length,
      'available_videos': _availabilityCache.values.where((v) => v).length,
      'unavailable_videos': _availabilityCache.values.where((v) => !v).length,
      'failed_videos': _failureCount.length,
      'videos_in_cooldown': _failureCount.entries
          .where((entry) => _isInFailureCooldown(entry.key))
          .length,
    };
  }
}
