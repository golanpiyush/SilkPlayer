class VideoFormat {
  final String formatId;
  final String url;
  final String ext;
  final int quality;
  final String resolution;
  final int height;
  final int width;
  final int fps;
  final int filesize;
  final int tbr;
  final int vbr;
  final int abr;
  final String acodec;
  final String vcodec;
  final String formatNote;
  final String protocol;

  VideoFormat({
    required this.formatId,
    required this.url,
    required this.ext,
    required this.quality,
    required this.resolution,
    required this.height,
    required this.width,
    required this.fps,
    required this.filesize,
    required this.tbr,
    required this.vbr,
    required this.abr,
    required this.acodec,
    required this.vcodec,
    required this.formatNote,
    required this.protocol,
  });

  factory VideoFormat.fromJson(Map<String, dynamic> json) {
    return VideoFormat(
      formatId: json['formatId'] ?? '',
      url: json['url'] ?? '',
      ext: json['ext'] ?? '',
      quality: json['quality'] ?? 0,
      resolution: json['resolution'] ?? '',
      height: json['height'] ?? 0,
      width: json['width'] ?? 0,
      fps: json['fps'] ?? 0,
      filesize: json['filesize'] ?? 0,
      tbr: json['tbr'] ?? 0,
      vbr: json['vbr'] ?? 0,
      abr: json['abr'] ?? 0,
      acodec: json['acodec'] ?? '',
      vcodec: json['vcodec'] ?? '',
      formatNote: json['formatNote'] ?? '',
      protocol: json['protocol'] ?? '',
    );
  }
}

class AudioFormat {
  final String formatId;
  final String url;
  final String ext;
  final int abr;
  final String acodec;
  final String formatNote;
  final String protocol;

  AudioFormat({
    required this.formatId,
    required this.url,
    required this.ext,
    required this.abr,
    required this.acodec,
    required this.formatNote,
    required this.protocol,
  });

  factory AudioFormat.fromJson(Map<String, dynamic> json) {
    return AudioFormat(
      formatId: json['formatId'] ?? '',
      url: json['url'] ?? '',
      ext: json['ext'] ?? '',
      abr: json['abr'] ?? 0,
      acodec: json['acodec'] ?? '',
      formatNote: json['formatNote'] ?? '',
      protocol: json['protocol'] ?? '',
    );
  }
}

class VideoInfo {
  final String videoId;
  final String title;
  final String? channelName;
  final String? channelId;
  final int? duration;
  final int? viewCount;
  final String? uploadDate;
  final String? thumbnail;
  final String? description;
  final String? webpageUrl;
  final String? originalUrl;
  final String timestamp;
  final List<VideoFormat>? videoFormats;
  final List<AudioFormat>? audioFormats;

  VideoInfo({
    required this.videoId,
    required this.title,
    this.channelName,
    this.channelId,
    this.duration,
    this.viewCount,
    this.uploadDate,
    this.thumbnail,
    this.description,
    this.webpageUrl,
    this.originalUrl,
    required this.timestamp,
    this.videoFormats,
    this.audioFormats,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      channelName: json['channelName'],
      channelId: json['channelId'],
      duration: json['duration'],
      viewCount: json['viewCount'],
      uploadDate: json['uploadDate'],
      thumbnail: json['thumbnail'],
      description: json['description'],
      webpageUrl: json['webpageUrl'],
      originalUrl: json['originalUrl'],
      timestamp: json['timestamp'] ?? '',
      videoFormats: json['videoFormats'] != null
          ? (json['videoFormats'] as List)
              .map((e) => VideoFormat.fromJson(e))
              .toList()
          : null,
      audioFormats: json['audioFormats'] != null
          ? (json['audioFormats'] as List)
              .map((e) => AudioFormat.fromJson(e))
              .toList()
          : null,
    );
  }
}

class BestFormatUrls {
  final String videoId;
  final String title;
  final String? bestVideoUrl;
  final String? bestAudioUrl;
  final String? bestCombinedUrl;
  final int formatsAvailable;

