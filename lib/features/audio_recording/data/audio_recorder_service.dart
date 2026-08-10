import 'package:record/record.dart';

/// Service that wraps the [AudioRecorder] plugin with a fixed
/// WAV PCM 16 kHz / Mono / 16-bit configuration.
///
/// This is the core artefact of SPIKE-1: it proves that the `record`
/// plugin can produce a valid .wav file natively, with no intermediate
/// compressed format and no post-processing.
class AudioRecorderService {
  AudioRecorderService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  /// Fixed recording configuration — WAV 16 kHz mono.
  static const RecordConfig wavConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  // ---------------------------------------------------------------------------
  // Capabilities
  // ---------------------------------------------------------------------------

  /// Returns `true` if the user has granted microphone permission.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Returns `true` if the current platform supports [AudioEncoder.wav].
  Future<bool> isEncoderSupported() =>
      _recorder.isEncoderSupported(AudioEncoder.wav);

  // ---------------------------------------------------------------------------
  // Recording lifecycle
  // ---------------------------------------------------------------------------

  /// Starts recording to [filePath].
  ///
  /// The caller is responsible for providing a valid path with a `.wav`
  /// extension (e.g. obtained via `path_provider`).
  Future<void> start(String filePath) =>
      _recorder.start(wavConfig, path: filePath);

  /// Stops the current recording and returns the output file path,
  /// or `null` if nothing was being recorded.
  Future<String?> stop() => _recorder.stop();

  /// Whether a recording session is currently active.
  Future<bool> isRecording() => _recorder.isRecording();

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Releases native resources held by the recorder.
  Future<void> dispose() => _recorder.dispose();
}
