// thumbnail_info.dart
class ThumbnailInfo {
  final String url;
  final int? width;
  final int? height;

  ThumbnailInfo({required this.url, this.width, this.height});

  factory ThumbnailInfo.fromJson(Map<String, dynamic> json) {
    return ThumbnailInfo(
      url: json['url'] ?? '',
      width: json['width'],
      height: json['height'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'width': width, 'height': height};
  }
}
