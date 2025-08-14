class StreamQualityInfo {
  final String? videoUrl;
  final String? audioUrl;
  final String quality;
  final bool hasVideo;
  final bool hasAudio;
  final List<String> availableQualities; // This is List<String>
  final String? videoCodec;
  final String? audioCodec;
  final int? bitrate;

  StreamQualityInfo({
    this.videoUrl,
    this.audioUrl,
    required this.quality,
    this.hasVideo = false,
    this.hasAudio = false,
    List<String>? availableQualities, // Changed to List<String>
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
  }) : availableQualities = availableQualities ?? [];

  // Factory constructor now matches the main constructor
  factory StreamQualityInfo.withQualities({
    required String quality,
    List<String> availableQualities = const [], // Changed to List<String>
    String? videoUrl,
    String? audioUrl,
    bool hasVideo = false,
    bool hasAudio = false,
  }) {
    return StreamQualityInfo(
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      quality: quality,
      hasVideo: hasVideo,
      hasAudio: hasAudio,
      availableQualities: availableQualities,
    );
  }

  // Helper methods...
  bool isSelected(StreamQualityInfo current) {
    return quality == current.quality &&
        videoUrl == current.videoUrl &&
        audioUrl == current.audioUrl;
  }

  String get displayText {
    return '$quality${hasVideo && hasAudio
        ? ''
        : hasVideo
        ? ' (Video Only)'
        : ' (Audio Only)'}';
  }
}
