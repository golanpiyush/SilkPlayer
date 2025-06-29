import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silkplayer/models/stream_quality-info.dart';
import 'package:silkplayer/utils/ai_term_generator.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_model.dart';

final qualityProvider = StateProvider<String>((ref) => '720p');

// Enhanced quality options
const List<String> videoQualityOptions = [
  '144p',
  '240p',
  '360p',
  '480p',
  '720p',
  '1080p',
  '2K',
  '4K',
  'Auto',
];

class VideoService {
  final YoutubeExplode _youtube = YoutubeExplode();

  final Map<String, List<VideoModel>> _cachedRandomVideos = {};
  final Map<String, DateTime> _randomVideosCacheTimestamps = {};
  final Set<String> _seenRandomVideoIds = {};

  // 🎯 NEW: Get separate video and audio streams for BetterPlayerPlus
  Future<StreamQualityInfo?> getVideoAndAudioStreams(
    String videoId,
    String qualityPreference,
  ) async {
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);

      // Get video-only streams
      final videoOnlyStreams = manifest.videoOnly.sortByVideoQuality();
      final videoStream = _selectVideoQualityStream(
        videoOnlyStreams,
        qualityPreference,
      );

      // Get audio-only streams (highest quality)
      final audioOnlyStreams = manifest.audioOnly.sortByBitrate();
      final audioStream = audioOnlyStreams.isNotEmpty
          ? audioOnlyStreams.last
          : null;

      if (videoStream != null && audioStream != null) {
        print('✅ Successful HQ audio stream: ${audioStream.bitrate}');
        print(
          '✅ Successful HQ video stream: ${videoStream.videoQuality} (${videoStream.videoResolution})',
        );

        return StreamQualityInfo(
          videoUrl: videoStream.url.toString(),
          audioUrl: audioStream.url.toString(),
          quality: qualityPreference,
          hasVideo: true,
          hasAudio: true,
        );
      }

      // Fallback to muxed streams if separate streams not available
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      final muxedStream = _selectMuxedQualityStream(
        muxedStreams,
        qualityPreference,
      );

      if (muxedStream != null) {
        print('✅ Successful muxed stream: ${muxedStream.videoQuality}');

        return StreamQualityInfo(
          videoUrl: muxedStream.url.toString(),
          audioUrl: muxedStream.url.toString(), // Same URL for muxed
          quality: qualityPreference,
          hasVideo: true,
          hasAudio: true,
        );
      }

