// audio_stream.dart
class AudioStream {
  final String url;
  final int? bitrate;
  final String? codec;

  AudioStream({required this.url, this.bitrate, this.codec});

  factory AudioStream.fromJson(Map<String, dynamic> json) {
    return AudioStream(
      url: json['url'] ?? '',
      bitrate: json['bitrate'],
      codec: json['codec'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'bitrate': bitrate, 'codec': codec};
  }
}
