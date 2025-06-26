import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class VideoModel {
  final String id;
  final String title;
  final String author;
  final String channelId;
  final String description;
  final Duration? duration;
  final String thumbnailUrl;
  final int? viewCount;
  final DateTime? uploadDate;

  VideoModel({
    required this.id,
    required this.title,
    required this.author,
    required this.channelId,
    required this.description,
    this.duration,
    required this.thumbnailUrl,
    this.viewCount,
    this.uploadDate,
  });

  factory VideoModel.fromVideo(Video video) {
    return VideoModel(
      id: video.id.value,
      title: video.title,
      author: video.author,
      channelId: video.channelId.value,
      description: video.description,
      duration: video.duration,
      thumbnailUrl: video.thumbnails.mediumResUrl,
      viewCount: video.engagement.viewCount,
      uploadDate: video.uploadDate,
    );
  }

  factory VideoModel.fromSearchResult(SearchVideo searchVideo) {
    // Helper to parse duration string (format: "HH:MM:SS" or "MM:SS")
    Duration? parseDuration(String? durationString) {
      if (durationString == null) return null;
      try {
        final parts = durationString.split(':');
        if (parts.length == 3) {
          return Duration(
            hours: int.parse(parts[0]),
            minutes: int.parse(parts[1]),
            seconds: int.parse(parts[2]),
          );
        } else if (parts.length == 2) {
          return Duration(
            minutes: int.parse(parts[0]),
            seconds: int.parse(parts[1]),
          );
        }
        return null;
      } catch (e) {
        return null;
      }
    }

    // Helper to get best thumbnail URL
    String getThumbnailUrl(List<Thumbnail> thumbnails) {
      // Try to get medium resolution first
      try {
        final thumbnail = thumbnails.firstWhere(
          (t) => t.url.toString().contains('mqdefault'),
        );
        return thumbnail.url.toString(); // Convert Uri to String
      } catch (e) {
        // Fallback to first available thumbnail
        return thumbnails.isNotEmpty ? thumbnails.first.url.toString() : '';
      }
    }

    // Helper to parse upload date
    DateTime? parseUploadDate(String? dateString) {
      if (dateString == null) return null;
      try {
        return DateTime.tryParse(dateString);
      } catch (e) {
        return null;
      }
    }

    return VideoModel(
      id: searchVideo.id.value,
      title: searchVideo.title,
      author: searchVideo.author,
      channelId: searchVideo.channelId, // Already a String
      description: searchVideo.description ?? 'sex suxx ki batte',
      duration: parseDuration(searchVideo.duration),
      thumbnailUrl: getThumbnailUrl(searchVideo.thumbnails),
      viewCount: searchVideo.viewCount,
      uploadDate: parseUploadDate(searchVideo.uploadDate),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'channelId': channelId,
      'description': description,
      'duration': duration?.inSeconds,
      'thumbnailUrl': thumbnailUrl,
      'viewCount': viewCount,
      'uploadDate': uploadDate?.toIso8601String(),
    };
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      channelId: json['channelId'] ?? '',
      description: json['description'] ?? '',
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      viewCount: json['viewCount'],
      uploadDate: json['uploadDate'] != null
          ? DateTime.tryParse(json['uploadDate'] as String)
          : null,
    );
  }

  String get durationString {
    if (duration == null) return '';
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get viewCountString {
    if (viewCount == null) return '';

    if (viewCount! >= 1000000000) {
      return '${(viewCount! / 1000000000).toStringAsFixed(1)}B views';
    } else if (viewCount! >= 1000000) {
      return '${(viewCount! / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount! >= 1000) {
      return '${(viewCount! / 1000).toStringAsFixed(1)}K views';
    }
    return '$viewCount views';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