      return null;
    } catch (e) {
      print('❌ Error getting video and audio streams: $e');
      return null;
    }
  }

  // 🎯 NEW: Get only video stream URL
  Future<String?> getVideoStreamUrl(
    String videoId,
    String qualityPreference,
  ) async {
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      final videoOnlyStreams = manifest.videoOnly.sortByVideoQuality();
      final videoStream = _selectVideoQualityStream(
        videoOnlyStreams,
        qualityPreference,
      );

      if (videoStream != null) {
        print('✅ Successful HQ video stream: ${videoStream.videoQuality}');
        return videoStream.url.toString();
      }

      // Fallback to muxed
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      final muxedStream = _selectMuxedQualityStream(
        muxedStreams,
        qualityPreference,
      );
      return muxedStream?.url.toString();
    } catch (e) {
      print('❌ Error getting video stream: $e');
      return null;
    }
  }

  // 🎯 NEW: Get only audio stream URL
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      final audioOnlyStreams = manifest.audioOnly.sortByBitrate();

      if (audioOnlyStreams.isNotEmpty) {
        final audioStream = audioOnlyStreams.last; // Highest bitrate
        print('✅ Successful HQ audio stream: ${audioStream.bitrate}');
        return audioStream.url.toString();
      }

      return null;
    } catch (e) {
      print('❌ Error getting audio stream: $e');
      return null;
    }
  }

  // 🎯 NEW: Enhanced quality selection for video-only streams
  VideoOnlyStreamInfo? _selectVideoQualityStream(
    List<VideoOnlyStreamInfo> streams,
    String qualityPreference,
  ) {
    if (streams.isEmpty) return null;

    // Handle Auto quality
    if (qualityPreference == 'Auto') {
      return streams.last; // Highest quality
    }

    // Parse target quality
    final targetQuality = _parseQualityNumber(qualityPreference);
    if (targetQuality == null) return streams.last;

    // Find closest matching quality
    VideoOnlyStreamInfo? closestStream;
    int? closestDiff;

    for (final stream in streams) {
      final streamQuality = _parseQualityNumber(stream.videoQuality.toString());
      if (streamQuality != null) {
        final diff = (targetQuality - streamQuality).abs();
        if (closestDiff == null || diff < closestDiff!) {
          closestDiff = diff;
          closestStream = stream;
        }
      }
    }

    return closestStream ?? streams.last;
  }

  // 🎯 NEW: Enhanced quality selection for muxed streams
  MuxedStreamInfo? _selectMuxedQualityStream(
    List<MuxedStreamInfo> streams,
    String qualityPreference,
  ) {
    if (streams.isEmpty) return null;

    if (qualityPreference == 'Auto') {
      return streams.last;
    }

    final targetQuality = _parseQualityNumber(qualityPreference);
    if (targetQuality == null) return streams.last;

    MuxedStreamInfo? closestStream;
    int? closestDiff;

    for (final stream in streams) {
      final streamQuality = _parseQualityNumber(stream.videoQuality.toString());
      if (streamQuality != null) {
        final diff = (targetQuality - streamQuality).abs();
        if (closestDiff == null || diff < closestDiff!) {
          closestDiff = diff;
          closestStream = stream;
        }
      }
    }

    return closestStream ?? streams.last;
  }

  // 🎯 NEW: Parse quality number from string (supports 2K, 4K)
  int? _parseQualityNumber(String quality) {
    final cleanQuality = quality.toLowerCase().replaceAll('p', '');

    // Handle special cases
    switch (cleanQuality) {
      case '2k':
        return 1440;
      case '4k':
        return 2160;
      default:
        return int.tryParse(cleanQuality);
    }
  }

  // 🎯 ENHANCED: Updated methods with quality stream support
  Future<List<VideoModel>> getGeoTargetedVideos(
    String countryName, {
    int count = 20,
    String quality = '720p',
  }) async {
    try {
      final terms = await AIGeoKeywordGenerator.generateUniqueTerms(
        countryName,
      );
      final List<VideoModel> allVideos = [];
      final seenIds = <String>{};

      for (final term in terms) {
        final results = await _youtube.search.search(term);
        final list = await results.take(40).toList();

        for (final v in list.whereType<Video>()) {
          if (v.duration != null &&
              v.duration!.inSeconds >= 60 &&
              !v.url.contains('/shorts/') &&
              !seenIds.contains(v.id.value)) {
            // Add stream quality info to video model
            final videoModel = VideoModel.fromVideo(v);
            allVideos.add(videoModel);
            seenIds.add(v.id.value);
          }
          if (allVideos.length >= count) break;
        }

        if (allVideos.length >= count) break;
      }

      allVideos.shuffle();
      return allVideos.take(count).toList();
    } catch (e) {
      print('Error fetching geo-targeted videos: $e');
      return [];
    }
  }

  Future<List<VideoModel>> getRandomVideos({
    int count = 60,
    bool forceReload = false,
    String quality = '720p',
  }) async {
    final now = DateTime.now();
    final List<VideoModel> allVideos = [];

    const Map<String, String> nicheSearchMap = {
      'coding': 'coding tutorials 2025',
      'music': 'trending songs 2025',
      'gaming': 'gameplay 2025',
      'movies': 'new movie trailers 2025',
      'education': 'learning videos',
      'technology': 'tech reviews',
      'fitness': 'home workouts',
      'ai': 'artificial intelligence',
      'news': 'world news',
      'vlogs': 'daily vlogs',
    };

    print('😊👌 Retrieving random videos with $quality quality support');

    for (final entry in nicheSearchMap.entries) {
      final tag = entry.key;
      final query = entry.value;

      final lastFetched = _randomVideosCacheTimestamps[tag];
      final isExpired =
          lastFetched == null || now.difference(lastFetched).inMinutes >= 10;

      if (!forceReload &&
          _cachedRandomVideos.containsKey(tag) &&
          !isExpired &&
          _cachedRandomVideos[tag]!.isNotEmpty) {
        allVideos.addAll(
          _cachedRandomVideos[tag]!.where(
            (v) => !_seenRandomVideoIds.contains(v.id),
          ),
        );
        continue;
      }

      try {
        final searchResults = await _youtube.search.search(query);
        final videos = searchResults
            .whereType<Video>()
            .where(
              (v) =>
                  v.duration != null &&
                  v.duration!.inSeconds > 90 &&
                  !_seenRandomVideoIds.contains(v.id.value) &&
                  !v.url.contains('/shorts/'),
            )
            .take(10)
            .toList();

        final List<VideoModel> enrichedVideos = [];
        for (final video in videos) {
          final model = await VideoModel.fromVideoWithChannelInfo(
            _youtube,
            video,
          );
          enrichedVideos.add(model);
        }

        _cachedRandomVideos[tag] = enrichedVideos;
        _randomVideosCacheTimestamps[tag] = now;

        allVideos.addAll(enrichedVideos);
      } catch (e) {
        print('Error searching $query: $e');
      }
    }

    allVideos.shuffle();

    final uniqueNew = allVideos
        .where((v) => !_seenRandomVideoIds.contains(v.id))
        .take(count)
        .toList();

    for (final v in uniqueNew) {
      _seenRandomVideoIds.add(v.id);
    }

    print(
      '✅ Retrieved ${uniqueNew.length} random videos with $quality quality support',
    );
    return uniqueNew;
  }

  Stream<List<VideoModel>> streamRandomVideos({
    int count = 60,
    bool forceReload = false,
    String quality = '1080p',
  }) async* {
    final now = DateTime.now();
    final List<VideoModel> allVideos = [];

    const Map<String, String> nicheSearchMap = {
      'coding': 'coding tutorials 2025',
      'music': 'trending songs 2025',
      'gaming': 'gameplay 2025',
      'movies': 'new movie trailers 2025',
      'education': 'learning videos',
      'technology': 'tech reviews',
      'fitness': 'home workouts',
      'ai': 'artificial intelligence',
      'news': 'world news',
      'vlogs': 'daily vlogs',
    };

    for (final entry in nicheSearchMap.entries) {
      final tag = entry.key;
      final query = entry.value;

      final lastFetched = _randomVideosCacheTimestamps[tag];
      final isExpired =
          lastFetched == null || now.difference(lastFetched).inMinutes >= 10;

      if (!forceReload &&
          _cachedRandomVideos.containsKey(tag) &&
          !isExpired &&
          _cachedRandomVideos[tag]!.isNotEmpty) {
        final fresh = _cachedRandomVideos[tag]!
            .where((v) => !_seenRandomVideoIds.contains(v.id))
            .toList();
        allVideos.addAll(fresh);
        yield List<VideoModel>.from(allVideos);
        continue;
      }

      try {
        final searchResults = await _youtube.search.search(query);
        final videos = searchResults
            .whereType<Video>()
            .where(
              (v) =>
                  v.duration != null &&
                  v.duration!.inSeconds > 90 &&
                  !_seenRandomVideoIds.contains(v.id.value) &&
                  !v.url.contains('/shorts/'),
            )
            .take(10)
            .map((v) => VideoModel.fromVideo(v))
            .toList();

        _cachedRandomVideos[tag] = videos;
        _randomVideosCacheTimestamps[tag] = now;

        allVideos.addAll(videos);
        yield List<VideoModel>.from(allVideos);
      } catch (e) {
        print('Error searching $query: $e');
      }
    }

    print('✅ Streamed random videos with $quality quality support');
  }

  Future<List<VideoModel>> getTrendingVideos({
    int count = 50,
    String quality = '720p',
  }) async {
    try {
      final searchResults = await _youtube.search.search('trending music 2025');
      final filtered = searchResults.whereType<Video>().take(count);

      final List<VideoModel> enriched = [];
      for (final video in filtered) {
        final model = await VideoModel.fromVideoWithChannelInfo(
          _youtube,
          video,
        );
        enriched.add(model);
      }

      print(
        '✅ Retrieved ${enriched.length} trending videos with $quality quality support',
      );
      return enriched;
    } catch (e) {
      print('Error fetching enriched trending videos: $e');
      return [];
    }
  }

  Future<List<VideoModel>> getRelatedVideos(
    String videoId, {
    int count = 10,
    String quality = '720p',
  }) async {
    try {
      final video = await _youtube.videos.get(videoId);
      final tags = video.keywords.take(3).join(' ');
      final searchQuery = '${video.title} $tags';

      final searchResults = await _youtube.search.search(searchQuery);
      final resultList = searchResults.toList();

      final relatedVideos = resultList
          .whereType<Video>()
          .where(
            (v) =>
                v.id.value != videoId &&
                v.duration != null &&
                v.duration!.inSeconds >= 60 &&
                !v.url.contains('/shorts/'),
          )
          .take(count)
          .toList();

      final List<VideoModel> enriched = [];
      for (final video in relatedVideos) {
        final model = await VideoModel.fromVideoWithChannelInfo(
          _youtube,
          video,
        );
        enriched.add(model);
      }

      print(
        '✅ Retrieved ${enriched.length} related videos with $quality quality support',
      );
      return enriched;
    } catch (e) {
      print('Error getting related videos: $e');
      return [];
    }
  }

  Future<List<VideoModel>> getMoreFromChannel(
    String channelId, {
    int count = 10,
    String quality = '720p',
  }) async {
    try {
      final stream = _youtube.channels.getUploads(channelId);
      final List<VideoModel> videos = [];

      await for (final video in stream) {
        if (video.duration != null &&
            video.duration!.inSeconds > 60 &&
            !video.url.contains('/shorts/')) {
          videos.add(VideoModel.fromVideo(video));
        }
        if (videos.length >= count) break;
      }

      print(
        '✅ Retrieved ${videos.length} channel videos with $quality quality support',
      );
      return videos;
    } catch (e) {
      print('Error fetching channel uploads: $e');
      return [];
    }
  }

  Future<List<VideoModel>> searchVideos(
    String query, {
    int count = 10,
    String quality = '720p',
  }) async {
    try {
      final results = await _youtube.search
          .search(query)
          .timeout(Duration(seconds: 10));

      final resultList = results.toList();
      final videos = resultList
          .whereType<Video>()
          .where(
            (v) =>
                v.duration != null &&
                v.duration!.inSeconds >= 60 &&
                !v.url.contains('/shorts/'),
          )
          .take(count)
          .map((video) => VideoModel.fromVideo(video))
          .toList();

      print(
        '✅ Search found ${videos.length} videos with $quality quality support',
      );
      return videos;
    } on TimeoutException {
      print('Search timed out, retrying...');
      return await _retrySearch(query, count, quality);
    } catch (e) {
      print('Error searching videos: $e');
      return [];
    }
  }

  Future<List<VideoModel>> _retrySearch(
    String query,
    int count,
    String quality,
  ) async {
    try {
      await Future.delayed(Duration(milliseconds: 500));
      final results = await _youtube.search
          .search(query)
          .timeout(Duration(seconds: 15));

      final resultList = results.toList();
      final videos = resultList
          .whereType<Video>()
          .where(
            (v) =>
                v.duration != null &&
                v.duration!.inSeconds >= 60 &&
                !v.url.contains('/shorts/'),
          )
          .take(count)
          .map((video) => VideoModel.fromVideo(video))
          .toList();
      return videos;
    } catch (e) {
      print('Retry failed: $e');
      return [];
    }
  }

  Future<StreamManifest?> getVideoStreams(String videoId) async {
    try {
      return await _youtube.videos.streamsClient.getManifest(videoId);
    } catch (e) {
      print('Error getting video streams: $e');
      return null;
    }
  }

  Future<Channel?> getChannelDetails(String channelId) async {
    try {
      return await _youtube.channels.get(ChannelId(channelId));
    } catch (e) {
      print('Error getting channel details: $e');
      return null;
    }
  }

  Future<List<VideoModel>> getVideosByUserInterests(
    List<String> interests, {
    int countPerCategory = 3,
    String quality = '720p',
  }) async {
    final List<VideoModel> allResults = [];

    final Map<String, String> expandedTags = {
      'coding': 'coding tutorials',
      'music': 'trending songs',
      'gaming': 'gameplay 2025',
      'movies': 'new movie trailers',
      'education': 'learning videos',
      'technology': 'tech reviews',
      'fitness': 'home workouts',
      'ai': 'artificial intelligence',
      'news': 'world news',
      'vlogs': 'daily vlogs',
    };

    try {
      for (final interest in interests.take(5)) {
        final searchQuery = expandedTags[interest.toLowerCase()] ?? interest;

        final searchResults = await _youtube.search.search(searchQuery);
        final videos = searchResults
            .whereType<Video>()
            .where(
              (v) =>
                  v.duration != null &&
                  v.duration!.inSeconds >= 60 &&
                  !v.url.contains('/shorts/'),
            )
            .take(countPerCategory)
            .map((video) => VideoModel.fromVideo(video));

        allResults.addAll(videos);
      }

      allResults.shuffle();
      print(
        '✅ Retrieved ${allResults.length} interest-based videos with $quality quality support',
      );
      return allResults;
    } catch (e) {
      print('Error fetching videos by interests: $e');
      return [];
    }
  }

  Future<Video?> getVideoDetails(String videoId) async {
    try {
      return await _youtube.videos.get(videoId);
    } catch (e) {
      print('Error getting video details: $e');
      return null;
    }
  }

  // Keep existing static methods with enhanced quality support
  static MuxedStreamInfo? selectQualityStream(
    StreamManifest manifest,
    String qualityPreference,
  ) {
    try {
      final muxed = manifest.muxed.sortByVideoQuality();

      print('Available stream qualities:');
      for (final stream in muxed) {
        print(' - ${stream.videoQuality} (${stream.size})');
      }

      if (qualityPreference == 'Auto') {
        return muxed.last;
      }

      final targetQuality = _parseQualityNumberStatic(qualityPreference);
      if (targetQuality == null) return muxed.last;

      MuxedStreamInfo? closestStream;
      int? closestDiff;

      for (final stream in muxed) {
        final streamQuality = stream.videoQuality.toString();
        final qualityMatch = RegExp(r'(\d+)').firstMatch(streamQuality);
        if (qualityMatch != null) {
          final qualityNum = int.tryParse(qualityMatch.group(1)!);
          if (qualityNum != null) {
            final diff = (targetQuality - qualityNum).abs();
            if (closestDiff == null || diff < closestDiff!) {
              closestDiff = diff;
              closestStream = stream;
            }
          }
        }
      }

      return closestStream ?? muxed.last;
    } catch (e) {
      print('Error selecting quality: $e');
      return manifest.muxed.sortByVideoQuality().last;
    }
  }

  static int? _parseQualityNumberStatic(String quality) {
    final cleanQuality = quality.toLowerCase().replaceAll('p', '');
    switch (cleanQuality) {
      case '2k':
        return 1440;
      case '4k':
        return 2160;
      default:
        return int.tryParse(cleanQuality);
    }
  }

  static MuxedStreamInfo? getFallbackQuality(
    StreamManifest manifest,
    String quality,
  ) {
    try {
      final muxed = manifest.muxed.sortByVideoQuality();
      if (quality == 'Auto') return muxed.last;

      final targetQuality = quality.replaceAll('p', '');
      for (final stream in muxed.reversed) {
        if (stream.toString().contains(targetQuality)) {
          return stream;
        }
      }

      return muxed.last;
    } catch (e) {
      print('Error in fallback quality selection: $e');
      return manifest.muxed.sortByVideoQuality().last;
    }
  }

  void dispose() {
    _youtube.close();
  }
}

