// audio_quality.dart
class AudioQuality {
  final int bitrate;
  final String description;
  final bool available;

  AudioQuality({
    required this.bitrate,
    required this.description,
    required this.available,
  });

  factory AudioQuality.fromJson(Map<String, dynamic> json) {
    return AudioQuality(
      bitrate: json['bitrate'] ?? 0,
      description: json['description'] ?? '',
      available: json['available'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bitrate': bitrate,
      'description': description,
      'available': available,
    };
  }
}
