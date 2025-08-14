import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silkplayer/models/stream_quality-info.dart';
import 'package:silkplayer/models/video_model.dart';
import 'package:silkplayer/providers/ytdlpServicesProvider.dart';
import 'package:silkplayer/providers/ytdlp_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// ============================================================================
// PROVIDERS & STATE MANAGEMENT
// ============================================================================

/// Quality options available for video playback
const List<String> videoQualityOptions = [
  '144p',
  '240p',
  '360p',
  '480p',
  '720p',
  '1080p',
  '1440p',
  '2160p',
  'Auto',
];

/// Force refresh state for clearing caches
final forceRefreshProvider = StateProvider<bool>((ref) => false);

/// Selected country for geo-targeted content
final selectedCountryProvider = StateProvider<String>((ref) => 'India');

// ============================================================================
// VIDEO SERVICE CLASS
// ============================================================================

class VideoService {
  // YouTube Explode instance for API calls
  final YoutubeExplode _youtube = YoutubeExplode();
  final YtdlpService _ytdlpService = YtdlpService();

  // Random number generator for variety in results
  final Random _random = Random();

  // Cache management
  final Map<String, List<VideoModel>> _cachedVideos = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Set<String> _seenVideoIds = {};

  // Cache duration in minutes
  static const int _cacheExpiryMinutes = 15;

  // HTTP client with timeout
  static const Duration _defaultTimeout = Duration(
    seconds: 20,
  ); // Reduced from 30
  static const Duration _streamTimeout = Duration(
    seconds: 20,
  ); // Reduced from 45

  /// Quality options available for video playback
  static List<String> videoQualityOptions = [
    '144p',
    '240p',
    '360p',
    '480p',
    '720p',
    '1080p',
    '1440p',
    '2160p',
    'Auto',
  ];

  /// Initialize the service (placeholder for future setup)
  Future<void> initialize() async {
    // Future initialization logic can go here
    print('🎬 VideoService initialized with YouTube Explode');
  }

  // ============================================================================
  // ENHANCED ERROR HANDLING
  // ============================================================================

  String _cleanQualityString(String quality) {
    return quality.replaceAll(RegExp(r'[^0-9pAuto]'), '').trim();
  }

  String? _normalizeQualityFromYtdlp(dynamic quality) {
    if (quality == null) return null;
    final match = RegExp(
      r'(\d+)p',
    ).firstMatch(quality.toString().toLowerCase());
    return match?.group(0);
  }

  String? _normalizeQuality(String quality) {
    final match = RegExp(r'(\d+)p').firstMatch(quality.toLowerCase());
    return match?.group(0);
  }

  int? _parseQualityNumber(String quality) {
    final cleanQuality = quality
        .toLowerCase()
        .replaceAll('p', '')
        .replaceAll('k', '000');

    switch (cleanQuality) {
      case '2k':
      case '1440':
        return 1440;
      case '4k':
      case '2160':
        return 2160;
      default:
        return int.tryParse(cleanQuality);
    }
  }

  int _safeBitrateToInt(dynamic bitrate) {
    if (bitrate == null) return 128;
    if (bitrate is int) return bitrate;
    if (bitrate is double) return bitrate.round();
    if (bitrate is String) {
      return int.tryParse(bitrate) ?? 128;
    }
    return 128;
  }

  List<String> _getAvailableQualitiesFromYtdlp(
    List<Map<String, dynamic>> streams,
  ) {
    final qualities = <String>{'Auto'};

    for (final stream in streams) {
      final quality = _normalizeQualityFromYtdlp(stream['quality']);
      if (quality != null) {
        qualities.add(quality);
      }
    }

    return qualities.toList()..sort((a, b) {
      if (a == 'Auto') return -1;
      if (b == 'Auto') return 1;
      return (_parseQualityNumber(b) ?? 0).compareTo(
        _parseQualityNumber(a) ?? 0,
      );
    });
  }

  List<String> _getAvailableQualities(List<VideoOnlyStreamInfo> streams) {
    final qualities = <String>{'Auto'};

    for (final stream in streams) {
      final quality = _normalizeQuality(stream.videoQuality.toString());
      if (quality != null) {
        qualities.add(quality);
      }
    }

    return qualities.toList()..sort((a, b) {
      if (a == 'Auto') return -1;
      if (b == 'Auto') return 1;
      return (_parseQualityNumber(b) ?? 0).compareTo(
        _parseQualityNumber(a) ?? 0,
      );
    });
  }

