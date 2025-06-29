// video_stream.dart
class VideoStream {
  final String url;
  final int? width;
  final int? height;
  final String? codec;
  final double? fps;

  VideoStream({
    required this.url,
    this.width,
    this.height,
    this.codec,
    this.fps,
  });

  factory VideoStream.fromJson(Map<String, dynamic> json) {
    return VideoStream(
      url: json['url'] ?? '',
      width: json['width'],
      height: json['height'],
      codec: json['codec'],
      fps: json['fps']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'width': width,
      'height': height,
      'codec': codec,
      'fps': fps,
    };
  }
}
