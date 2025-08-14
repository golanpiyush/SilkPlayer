import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ytdlp_service.dart';

class YtdlpServicesProvider with ChangeNotifier {
  final YtdlpService _ytdlpService = YtdlpService();
  SharedPreferences? _prefs;

  // Settings
  String _videoQuality = '1080p';
  int _audioBitrate = 192;
  String _audioCodec = 'opus';
  String _videoCodec = 'avc1';
  bool _backgroundPlayback = false;

  // Loading states
  bool _isLoading = false;
  String? _error;

  // Current video data
  Map<String, dynamic>? _currentVideoStatus;
  List<Map<String, dynamic>>? _videoStreams;
  List<Map<String, dynamic>>? _audioStreams;
  Map<String, dynamic>? _unifiedStreams;

  // Getters
  YtdlpService get ytdlpService => _ytdlpService;
  String get videoQuality => _videoQuality;
  int get audioBitrate => _audioBitrate;
  String get audioCodec => _audioCodec;
  String get videoCodec => _videoCodec;
  bool get backgroundPlayback => _backgroundPlayback;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get currentVideoStatus => _currentVideoStatus;
  List<Map<String, dynamic>>? get videoStreams => _videoStreams;
  List<Map<String, dynamic>>? get audioStreams => _audioStreams;
  Map<String, dynamic>? get unifiedStreams => _unifiedStreams;

  // Available options
  final List<String> videoQualities = [
    '144p',
    '240p',
    '360p',
    '480p',
    '720p',
    '1080p',
    '1440p',
    '2160p',
  ];

  final List<int> audioBitrates = [32, 64, 96, 128, 160, 192, 256, 320];

  final List<String> audioCodecs = ['opus', 'aac', 'mp3', 'vorbis', 'best'];