  /// Handle YouTube Explode specific errors
  String _handleYouTubeError(dynamic error) {
    if (error is VideoUnplayableException) {
      return 'Video is not available for playback';
    } else if (error is VideoUnavailableException) {
      return 'Video is unavailable in your region';
    } else if (error is RequestLimitExceededException) {
      return 'Request limit exceeded. Please try again later';
    } else if (error is SocketException) {
      return 'Network connection error. Check your internet connection';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again';
    } else if (error is HttpException) {
      return 'Server error. Please try again later';
    } else {
      return 'An unexpected error occurred: ${error.toString()}';
    }
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  /// Clear all caches and force refresh
  Future<void> forceRefreshAllCaches(WidgetRef ref) async {
    _cachedVideos.clear();
    _cacheTimestamps.clear();
    _seenVideoIds.clear();

    // Update force refresh state
    ref.read(forceRefreshProvider.notifier).state = true;

    // Invalidate all providers
    ref.invalidate(randomVideosProvider);
    ref.invalidate(trendingVideosProvider);
    ref.invalidate(randomVideosStreamProvider);

    print('🔄 All caches cleared and providers refreshed');
  }

  /// Check if cache is expired for a given key
  bool _isCacheExpired(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return true;

    final now = DateTime.now();
    return now.difference(timestamp).inMinutes >= _cacheExpiryMinutes;
  }

  /// Store results in cache
  void _cacheResults(String key, List<VideoModel> videos) {
    _cachedVideos[key] = videos;
    _cacheTimestamps[key] = DateTime.now();
  }

  // ============================================================================
  // VIDEO MODEL ENHANCEMENT
  // ============================================================================

  /// Get highest quality thumbnail URL from available options
  String _getHighestQualityThumbnail(Video video) {
    try {
      final thumbnails = video.thumbnails;

      // Priority: maxres -> high -> medium -> standard -> low
      if (thumbnails.maxResUrl.isNotEmpty) return thumbnails.maxResUrl;
      if (thumbnails.highResUrl.isNotEmpty) return thumbnails.highResUrl;
      if (thumbnails.mediumResUrl.isNotEmpty) return thumbnails.mediumResUrl;
      if (thumbnails.standardResUrl.isNotEmpty)
        return thumbnails.standardResUrl;

      return thumbnails.lowResUrl;
    } catch (e) {
      print('⚠️ Error getting high quality thumbnail: $e');
      return video.thumbnails.mediumResUrl;
    }
  }

  /// Create enhanced VideoModel with channel info and high-quality thumbnails
  Future<VideoModel> _createEnhancedVideoModel(Video video) async {
    try {
      // Fetch channel details with much shorter timeout
      Channel? channel;
      String? channelAvatarUrl;

      try {
        // Use a very short timeout for channel fetching to prevent blocking
        channel = await _youtube.channels
            .get(video.channelId)
            .timeout(const Duration(seconds: 5)); // Much shorter timeout

        if (channel?.logoUrl.isNotEmpty == true) {
          channelAvatarUrl = channel!.logoUrl
              .replaceAll('=s88-', '=s240-')
              .replaceAll('=s100-', '=s240-')
              .replaceAll('=s176-', '=s240-');
        }
      } catch (e) {
        // Silently fail and continue without channel avatar
        // Don't log to reduce noise
      }

      return VideoModel(
        id: video.id.value,
        title: video.title,
        author: video.author,
        channelId: video.channelId.value,
        duration: video.duration,
        viewCount: video.engagement.viewCount,
        uploadDate: video.uploadDate,
        thumbnailUrl: _getHighestQualityThumbnail(video),
        uploaderAvatarUrl: channelAvatarUrl,
        description: video.description,
      );
    } catch (e) {
      // Fallback to basic model without enhancement
      return VideoModel.fromVideo(video);
    }
  }

  // ============================================================================
  // STREAM QUALITY MANAGEMENT
  // ============================================================================

  /// Get video and audio streams with quality preference
  Future<StreamQualityInfo?> getVideoAndAudioStreams(
    String videoId,
    String qualityPreference,
  ) async {
    try {
      final cleanQuality = _cleanQualityString(qualityPreference);
      print('🎥 Fetching streams for $videoId with quality: $cleanQuality');

      // Try YT-DLP first for better quality options
      try {
        final ytdlpResult = await _getStreamsFromYtdlp(videoId, cleanQuality)
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                print('⏰ YT-DLP timeout, switching to fallback');
                throw TimeoutException('YT-DLP timeout');
              },
            );

        if (ytdlpResult != null) {
          print('✅ Successfully using YT-DLP streams: ${ytdlpResult.quality}');
          return ytdlpResult;
        }
      } catch (e) {
        print('⚠️ YT-DLP failed: ${_handleYouTubeError(e)}');
      }

      // Fallback to YouTube Explode
      print('🔄 Falling back to YouTube Explode');
      return await _getStreamsFromExplode(videoId, cleanQuality).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('YouTube Explode timeout');
        },
      );
    } catch (e) {
      print('❌ Final error getting video streams: ${_handleYouTubeError(e)}');
      rethrow;
    }
  }

  Future<StreamQualityInfo?> getVideoStreamsWithAutoQualityReduction(
    String videoId,
    String initialQuality,
  ) async {
    try {
      // Try initial quality first
      final result = await getVideoAndAudioStreams(videoId, initialQuality);
      if (result != null) return result;

      // If failed, try lower qualities automatically
      final fallbackQualities = ['480p', '360p', '240p', '144p'];

      for (final quality in fallbackQualities) {
        if (quality == initialQuality) continue;

        developer.log('🔄 Trying fallback quality: $quality');
        try {
          final fallbackResult = await getVideoAndAudioStreams(
            videoId,
            quality,
          );
          if (fallbackResult != null) {
            developer.log('✅ Fallback quality $quality successful');
            return fallbackResult;
          }
        } catch (e) {
          developer.log('❌ Fallback quality $quality failed: $e');
          continue;
        }
      }

      return null;
    } catch (e) {
      developer.log('❌ Auto quality reduction failed: $e');
      return null;
    }
  }

  Future<StreamQualityInfo?> _getStreamsFromYtdlp(
    String videoId,
    String qualityPreference,
  ) async {
    try {
      print('🎬 YT-DLP: Getting streams for $videoId');

      final streams = await _ytdlpService.getUnifiedStreams(
        videoId: videoId,
        videoQuality: qualityPreference == 'Auto' ? 'best' : qualityPreference,
        timeout: const Duration(seconds: 20),
      );

      final videoStreams =
          streams['video'] as List<Map<String, dynamic>>? ?? [];
      final audioStreams =
          streams['audio'] as List<Map<String, dynamic>>? ?? [];

      if (videoStreams.isEmpty) {
        print('⚠️ YT-DLP: No video streams found');
        return null;
      }

      // Select best video stream matching quality preference
      final videoStream = _selectBestYtdlpStream(
        videoStreams,
        qualityPreference,
      );
      if (videoStream == null) {
        print('⚠️ YT-DLP: No matching video stream found');
        return null;
      }

      // Select best audio stream (highest bitrate)
      final audioStream = audioStreams.isNotEmpty
          ? audioStreams.reduce(
              (a, b) =>
                  _safeBitrateToInt(a['bitrate']) >
                      _safeBitrateToInt(b['bitrate'])
                  ? a
                  : b,
            )
          : null;

      return StreamQualityInfo(
        videoUrl: videoStream['url'] ?? '',
        audioUrl: audioStream?['url'] ?? videoStream['url'] ?? '',
        quality:
            _normalizeQualityFromYtdlp(videoStream['quality']) ??
            qualityPreference,
        hasVideo: true,
        hasAudio: audioStream != null || videoStream['acodec'] != null,
        availableQualities: _getAvailableQualitiesFromYtdlp(videoStreams),
        videoCodec: videoStream['vcodec'] ?? 'unknown',
        audioCodec:
            audioStream?['acodec'] ?? videoStream['acodec'] ?? 'unknown',
        bitrate: _safeBitrateToInt(audioStream?['bitrate']) ?? 128,
      );
    } catch (e) {
      print('❌ YT-DLP stream extraction failed: $e');
      rethrow;
    }
  }

  Map<String, dynamic>? _selectBestYtdlpStream(
    List<Map<String, dynamic>> streams,
    String qualityPreference,
  ) {
    if (streams.isEmpty) return null;

    // For Auto quality, return the first stream (should be best quality)
    if (qualityPreference == 'Auto') {
      return streams.firstWhere(
        (s) => s['url'] != null && s['url'].toString().isNotEmpty,
        orElse: () => streams.first,
      );
    }

    // For specific quality, find closest match
    final targetQuality = _parseQualityNumber(qualityPreference);
    if (targetQuality == null) return streams.last;

    Map<String, dynamic>? bestMatch;
    int? smallestDiff;

    for (final stream in streams) {
      final streamQuality = _parseQualityNumber(
        _normalizeQualityFromYtdlp(stream['quality']) ?? '',
      );
      if (streamQuality != null) {
        final diff = (targetQuality - streamQuality).abs();
        if (smallestDiff == null || diff < smallestDiff) {
          smallestDiff = diff;
          bestMatch = stream;
        }
      }
    }

    return bestMatch ?? streams.last;
  }

  // Enhanced retry operation with exponential backoff
  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 2,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 1.5,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('❌ Attempt $attempt/$maxRetries failed: $e');

        if (attempt == maxRetries) {
          throw lastException;
        }

        // Exponential backoff delay
        final delay = Duration(
          milliseconds:
              (initialDelay.inMilliseconds * (backoffMultiplier * attempt))
                  .round(),
        );

        print('⏳ Waiting ${delay.inMilliseconds}ms before retry...');
        await Future.delayed(delay);
      }
    }

    throw lastException ?? Exception('All retry attempts failed');
  }

  // Fallback method using YouTube Explode (existing logic)
  Future<StreamQualityInfo?> _getStreamsFromExplode(
    String videoId,
    String qualityPreference,
  ) async {
    try {
      print('🔄 YouTube Explode: Getting fallback streams');
      final manifest = await _youtube.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 12));

      // Try muxed streams first (video+audio together)
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      if (muxedStreams.isNotEmpty) {
        final stream = _selectBestExplodeStream(
          muxedStreams,
          qualityPreference,
        );
        if (stream != null) {
          return StreamQualityInfo(
            videoUrl: stream.url.toString(),
            audioUrl: stream.url.toString(),
            quality:
                _normalizeQuality(stream.videoQuality.toString()) ??
                qualityPreference,
            hasVideo: true,
            hasAudio: true,
            availableQualities: _getAvailableMuxedQualities(muxedStreams),
            videoCodec: stream.videoCodec,
            audioCodec: stream.audioCodec,
            bitrate: stream.bitrate?.bitsPerSecond ?? 128000,
          );
        }
      }

      // Fallback to separate video+audio streams
      final videoStreams = manifest.videoOnly.sortByVideoQuality();
      final audioStreams = manifest.audioOnly.sortByBitrate();

      if (videoStreams.isNotEmpty && audioStreams.isNotEmpty) {
        final videoStream = _selectBestExplodeStream(
          videoStreams,
          qualityPreference,
        );
        final audioStream = audioStreams.last; // Highest quality audio

        if (videoStream != null) {
          return StreamQualityInfo(
            videoUrl: videoStream.url.toString(),
            audioUrl: audioStream.url.toString(),
            quality:
                _normalizeQuality(videoStream.videoQuality.toString()) ??
                qualityPreference,
            hasVideo: true,
            hasAudio: true,
            availableQualities: _getAvailableQualities(videoStreams),
            videoCodec: videoStream.videoCodec,
            audioCodec: audioStream.audioCodec,
            bitrate: audioStream.bitrate.bitsPerSecond,
          );
        }
      }

      print('⚠️ YouTube Explode: No suitable streams found');
      return null;
    } catch (e) {
      print('❌ YouTube Explode fallback failed: $e');
      rethrow;
    }
  }

  dynamic _selectBestExplodeStream(List streams, String qualityPreference) {
    if (streams.isEmpty) return null;

    // Auto quality returns highest available
    if (qualityPreference == 'Auto') {
      return streams.last;
    }

    final targetQuality = _parseQualityNumber(qualityPreference);
    if (targetQuality == null) return streams.last;

    dynamic bestMatch;
    int? smallestDiff;

    for (final stream in streams) {
      final streamQuality = _parseQualityNumber(stream.videoQuality.toString());
      if (streamQuality != null) {
        final diff = (targetQuality - streamQuality).abs();
        if (smallestDiff == null || diff < smallestDiff) {
          smallestDiff = diff;
          bestMatch = stream;
        }
      }
    }

    return bestMatch ?? streams.last;
  }

  /// Select best muxed stream based on quality preference
  MuxedStreamInfo? _selectBestMuxedStream(
    List<MuxedStreamInfo> streams,
    String qualityPreference,
  ) {
    if (streams.isEmpty) return null;

    // Auto quality returns highest available
    if (qualityPreference == 'Auto') return streams.last;

    final targetQuality = _parseQualityNumber(qualityPreference);
    if (targetQuality == null) return streams.last;

    MuxedStreamInfo? bestMatch;
    int? smallestDiff;

    for (final stream in streams) {
      final streamQuality = _parseQualityNumber(stream.videoQuality.toString());
      if (streamQuality != null) {
        final diff = (targetQuality - streamQuality).abs();
        if (smallestDiff == null || diff < smallestDiff) {
          smallestDiff = diff;
          bestMatch = stream;
        }
      }
    }

    return bestMatch ?? streams.last;
  }

  /// Get list of available qualities from muxed streams
  List<String> _getAvailableMuxedQualities(List<MuxedStreamInfo> streams) {
    final qualities = <String>['Auto'];

    for (final stream in streams) {
      final quality = _normalizeQuality(stream.videoQuality.toString());
      if (quality != null && !qualities.contains(quality)) {
        qualities.add(quality);
      }
    }

    // Sort qualities (Auto first, then by number descending)
    qualities.sort((a, b) {
      if (a == 'Auto') return -1;
      if (b == 'Auto') return 1;

      final aNum = _parseQualityNumber(a) ?? 0;
      final bNum = _parseQualityNumber(b) ?? 0;
      return bNum.compareTo(aNum);
    });

    return qualities;
  }

  // Helper methods for YT-DLP stream selection
  Map<String, dynamic>? _selectBestYtdlpVideoStream(
    List<Map<String, dynamic>> streams,
    String qualityPreference,
  ) {
    if (streams.isEmpty) return null;

    // Filter valid streams
    final validStreams = streams.where((stream) {
      final url = stream['url'];
      return url != null && url.toString().isNotEmpty;
    }).toList();

    if (validStreams.isEmpty) return null;

    // Auto quality - prefer 720p for balance of quality and performance
    if (qualityPreference == 'Auto' || qualityPreference == 'best') {
      // Try to find 720p first, then fall back to highest available
      final preferredStream = validStreams.where((s) {
        final quality =
            _parseQualityNumberYtdlp(s['quality']?.toString() ?? '') ?? 0;
        return quality <= 720 && quality >= 480;
      }).lastOrNull;

      return preferredStream ?? validStreams.last;
    }

    final targetQuality = _parseQualityNumberYtdlp(qualityPreference);
    if (targetQuality == null) return validStreams.last;

    // Find closest quality match
    Map<String, dynamic>? bestMatch;
    int? smallestDiff;

    for (final stream in validStreams) {
      final streamQuality = _parseQualityNumberYtdlp(
        stream['quality']?.toString() ?? '',
      );
      if (streamQuality != null) {
        final diff = (targetQuality - streamQuality).abs();
        if (smallestDiff == null || diff < smallestDiff) {
          smallestDiff = diff;
          bestMatch = stream;
        }
      }
    }

    return bestMatch ?? validStreams.last;
  }

  Map<String, dynamic>? _selectBestYtdlpAudioStream(
    List<Map<String, dynamic>> streams,
  ) {
    if (streams.isEmpty) return null;

    // Filter valid streams
    final validStreams = streams.where((stream) {
      final url = stream['url'];
      return url != null && url.toString().isNotEmpty;
    }).toList();

    if (validStreams.isEmpty) return null;

    // Sort by bitrate (highest first) and pick the best one
    try {
      validStreams.sort((a, b) {
        final aBitrate = _safeBitrateToInt(a['bitrate']);
        final bBitrate = _safeBitrateToInt(b['bitrate']);
        return bBitrate.compareTo(aBitrate);
      });
    } catch (e) {
      print('⚠️ Error sorting audio streams by bitrate: $e');
    }

    return validStreams.first;
  }

  /// Parse quality string to number (e.g., "720p" -> 720) - DUPLICATE from existing method
  int? _parseQualityNumberYtdlp(String quality) {
    final cleanQuality = quality.toLowerCase().replaceAll('p', '');

    switch (cleanQuality) {
      case '2k':
      case '1440':
        return 1440;
      case '4k':
      case '2160':
        return 2160;
      default:
        return int.tryParse(cleanQuality);
    }
  }

  /// Normalize quality string to standard format (e.g., "720p")

  // ============================================================================
  // SEARCH FUNCTIONALITY
  // ============================================================================

  /// Search for videos with enhanced models
  Stream<List<VideoModel>> searchVideos(String query, {int count = 20}) async* {
    try {
      print('🔍 Streaming search for: $query');
      final searchQuery = _addSearchVariation(query);

      final searchResults = await _retryOperation(
        () => _youtube.search.search(searchQuery).timeout(_defaultTimeout),
        maxRetries: 2,
      );

      final videos = searchResults
          .whereType<Video>()
          .where(_isValidVideo)
          .take(count * 2)
          .toList();

      videos.shuffle(_random);
      final selectedVideos = videos.take(count).toList();

      final List<VideoModel> enrichedVideos = [];
      yield []; // Initial empty state

      for (final video in selectedVideos) {
        try {
          final model = await _createEnhancedVideoModel(video);
          enrichedVideos.add(model);
          yield List.from(enrichedVideos); // Emit current state
          await Future.delayed(
            const Duration(milliseconds: 100),
          ); // Smooth streaming
        } catch (e) {
          print('⚠️ Error processing video ${video.id}: $e');
        }
      }

      print('✅ Streamed ${enrichedVideos.length} search results');
    } catch (e) {
      print('❌ Search stream failed for "$query": ${_handleYouTubeError(e)}');
      yield [];
    }
  }

  /// Add slight variation to search query for more diverse results
  String _addSearchVariation(String query) {
    final variations = [
      query,
      '$query 2024',
      '$query 2025',
      '$query latest',
      '$query new',
    ];

    return variations[_random.nextInt(variations.length)];
  }

  // ============================================================================
  // TRENDING VIDEOS
  // ============================================================================

  /// Get trending videos using popular search terms
  Stream<List<VideoModel>> getTrendingVideos({int count = 50}) async* {
    const cacheKey = 'trending';

    // Return cached results immediately if available
    if (!_isCacheExpired(cacheKey) && _cachedVideos.containsKey(cacheKey)) {
      print('📱 Returning cached trending videos');
      yield _cachedVideos[cacheKey]!;
      return;
    }

    try {
      print('🔥 Streaming trending videos');
      final trendingQueries = [
        'trending videos',
        'popular videos 2025',
        'viral videos',
        'top videos today',
        'trending now',
        'most viewed',
      ];

      final query = trendingQueries[_random.nextInt(trendingQueries.length)];
      final searchResults = await _retryOperation(
        () => _youtube.search.search(query).timeout(_defaultTimeout),
        maxRetries: 2,
      );

      final videos = searchResults
          .whereType<Video>()
          .where(_isValidVideo)
          .take(count * 2)
          .toList();

      videos.shuffle(_random);
      final selectedVideos = videos.take(count).toList();

      final List<VideoModel> enrichedVideos = [];
      yield []; // Initial empty state

      for (final video in selectedVideos) {
        try {
          final model = await _createEnhancedVideoModel(video);
          enrichedVideos.add(model);
          yield List.from(enrichedVideos);
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('⚠️ Error processing trending video ${video.id}: $e');
        }
      }

      _cacheResults(cacheKey, enrichedVideos);
      print('✅ Streamed ${enrichedVideos.length} trending videos');
    } catch (e) {
      print('❌ Error streaming trending videos: ${_handleYouTubeError(e)}');
      yield [];
    }
  }

  // ============================================================================
  // RANDOM VIDEOS
  // ============================================================================

  /// Get random videos from various categories
  Future<List<VideoModel>> getRandomVideos({
    int count = 60,
    bool forceReload = false,
  }) async {
    const cacheKey = 'random';

    // Check cache unless force reload
    if (!forceReload &&
        !_isCacheExpired(cacheKey) &&
        _cachedVideos.containsKey(cacheKey)) {
      print('🎲 Returning cached random videos');
      return _cachedVideos[cacheKey]!;
    }

    try {
      print('🎲 Fetching random videos');

      final randomQueries = [
        'music videos 2025',
        'funny videos',
        'educational content',
        'gaming videos',
        'cooking tutorials',
        'travel vlogs',
        'tech reviews',
        'sports highlights',
        'movie trailers',
        'documentary shorts',
        'how to videos',
        'tutorials',
      ];

      final allVideos = <VideoModel>[];
      final usedVideoIds = <String>{};

      // Shuffle queries for randomness
      randomQueries.shuffle(_random);

      for (final query in randomQueries) {
        if (allVideos.length >= count) break;

        try {
          final searchResults = await _retryOperation(
            () => _youtube.search.search(query).timeout(_defaultTimeout),
            maxRetries: 2,
          );

          final videos = searchResults
              .whereType<Video>()
              .where(
                (v) => _isValidVideo(v) && !usedVideoIds.contains(v.id.value),
              )
              .take(8)
              .toList();

          // Shuffle category results
          videos.shuffle(_random);

          for (final video in videos) {
            if (allVideos.length >= count) break;

            usedVideoIds.add(video.id.value);
            final model = await _createEnhancedVideoModel(video);
            allVideos.add(model);
          }
        } catch (e) {
          print('⚠️ Error in category "$query": ${_handleYouTubeError(e)}');
          continue;
        }
      }

      // Final shuffle of all results
      allVideos.shuffle(_random);

      // Cache results
      _cacheResults(cacheKey, allVideos);

      print('✅ Retrieved ${allVideos.length} random videos');
      return allVideos;
    } catch (e) {
      print('❌ Error fetching random videos: ${_handleYouTubeError(e)}');
      return [];
    }
  }

  /// Stream version of random videos for progressive loading
  Stream<List<VideoModel>> getRandomVideosStream({int count = 60}) async* {
    final allVideos = <VideoModel>[];
    final usedVideoIds = <String>{};

    final categories = [
      'music',
      'gaming',
      'education',
      'technology',
      'sports',
      'cooking',
      'travel',
      'movies',
      'comedy',
      'science',
      'tutorials',
      'reviews',
    ];

    categories.shuffle(_random);
    yield []; // Initial empty state

    for (final category in categories) {
      if (allVideos.length >= count) break;

      try {
        final searchResults = await _retryOperation(
          () => _youtube.search
              .search('$category videos')
              .timeout(_defaultTimeout),
          maxRetries: 2,
        );

        final videos = searchResults
            .whereType<Video>()
            .where(
              (v) => _isValidVideo(v) && !usedVideoIds.contains(v.id.value),
            )
            .take(6)
            .toList();

        for (final video in videos) {
          if (allVideos.length >= count) break;

          try {
            usedVideoIds.add(video.id.value);
            final model = await _createEnhancedVideoModel(video);
            allVideos.add(model);

            // Yield updated list after each video
            yield List<VideoModel>.from(allVideos);

            // Small delay for smooth streaming
            await Future.delayed(const Duration(milliseconds: 150));
          } catch (e) {
            print('⚠️ Error processing video ${video.id}: $e');
          }
        }
      } catch (e) {
        print('⚠️ Error in category "$category": ${_handleYouTubeError(e)}');
      }
    }
  }

  // ============================================================================
  // RELATED VIDEOS
  // ============================================================================

  /// Get videos related to a specific video
  Stream<List<VideoModel>> getRelatedVideos(
    String videoId, {
    int count = 15,
  }) async* {
    try {
      print('🔗 Streaming related videos for: $videoId');

      // Get original video details with retry
      final originalVideo = await _retryOperation(
        () => _youtube.videos.get(videoId).timeout(_defaultTimeout),
        maxRetries: 2,
      );

      final searchTerms = <String>[];

      // Extract search terms from title
      final titleWords = originalVideo.title
          .split(' ')
          .where(
            (word) =>
                word.length > 3 &&
                ![
                  'the',
                  'and',
                  'for',
                  'with',
                  'from',
                ].contains(word.toLowerCase()),
          )
          .take(3);
      searchTerms.addAll(titleWords);

      // Add author for more related content
      searchTerms.add(originalVideo.author);

      // Add keywords if available
      if (originalVideo.keywords.isNotEmpty) {
        searchTerms.addAll(originalVideo.keywords.take(2));
      }

      final searchQuery = searchTerms.join(' ');
      final searchResults = await _retryOperation(
        () => _youtube.search.search(searchQuery).timeout(_defaultTimeout),
        maxRetries: 2,
      );

      final videos = searchResults
          .whereType<Video>()
          .where((v) => _isValidVideo(v) && v.id.value != videoId)
          .take(count * 2)
          .toList();

      videos.shuffle(_random);
      final selectedVideos = videos.take(count).toList();

      final List<VideoModel> enrichedVideos = [];
      yield []; // Initial empty state

      for (final video in selectedVideos) {
        try {
          final model = await _createEnhancedVideoModel(video);
          enrichedVideos.add(model);
          yield List.from(enrichedVideos);
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('⚠️ Error processing related video ${video.id}: $e');
        }
      }

      print('✅ Streamed ${enrichedVideos.length} related videos');
    } catch (e) {
      print('❌ Error streaming related videos: ${_handleYouTubeError(e)}');
      yield [];
    }
  }

  // ============================================================================
  // CHANNEL OPERATIONS
  // ============================================================================

  /// Get more videos from a specific channel
  Stream<List<VideoModel>> getMoreFromChannel(
    String channelId, {
    int count = 15,
  }) async* {
    try {
      print('📺 Streaming videos from channel: $channelId');
      final uploads = _youtube.channels.getUploads(channelId);
      final List<VideoModel> videos = [];
      yield []; // Initial empty state

      await for (final video in uploads.take(count * 2)) {
        if (videos.length >= count) break;

        if (_isValidVideo(video)) {
          try {
            final model = await _createEnhancedVideoModel(video);
            videos.add(model);
            yield List.from(videos);
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            print('⚠️ Error processing channel video ${video.id}: $e');
          }
        }
      }

      print('✅ Streamed ${videos.length} channel videos');
    } catch (e) {
      print('❌ Error streaming channel videos: ${_handleYouTubeError(e)}');
      yield [];
    }
  }

  /// Get channel details
  Future<Channel?> getChannelDetails(String channelId) async {
    try {
      return await _retryOperation(
        () => _youtube.channels
            .get(ChannelId(channelId))
            .timeout(_defaultTimeout),
        maxRetries: 2,
      );
    } catch (e) {
      print('❌ Error getting channel details: ${_handleYouTubeError(e)}');
      return null;
    }
  }

  // ============================================================================
  // GEO-TARGETED VIDEOS
  // ============================================================================

  /// Get videos targeted for a specific country/region
  Stream<List<VideoModel>> getGeoTargetedVideos(
    String countryName, {
    int count = 30,
  }) async* {
    final cacheKey = 'geo_$countryName';

    if (!_isCacheExpired(cacheKey) && _cachedVideos.containsKey(cacheKey)) {
      print('🌍 Returning cached geo-targeted videos for $countryName');
      yield _cachedVideos[cacheKey]!;
      return;
    }

    try {
      print('🌍 Streaming geo-targeted videos for: $countryName');
      final geoQueries = [
        '$countryName culture',
        '$countryName music',
        '$countryName news today',
        '$countryName food',
        '$countryName travel',
        '$countryName lifestyle',
        'popular in $countryName',
        '$countryName entertainment',
        '$countryName trending',
        '$countryName viral',
      ];

      final allVideos = <VideoModel>[];
      final usedVideoIds = <String>{};
      geoQueries.shuffle(_random);
      yield []; // Initial empty state

      for (final query in geoQueries) {
        if (allVideos.length >= count) break;

        try {
          final searchResults = await _retryOperation(
            () => _youtube.search.search(query).timeout(_defaultTimeout),
            maxRetries: 2,
          );

          final videos = searchResults
              .whereType<Video>()
              .where(
                (v) => _isValidVideo(v) && !usedVideoIds.contains(v.id.value),
              )
              .take(5)
              .toList();

          videos.shuffle(_random);

          for (final video in videos) {
            if (allVideos.length >= count) break;

            try {
              usedVideoIds.add(video.id.value);
              final model = await _createEnhancedVideoModel(video);
              allVideos.add(model);
              yield List.from(allVideos);
              await Future.delayed(const Duration(milliseconds: 100));
            } catch (e) {
              print('⚠️ Error processing geo video ${video.id}: $e');
            }
          }
        } catch (e) {
          print('⚠️ Error in geo query "$query": ${_handleYouTubeError(e)}');
        }
      }

      _cacheResults(cacheKey, allVideos);
      print('✅ Streamed ${allVideos.length} geo-targeted videos');
    } catch (e) {
      print('❌ Error streaming geo-targeted videos: ${_handleYouTubeError(e)}');
      yield [];
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if video meets quality criteria
  bool _isValidVideo(Video video) {
    try {
      return video.duration != null &&
          video.duration!.inSeconds >= 30 && // At least 30 seconds
          video.duration!.inSeconds <= 7200 && // At most 2 hours
          !video.url.contains('/shorts/') && // No YouTube Shorts
          video.title.isNotEmpty &&
          video.author.isNotEmpty &&
          !video.title.toLowerCase().contains('deleted') &&
          !video.title.toLowerCase().contains('private') &&
          video.engagement.viewCount > 100; // Minimum view threshold
    } catch (e) {
      return false;
    }
  }

  /// Get video details
  Future<Video?> getVideoDetails(String videoId) async {
    try {
      return await _retryOperation(
        () => _youtube.videos.get(videoId).timeout(_defaultTimeout),
        maxRetries: 2,
      );
    } catch (e) {
      print('❌ Error getting video details: ${_handleYouTubeError(e)}');
      return null;
    }
  }

  /// Get video stream manifest
  Future<StreamManifest?> getVideoStreams(String videoId) async {
    try {
      return await _retryOperation(
        () => _youtube.videos.streamsClient
            .getManifest(videoId)
            .timeout(_streamTimeout),
        maxRetries: 2,
      );
    } catch (e) {
      print('❌ Error getting video streams: ${_handleYouTubeError(e)}');
      return null;
    }
  }

  /// Check if video is available for playback
  Future<bool> isVideoAvailable(String videoId) async {
    try {
      final video = await getVideoDetails(videoId);
      return video != null && _isValidVideo(video);
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _youtube.close();
    print('🗑️ VideoService disposed');
  }
}

// ============================================================================
// RIVERPOD PROVIDERS
// ============================================================================

/// Main video service provider
final videoServiceProvider = Provider<VideoService>((ref) {
  final service = VideoService();
  ref.onDispose(() => service.dispose());
  return service;
});

// This provider takes both video ID and quality as parameters
final videoAndAudioStreamsProvider =
    FutureProvider.family<StreamQualityInfo?, (String, String)>((
      ref,
      params,
    ) async {
      final (videoId, quality) = params;
      final service = ref.read(videoServiceProvider);
      return service.getVideoAndAudioStreams(videoId, quality);
    });

/// Random videos provider
final randomVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final service = ref.read(videoServiceProvider);
  final forceReload = ref.watch(forceRefreshProvider);
  return service.getRandomVideos(forceReload: forceReload);
});

