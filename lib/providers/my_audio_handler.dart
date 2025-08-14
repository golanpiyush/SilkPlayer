import 'dart:async';
import 'dart:developer' as developer;
import 'package:just_audio/just_audio.dart';
import 'package:pod_player/pod_player.dart';

class AudioVideoSyncHandler {
  PodPlayerController? _videoController;
  AudioPlayer? _audioPlayer;

  // State management
  bool _hasAudioStream = false;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isManualOperation = false;
  bool _isDisposed = false;
  bool _videoPreloaded = false;
  bool _audioReady = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Timers and subscriptions
  Timer? _syncTimer;
  Timer? _stateDebounceTimer;
  StreamSubscription<PlayerState>? _audioSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  Timer? _positionUpdateTimer;
  Timer? _durationUpdateTimer;
  Timer? _syncMonitoringTimer;

  bool _mediaCodecStable = false;
  bool _syncHandlerReady = false;
  Timer? _mediaCodecStabilityTimer;
  void Function(String status)? onStatusUpdate;

  // Callbacks
  void Function(bool isPlaying)? onPlayingStateChanged;
  void Function(Duration position)? onPositionChanged;
  void Function(Duration duration)? onDurationChanged;
  void Function(String error)? onError;
  void Function(bool isBuffering)? onBufferingChanged;

  AudioVideoSyncHandler({
    this.onPlayingStateChanged,
    this.onPositionChanged,
    this.onDurationChanged,
    this.onError,
    this.onBufferingChanged,
    required Null Function(dynamic status) onStatusUpdate,
  });

  // FIXED: Sequential initialization to prevent race conditions
  Future<bool> initialize({
    required String videoUrl,
    String? audioUrl,
    required PodPlayerController videoController,
  }) async {
    try {
      await dispose();

      _videoController = videoController;
      _isDisposed = false;
      _videoPreloaded = false;
      _audioReady = false;

      developer.log('🎬 Initializing AudioVideoSyncHandler - SEQUENTIAL MODE');
      developer.log('🎥 Video URL: ${videoUrl.substring(0, 50)}...');

      // Check URL similarity
      final isSameUrl =
          audioUrl != null &&
          audioUrl.isNotEmpty &&
          (_extractBaseUrl(videoUrl) == _extractBaseUrl(audioUrl) ||
              videoUrl == audioUrl);

      if (isSameUrl) {
        developer.log('⚠️ Same URL detected - using video-only mode');
        _hasAudioStream = false;
      } else {
        _hasAudioStream = audioUrl != null && audioUrl.isNotEmpty;
      }

      // PHASE 1: Initialize and preload video FIRST (priority for MediaCodec)
      await _initializeAndPreloadVideo();

      // PHASE 2: Initialize audio AFTER video is stable
      if (_hasAudioStream) {
        developer.log('🎵 Audio URL: ${audioUrl!.substring(0, 50)}...');
        await _initializeAudioPlayer(audioUrl);
      } else {
        developer.log('🎵 Using video audio only');
      }

      // PHASE 3: Setup position tracking
      _setupPositionTracking();

      _isInitialized = true;
      developer.log('✅ AudioVideoSyncHandler initialized - SEQUENTIAL MODE');
      return true;
    } catch (e) {
      developer.log('❌ Initialize failed: $e');
      onError?.call('Initialize failed: $e');
      return false;
    }
  }

  // NEW: Dedicated video preloading to solve MediaCodec timing issues
  Future<void> _initializeAndPreloadVideo() async {
    if (_videoController == null) return;

    developer.log('🎥 Phase 1: ENHANCED MediaCodec stability detection...');
    onBufferingChanged?.call(true);

    // Step 1: Wait for basic initialization
    int attempts = 0;
    while (!_videoController!.isInitialised && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!_videoController!.isInitialised) {
      throw Exception('Video controller failed to initialize');
    }

    // Step 2: Configure for optimal buffering
    if (_hasAudioStream) {
      await _videoController!.mute();
    } else {
      await _videoController!.unMute();
    }

    // Step 3: ENHANCED MediaCodec stability check
    await _ensureMediaCodecStability();

    // Step 4: Final verification
    await _verifyVideoReadiness();

    _videoPreloaded = true;
    _mediaCodecStable = true;
    onBufferingChanged?.call(false);
  }

