import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recording_state.dart';
import 'audio_recorder_manager.dart';

/// Provider for the singleton [AudioRecorderManager] instance.
final audioRecorderManagerProvider = Provider<AudioRecorderManager>((ref) {
  final manager = AudioRecorderManager();
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});

/// StreamProvider exposing real-time [RecordingState] updates.
final recordingStateStreamProvider = StreamProvider<RecordingState>((ref) {
  final manager = ref.watch(audioRecorderManagerProvider);
  return manager.stateStream;
});

/// StreamProvider exposing real-time recording [Duration] updates.
final recordingDurationStreamProvider = StreamProvider<Duration>((ref) {
  final manager = ref.watch(audioRecorderManagerProvider);
  return manager.durationStream;
});
