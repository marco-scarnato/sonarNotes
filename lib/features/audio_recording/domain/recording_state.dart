/// Represents the state of the audio recorder hardware engine.
enum RecordingState {
  /// Recorder is inactive and ready.
  idle,

  /// Recorder is actively capturing microphone input.
  recording,

  /// Recorder is currently paused by the user.
  paused,

  /// Recording has stopped and is finalizing output.
  stopped,
}
