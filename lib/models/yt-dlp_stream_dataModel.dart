class StreamInfo {
  final String formatId;
  final String url;
  final String ext;
  final String quality;
  final String resolution;
  final int fps;
  final int filesize;
  final String vcodec;
  final String acodec;
  final double abr;
  final double vbr;
  final double tbr;
  final int width;
  final int height;
  final String formatNote;
  final String protocol;

  StreamInfo({
    required this.formatId,
    required this.url,
    required this.ext,
    required this.quality,
    required this.resolution,
    required this.fps,
    required this.filesize,
    required this.vcodec,
    required this.acodec,
    required this.abr,
    required this.vbr,
    required this.tbr,
    required this.width,
    required this.height,
    required this.formatNote,
    required this.protocol,
  });

  factory StreamInfo.fromMap(Map<String, dynamic> map) {
    return StreamInfo(
      formatId: map['formatId'] ?? '',
      url: map['url'] ?? '',
      ext: map['ext'] ?? '',
      quality: map['quality'] ?? '',
      resolution: map['resolution'] ?? '',
      fps: map['fps'] ?? 0,
      filesize: map['filesize'] ?? 0,
      vcodec: map['vcodec'] ?? '',
      acodec: map['acodec'] ?? '',
      abr: (map['abr'] ?? 0.0).toDouble(),
      vbr: (map['vbr'] ?? 0.0).toDouble(),
      tbr: (map['tbr'] ?? 0.0).toDouble(),
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
      formatNote: map['formatNote'] ?? '',
      protocol: map['protocol'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formatId': formatId,
      'url': url,
      'ext': ext,
      'quality': quality,
      'resolution': resolution,
      'fps': fps,
      'filesize': filesize,
      'vcodec': vcodec,
      'acodec': acodec,
      'abr': abr,
      'vbr': vbr,
      'tbr': tbr,
      'width': width,
      'height': height,
      'formatNote': formatNote,
      'protocol': protocol,
    };
  }
}