// Providers
// 🎯 NEW: Enhanced Providers with stream quality support
final videoServiceProvider = Provider<VideoService>((ref) {
  final service = VideoService();
  ref.onDispose(() => service.dispose());
  return service;
});

// 🎯 NEW: Video and Audio stream providers
final videoAndAudioStreamsProvider =
    FutureProvider.family<StreamQualityInfo?, (String, String)>((
      ref,
      params,
    ) async {
      final (videoId, quality) = params;
      final service = ref.read(videoServiceProvider);
      return service.getVideoAndAudioStreams(videoId, quality);
    });

final videoStreamUrlProvider = FutureProvider.family<String?, (String, String)>(
  (ref, params) async {
    final (videoId, quality) = params;
    final service = ref.read(videoServiceProvider);
    return service.getVideoStreamUrl(videoId, quality);
  },
);

final audioStreamUrlProvider = FutureProvider.family<String?, String>((
  ref,
  videoId,
) async {
  final service = ref.read(videoServiceProvider);
  return service.getAudioStreamUrl(videoId);
});

// Updated existing providers
final randomVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final service = ref.read(videoServiceProvider);
  final quality = ref.watch(qualityProvider);
  return service.getRandomVideos(quality: quality);
});

final trendingVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final service = ref.read(videoServiceProvider);
  final quality = ref.watch(qualityProvider);
  return service.getTrendingVideos(quality: quality);
});

