import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_player_manager.dart';

/// Provider for the singleton [AudioPlayerManager] instance.
final audioPlayerManagerProvider = Provider<AudioPlayerManager>((ref) {
  final manager = AudioPlayerManager();
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});

/// Provider holding the ID of the note currently being played.
final activePlayingNoteIdProvider = StateProvider<String?>((ref) => null);

/// StreamProvider for real-time [PlayerState] updates.
final playerStateStreamProvider = StreamProvider<PlayerState>((ref) {
  final manager = ref.watch(audioPlayerManagerProvider);
  return manager.playerStateStream;
});

/// StreamProvider for real-time position updates.
final playerPositionStreamProvider = StreamProvider<Duration>((ref) {
  final manager = ref.watch(audioPlayerManagerProvider);
  return manager.positionStream;
});

/// StreamProvider for track total duration updates.
final playerDurationStreamProvider = StreamProvider<Duration>((ref) {
  final manager = ref.watch(audioPlayerManagerProvider);
  return manager.durationStream;
});

/// StreamProvider for playback speed updates.
final playerSpeedStreamProvider = StreamProvider<double>((ref) {
  final manager = ref.watch(audioPlayerManagerProvider);
  return manager.speedStream;
});