  // ADD this new method for MediaCodec stability:
  Future<void> _ensureMediaCodecStability() async {
    developer.log('🔧 Enhanced MediaCodec stability check...');

    // Start playback to trigger buffer filling
    _videoController!.play();

    bool isStable = false;
    int stabilityChecks = 0;
    int consecutiveGoodFrames = 0;
    const requiredStableFrames = 3;
    const maxChecks = 60; // 12 seconds max

    while (!isStable && stabilityChecks < maxChecks) {
      await Future.delayed(const Duration(milliseconds: 200));
      stabilityChecks++;

      if (_videoController!.isVideoPlaying) {
        final currentPos = _videoController!.currentVideoPosition;

        // Check if we're getting consistent frame progression
        if (currentPos > const Duration(milliseconds: 100)) {
          consecutiveGoodFrames++;

          if (consecutiveGoodFrames >= requiredStableFrames) {
            // Additional stability verification
            await Future.delayed(const Duration(milliseconds: 500));

            if (_videoController!.isVideoPlaying &&
                _videoController!.currentVideoPosition > currentPos) {
              isStable = true;
              developer.log(
                '✅ MediaCodec stable after ${stabilityChecks * 200}ms',
              );
            }
          }
        } else {
          consecutiveGoodFrames = 0; // Reset counter
        }
      }

      // Progress feedback
      if (stabilityChecks % 10 == 0) {
        developer.log(
          '🔧 Stability check ${stabilityChecks}/60 - Frames: $consecutiveGoodFrames',
        );
      }
    }

    // Stop after stability check
    _videoController!.pause();
    await _videoController!.videoSeekTo(Duration.zero);

    if (!isStable) {
      developer.log('⚠️ MediaCodec stability timeout - may have issues');
    }
  }

  // ADD this new verification method:
  Future<void> _verifyVideoReadiness() async {
    developer.log('🔍 Final video readiness verification...');

    // Test seek capability
    await _videoController!.videoSeekTo(const Duration(seconds: 1));
    await Future.delayed(const Duration(milliseconds: 300));
    await _videoController!.videoSeekTo(Duration.zero);
    await Future.delayed(const Duration(milliseconds: 300));

    // Verify duration is available
    _duration = _videoController!.totalVideoLength;
    if (_duration > Duration.zero) {
      onDurationChanged?.call(_duration);
      developer.log('✅ Video ready - Duration: ${_duration.inSeconds}s');
    } else {
      developer.log('⚠️ Video duration not available');
    }
  }

  // ENHANCED: More robust audio initialization
  Future<void> _initializeAudioPlayer(String audioUrl) async {
    try {
      developer.log('🎵 Phase 3: Initializing audio (video already stable)...');

      // Clean up any existing player
      await _cleanupAudioPlayer();

      // Create new player
      _audioPlayer = AudioPlayer();

      // Configure audio session
      try {
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.setLoopMode(LoopMode.off);
      } catch (e) {
        developer.log('⚠️ Audio config warning: $e');
      }

      // Setup listeners with state preservation
      _setupAudioListeners();

      // Load URL with retry logic
      await _loadAudioUrlWithRetry(audioUrl);

      // Mark audio as ready
      _audioReady = true;
      developer.log('✅ Audio initialized and ready');
    } catch (e) {
      developer.log('❌ Audio init failed: $e');
      _audioReady = false;
      await _cleanupAudioPlayer();
      rethrow;
    }
  }

  // NEW: Separate audio listeners setup for better error handling
  void _setupAudioListeners() {
    _audioSubscription = _audioPlayer!.playerStateStream.listen(
      (state) {
        if (_isDisposed || _isManualOperation) return;

        developer.log(
          '🎵 Audio state: ${state.playing} (${state.processingState})',
        );

        // Handle buffering states
        if (state.processingState == ProcessingState.buffering) {
          onBufferingChanged?.call(true);
        } else if (state.processingState == ProcessingState.ready) {
          onBufferingChanged?.call(false);
        }

        // Handle completed state
        if (state.processingState == ProcessingState.completed) {
          developer.log('🎵 Audio completed');
          _handleAudioCompletion();
        }
      },
      onError: (error) {
        if (_isDisposed) return;
        developer.log('❌ Audio stream error: $error');
        _recoverFromAudioError(error.toString());
      },
    );

    _audioDurationSubscription = _audioPlayer!.durationStream.listen((
      duration,
    ) {
      if (_isDisposed || duration == null || duration == Duration.zero) return;

      if (duration != _duration) {
        _duration = duration;
        onDurationChanged?.call(duration);
        developer.log('🎵 Audio duration updated: ${duration.inSeconds}s');
      }
    });

    _audioPositionSubscription = _audioPlayer!.positionStream.listen((
      position,
    ) {
      if (_isDisposed) return;
      if (position != _position) {
        _position = position;
        onPositionChanged?.call(position);
      }
    });
  }