/// Trending videos stream provider
final trendingVideosProvider = StreamProvider<List<VideoModel>>((ref) {
  final service = ref.read(videoServiceProvider);
  return service.getTrendingVideos();
});

/// Search videos stream provider
final videoSearchProvider = StreamProvider.family<List<VideoModel>, String>((
  ref,
  query,
) {
  final service = ref.read(videoServiceProvider);
  return service.searchVideos(query);
});

/// Related videos stream provider with error handling
final relatedVideosProvider = StreamProvider.family<List<VideoModel>, String>((
  ref,
  videoId,
) {
  final service = ref.read(videoServiceProvider);
  return service.getRelatedVideos(videoId).handleError((error) {
    print('❌ Related videos provider error: $error');
    return Stream.value(<VideoModel>[]);
  });
});

/// Channel videos stream provider
final channelVideosProvider = StreamProvider.family<List<VideoModel>, String>((
  ref,
  channelId,
) {
  final service = ref.read(videoServiceProvider);
  return service.getMoreFromChannel(channelId);
});

/// Channel details provider
final channelDetailsProvider = FutureProvider.family<Channel?, String>((
  ref,
  channelId,
) async {
  final service = ref.read(videoServiceProvider);
  return service.getChannelDetails(channelId);
});

/// Video details provider
final videoDetailsProvider = FutureProvider.family<Video?, String>((
  ref,
  videoId,
) async {
  final service = ref.read(videoServiceProvider);
  return service.getVideoDetails(videoId);
});