final videoSearchProvider = FutureProvider.family<List<VideoModel>, String>((
  ref,
  query,
) async {
  final service = ref.read(videoServiceProvider);
  final quality = ref.watch(qualityProvider);
  return service.searchVideos(query, quality: quality);
});

final videoStreamsProvider = FutureProvider.family<StreamManifest?, String>((
  ref,
  videoId,
) async {
  final service = ref.read(videoServiceProvider);
  return service.getVideoStreams(videoId);
});

final videoDetailsProvider = FutureProvider.family<Video?, String>((
  ref,
  videoId,
) async {
  final service = ref.read(videoServiceProvider);
  return service.getVideoDetails(videoId);
});

final userInterestVideosProvider =
    FutureProvider.family<List<VideoModel>, List<String>>((
      ref,
      interests,
    ) async {
      final service = ref.read(videoServiceProvider);
      final quality = ref.watch(qualityProvider);
      return service.getRandomVideos(quality: quality);
    });

final qualityStreamProvider = FutureProvider.family<MuxedStreamInfo?, String>((
  ref,
  videoId,
) async {
  final manifest = await ref.watch(videoStreamsProvider(videoId).future);
  final quality = ref.watch(qualityProvider);

  if (manifest == null) return null;

  return VideoService.selectQualityStream(manifest, quality);
});

