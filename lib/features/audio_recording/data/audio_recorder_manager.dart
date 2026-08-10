import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../domain/recording_state.dart';

/// Service managing microphone hardware access, system permission checks,
/// and recording lifecycle (Start, Pause, Resume, Stop).
///
/// Records uncompressed PCM 16 kHz Mono 16-bit WAV files natively.
class AudioRecorderManager {
  AudioRecorderManager({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// Target recording configuration — WAV 16 kHz Mono 16-bit.
  static const RecordConfig wavConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  RecordingState _state = RecordingState.idle;
  Duration _elapsedDuration = Duration.zero;
  Timer? _timer;
  String? _currentFilePath;

  final StreamController<RecordingState> _stateController =
      StreamController<RecordingState>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  // ---------------------------------------------------------------------------
  // Getters & Streams
  // ---------------------------------------------------------------------------

  RecordingState get state => _state;
  Duration get elapsedDuration => _elapsedDuration;
  String? get currentFilePath => _currentFilePath;

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Checks if microphone permission is granted.
  /// Requests permission automatically if missing.
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  // ---------------------------------------------------------------------------
  // Recording Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts recording to [customPath] or generates a new `.wav` file
  /// in the application documents directory.
  Future<String> startRecording({String? customPath}) async {
    final granted = await hasPermission();
    if (!granted) {
      throw Exception('Microphone permission not granted.');
    }

    final targetPath = customPath ?? await _generateAudioFilePath();
    _currentFilePath = targetPath;

    await _recorder.start(wavConfig, path: targetPath);

    _elapsedDuration = Duration.zero;
    _startTimer();
    _updateState(RecordingState.recording);

    return targetPath;
  }

  /// Pauses the active recording session.
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) return;
    await _recorder.pause();
    _stopTimer();
    _updateState(RecordingState.paused);
  }

  /// Resumes a paused recording session.
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) return;
    await _recorder.resume();
    _startTimer();
    _updateState(RecordingState.recording);
  }

  /// Stops the active recording session and returns the saved `.wav` file path.
  Future<String?> stopRecording() async {
    if (_state == RecordingState.idle) return null;

    _stopTimer();
    final savedPath = await _recorder.stop();
    _updateState(RecordingState.stopped);

    final finalPath = savedPath ?? _currentFilePath;
    _currentFilePath = null;
    _updateState(RecordingState.idle);

    return finalPath;
  }

  /// Cancels recording and deletes the temporary audio file if created.
  Future<void> cancelRecording() async {
    _stopTimer();
    final path = await _recorder.stop();
    _updateState(RecordingState.idle);

    final fileToDelete = path ?? _currentFilePath;
    if (fileToDelete != null) {
      final file = File(fileToDelete);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _currentFilePath = null;
    _elapsedDuration = Duration.zero;
    _durationController.add(Duration.zero);
  }

  /// Exposes live audio byte stream for real-time buffer processing (Phase 2.5).
  Future<Stream<Uint8List>> startAudioStream() async {
    final granted = await hasPermission();
    if (!granted) {
      throw Exception('Microphone permission not granted.');
    }
    return _recorder.startStream(wavConfig);
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  Future<String> _generateAudioFilePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docsDir.path, 'recordings'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(audioDir.path, 'note_$timestamp.wav');
  }

  void _updateState(RecordingState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedDuration += const Duration(seconds: 1);
      if (!_durationController.isClosed) {
        _durationController.add(_elapsedDuration);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Releases resources.
  Future<void> dispose() async {
    _stopTimer();
    await _stateController.close();
    await _durationController.close();
    await _recorder.dispose();
  }
}
