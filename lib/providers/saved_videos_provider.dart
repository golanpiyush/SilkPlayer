import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class SavedVideosNotifier extends StateNotifier<List<VideoModel>> {
  SavedVideosNotifier() : super([]) {
    _loadSavedVideos();
  }

  static const String _savedVideosKey = 'saved_videos';

  Future<void> _loadSavedVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVideosJson = prefs.getStringList(_savedVideosKey) ?? [];

    final savedVideos = savedVideosJson
        .map((jsonString) => VideoModel.fromJson(jsonDecode(jsonString)))
        .toList();

    state = savedVideos;
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVideosJson = state
        .map((video) => jsonEncode(video.toJson()))
        .toList();

    await prefs.setStringList(_savedVideosKey, savedVideosJson);
  }

  Future<void> addVideo(VideoModel video) async {
    if (!isVideoSaved(video.id)) {
      state = [...state, video];
      await _saveToDisk();
    }
  }

  Future<void> removeVideo(String videoId) async {
    state = state.where((video) => video.id != videoId).toList();
    await _saveToDisk();
  }

  bool isVideoSaved(String videoId) {
    return state.any((video) => video.id == videoId);
  }

  Future<void> toggleVideo(VideoModel video) async {
    if (isVideoSaved(video.id)) {
      await removeVideo(video.id);
    } else {
      await addVideo(video);
    }
  }

  Future<void> clearAll() async {
    state = [];
    await _saveToDisk();
  }
}

final savedVideosProvider =
    StateNotifierProvider<SavedVideosNotifier, List<VideoModel>>((ref) {
      return SavedVideosNotifier();
    });
