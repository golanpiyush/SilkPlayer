// channel_info.dart
class ChannelInfo {
  final String id;
  final String title;
  final String description;
  final int subscriberCount;
  final int videoCount;
  final String thumbnail;
  final String bannerUrl;
  final String avatarUrl;
  final bool verified;

  ChannelInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.subscriberCount,
    required this.videoCount,
    required this.thumbnail,
    required this.bannerUrl,
    required this.avatarUrl,
    required this.verified,
  });

  factory ChannelInfo.fromJson(Map<String, dynamic> json) {
    return ChannelInfo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subscriberCount: json['subscriberCount'] ?? 0,
      videoCount: json['videoCount'] ?? 0,
      thumbnail: json['thumbnail'] ?? '',
      bannerUrl: json['bannerUrl'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      verified: json['verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
      'thumbnail': thumbnail,
      'bannerUrl': bannerUrl,
      'avatarUrl': avatarUrl,
      'verified': verified,
    };
  }
}
