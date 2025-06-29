// Stream quality info class for BetterPlayerPlus
class StreamQualityInfo {
  final String? videoUrl;
  final String? audioUrl;
  final String quality;
  final bool hasVideo;
  final bool hasAudio;

  StreamQualityInfo({
    this.videoUrl,
    this.audioUrl,
    required this.quality,
    this.hasVideo = false,
    this.hasAudio = false,
  });
}
