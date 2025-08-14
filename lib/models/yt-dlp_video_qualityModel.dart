// video_quality.dart
class VideoQuality {
  final int height;
  final String description;
  final bool available;

  VideoQuality({
    required this.height,
    required this.description,
    required this.available,
  });

  factory VideoQuality.fromJson(Map<String, dynamic> json) {
    return VideoQuality(
      height: json['height'] ?? 0,
      description: json['description'] ?? '',
      available: json['available'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'description': description,
      'available': available,
    };
  }
}