  final List<String> videoCodecs = ['avc1', 'vp9', 'av01', 'best'];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_prefs != null) {
      _videoQuality = _prefs!.getString('video_quality') ?? '1080p';
      _audioBitrate = _prefs!.getInt('audio_bitrate') ?? 192;
      _audioCodec = _prefs!.getString('audio_codec') ?? 'opus';
      _videoCodec = _prefs!.getString('video_codec') ?? 'avc1';
      _backgroundPlayback = _prefs!.getBool('background_playback') ?? false;
      notifyListeners();
    }
  }

  Future<void> setVideoQuality(String quality) async {
    _videoQuality = quality;
    await _prefs?.setString('video_quality', quality);
    notifyListeners();
  }

  Future<void> setAudioBitrate(int bitrate) async {
    _audioBitrate = bitrate;
    await _prefs?.setInt('audio_bitrate', bitrate);
    notifyListeners();
  }

  Future<void> setAudioCodec(String codec) async {
    _audioCodec = codec;
    await _prefs?.setString('audio_codec', codec);
    notifyListeners();
  }

  Future<void> setVideoCodec(String codec) async {
    _videoCodec = codec;
    await _prefs?.setString('video_codec', codec);
    notifyListeners();
  }

  Future<void> setBackgroundPlayback(bool enabled) async {
    _backgroundPlayback = enabled;
    await _prefs?.setBool('background_playback', enabled);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // FIXED: Implement the missing checkVideoStatus method
  // Future<void> checkVideoStatus(String videoId) async {
  //   _setLoading(true);
  //   _setError(null);

  //   try {
  //     // Check if video is available using the YtdlpService
  //     final isAvailable = await _ytdlpService.isVideoAvailable(videoId);

  //     _currentVideoStatus = {
  //       'videoId': videoId,
  //       'available': isAvailable,
  //       'status': isAvailable ? 'available' : 'unavailable',
  //       'checkedAt': DateTime.now().toIso8601String(),
  //     };

  //     if (kDebugMode) {
  //       print(
  //         'Video status check complete for $videoId: ${isAvailable ? "Available" : "Unavailable"}',
  //       );
  //     }
  //   } catch (e) {
  //     _setError('Failed to check video status: $e');
  //     _currentVideoStatus = {
  //       'videoId': videoId,
  //       'available': false,
  //       'status': 'error',
  //       'error': e.toString(),
  //       'checkedAt': DateTime.now().toIso8601String(),
  //     };
  //   } finally {
  //     _setLoading(false);
  //   }
  // }

  // FIXED: Improved getVideoStreams with better error handling
  Future<void> getVideoStreams(String videoId) async {
    _setLoading(true);
    _setError(null);

    try {
      _videoStreams = await _ytdlpService.getVideoStreams(
        videoId: videoId,
        quality: _videoQuality,
        timeout: const Duration(seconds: 20),
      );

      if (kDebugMode) {
        print(
          'Retrieved ${_videoStreams?.length ?? 0} video streams for $videoId',
        );
      }
    } catch (e) {
      _setError('Failed to get video streams: $e');
      if (kDebugMode) {
        print('Error getting video streams for $videoId: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // FIXED: Improved getAudioStreams with better error handling
  Future<void> getAudioStreams(String videoId) async {
    _setLoading(true);
    _setError(null);

    try {
      _audioStreams = await _ytdlpService.getAudioStreams(
        videoId: videoId,
        bitrate: _audioBitrate,
        codec: _audioCodec == 'best' ? null : _audioCodec,
        timeout: const Duration(seconds: 20),
      );

      if (kDebugMode) {
        print(
          'Retrieved ${_audioStreams?.length ?? 0} audio streams for $videoId',
        );
      }
    } catch (e) {
      _setError('Failed to get audio streams: $e');
      if (kDebugMode) {
        print('Error getting audio streams for $videoId: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // FIXED: Corrected parameter names and improved error handling
  Future<void> getUnifiedStreams(String videoId) async {
    _setLoading(true);
    _setError(null);

    try {
      _unifiedStreams = await _ytdlpService.getUnifiedStreams(
        videoId: videoId,
        audioBitrate: _audioBitrate,
        videoQuality: _videoQuality,
        audioCodec: _audioCodec == 'best' ? null : _audioCodec,
        videoCodec: _videoCodec == 'best' ? null : _videoCodec,
        includeVideo: true,
        includeAudio: true,
        timeout: const Duration(seconds: 25),
      );

      if (kDebugMode) {
        final videoCount = (_unifiedStreams?['video'] as List?)?.length ?? 0;
        final audioCount = (_unifiedStreams?['audio'] as List?)?.length ?? 0;
        final duration = _unifiedStreams?['duration'] ?? 0;
        print(
          'Retrieved unified streams for $videoId: $videoCount video, $audioCount audio, duration: ${duration}s',
        );
      }
    } catch (e) {
      _setError('Failed to get unified streams: $e');
      if (kDebugMode) {
        print('Error getting unified streams for $videoId: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // ENHANCED: Get all stream types at once for efficiency
  Future<void> getAllStreams(String videoId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Get all stream types in parallel for better performance
      final futures = await Future.wait([
        _ytdlpService
            .getVideoStreams(
              videoId: videoId,
              quality: _videoQuality,
              timeout: const Duration(seconds: 20),
            )
            .catchError((e) {
              if (kDebugMode) print('Video streams error: $e');
              return <Map<String, dynamic>>[];
            }),

        _ytdlpService
            .getAudioStreams(
              videoId: videoId,
              bitrate: _audioBitrate,
              codec: _audioCodec == 'best' ? null : _audioCodec,
              timeout: const Duration(seconds: 20),
            )
            .catchError((e) {
              if (kDebugMode) print('Audio streams error: $e');
              return <Map<String, dynamic>>[];
            }),

        _ytdlpService
            .getUnifiedStreams(
              videoId: videoId,
              audioBitrate: _audioBitrate,
              videoQuality: _videoQuality,
              audioCodec: _audioCodec == 'best' ? null : _audioCodec,
              videoCodec: _videoCodec == 'best' ? null : _videoCodec,
              includeVideo: true,
              includeAudio: true,
              timeout: const Duration(seconds: 25),
            )
            .catchError((e) {
              if (kDebugMode) print('Unified streams error: $e');
              return <String, dynamic>{};
            }),
      ]);

      _videoStreams = futures[0] as List<Map<String, dynamic>>;
      _audioStreams = futures[1] as List<Map<String, dynamic>>;
      _unifiedStreams = futures[2] as Map<String, dynamic>;

      if (kDebugMode) {
        print('Retrieved all streams for $videoId:');
        print('  Video: ${_videoStreams?.length ?? 0} streams');
        print('  Audio: ${_audioStreams?.length ?? 0} streams');
        print(
          '  Unified: ${(_unifiedStreams?['video'] as List?)?.length ?? 0} video, ${(_unifiedStreams?['audio'] as List?)?.length ?? 0} audio',
        );
      }
    } catch (e) {
      _setError('Failed to get streams: $e');
      if (kDebugMode) {
        print('Error getting all streams for $videoId: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // FIXED: Get best available stream for immediate playback with correct format handling
  Future<Map<String, dynamic>?> getBestStreamUrls(String videoId) async {
    try {
      await getUnifiedStreams(videoId);

      if (_unifiedStreams != null && _unifiedStreams!.isNotEmpty) {
        final videoStreams = _unifiedStreams!['video'] as List?;
        final audioStreams = _unifiedStreams!['audio'] as List?;
        final duration = _unifiedStreams!['duration'];

        // Check if both video and audio streams are available
        if (videoStreams != null &&
            videoStreams.isNotEmpty &&
            audioStreams != null &&
            audioStreams.isNotEmpty) {
          // Get the first (best) video stream
          final bestVideo = videoStreams.first as Map<String, dynamic>;
          final bestAudio = audioStreams.first as Map<String, dynamic>;

          return {
            'videoUrl': bestVideo['url']?.toString() ?? '',
            'audioUrl': bestAudio['url']?.toString() ?? '',
            'duration': duration ?? 0,
            'quality': bestVideo['quality']?.toString() ?? _videoQuality,
            'videoCodec': bestVideo['codec']?.toString() ?? 'unknown',
            'audioCodec': bestAudio['codec']?.toString() ?? 'unknown',
            'videoBitrate': bestVideo['bitrate']?.toString() ?? 'unknown',
            'audioBitrate':
                bestAudio['bitrate']?.toString() ?? _audioBitrate.toString(),
            'videoFormat': bestVideo['format']?.toString() ?? 'unknown',
            'audioFormat': bestAudio['format']?.toString() ?? 'unknown',
          };
        }

        // If only video streams are available (for video-only content)
        if (videoStreams != null && videoStreams.isNotEmpty) {
          final bestVideo = videoStreams.first as Map<String, dynamic>;

          return {
            'videoUrl': bestVideo['url']?.toString() ?? '',
            'audioUrl': null,
            'duration': duration ?? 0,
            'quality': bestVideo['quality']?.toString() ?? _videoQuality,
            'videoCodec': bestVideo['codec']?.toString() ?? 'unknown',
            'audioCodec': null,
            'videoBitrate': bestVideo['bitrate']?.toString() ?? 'unknown',
            'audioBitrate': null,
            'videoFormat': bestVideo['format']?.toString() ?? 'unknown',
            'audioFormat': null,
          };
        }

        // If only audio streams are available (for audio-only content)
        if (audioStreams != null && audioStreams.isNotEmpty) {
          final bestAudio = audioStreams.first as Map<String, dynamic>;

          return {
            'videoUrl': null,
            'audioUrl': bestAudio['url']?.toString() ?? '',
            'duration': duration ?? 0,
            'quality': null,
            'videoCodec': null,
            'audioCodec': bestAudio['codec']?.toString() ?? 'unknown',
            'videoBitrate': null,
            'audioBitrate':
                bestAudio['bitrate']?.toString() ?? _audioBitrate.toString(),
            'videoFormat': null,
            'audioFormat': bestAudio['format']?.toString() ?? 'unknown',
          };
        }
      }

      if (kDebugMode) {
        print('No suitable streams found for $videoId');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting best stream URLs for $videoId: $e');
      }
      return null;
    }
  }

  // NEW: Get video duration from unified streams
  int? getVideoDuration() {
    return _unifiedStreams?['duration'] as int?;
  }

  // NEW: Get all available qualities from unified streams
  List<String> getAvailableQualities() {
    final videoStreams = _unifiedStreams?['video'] as List?;
    if (videoStreams == null || videoStreams.isEmpty) {
      return [];
    }

    final qualities = videoStreams
        .map((stream) => stream['quality']?.toString())
        .where((quality) => quality != null)
        .cast<String>()
        .toSet()
        .toList();

    // Sort qualities in descending order
    qualities.sort((a, b) {
      final aNum = int.tryParse(a.replaceAll('p', '')) ?? 0;
      final bNum = int.tryParse(b.replaceAll('p', '')) ?? 0;
      return bNum.compareTo(aNum);
    });

    return qualities;
  }

  // NEW: Get stream by specific quality
  Future<Map<String, dynamic>?> getStreamByQuality(
    String videoId,
    String quality,
  ) async {
    try {
      await getUnifiedStreams(videoId);

      if (_unifiedStreams != null) {
        final videoStreams = _unifiedStreams!['video'] as List?;
        final audioStreams = _unifiedStreams!['audio'] as List?;

        // Find video stream with requested quality
        Map<String, dynamic>? targetVideo;
        if (videoStreams != null) {
          for (final stream in videoStreams) {
            if (stream['quality']?.toString() == quality) {
              targetVideo = stream as Map<String, dynamic>;
              break;
            }
          }
        }

        if (targetVideo != null &&
            audioStreams != null &&
            audioStreams.isNotEmpty) {
          final bestAudio = audioStreams.first as Map<String, dynamic>;

          return {
            'videoUrl': targetVideo['url']?.toString() ?? '',
            'audioUrl': bestAudio['url']?.toString() ?? '',
            'duration': _unifiedStreams!['duration'] ?? 0,
            'quality': quality,
            'videoCodec': targetVideo['codec']?.toString() ?? 'unknown',
            'audioCodec': bestAudio['codec']?.toString() ?? 'unknown',
          };
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stream by quality $quality for $videoId: $e');
      }
      return null;
    }
  }

  void clearData() {
    _currentVideoStatus = null;
    _videoStreams = null;
    _audioStreams = null;
    _unifiedStreams = null;
    _setError(null);
    notifyListeners();
  }

  // ENHANCED: Clear cache and reset service
  void clearCache() {
    _ytdlpService.clearCache();
    clearData();
    if (kDebugMode) {
      print('YT-DLP cache and data cleared');
    }
  }

  // ENHANCED: Get service statistics for debugging
  Map<String, dynamic> getServiceStats() {
    final stats = _ytdlpService.getCacheStats();
    stats['hasVideoStreams'] = _videoStreams?.isNotEmpty == true;
    stats['hasAudioStreams'] = _audioStreams?.isNotEmpty == true;
    stats['hasUnifiedStreams'] = _unifiedStreams?.isNotEmpty == true;
    stats['currentError'] = _error;
    stats['isLoading'] = _isLoading;
    stats['videoDuration'] = getVideoDuration();
    stats['availableQualities'] = getAvailableQualities();
    return stats;
  }
}

// Provider definition (should be at top level, outside the class)
final ytdlpServicesProvider = ChangeNotifierProvider<YtdlpServicesProvider>((
  ref,
) {
  final provider = YtdlpServicesProvider();

  // Initialize the provider
  provider.init().catchError((e) {
    if (kDebugMode) {
      print('Error initializing YtdlpServicesProvider: $e');
    }
  });

  return provider;
});
