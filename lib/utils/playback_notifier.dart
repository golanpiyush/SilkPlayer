import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundPlaybackNotifier extends StateNotifier<bool> {
  BackgroundPlaybackNotifier() : super(false) {
    _loadSetting();
  }

  void _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('background_playback') ?? false;
  }

  void toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool('background_playback', state);
  }
}
