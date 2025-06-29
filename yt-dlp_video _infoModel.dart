class VideoInfo {
  final String id;
  final String title;
  final String description;
  final int duration;
  final String thumbnail;
  final String uploader;
  final String uploaderAvatarUrl;
  final int viewCount;
  final int likeCount;
  final String uploadDate;
  final String channelId;
  final String channelUrl;
  final List<String> tags;
  final List<String> categories;

  VideoInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.thumbnail,
    required this.uploader,
    required this.uploaderAvatarUrl,
    required this.viewCount,
    required this.likeCount,
    required this.uploadDate,
    required this.channelId,
    required this.channelUrl,
    required this.tags,
    required this.categories,
  });

  factory VideoInfo.fromMap(Map<String, dynamic> map) {
    return VideoInfo(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      duration: map['duration'] ?? 0,
      thumbnail: map['thumbnail'] ?? '',
      uploader: map['uploader'] ?? '',
      uploaderAvatarUrl: map['uploaderAvatarUrl'] ?? '',
      viewCount: map['viewCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      uploadDate: map['uploadDate'] ?? '',
      channelId: map['channelId'] ?? '',
      channelUrl: map['channelUrl'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      categories: List<String>.from(map['categories'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'duration': duration,
      'thumbnail': thumbnail,
      'uploader': uploader,
      'uploaderAvatarUrl': uploaderAvatarUrl,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'uploadDate': uploadDate,
      'channelId': channelId,
      'channelUrl': channelUrl,
      'tags': tags,
      'categories': categories,
    };
  }
}
