import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_model.dart';

class VideoService {
  final YoutubeExplode _youtube = YoutubeExplode();

  // Random search terms for home screen
  final List<String> _randomSearchTerms = [
    'music',
    'gaming',
    'technology',
    'entertainment',
    'sports',
    'comedy',
    'education',
    'travel',
    'food',
    'lifestyle',
    'news',
    'science',
    'art',
    'fashion',
    'fitness',
  ];

  // Trending search terms for Hindi/English content
  final List<String> _trendingTerms = [
    'hindi songs 2025',
    'bollywood songs 2025',
    'english songs 2025',
    'trending music 2025',
    'viral videos 2025',
    'latest hindi music',
    'top english hits 2025',
    'bollywood hits 2025',
    'punjabi songs 2025',
    'pop music 2025',
  ];

  Future<List<VideoModel>> getRandomVideos({int count = 20}) async {
    try {
      final random = Random();
      final searchTerm =
          _randomSearchTerms[random.nextInt(_randomSearchTerms.length)];

      final searchResults = await _youtube.search.search(searchTerm);
      final videos = searchResults.take(count).whereType<Video>().cast<Video>();

      return videos.map((video) => VideoModel.fromVideo(video)).toList();
    } catch (e) {
      print('Error fetching random videos: $e');
      return [];
    }
  }

  Future<List<VideoModel>> getTrendingVideos({int count = 20}) async {
    try {
      final random = Random();
      final searchTerm = _trendingTerms[random.nextInt(_trendingTerms.length)];

      final searchResults = await _youtube.search.search(searchTerm);
      final videos = searchResults.take(count).whereType<Video>().cast<Video>();

      return videos.map((video) => VideoModel.fromVideo(video)).toList();
    } catch (e) {
      print('Error fetching trending videos: $e');
      return [];
    }
  }

  Future<List<VideoModel>> searchVideos(String query, {int count = 20}) async {
    try {
      final searchResults = await _youtube.search.search(query);
      final videos = searchResults.take(count).whereType<Video>().cast<Video>();

      return videos.map((video) => VideoModel.fromVideo(video)).toList();
    } catch (e) {
      print('Error searching videos: $e');
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

  Future<Video?> getVideoDetails(String videoId) async {
    try {
      return await _youtube.videos.get(videoId);
    } catch (e) {
      print('Error getting video details: $e');
      return null;
    }
  }

  void dispose() {
    _youtube.close();
  }
}

// Providers
final videoServiceProvider = Provider<VideoService>((ref) {
  final service = VideoService();
  ref.onDispose(() => service.dispose());
  return service;
});

final randomVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final service = ref.read(videoServiceProvider);
  return service.getRandomVideos();
});

final trendingVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final service = ref.read(videoServiceProvider);
  return service.getTrendingVideos();
});

final videoSearchProvider = FutureProvider.family<List<VideoModel>, String>((
  ref,
  query,
) async {
  final service = ref.read(videoServiceProvider);
  return service.searchVideos(query);
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
