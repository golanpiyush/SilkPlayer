import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pod_player/pod_player.dart';
import 'package:silkplayer/models/stream_quality-info.dart';
import 'package:just_audio/just_audio.dart';
import 'package:silkplayer/models/video_model.dart';
import 'package:silkplayer/providers/my_audio_handler.dart';
import 'package:silkplayer/providers/provider.dart';
import 'package:silkplayer/providers/ytdlpServicesProvider.dart';
import 'package:silkplayer/widgets/loading_shimmer.dart';
import 'package:silkplayer/widgets/video_card.dart';
import 'package:timeago/timeago.dart' as timeago;

class PlayerScreen extends ConsumerStatefulWidget {
  final VideoModel video;

  const PlayerScreen({super.key, required this.video});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  PodPlayerController? _podPlayerController;
  AudioVideoSyncHandler? _syncHandler;

  // Core Player State
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isInitializing = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  String _statusMessage = '';

  // UI State
  bool _isDescriptionExpanded = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;

  // Subscription State
  bool _isSubscribed = false;

  // Related Videos State
  final _scrollController = ScrollController();
  StreamSubscription<List<VideoModel>>? _relatedVideosSubscription;
  List<VideoModel> _relatedVideos = [];
  bool _isLoadingRelated = true;
  String? _relatedVideosError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initializeSyncHandler();
    _initializePlayer();
    _loadRelatedVideos();
  }

  void _loadRelatedVideos() {
    setState(() {
      _isLoadingRelated = true;
      _relatedVideosError = null;
    });

    _relatedVideosSubscription?.cancel();
    _relatedVideosSubscription = ref
        .read(relatedVideosProvider(widget.video.id).stream)
        .listen(
          (videos) {
            if (mounted) {
              setState(() {
                _relatedVideos = videos
                    .where((v) => v.id != widget.video.id)
                    .take(5)
                    .toList();
                _isLoadingRelated = false;
                _relatedVideosError = null;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isLoadingRelated = false;
                _relatedVideosError = error.toString();
              });
            }
            print('❌ Related videos error: $error');
          },
        );
  }

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

  Future<void> _initializePlayer() async {
    int attemptCount = 0;
    const maxAttempts = 3;
    final quality = ref.read(ytdlpServicesProvider).videoQuality;

    while (attemptCount < maxAttempts) {
      attemptCount++;

      try {
        setState(() {
          _isInitializing = true;
          _errorMessage = null;
          _isPlaying = false;
          _isBuffering = false;
        });

        print('🎯 Initializing player (attempt $attemptCount/$maxAttempts)');

        // Clear any existing state
        await _disposeVideoController();
        await Future.delayed(const Duration(milliseconds: 200));

        // Get stream info with progressive timeout
        final timeout = Duration(seconds: 15 + (attemptCount * 5));

        StreamQualityInfo? streamInfo;
        try {
          if (attemptCount > 1) {
            ref.invalidate(
              videoAndAudioStreamsProvider((widget.video.id, quality)),
            );
            // Force refresh after invalidation
            await Future.delayed(const Duration(milliseconds: 500));
          }

          streamInfo = await ref
              .read(
                videoAndAudioStreamsProvider((widget.video.id, quality)).future,
              )
              .timeout(timeout);
        } on TimeoutException {
          if (attemptCount < maxAttempts) {
            print('⏰ Stream timeout, trying auto quality');
            if (quality != 'Auto') {
              ref.read(ytdlpServicesProvider.notifier).setVideoQuality('Auto');
            }
            continue;
          }
          throw TimeoutException(
            'Stream loading timeout after $maxAttempts attempts',
            timeout,
          );
        }

        if (streamInfo?.videoUrl == null || streamInfo!.videoUrl!.isEmpty) {
          throw Exception('Invalid or empty video URL received');
        }

        // Validate stream URL accessibility
        if (!await _validateStreamUrl(streamInfo.videoUrl!)) {
          throw Exception('Stream URL is not accessible');
        }

        await _setupPlayerWithSyncHandler(streamInfo);

        if (mounted) {
          setState(() {
            _isInitializing = false;
            _isPlayerReady = true;
            _isBuffering = false;
          });
        }

        print('✅ Player initialized successfully on attempt $attemptCount');
        return;
      } catch (e) {
        print('❌ Player initialization attempt $attemptCount failed: $e');

        if (attemptCount >= maxAttempts) {
          if (mounted) {
            setState(() {
              _isInitializing = false;
              _errorMessage = _getUserFriendlyError(e);
              _isBuffering = false;
            });
          }
          return;
        }

        // Progressive retry delay
        final retryDelay = Duration(milliseconds: 500 * attemptCount);
        if (mounted) {
          setState(() {
            _errorMessage =
                'Loading failed, retrying in ${retryDelay.inSeconds}s... ($attemptCount/$maxAttempts)';
          });
        }

        await Future.delayed(retryDelay);
      }
    }
  }

  Future<bool> _validateStreamUrl(String url) async {
    try {
      print('🔍 Validating stream URL accessibility...');

      // Simple connectivity check - don't download content
      final uri = Uri.parse(url);
      if (uri.scheme.isEmpty || uri.host.isEmpty) {
        print('❌ Invalid URL format');
        return false;
      }

      print('✅ Stream URL format valid');
      return true;
    } catch (e) {
      print('❌ Stream URL validation failed: $e');
      return false;
    }
  }

  // Initialize the sync handler
  void _initializeSyncHandler() {
    _syncHandler = AudioVideoSyncHandler(
      onPlayingStateChanged: (isPlaying) {
        if (mounted && !_isInitializing) {
          setState(() {
            _isPlaying = isPlaying;
            _isBuffering = false;
          });
          print('🎮 Playing state changed: $isPlaying');
        }
      },
      onPositionChanged: (position) {
        if (mounted && !_isInitializing) {
          setState(() => _position = position);
        }
      },
      onDurationChanged: (duration) {
        if (mounted && !_isInitializing) {
          setState(() => _duration = duration);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _isInitializing = false;
            _isPlayerReady = false;
            _isPlaying = false;
            _isBuffering = false;
            _statusMessage = '';
          });
          print('❌ Sync handler error: $error');
        }
      },
      onBufferingChanged: (isBuffering) {
        if (mounted && !_isInitializing) {
          setState(() => _isBuffering = isBuffering);
          print('📡 Buffering state changed: $isBuffering');
        }
      },
      // NEW: Add status update callback
      onStatusUpdate: (status) {
        if (mounted && _isInitializing) {
          setState(() => _statusMessage = status);
        }
      },
    );
  }

  Future<void> _setupPlayerWithSyncHandler(StreamQualityInfo streamInfo) async {
    try {
      // Dispose existing sync handler first
      await _syncHandler?.dispose();
      await Future.delayed(
        const Duration(milliseconds: 300),
      ); // Wait for cleanup

      if (streamInfo.videoUrl == null || streamInfo.videoUrl!.isEmpty) {
        throw Exception('Invalid video URL received from stream service');
      }

      print('🎥 Setting up player with sync handler');
      print('🎥 Video URL: ${streamInfo.videoUrl!.substring(0, 100)}...');
      if (streamInfo.audioUrl != null && streamInfo.audioUrl!.isNotEmpty) {
        print('🎵 Audio URL: ${streamInfo.audioUrl!.substring(0, 100)}...');
      }

      // Setup video controller first
      await _setupVideoController(streamInfo.videoUrl!);

      // Wait for video to be fully ready
      await _waitForVideoReady();

      // Initialize sync handler with both video and audio
      final success = await _syncHandler!.initialize(
        videoUrl: streamInfo.videoUrl!,
        audioUrl: streamInfo.audioUrl, // Can be null
        videoController: _podPlayerController!,
      );

      if (!success) {
        throw Exception('Sync handler initialization failed');
      }

      print('✅ Player setup with sync handler completed');
    } catch (e) {
      print('❌ Player setup with sync handler failed: $e');
      rethrow;
    }
  }

  Future<void> _setupVideoController(String videoUrl) async {
    try {
      await _disposeVideoController();

      _podPlayerController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(
          videoUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
            'Referer': 'https://www.youtube.com/',
            'Accept': '*/*',
            'Accept-Encoding':
                'identity', // Disable compression for better streaming
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          },
        ),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: false,
          isLooping: false,
          videoQualityPriority: [720, 480, 360],
          wakelockEnabled: true,
          // Buffer optimization
          forcedVideoFocus: true,
          // enablePlaybackSpeed: false, // Reduce processing overhead
        ),
      );

      // Pre-buffer the video with extended timeout
      await _podPlayerController!.initialise().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Video initialization timeout',
            const Duration(seconds: 30),
          );
        },
      );

      // Force initial buffer loading
      await _preBufferVideo();

      print('✅ Video controller setup completed with buffer optimization');
    } catch (e) {
      print('❌ Video controller setup failed: $e');
      rethrow;
    }
  }

  Future<void> _preBufferVideo() async {
    if (_podPlayerController == null || !_podPlayerController!.isInitialised) {
      return;
    }

    try {
      print('🔄 Pre-buffering video...');

      // Start playing briefly to trigger buffer fill
      _podPlayerController!.play();
      await Future.delayed(const Duration(milliseconds: 100));
      _podPlayerController!.pause();

      // Wait for buffer to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      print('✅ Pre-buffering completed');
    } catch (e) {
      print('⚠️ Pre-buffering failed (non-critical): $e');
    }
  }

  Future<void> _waitForVideoReady() async {
    if (_podPlayerController == null) return;

    int attempts = 0;
    const maxWaitAttempts = 50; // Increased from 30

    print('⏳ Waiting for video to be ready...');

    while (attempts < maxWaitAttempts && mounted) {
      if (_podPlayerController!.isInitialised) {
        final duration = _podPlayerController!.totalVideoLength;
        if (duration > Duration.zero) {
          // Check if video is actually ready by testing position capability
          try {
            final currentPos = _podPlayerController!.currentVideoPosition;
            if (currentPos >= Duration.zero) {
              print(
                '✅ Video ready with duration: ${duration.inSeconds}s, position: ${currentPos.inSeconds}s',
              );

              // Additional buffer stability wait
              await Future.delayed(const Duration(milliseconds: 800));
              return;
            }
          } catch (e) {
            print('⚠️ Video not fully ready yet: $e');
          }
        }
      }
      attempts++;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print(
      '⚠️ Video ready timeout after ${maxWaitAttempts * 100}ms, proceeding anyway',
    );
  }
  // ============================================================================
  // PLAYBACK CONTROL METHODS (NOW USING SYNC HANDLER)
  // ============================================================================

  Future<void> _handlePlayPause() async {
    if (!_isPlayerReady ||
        _syncHandler == null ||
        !_syncHandler!.isInitialized ||
        _isInitializing) {
      print('⚠️ Player not ready for play/pause');
      return;
    }

    _showControlsTemporarily();

    try {
      print('🎮 Enhanced play/pause triggered. Current state: $_isPlaying');

      // Enhanced state management
      if (_isPlaying) {
        // Pausing - no buffering indicator needed
        setState(() => _isBuffering = false);

        bool success = await _syncHandler!.pause();
        if (success && mounted) {
          setState(() {
            _isPlaying = false;
            _isBuffering = false;
          });
          print('✅ Enhanced pause successful');
        }
      } else {
        // Playing - show buffering during startup
        setState(() => _isBuffering = true);

        // Enhanced buffer readiness check
        await _ensureEnhancedBufferReady();

        bool success = await _syncHandler!.play();
        if (success && mounted) {
          // Enhanced playback verification
          await _verifyPlaybackStarted();
          print('✅ Enhanced play successful');
        } else {
          setState(() => _isBuffering = false);
          print('❌ Enhanced play failed');
        }
      }
    } catch (e) {
      print('❌ Enhanced play/pause failed: $e');
      if (mounted) {
        setState(() => _isBuffering = false);
      }
    }
  }

  // ADD these new helper methods:
  Future<void> _ensureEnhancedBufferReady() async {
    if (_podPlayerController == null || !_podPlayerController!.isInitialised) {
      return;
    }

    try {
      print('🔄 Enhanced buffer readiness check...');

      // Verify player responsiveness
      final currentPos = _podPlayerController!.currentVideoPosition;
      if (currentPos < Duration.zero) {
        print('⚠️ Player position invalid, resetting...');
        _podPlayerController!.videoSeekTo(Duration.zero);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Additional stability check
      final testPos = _podPlayerController!.currentVideoPosition;
      if (testPos >= Duration.zero) {
        print('✅ Enhanced buffer check passed');
      }
    } catch (e) {
      print('⚠️ Enhanced buffer check failed (non-critical): $e');
    }
  }

  Future<void> _verifyPlaybackStarted() async {
    // Wait a bit longer for playback to actually start
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isPlaying = true;
        _isBuffering = false;
      });
    }
  }

  Widget _buildProgressSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.red,
        inactiveTrackColor: Colors.white.withOpacity(0.3),
        thumbColor: Colors.red,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        trackHeight: 3,
      ),
      child: Slider(
        value: _duration.inMilliseconds > 0
            ? (_position.inMilliseconds.toDouble()).clamp(
                0.0,
                _duration.inMilliseconds.toDouble(),
              )
            : 0.0,
        max: _duration.inMilliseconds > 0
            ? _duration.inMilliseconds.toDouble()
            : 1.0,
        onChanged: (value) {
          // Only update UI position while dragging
          if (mounted) {
            setState(() {
              _position = Duration(milliseconds: value.toInt());
            });
          }
        },
        onChangeEnd: (value) {
          // Perform actual seek when user releases slider
          final newPosition = Duration(milliseconds: value.toInt());
          _seekTo(newPosition);
        },
        onChangeStart: (_) {
          _showControlsTemporarily();
        },
      ),
    );
  }

  Future<void> _waitForStateConfirmation(
    bool expectedState, {
    int maxWaitMs = 2000,
  }) async {
    int waitTime = 0;
    const checkInterval = 100;

    while (waitTime < maxWaitMs && mounted) {
      await Future.delayed(const Duration(milliseconds: checkInterval));
      waitTime += checkInterval;

      // Check if sync handler state matches expected
      if (_syncHandler!.isPlaying == expectedState) {
        setState(() {
          _isPlaying = expectedState;
          _isBuffering = false;
        });
        print('✅ State confirmed: $_isPlaying');
        return;
      }
    }

    // Timeout - set state anyway but log warning
    print('⚠️ State confirmation timeout, setting state anyway');
    setState(() {
      _isPlaying = expectedState;
      _isBuffering = false;
    });
  }

  Future<void> _seekTo(Duration position) async {
    if (!_isPlayerReady ||
        _syncHandler == null ||
        !_syncHandler!.isInitialized ||
        _isInitializing) {
      print('⚠️ Player not ready for seek');
      return;
    }

    _showControlsTemporarily();
    print('🔍 Player seeking to: ${position.inSeconds}s');

    try {
      setState(() => _isBuffering = true);

      // Pause first to prevent buffer conflicts during seek
      final wasPlaying = _isPlaying;
      if (wasPlaying) {
        await _syncHandler!.pause();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Perform seek
      final success = await _syncHandler!.seekTo(position);

      if (success) {
        // Wait for seek to stabilize
        await Future.delayed(const Duration(milliseconds: 700));

        // Get the actual position from sync handler
        if (mounted) {
          final actualPosition = _syncHandler!.position;
          setState(() {
            _position = actualPosition;
            _isBuffering = false;
          });

          // Resume playback if it was playing
          if (wasPlaying) {
            await Future.delayed(const Duration(milliseconds: 200));
            await _syncHandler!.play();
            setState(() => _isPlaying = true);
          }

          print(
            '✅ Seek completed. Actual position: ${actualPosition.inSeconds}s',
          );
        }
      } else {
        print('❌ Sync handler seek failed');
        if (mounted) {
          setState(() => _isBuffering = false);
        }
      }
    } catch (e) {
      print('❌ Player seek failed: $e');
      if (mounted) {
        setState(() => _isBuffering = false);
      }
    }
  }

  // ============================================================================
  // QUALITY CHANGE METHOD
  // ============================================================================

  Future<void> _changeQuality(String newQuality) async {
    if (!_isPlayerReady || _isInitializing) return;

    final currentPosition = _position;
    final wasPlaying = _isPlaying;

    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
        _isPlaying = false;
      });

      if (wasPlaying && _syncHandler != null) {
        await _syncHandler!.pause();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Update quality in persistent settings
      ref.read(ytdlpServicesProvider.notifier).setVideoQuality(newQuality);

      // Invalidate with both video ID and quality
      ref.invalidate(
        videoAndAudioStreamsProvider((widget.video.id, newQuality)),
      );

      // Get new stream info
      final streamInfo = await ref
          .read(
            videoAndAudioStreamsProvider((widget.video.id, newQuality)).future,
          )
          .timeout(const Duration(seconds: 15));

      if (streamInfo == null) {
        throw Exception('Could not load streams for new quality');
      }

      await _setupPlayerWithSyncHandler(streamInfo);

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isPlayerReady = true;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (_isPlayerReady &&
          currentPosition > Duration.zero &&
          _syncHandler != null) {
        await _syncHandler!.seekTo(currentPosition);
        if (wasPlaying) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _syncHandler!.play();
        }
      }

      print('✅ Quality changed successfully to $newQuality');
    } catch (e) {
      print('❌ Quality change failed: $e');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to change quality: ${e.toString()}';
        });
      }

      Timer(const Duration(seconds: 2), () {
        if (mounted) _initializePlayer();
      });
    }
  }

  // ============================================================================
  // CLEANUP METHODS
  // ============================================================================

  Future<void> _disposeControllers() async {
    print('🗑️ Disposing controllers');

    _controlsTimer?.cancel();
    _controlsTimer = null;

    // Dispose sync handler first - it will handle both video and audio
    if (_syncHandler != null) {
      await _syncHandler!.dispose();
      _syncHandler = null;
    }

    // Dispose video controller
    await _disposeVideoController();

    _isPlayerReady = false;
  }

  Future<void> _disposeVideoController() async {
    try {
      if (_podPlayerController != null) {
        _podPlayerController!.dispose();
        _podPlayerController = null;
        print('✅ Video controller disposed');
      }
    } catch (e) {
      print('❌ Video controller disposal failed: $e');
    }
  }

  // ============================================================================
  // LIFECYCLE METHODS
  // ============================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        print('🔄 App paused/inactive - pausing playback');
        _controlsTimer?.cancel();
        if (_isPlaying && _syncHandler != null) {
          _syncHandler!.pause();
        }
        break;

      case AppLifecycleState.resumed:
        print('🔄 App resumed');
        // Don't auto-resume, let user manually play
        break;

      default:
        break;
    }
  }

  @override
  void dispose() {
    print('🗑️ Disposing PlayerScreen');

    WidgetsBinding.instance.removeObserver(this);
    _relatedVideosSubscription?.cancel();
    _controlsTimer?.cancel();
    _disposeControllers();
    _scrollController.dispose();
    // AudioVideoSyncHandler.dispose();
    super.dispose();
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('timeout')) {
      return 'Video is taking too long to load. Please check your connection and try again.';
    } else if (errorString.contains('private video') ||
        errorString.contains('video unavailable')) {
      return 'This video is not available for playback.';
    } else if (errorString.contains('region') || errorString.contains('geo')) {
      return 'This video is not available in your region.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network connection error. Please check your internet and try again.';
    } else if (errorString.contains('not available for streaming')) {
      return 'Video streams are temporarily unavailable. Please try again later.';
    } else {
      return 'Unable to load video. Please try again or select a different quality.';
    }
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Video playback error',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _initializePlayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    // Try with different quality
                    ref
                        .read(ytdlpServicesProvider.notifier)
                        .setVideoQuality('Auto');
                    _initializePlayer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Auto Quality'),
                ),
              ],
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
      isScrollControlled: true, // Fix overflow
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit height
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentQuality = ref.read(ytdlpServicesProvider).videoQuality;
            final qualityOptions = ref.watch(videoQualityOptionsProvider);

            return Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: qualityOptions.length,
                      itemBuilder: (context, index) {
                        final quality = qualityOptions[index];
                        return ListTile(
                          title: Text(
                            quality,
                            style: TextStyle(
                              color: currentQuality == quality
                                  ? Colors.red
                                  : Colors.white,
                              fontWeight: currentQuality == quality
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                      },
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      // Going fullscreen
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Exiting fullscreen
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    // Show controls temporarily after orientation change
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showControlsTemporarily();
      }
    });
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
                const SizedBox(height: 16),
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      widget.video.viewCountString,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const Text(" • ", style: TextStyle(color: Colors.grey)),
                    Text(
                      widget.video.uploadDate != null
                          ? timeago.format(widget.video.uploadDate!)
                          : '',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontFamily: 'Montserrat',
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
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
        if (_isLoadingRelated)
          // Fixed: Use shrinkWrap and disable scrolling for LoadingShimmer
          LoadingShimmer(
            targetCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          )
        else if (_relatedVideosError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.grey, size: 48),
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
          )
        else if (_relatedVideos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No related videos available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._relatedVideos.map(
            (video) => VideoCard(
              video: video,
              showTrendingBadge: false,
              key: ValueKey('related_${video.id}'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(ytdlpServicesProvider.select((p) => p.videoQuality), (
      previous,
      next,
    ) {
      if (previous != next && mounted) {
        _changeQuality(next);
      }
    });

    if (_isFullscreen) {
      // Fullscreen mode - only show video player
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildYouTubeStylePlayer(),
      );
    }

    // Normal mode - show video + content
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Video Player Section
            _buildYouTubeStylePlayer(),

            // Bottom content
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
                    children: [
                      _buildVideoInfoSection(),
                      _buildRelatedVideos(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fixed PodVideoPlayer with correct overlay syntax
  Widget _buildYouTubeStylePlayer() {
    return Container(
      margin: _isFullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: _isFullscreen
            ? BorderRadius.zero
            : const BorderRadius.all(Radius.circular(12)),
        child: _isFullscreen
            ? SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: _buildVideoPlayerContent(),
              )
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: SizedBox(
                  width: double.infinity,
                  child: _buildVideoPlayerContent(),
                ),
              ),
      ),
    );
  }

  // 5. NEW: Extracted video player content with gesture detection
  Widget _buildVideoPlayerContent() {
    return GestureDetector(
      onVerticalDragEnd: _handleVerticalSwipe,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: _isInitializing
            ? _buildLoadingWidget()
            : _errorMessage != null
            ? _buildErrorWidget()
            : _podPlayerController != null &&
                  _podPlayerController!.isInitialised
            ? Stack(
                children: [
                  // Video player with proper fit
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _isFullscreen
                            ? MediaQuery.of(context).size.height * (16 / 9)
                            : MediaQuery.of(context).size.width,
                        height: _isFullscreen
                            ? MediaQuery.of(context).size.height
                            : MediaQuery.of(context).size.width * (9 / 16),
                        child: PodVideoPlayer(
                          controller: _podPlayerController!,
                          backgroundColor: Colors.black,
                          videoAspectRatio: 16 / 9,
                          alwaysShowProgressBar: false,
                          overlayBuilder: (overlayOptions) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),

                  // Custom Controls Overlay
                  _buildCustomControls(),

                  // Buffering indicator
                  if (_isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    ),
                ],
              )
            : _buildLoadingWidget(),
      ),
    );
  }

  void _handleVerticalSwipe(DragEndDetails details) {
    const double swipeThreshold = 100.0;

    if (details.primaryVelocity == null) return;

    final double velocity = details.primaryVelocity!;

    if (velocity.abs() > swipeThreshold) {
      if (velocity < 0 && !_isFullscreen) {
        // Swipe up - go fullscreen
        _toggleFullscreen();
      } else if (velocity > 0 && _isFullscreen) {
        // Swipe down - exit fullscreen
        _toggleFullscreen();
      }
    }
  }

  // Missing _formatDuration method
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  // Missing _buildControlButton method
  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // Fixed controls methods with mounted checks
  void _showControlsTemporarily() {
    if (!mounted) return;

    setState(() => _showControls = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;

    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _showControlsTemporarily();
    }
  }

  // Fixed custom controls with working button references
  Widget _buildCustomControls() {
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.translucent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Top controls bar (added this section)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Settings button moved here
                        _buildControlButton(
                          Icons.settings,
                          _showQualitySelector,
                        ),
                      ],
                    ),
                  ),
                ),

                // Center play/pause button
                Center(
                  child: GestureDetector(
                    onTap: _handlePlayPause,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),

                // Bottom controls bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar
                        Row(
                          children: [
                            // Current time - FIXED width and better formatting
                            SizedBox(
                              width: 45,
                              child: Text(
                                _formatDuration(_position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),

                            // Progress slider - FIXED calculation
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.red,
                                    inactiveTrackColor: Colors.white
                                        .withOpacity(0.3),
                                    thumbColor: Colors.red,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12,
                                    ),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value:
                                        _getSliderValue(), // Use helper method
                                    min: 0.0,
                                    max: _getSliderMax(), // Use helper method
                                    onChanged: (value) {
                                      if (mounted) {
                                        setState(() {
                                          _position = Duration(
                                            milliseconds: value.toInt(),
                                          );
                                        });
                                      }
                                    },
                                    onChangeEnd: (value) {
                                      final newPosition = Duration(
                                        milliseconds: value.toInt(),
                                      );
                                      _seekTo(newPosition);
                                    },
                                    onChangeStart: (_) {
                                      _showControlsTemporarily();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (_isBuffering)
                              Container(
                                color: Colors.black.withOpacity(0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                        strokeWidth: 2,
                                      ),
                                      if (_statusMessage.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          _statusMessage,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            // Total duration - FIXED width
                            SizedBox(
                              width: 45,
                              child: Text(
                                _formatDuration(_duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),

                        // Control buttons row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Skip back 10s
                                _buildControlButton(Icons.replay_10, () {
                                  final newPosition =
                                      _position - const Duration(seconds: 10);
                                  _seekTo(
                                    newPosition < Duration.zero
                                        ? Duration.zero
                                        : newPosition,
                                  );
                                }),
                                const SizedBox(width: 16),
                                // Skip forward 10s
                                _buildControlButton(Icons.forward_10, () {
                                  final newPosition =
                                      _position + const Duration(seconds: 10);
                                  _seekTo(
                                    newPosition > _duration
                                        ? _duration
                                        : newPosition,
                                  );
                                }),
                              ],
                            ),
                            Row(
                              children: [
                                // Quality selector (removed from here since we moved it to top)
                                // Fullscreen toggle
                                _buildControlButton(
                                  _isFullscreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  _toggleFullscreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getSliderValue() {
    if (_duration.inMilliseconds <= 0) return 0.0;

    final currentMs = _position.inMilliseconds.toDouble();
    final maxMs = _duration.inMilliseconds.toDouble();

    // Clamp to prevent slider errors
    return currentMs.clamp(0.0, maxMs);
  }

  double _getSliderMax() {
    return _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 100.0; // Fallback to prevent division by zero
  }
}