final channelDetailsProvider = FutureProvider.family<Channel?, String>((
  ref,
  id,
) async {
  final service = ref.read(videoServiceProvider);
  return service.getChannelDetails(id);
});

final channelVideosProvider = FutureProvider.family<List<VideoModel>, String>((
  ref,
  id,
) async {
  final service = ref.read(videoServiceProvider);
  final quality = ref.watch(qualityProvider);
  return service.getMoreFromChannel(id, quality: quality);
});

final relatedVideosProvider = FutureProvider.family<List<VideoModel>, String>((
  ref,
  videoId,
) async {
  final service = ref.read(videoServiceProvider);
  final quality = ref.watch(qualityProvider);
  return service.getRelatedVideos(videoId, quality: quality);
});

final geoTargetedVideosProvider =
    FutureProvider.family<List<VideoModel>, String>((ref, country) async {
      final service = ref.read(videoServiceProvider);
      final quality = ref.watch(qualityProvider);
      return service.getGeoTargetedVideos(country, quality: quality);
    });

final selectedCountryProvider = StateProvider<String>((ref) => 'India');
final forceRandomVideosReloadProvider = StateProvider<bool>((ref) => false);

final randomVideosStreamProvider = StreamProvider<List<VideoModel>>((
  ref,
) async* {
  final forceReload = ref.watch(forceRandomVideosReloadProvider);
  final quality = ref.watch(qualityProvider);

  debugPrint(
    '⏳ Loading random videos stream (forceReload: $forceReload, quality: $quality)',
  );

  final service = ref.read(videoServiceProvider);
  final videos = await service.getRandomVideos(
    forceReload: forceReload,
    quality: quality,
  );

  yield videos;
});

// 🎯 NEW: Quality options provider
final videoQualityOptionsProvider = Provider<List<String>>(
  (ref) => videoQualityOptions,
);
