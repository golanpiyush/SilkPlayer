import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:silkplayer/models/stream_quality-info.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'package:silkplayer/providers/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/video_model.dart';

import '../widgets/video_card.dart';
import '../widgets/loading_shimmer.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final VideoModel video;

  const PlayerScreen({super.key, required this.video});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  AudioPlayer? _audioPlayer;

  bool _isPlayerReady = false;
  bool _isDescriptionExpanded = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isFullscreen = false;
  bool _isInitializing = true;
  String? _errorMessage;
  bool _isSubscribed = false;

  // Audio playback state
  bool _hasAudioStream = false;
  String? _currentVideoUrl;
  String? _currentAudioUrl;

  // Seeking state
  bool _isSeeking = false;

  // Web-specific optimizations
  bool _isWebPlatform = kIsWeb;
  Timer? _syncTimer;
  int _pauseAttempts = 0;
  static const int maxPauseAttempts = 3;

  final _scrollController = ScrollController();

  // Related videos state
  Future<List<VideoModel>>? _relatedVideosFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
    _loadRelatedVideos();
  }

  void _loadRelatedVideos() {
    _relatedVideosFuture = ref.read(randomVideosProvider.future).then((videos) {
      return videos.where((v) => v.id != widget.video.id).take(5).toList();
    });
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
        _pauseAttempts = 0;
      });

      // Get quality from provider
      final quality = ref.read(qualityProvider);
      print(
        '🎯 Initializing player for video: ${widget.video.id} with quality: $quality',
      );

      // Get stream quality info from provider
      final streamInfo = await ref.read(
        videoAndAudioStreamsProvider((widget.video.id, quality)).future,
      );

      if (streamInfo == null) {
        throw Exception('Could not load video streams');
      }

      await _setupPlayer(streamInfo);

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isPlayerReady = true;
        });
      }
    } catch (e) {
      print('❌ Player initialization failed: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _setupPlayer(StreamQualityInfo streamInfo) async {
    try {
      // Dispose existing controllers first
      await _disposeControllers();

      // Setup video player with better error handling
      if (streamInfo.videoUrl != null && streamInfo.videoUrl!.isNotEmpty) {
        _currentVideoUrl = streamInfo.videoUrl;
        await _setupVideoPlayer(streamInfo.videoUrl!);
        print('✅ Video player setup completed');
      }

      // Only setup audio if it's truly separate and valid
      final hasValidAudio =
          streamInfo.audioUrl != null &&
          streamInfo.audioUrl!.isNotEmpty &&
          streamInfo.audioUrl != streamInfo.videoUrl;

      if (hasValidAudio) {
        try {
          _currentAudioUrl = streamInfo.audioUrl;
          await _setupAudioPlayer(streamInfo.audioUrl!);
          _hasAudioStream = true;
          print('✅ Separate audio stream setup completed');

          // Mute video player when we have separate audio
          if (_videoController != null) {
            await _videoController!.setVolume(0);
          }
        } catch (e) {
          print('⚠️ Audio setup failed, using video audio: $e');
          _hasAudioStream = false;
          _currentAudioUrl = null;

          // Unmute video player if audio setup failed
          if (_videoController != null) {
            await _videoController!.setVolume(1.0);
          }
        }
      } else {
        _hasAudioStream = false;
        _currentAudioUrl = null;
        print('ℹ️ Using video stream audio only');

        // Ensure video player is unmuted
        if (_videoController != null) {
          await _videoController!.setVolume(1.0);
        }
      }

      print(
        '✅ Player setup completed - Video: ${_currentVideoUrl != null}, Separate Audio: $_hasAudioStream',
      );
    } catch (e) {
      print('❌ Player setup failed: $e');
      rethrow;
    }
  }

  Future<void> _setupVideoPlayer(String videoUrl) async {
    try {
      // Enhanced headers for web compatibility
      final headers = <String, String>{
        'User-Agent': _isWebPlatform
            ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.youtube.com/',
        'Origin': 'https://www.youtube.com',
        'Accept':
            'video/webm,video/ogg,video/*;q=0.9,application/ogg;q=0.7,audio/*;q=0.6,*/*;q=0.5',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity;q=1, *;q=0',
        'Range': 'bytes=0-',
      };

      // Add CORS headers for web
      if (_isWebPlatform) {
        headers.addAll({
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, Range',
        });
      }

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: !_hasAudioStream,
          allowBackgroundPlayback: false,
          // Add web-specific options
          webOptions: _isWebPlatform
              ? const VideoPlayerWebOptions(
                  controls: VideoPlayerWebOptionsControls.disabled(),
                )
              : null,
        ),
      );

      // Add timeout for web
      if (_isWebPlatform) {
        await _videoController!.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception(
              'Video initialization timeout - URL may be expired or blocked',
            );
          },
        );
      } else {
        await _videoController!.initialize();
      }

      // Setup Chewie controller with web optimizations
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: !_hasAudioStream,
        showControls: true,
        aspectRatio: 16 / 9,
        placeholder: _buildLoadingWidget(),
        autoInitialize: true,
        startAt: Duration.zero,
        errorBuilder: (context, errorMessage) => _buildErrorWidget(),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.white.withOpacity(0.3),
          bufferedColor: Colors.white.withOpacity(0.5),
        ),
        customControls: _isWebPlatform
            ? _buildWebControls()
            : const MaterialControls(),
      );

      // Add video player listeners
      _videoController!.addListener(_onVideoPlayerUpdate);

      // Start sync timer for web
      if (_isWebPlatform && _hasAudioStream) {
        _startSyncTimer();
      }

      print(
        '✅ Video player setup completed for ${_isWebPlatform ? "web" : "mobile"}',
      );
    } catch (e) {
      print('❌ Video player setup failed: $e');
      throw e;
    }
  }

  Widget _buildWebControls() {
    return Stack(
      children: [
        // Invisible overlay to capture clicks
        Positioned.fill(
          child: GestureDetector(
            onTap: _handlePlayPause,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Custom control buttons
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(50),
            ),
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
              onPressed: _handlePlayPause,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePlayPause() async {
    if (_videoController == null) return;

    try {
      if (_videoController!.value.isPlaying) {
        await _pausePlayback();
      } else {
        await _resumePlayback();
      }
    } catch (e) {
      print('❌ Play/pause failed: $e');
    }
  }

  Future<void> _pausePlayback() async {
    await _videoController?.pause();
    if (_hasAudioStream && _audioPlayer != null) {
      await _audioPlayer!.pause();
    }
    setState(() => _isPlaying = false);
  }

  Future<void> _resumePlayback() async {
    try {
      // For web, add delay to prevent immediate pause
      if (_isWebPlatform) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await _videoController?.play();

      if (_hasAudioStream && _audioPlayer != null) {
        await _audioPlayer!.play();
      }

      setState(() => _isPlaying = true);
      _pauseAttempts = 0;
    } catch (e) {
      print('❌ Resume playback failed: $e');
      _pauseAttempts++;

      if (_pauseAttempts < maxPauseAttempts) {
        // Retry after a delay
        await Future.delayed(const Duration(milliseconds: 500));
        _resumePlayback();
      }
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (_hasAudioStream && !_isSeeking && mounted) {
        _syncAudioWithVideo();
      }
    });
  }

  Future<void> _setupAudioPlayer(String audioUrl) async {
    try {
      // Create new audio player instance
      await _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();

      // Enhanced headers for audio
      final headers = <String, String>{
        'User-Agent': _isWebPlatform
            ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.youtube.com/',
        'Origin': 'https://www.youtube.com',
        'Accept':
            'audio/webm,audio/ogg,audio/mpeg,audio/*;q=0.9,application/ogg;q=0.7,*/*;q=0.5',
        'Range': 'bytes=0-',
      };

      // Set audio source with timeout
      await _audioPlayer!
          .setAudioSource(
            AudioSource.uri(Uri.parse(audioUrl), headers: headers),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Audio stream setup timeout'),
          );

      // Ensure audio volume is at 100%
      await _audioPlayer!.setVolume(1.0);

      // Setup listeners
      _audioPlayer!.playingStream.listen((playing) {
        if (!mounted || _audioPlayer == null) return;
        setState(() {});
      });

      // Simplified state handling
      _audioPlayer!.playerStateStream.listen((state) {
        if (!mounted || _audioPlayer == null) return;

        switch (state.processingState) {
          case ProcessingState.buffering:
          case ProcessingState.loading:
            setState(() => _isBuffering = true);
            break;
          case ProcessingState.ready:
            setState(() => _isBuffering = false);
            break;
          case ProcessingState.completed:
            _handlePlaybackCompleted();
            break;
          default:
            break;
        }
      });

      print('✅ Audio player setup completed');
    } catch (e) {
      print('❌ Audio player setup failed: $e');
      _hasAudioStream = false;
      _audioPlayer?.dispose();
      _audioPlayer = null;
      rethrow;
    }
  }

  void _onVideoPlayerUpdate() {
    if (!mounted || _videoController == null) return;

    final value = _videoController!.value;

    // Handle auto-pause issue on web
    if (_isWebPlatform &&
        value.isInitialized &&
        !value.isPlaying &&
        _isPlaying &&
        !_isBuffering &&
        value.position < value.duration) {
      print('🔄 Detected unexpected pause, attempting to resume...');
      _handleUnexpectedPause();
    }

    if (mounted) {
      setState(() {
        _isPlaying = value.isPlaying;
        _isBuffering = value.isBuffering;
        _position = value.position;
        _duration = value.duration;
      });
    }
  }

  Future<void> _handleUnexpectedPause() async {
    if (_pauseAttempts >= maxPauseAttempts) {
      print('❌ Max pause attempts reached, giving up');
      return;
    }

    _pauseAttempts++;
    await Future.delayed(Duration(milliseconds: 200 * _pauseAttempts));

    if (_videoController != null && _videoController!.value.isInitialized) {
      try {
        await _videoController!.play();
        if (_hasAudioStream && _audioPlayer != null) {
          await _audioPlayer!.play();
        }
      } catch (e) {
        print('❌ Failed to resume after unexpected pause: $e');
      }
    }
  }

  Future<void> _syncAudioWithVideo() async {
    if (_audioPlayer == null || _videoController == null || !mounted) return;
    if (_isSeeking || !_hasAudioStream) return;

    try {
      final videoPosition = _videoController!.value.position;
      final audioPosition = _audioPlayer!.position;

      // Larger threshold to prevent constant syncing
      final threshold = const Duration(milliseconds: 300);

      // Only sync if difference is significant
      if ((videoPosition - audioPosition).abs() > threshold) {
        await _audioPlayer!.seek(videoPosition);
      }

      // Sync playback state
      final videoPlaying = _videoController!.value.isPlaying;
      final audioPlaying = _audioPlayer!.playing;

      if (videoPlaying && !audioPlaying) {
        await _audioPlayer!.play();
      } else if (!videoPlaying && audioPlaying) {
        await _audioPlayer!.pause();
      }
    } catch (e) {
      print('❌ Audio sync failed: $e');
    }
  }

  void _handlePlaybackCompleted() {
    setState(() {
      _isPlaying = false;
      _position = _duration;
    });
    _syncTimer?.cancel();
  }

  Future<void> _disposeControllers() async {
    // Cancel timer first
    _syncTimer?.cancel();
    _syncTimer = null;

    // Dispose in correct order
    try {
      _chewieController?.dispose();
      _chewieController = null;
    } catch (e) {
      print('❌ Chewie controller disposal failed: $e');
    }

    try {
      await _videoController?.dispose();
      _videoController = null;
    } catch (e) {
      print('❌ Video controller disposal failed: $e');
    }

    try {
      await _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (e) {
      print('❌ Audio player disposal failed: $e');
    }

    // Reset state
    _hasAudioStream = false;
    _isPlayerReady = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _disposeControllers();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _videoController?.pause();
        _audioPlayer?.pause();
        _syncTimer?.cancel();
        break;
      case AppLifecycleState.resumed:
        if (_isPlaying) {
          _videoController?.play();
          _audioPlayer?.play();
          if (_hasAudioStream && _isWebPlatform) {
            _startSyncTimer();
          }
        }
        break;
      default:
        break;
    }
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Video playback error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializePlayer,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentQuality = ref.watch(qualityProvider);
            final qualityOptions = ref.watch(videoQualityOptionsProvider);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Quality',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...qualityOptions.map((quality) {
                  return ListTile(
                    title: Text(
                      quality,
                      style: TextStyle(
                        color: currentQuality == quality
                            ? Colors.red
                            : Colors.white,
                      ),
                    ),
                    trailing: currentQuality == quality
                        ? const Icon(Icons.check, color: Colors.red)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _changeQuality(quality);
                    },
                  );
                }).toList(),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeQuality(String newQuality) async {
    if (!_isPlayerReady) return;

    final currentPosition = _position;
    final wasPlaying = _isPlaying;

    try {
      // Pause current playback
      if (_isPlaying) {
        await _videoController?.pause();
        await _audioPlayer?.pause();
      }

      // Update quality in provider
      ref.read(qualityProvider.notifier).state = newQuality;

      // Reinitialize with new quality
      await _initializePlayer();

      // Seek to previous position and resume if was playing
      if (_isPlayerReady) {
        await _seekTo(currentPosition);
        if (wasPlaying) {
          await _videoController?.play();
          if (_hasAudioStream && _audioPlayer != null) {
            await _audioPlayer!.play();
          }
        }
      }
    } catch (e) {
      print('❌ Quality change failed: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    if (_videoController == null || !_isPlayerReady) return;

    _isSeeking = true;

    try {
      await _videoController!.seekTo(position);
      if (_hasAudioStream && _audioPlayer != null) {
        await _audioPlayer!.seek(position);
      }

      setState(() => _position = position);
    } catch (e) {
      print('❌ Seek failed: $e');
    } finally {
      _isSeeking = false;
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleSubscription() {
    setState(() => _isSubscribed = !_isSubscribed);
    print('🔔 Subscription toggled: $_isSubscribed');
  }

  Widget _buildVideoInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 8,
                  ), // top padding for title
                  child: Text(
                    widget.video.title,
                    style: GoogleFonts.preahvihear(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      widget.video.viewCountString,
                      style: GoogleFonts.preahvihear(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const Text(" • ", style: TextStyle(color: Colors.grey)),
                    Text(
                      widget.video.uploadDate != null
                          ? timeago.format(widget.video.uploadDate!)
                          : '',
                      style: GoogleFonts.preahvihear(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isDescriptionExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.video.description,
                      style: GoogleFonts.preahvihear(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  crossFadeState: _isDescriptionExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Color(0xFF262626), height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: widget.video.uploaderAvatarUrl != null
                    ? NetworkImage(widget.video.uploaderAvatarUrl!)
                    : null,
                child: widget.video.uploaderAvatarUrl == null
                    ? const Icon(Icons.person, size: 24, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.video.author,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              GestureDetector(
                onTap: _toggleSubscription,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _isSubscribed ? Colors.grey[700] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: _isSubscribed
                        ? Border.all(color: Colors.white, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSubscribed) ...[
                        const Icon(
                          Icons.notifications,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _isSubscribed ? "Subscribed" : "Subscribe",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isSubscribed ? Colors.white : Colors.black,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRelatedVideos() {
    return FutureBuilder<List<VideoModel>>(
      future: _relatedVideosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Related Videos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                3,
                (index) => const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: LoadingShimmer(),
                ),
              ),
            ],
          );
        } else if (snapshot.hasError) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Related Videos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.grey,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading related videos',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadRelatedVideos,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else if (snapshot.hasData && snapshot.data!.isEmpty) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Related Videos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No related videos available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        }

        final relatedVideos = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Related Videos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...relatedVideos.map(
              (video) => VideoCard(
                video: video,
                showTrendingBadge: false,
                key: ValueKey('related_${video.id}'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (!_isFullscreen)
            Padding(
              padding: const EdgeInsets.only(top: 30.0, left: 12, right: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showQualitySelector,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          /* Menu action */
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.menu,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Video Player Section
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _isInitializing
                      ? _buildLoadingWidget()
                      : _errorMessage != null
                      ? _buildErrorWidget()
                      : _chewieController != null && _isPlayerReady
                      ? Chewie(controller: _chewieController!)
                      : _buildLoadingWidget(),
                ),
              ),
            ),
          ),

          // Bottom content
          if (!_isFullscreen)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Color(0xFF121212)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [_buildVideoInfoSection(), _buildRelatedVideos()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