/// Video streams provider
final videoStreamsProvider = FutureProvider.family<StreamManifest?, String>((
  ref,
  videoId,
) async {
  final service = ref.read(videoServiceProvider);
  return service.getVideoStreams(videoId);
});

/// Random videos stream provider (for progressive loading)
final randomVideosStreamProvider = StreamProvider<List<VideoModel>>((ref) {
  final service = ref.read(videoServiceProvider);
  return service.getRandomVideosStream();
});

/// Geo-targeted videos stream provider
final geoTargetedVideosStreamProvider =
    StreamProvider.family<List<VideoModel>, String>((ref, countryName) {
      final service = ref.read(videoServiceProvider);
      return service.getGeoTargetedVideos(countryName);
    });

/// Quality options provider
final videoQualityOptionsProvider = Provider<List<String>>(
  (ref) => videoQualityOptions,
);

/// Video availability checker
final videoAvailabilityProvider = FutureProvider.family<bool, String>((
  ref,
  videoId,
) async {
  final service = ref.read(videoServiceProvider);
  return service.isVideoAvailable(videoId);
});

final videoAndAudioStreamsWithAutoQualityProvider =
    FutureProvider.family<StreamQualityInfo?, (String, String)>((
      ref,
      params,
    ) async {
      final (videoId, quality) = params;
      final service = ref.read(videoServiceProvider);

      // Use the new auto-quality method instead of the original
      return service.getVideoStreamsWithAutoQualityReduction(videoId, quality);
    });
