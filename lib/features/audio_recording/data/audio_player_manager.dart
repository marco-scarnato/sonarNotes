import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service managing audio playback of saved WAV files.
///
/// Features:
/// - Smooth playback of local WAV files.
/// - Dynamic playback speed control (1.0x, 1.5x, 2.0x).
/// - Precise timeline scrubbing (seeking).
/// - Native audio focus and system call interruption handling.
class AudioPlayerManager {
  AudioPlayerManager({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _initAudioContext();
    _listenToStreams();
  }

  final AudioPlayer _player;

  /// Supported playback speeds.
  static const List<double> supportedSpeeds = [1.0, 1.5, 2.0];

  String? _currentAudioPath;
  double _speed = 1.0;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  final StreamController<double> _speedController =
      StreamController<double>.broadcast();

  // ---------------------------------------------------------------------------
  // Getters & Streams
  // ---------------------------------------------------------------------------

  String? get currentAudioPath => _currentAudioPath;
  double get speed => _speed;
  PlayerState get state => _state;
  Duration get position => _position;
  Duration get duration => _duration;

  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<double> get speedStream => _speedController.stream;

  // ---------------------------------------------------------------------------
  // Initialization & Audio Focus Context
  // ---------------------------------------------------------------------------

  void _initAudioContext() {
    if (!kIsWeb) {
      unawaited(
        AudioPlayer.global.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gain,
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.speech,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
        )).catchError((e) {
          // Platform channel not available in unit test environment
          debugPrint('AudioContext init skipped: $e');
        }),
      );
    }
  }

  void _listenToStreams() {
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      _state = s;
      if (s == PlayerState.completed || s == PlayerState.stopped) {
        _position = Duration.zero;
      }
    });

    _positionSub = _player.onPositionChanged.listen((p) {
      _position = p;
    });

    _durationSub = _player.onDurationChanged.listen((d) {
      _duration = d;
    });
  }

  // ---------------------------------------------------------------------------
  // Playback Control Methods
  // ---------------------------------------------------------------------------

  /// Plays the audio file at [filePath].
  Future<void> play(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File audio non trovato su disco: $filePath');
    }

    if (_currentAudioPath != filePath) {
      await _player.stop();
      _currentAudioPath = filePath;
    }

    await _player.setPlaybackRate(_speed);
    await _player.play(DeviceFileSource(filePath));
  }

  /// Pauses active playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resumes paused playback.
  Future<void> resume() async {
    await _player.resume();
  }

  /// Stops playback and resets position to zero.
  Future<void> stop() async {
    await _player.stop();
    _currentAudioPath = null;
    _position = Duration.zero;
  }

  /// Seeks to a specific [targetPosition] in the track.
  Future<void> seek(Duration targetPosition) async {
    await _player.seek(targetPosition);
    _position = targetPosition;
  }

  /// Sets the playback speed (1.0x, 1.5x, 2.0x).
  Future<void> setSpeed(double targetSpeed) async {
    if (!supportedSpeeds.contains(targetSpeed)) {
      throw ArgumentError('Velocità non supportata: $targetSpeed');
    }
    _speed = targetSpeed;
    await _player.setPlaybackRate(_speed);
    if (!_speedController.isClosed) {
      _speedController.add(_speed);
    }
  }

  /// Cycles through supported speeds (1.0x -> 1.5x -> 2.0x -> 1.0x).
  Future<double> cycleSpeed() async {
    final currentIndex = supportedSpeeds.indexOf(_speed);
    final nextIndex = (currentIndex + 1) % supportedSpeeds.length;
    final nextSpeed = supportedSpeeds[nextIndex];
    await setSpeed(nextSpeed);
    return nextSpeed;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _speedController.close();
    await _player.dispose();
  }
}
