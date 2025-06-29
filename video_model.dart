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
  final String? uploaderAvatarUrl;
  // final bool isVerified;

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
    this.uploaderAvatarUrl,
    // this.isVerified = false,
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
      uploaderAvatarUrl: null, // Need to fetch via `channels.get(channelId)`
      // isVerified: false, // Cannot determine without channel data
    );
  }

  factory VideoModel.fromSearchResult(SearchVideo searchVideo) {
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
      } catch (_) {}
      return null;
    }

    String getThumbnailUrl(List<Thumbnail> thumbnails) {
      try {
        return thumbnails
            .firstWhere((t) => t.url.toString().contains('mqdefault'))
            .url
            .toString();
      } catch (_) {
        return thumbnails.isNotEmpty ? thumbnails.first.url.toString() : '';
      }
    }

    return VideoModel(
      id: searchVideo.id.value,
      title: searchVideo.title,
      author: searchVideo.author,
      channelId: searchVideo.channelId,
      description: searchVideo.description ?? '',
      duration: parseDuration(searchVideo.duration),
      thumbnailUrl: getThumbnailUrl(searchVideo.thumbnails),
      viewCount: searchVideo.viewCount,
      uploadDate: DateTime.tryParse(searchVideo.uploadDate ?? ''),
      uploaderAvatarUrl: null, // Not available from SearchVideo
      // isVerified: false, // Not available from SearchVideo
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
      'uploaderAvatarUrl': uploaderAvatarUrl,
      // 'isVerified': isVerified,
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
          ? DateTime.tryParse(json['uploadDate'])
          : null,
      uploaderAvatarUrl: json['uploaderAvatarUrl'],
      // isVerified: json['isVerified'] ?? false,
    );
  }

  static Future<VideoModel> fromVideoWithChannelInfo(
    YoutubeExplode yt,
    Video video,
  ) async {
    try {
      final channel = await yt.channels.get(video.channelId);

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
        uploaderAvatarUrl: channel.logoUrl,
        // isVerified: channel.isVerified,
      );
    } catch (e) {
      print('Error fetching channel info for video: $e');
      return VideoModel.fromVideo(video); // fallback to basic info
    }
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
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get viewCountString {
    if (viewCount == null) return '';
    if (viewCount! >= 1_000_000_000) {
      return '${(viewCount! / 1_000_000_000).toStringAsFixed(1)}B views';
    } else if (viewCount! >= 1_000_000) {
      return '${(viewCount! / 1_000_000).toStringAsFixed(1)}M views';
    } else if (viewCount! >= 1_000) {
      return '${(viewCount! / 1_000).toStringAsFixed(1)}K views';
    } else {
      return '$viewCount views';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
