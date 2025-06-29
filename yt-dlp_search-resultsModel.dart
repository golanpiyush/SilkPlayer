class SearchResult {
  final String id;
  final String title;
  final String uploader;
  final int duration;
  final int viewCount;
  final String url;
  final String thumbnail;

  SearchResult({
    required this.id,
    required this.title,
    required this.uploader,
    required this.duration,
    required this.viewCount,
    required this.url,
    required this.thumbnail,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      uploader: map['uploader'] ?? '',
      duration: map['duration'] ?? 0,
      viewCount: map['viewCount'] ?? 0,
      url: map['url'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'uploader': uploader,
      'duration': duration,
      'viewCount': viewCount,
      'url': url,
      'thumbnail': thumbnail,
    };
  }
}
