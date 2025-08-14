enum VideoBackend {
  ytdlp('Youtube_DL'),
  explode('YouTube Explode'),
  piped('Piped'),
  invidious('Invidious'),
  beast('Beast Mode'); // Uses both Invidious + Piped

  const VideoBackend(this.displayName);
  final String displayName;
}