  // NEW: Robust URL loading with proper retry
  Future<void> _loadAudioUrlWithRetry(String audioUrl) async {
    int retryCount = 0;
    bool urlLoaded = false;

    while (!urlLoaded && retryCount < 3) {
      try {
        developer.log('🎵 Loading audio URL (attempt ${retryCount + 1})...');
        await _audioPlayer!.setUrl(audioUrl);

        // Wait for audio to be ready
        int readyAttempts = 0;
        while (_audioPlayer!.duration == null && readyAttempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          readyAttempts++;
        }

        urlLoaded = true;
        developer.log('✅ Audio URL loaded successfully');
      } catch (e) {
        retryCount++;
        developer.log('⚠️ Audio URL load attempt $retryCount failed: $e');

        if (retryCount < 3) {
          // Progressive delay
          await Future.delayed(Duration(milliseconds: 500 * retryCount));

          // Cleanup and recreate player for next attempt
          await _cleanupAudioPlayer();
          _audioPlayer = AudioPlayer();
          _setupAudioListeners();
        } else {
          throw Exception('Failed to load audio after 3 attempts: $e');
        }
      }
    }
  }

  // ENHANCED: Position tracking with better state management
  void _setupPositionTracking() {
    if (_videoController == null || _isDisposed) return;

    _position = _videoController!.currentVideoPosition;

    // Initial callbacks
    onPositionChanged?.call(_position);
    if (_duration > Duration.zero) {
      onDurationChanged?.call(_duration);
    }

    // Setup position tracking based on audio availability
    if (!_hasAudioStream) {
      _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
      ) {
        if (_isDisposed || _videoController == null) {
          timer.cancel();
          return;
        }
        final newPosition = _videoController!.currentVideoPosition;
        if (newPosition != _position) {
          _position = newPosition;
          onPositionChanged?.call(_position);
        }
      });
    }

    // Duration monitoring
    _durationUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isDisposed || _videoController == null) {
        timer.cancel();
        return;
      }
      final newDuration = _videoController!.totalVideoLength;
      if (newDuration != _duration && newDuration > Duration.zero) {
        _duration = newDuration;
        onDurationChanged?.call(_duration);
      }
    });
  }

  // COMPLETELY REWRITTEN: Sequential play with proper resource management
  Future<bool> play() async {
    if (!_isInitialized || _videoController == null || _isDisposed)
      return false;

    _isManualOperation = true;

    try {
      developer.log('▶️ VIDEO-FIRST PLAY: Starting video master approach');
      onBufferingChanged?.call(true);

      // STAGE 1: Video First - Get it 100% stable
      bool videoSuccess = await _startVideoMaster();
      if (!videoSuccess) {
        developer.log('❌ Video master failed');
        onBufferingChanged?.call(false);
        return false;
      }

      // STAGE 2: Audio Slave - Follow video state
      if (_hasAudioStream && _audioReady) {
        await _startAudioSlave();
      }

      // STAGE 3: Simple monitoring (no aggressive corrections)
      _startGentleMonitoring();

      _isPlaying = true;
      onPlayingStateChanged?.call(true);
      onBufferingChanged?.call(false);

      developer.log('✅ Video-first play completed successfully');
      return true;
    } catch (e) {
      developer.log('❌ Video-first play failed: $e');
      onError?.call('Play failed: $e');
      onBufferingChanged?.call(false);
      return false;
    } finally {
      _isManualOperation = false;
    }
  }

  void _startGentleMonitoring() {
    _syncMonitoringTimer?.cancel();

    if (!_hasAudioStream || _isDisposed) return;

    developer.log('🔍 Starting gentle sync monitoring (non-aggressive)');

    _syncMonitoringTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (_isDisposed || !_isPlaying) {
        timer.cancel();
        return;
      }

      try {
        if (_videoController != null && _audioPlayer != null) {
          final videoPos = _videoController!.currentVideoPosition;
          final audioPos = _audioPlayer!.position;
          final diff = (videoPos - audioPos).abs();

          // Only correct MAJOR drift (>2 seconds)
          if (diff > const Duration(seconds: 2)) {
            developer.log(
              '🔧 Major drift detected: ${diff.inSeconds}s - gentle correction',
            );

            // Simple correction: just sync audio to video (video is master)
            await _audioPlayer!.seek(videoPos);
          }

          // Log sync status every 30 seconds (reduce spam)
          if (timer.tick % 10 == 0) {
            developer.log(
              '📊 Sync status - V: ${videoPos.inSeconds}s, A: ${audioPos.inSeconds}s, Δ: ${diff.inMilliseconds}ms',
            );
          }
        }
      } catch (e) {
        developer.log('⚠️ Gentle monitoring error: $e');
      }
    });
  }

  // 2. ADD these new simple methods:
  Future<bool> _startVideoMaster() async {
    developer.log('🎥 Starting enhanced video master...');

    if (!_mediaCodecStable) {
      developer.log(
        '⚠️ MediaCodec not stable, performing quick stability check...',
      );
      await _ensureMediaCodecStability();
    }

    // Ensure proper audio state
    if (_hasAudioStream) {
      await _videoController!.mute();
    } else {
      await _videoController!.unMute();
    }

    // Start video with enhanced monitoring
    _videoController!.play();

    // Enhanced readiness verification
    bool videoReady = await _waitForVideoMasterReadiness();

    if (videoReady) {
      developer.log('✅ Enhanced video master ready');
      return true;
    } else {
      developer.log('❌ Enhanced video master failed');
      return false;
    }
  }

  // ADD this new method for better video master readiness:
  Future<bool> _waitForVideoMasterReadiness() async {
    int attempts = 0;
    const maxAttempts = 30; // 6 seconds max

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;

      if (_videoController!.isVideoPlaying) {
        final currentPos = _videoController!.currentVideoPosition;

        // Enhanced readiness check - ensure actual playback progress
        if (currentPos > const Duration(milliseconds: 300) || attempts > 15) {
          // Additional stability verification
          await Future.delayed(const Duration(milliseconds: 400));

          // Final check - ensure video is still playing and progressing
          if (_videoController!.isVideoPlaying) {
            final newPos = _videoController!.currentVideoPosition;
            if (newPos >= currentPos) {
              // Allow for same position due to timing
              return true;
            }
          }
        }
      }

      if (attempts % 5 == 0) {
        developer.log('🎥 Video master check ${attempts}/30...');
      }
    }

    return false;
  }

  // ADD this method to your class for status updates:
  void _updateStatus(String status) {
    developer.log(status);
    onStatusUpdate?.call(status);
  }

  Future<void> _startAudioSlave() async {
    if (!_hasAudioStream || _audioPlayer == null) return;

    developer.log('🎵 Starting audio slave (follows video)');

    try {
      // Get current video position for sync
      final videoPos = _videoController!.currentVideoPosition;

      // Sync audio to video position (video is master)
      if ((videoPos - _audioPlayer!.position).abs() >
          const Duration(milliseconds: 500)) {
        await _audioPlayer!.seek(videoPos);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Start audio
      await _audioPlayer!.play();

      // Brief verification (don't block on audio issues)
      await Future.delayed(const Duration(milliseconds: 300));

      if (_audioPlayer!.playing) {
        developer.log('✅ Audio slave started successfully');
      } else {
        developer.log('⚠️ Audio slave failed - continuing with video only');
        await _videoController!.unMute();
        _hasAudioStream = false;
      }
    } catch (e) {
      developer.log('⚠️ Audio slave error: $e - falling back to video audio');
      await _videoController!.unMute();
      _hasAudioStream = false;
    }
  }

  Future<bool> pause() async {
    if (!_isInitialized || _videoController == null || _isDisposed)
      return false;

    _isManualOperation = true;

    try {
      developer.log('⏸️ VIDEO-FIRST PAUSE: Pausing video master first');

      // Stop monitoring immediately
      _syncMonitoringTimer?.cancel();

      // STAGE 1: Pause video first (master)
      _videoController!.pause();
      await Future.delayed(const Duration(milliseconds: 100));

      // STAGE 2: Pause audio (slave)
      if (_hasAudioStream && _audioPlayer != null) {
        await _audioPlayer!.pause();
      }

      // Update state
      _position = _videoController!.currentVideoPosition;
      _isPlaying = false;
      onPlayingStateChanged?.call(false);

      developer.log(
        '✅ Video-first pause completed - Position: ${_position.inSeconds}s',
      );
      return true;
    } catch (e) {
      developer.log('❌ Video-first pause failed: $e');
      return false;
    } finally {
      _isManualOperation = false;
    }
  }

  // ENHANCED: Better seek with proper sync
  Future<bool> seekTo(Duration position) async {
    if (!_isInitialized || _videoController == null || _isDisposed)
      return false;

    _isManualOperation = true;

    try {
      developer.log('🔍 VIDEO-FIRST SEEK to ${position.inSeconds}s');

      final wasPlaying = _isPlaying;
      _syncMonitoringTimer?.cancel();
      onBufferingChanged?.call(true);

      // STAGE 1: Pause everything first
      if (_hasAudioStream && _audioPlayer != null) {
        await _audioPlayer!.pause();
      }
      _videoController!.pause();
      await Future.delayed(const Duration(milliseconds: 200));

      // STAGE 2: Seek video first (master)
      await _videoController!.videoSeekTo(position);
      await Future.delayed(const Duration(milliseconds: 400));

      // STAGE 3: Seek audio to match video (slave)
      if (_hasAudioStream && _audioPlayer != null) {
        await _audioPlayer!.seek(position);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Update position
      _position = position;
      onPositionChanged?.call(position);

      // STAGE 4: Resume if was playing (using our video-first approach)
      if (wasPlaying) {
        _isPlaying = false; // Reset state
        final playResult = await play();
        onBufferingChanged?.call(false);
        return playResult;
      }

      onBufferingChanged?.call(false);
      developer.log('✅ Video-first seek completed');
      return true;
    } catch (e) {
      developer.log('❌ Video-first seek failed: $e');
      onBufferingChanged?.call(false);
      return false;
    } finally {
      _isManualOperation = false;
    }
  }

  // NEW: Handle audio completion
  void _handleAudioCompletion() {
    if (_isDisposed) return;

    developer.log('🎵 Audio completed - stopping video');
    _videoController?.pause();
    _isPlaying = false;
    onPlayingStateChanged?.call(false);
  }

  // Helper methods (keeping existing logic)
  String _extractBaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final queryParams = Map<String, String>.from(uri.queryParameters);

      queryParams.removeWhere(
        (key, value) =>
            key == 'itag' ||
            key == 'mime' ||
            key == 'signature' ||
            key == 'sig' ||
            key.startsWith('ratebypass'),
      );

      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: path,
        queryParameters: queryParams,
      ).toString();
    } catch (e) {
      return url;
    }
  }

  Future<void> _cleanupAudioPlayer() async {
    try {
      await _audioSubscription?.cancel();
      await _audioDurationSubscription?.cancel();
      await _audioPositionSubscription?.cancel();

      _audioSubscription = null;
      _audioDurationSubscription = null;
      _audioPositionSubscription = null;

      if (_audioPlayer != null) {
        try {
          if (_audioPlayer!.playing) {
            await _audioPlayer!.stop();
          }
          await _audioPlayer!.dispose();
        } catch (e) {
          developer.log('⚠️ Audio cleanup warning: $e');
        }
        _audioPlayer = null;
      }

      _audioReady = false;
      developer.log('🧹 Audio player cleaned up');
    } catch (e) {
      developer.log('⚠️ Audio cleanup error: $e');
    }
  }

  Future<void> _recoverFromAudioError(String error) async {
    developer.log('🔄 Attempting audio recovery from: $error');
    // Keep existing recovery logic but add state checks
    try {
      if (_audioPlayer != null && !_isDisposed) {
        await _audioPlayer!.stop();
        await Future.delayed(const Duration(milliseconds: 300));

        if (_isPlaying) {
          await _audioPlayer!.seek(_position);
          await _audioPlayer!.play();
        }
      }
    } catch (e) {
      developer.log('❌ Audio recovery failed: $e');
      onError?.call('Audio recovery failed: $e');
    }
  }

  // Getters (enhanced with better state checking)
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
  bool get hasAudioStream => _hasAudioStream && _audioReady;

  Duration get position {
    if (_hasAudioStream && _audioPlayer != null && _audioReady) {
      return _audioPlayer!.position;
    }
    return _videoController?.currentVideoPosition ?? Duration.zero;
  }

  Duration get duration {
    if (_hasAudioStream && _audioPlayer != null && _audioReady) {
      return _audioPlayer!.duration ?? Duration.zero;
    }
    return _videoController?.totalVideoLength ?? Duration.zero;
  }

  // ENHANCED: Complete disposal with better cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    developer.log('🗑️ Enhanced disposal starting...');
    _isDisposed = true;
    _isManualOperation = true;

    // Cancel all timers including new ones
    _positionUpdateTimer?.cancel();
    _durationUpdateTimer?.cancel();
    _syncMonitoringTimer?.cancel();
    _syncTimer?.cancel();
    _stateDebounceTimer?.cancel();
    _mediaCodecStabilityTimer?.cancel(); // NEW

    try {
      // Enhanced cleanup
      await _cleanupAudioPlayer();

      // Reset enhanced state
      _videoController = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isInitialized = false;
      _isPlaying = false;
      _hasAudioStream = false;
      _videoPreloaded = false;
      _audioReady = false;
      _mediaCodecStable = false; // NEW
      _syncHandlerReady = false; // NEW

      developer.log('✅ Enhanced disposal completed');
    } catch (e) {
      developer.log('❌ Enhanced disposal error: $e');
    }
  }
}