  BestFormatUrls({
    required this.videoId,
    required this.title,
    this.bestVideoUrl,
    this.bestAudioUrl,
    this.bestCombinedUrl,
    required this.formatsAvailable,
  });

  factory BestFormatUrls.fromJson(Map<String, dynamic> json) {
    return BestFormatUrls(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      bestVideoUrl: json['bestVideoUrl'],
      bestAudioUrl: json['bestAudioUrl'],
      bestCombinedUrl: json['bestCombinedUrl'],
      formatsAvailable: json['formatsAvailable'] ?? 0,
    );
  }
}

// Base class for video metadata
class _BaseVideoInfo {
  final String videoId;
  final String title;
  final String? channelName;
  final String? channelId;
  final String? thumbnail;
  final int? duration;
  final int? viewCount;
  final String? uploadDate;
  final String? webpageUrl;

  _BaseVideoInfo({
    required this.videoId,
    required this.title,
    this.channelName,
    this.channelId,
    this.thumbnail,
    this.duration,
    this.viewCount,
    this.uploadDate,
    this.webpageUrl,
  });
}

class SearchResult extends _BaseVideoInfo {
  final String? searchQuery;
  final int? searchRank;

  SearchResult({
    required super.videoId,
    required super.title,
    super.channelName,
    super.channelId,
    super.thumbnail,
    super.duration,
    super.viewCount,
    super.uploadDate,
    super.webpageUrl,
    this.searchQuery,
    this.searchRank,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      channelName: json['channelName'],
      channelId: json['channelId'],
      thumbnail: json['thumbnail'],
      duration: json['duration'],
      viewCount: json['viewCount'],
      uploadDate: json['uploadDate'],
      webpageUrl: json['webpageUrl'],
      searchQuery: json['searchQuery'],
      searchRank: json['searchRank'],
    );
  }
}

class RelatedVideo extends _BaseVideoInfo {
  RelatedVideo({
    required super.videoId,
    required super.title,
    super.channelName,
    super.channelId,
    super.thumbnail,
    super.duration,
    super.viewCount,
    super.uploadDate,
    super.webpageUrl,
  });

  factory RelatedVideo.fromJson(Map<String, dynamic> json) {
    return RelatedVideo(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      channelName: json['channelName'],
      channelId: json['channelId'],
      thumbnail: json['thumbnail'],
      duration: json['duration'],
      viewCount: json['viewCount'],
      uploadDate: json['uploadDate'],
      webpageUrl: json['webpageUrl'],
    );
  }
}

class RandomVideo extends _BaseVideoInfo {
  final String? category;
  final String? searchTerm;

  RandomVideo({
    required super.videoId,
    required super.title,
    super.channelName,
    super.channelId,
    super.thumbnail,
    super.duration,
    super.viewCount,
    super.uploadDate,
    super.webpageUrl,
    this.category,
    this.searchTerm,
  });

  factory RandomVideo.fromJson(Map<String, dynamic> json) {
    return RandomVideo(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      channelName: json['channelName'],
      channelId: json['channelId'],
      thumbnail: json['thumbnail'],
      duration: json['duration'],
      viewCount: json['viewCount'],
      uploadDate: json['uploadDate'],
      webpageUrl: json['webpageUrl'],
      category: json['category'],
      searchTerm: json['searchTerm'],
    );
  }
}

class TrendingVideo extends _BaseVideoInfo {
  final String? trendingQuery;
  final bool isTrending;

  TrendingVideo({
    required super.videoId,
    required super.title,
    super.channelName,
    super.channelId,
    super.thumbnail,
    super.duration,
    super.viewCount,
    super.uploadDate,
    super.webpageUrl,
    this.trendingQuery,
    required this.isTrending,
  });

  factory TrendingVideo.fromJson(Map<String, dynamic> json) {
    return TrendingVideo(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      channelName: json['channelName'],
      channelId: json['channelId'],
      thumbnail: json['thumbnail'],
      duration: json['duration'],
      viewCount: json['viewCount'],
      uploadDate: json['uploadDate'],
      webpageUrl: json['webpageUrl'],
      trendingQuery: json['trendingQuery'],
      isTrending: json['isTrending'] ?? false,
    );
  }
}