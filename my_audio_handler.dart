import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';

class AudioStateProvider extends ChangeNotifier {
  YoutubePlayerController? _controller;
  VideoModel? _currentVideo;
  bool _isBackgroundMode = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Getters
  YoutubePlayerController? get controller => _controller;
  VideoModel? get currentVideo => _currentVideo;
  bool get isBackgroundMode => _isBackgroundMode;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get hasActiveAudio => _controller != null && _currentVideo != null;

  void setCurrentVideo(VideoModel video, YoutubePlayerController controller) {
    _currentVideo = video;
    _controller = controller;
    _controller?.addListener(_controllerListener);
    notifyListeners();
  }

  void _controllerListener() {
    if (_controller != null) {
      _isPlaying = _controller!.value.isPlaying;
      _position = _controller!.value.position;
      _duration = _controller!.metadata.duration;
      notifyListeners();
    }
  }

  void setBackgroundMode(bool isBackground) {
    _isBackgroundMode = isBackground;
    notifyListeners();
  }

  void play() {
    _controller?.play();
  }

  void pause() {
    _controller?.pause();
  }

  void seekTo(Duration position) {
    _controller?.seekTo(position);
  }

  void stop() {
    _controller?.pause();
    _controller?.removeListener(_controllerListener);
    _controller?.dispose();
    _controller = null;
    _currentVideo = null;
    _isBackgroundMode = false;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds'
        : '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  void dispose() {
    _controller?.removeListener(_controllerListener);
    _controller?.dispose();
    super.dispose();
  }
}
