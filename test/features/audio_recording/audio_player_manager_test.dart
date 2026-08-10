import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sonar_notes/features/audio_recording/data/audio_player_manager.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(const Duration());
    registerFallbackValue(AssetSource('test.wav'));
  });

  group('AudioPlayerManager Tests', () {
    late MockAudioPlayer mockPlayer;
    late AudioPlayerManager manager;

    setUp(() {
      mockPlayer = MockAudioPlayer();
      when(() => mockPlayer.onPlayerStateChanged)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.onPositionChanged)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.onDurationChanged)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.setPlaybackRate(any())).thenAnswer((_) async {});
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      manager = AudioPlayerManager(player: mockPlayer);
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('initial values are correctly set', () {
      expect(manager.speed, equals(1.0));
      expect(manager.currentAudioPath, isNull);
      expect(manager.position, equals(Duration.zero));
      expect(manager.duration, equals(Duration.zero));
    });

    test('setSpeed updates speed and notifies stream', () async {
      await manager.setSpeed(1.5);
      expect(manager.speed, equals(1.5));

      await manager.setSpeed(2.0);
      expect(manager.speed, equals(2.0));

      expect(() => manager.setSpeed(3.0), throwsArgumentError);
    });

    test('cycleSpeed cycles 1.0 -> 1.5 -> 2.0 -> 1.0', () async {
      when(() => mockPlayer.setPlaybackRate(any())).thenAnswer((_) async {});

      expect(manager.speed, equals(1.0));

      final speed1 = await manager.cycleSpeed();
      expect(speed1, equals(1.5));
      expect(manager.speed, equals(1.5));

      final speed2 = await manager.cycleSpeed();
      expect(speed2, equals(2.0));
      expect(manager.speed, equals(2.0));

      final speed3 = await manager.cycleSpeed();
      expect(speed3, equals(1.0));
      expect(manager.speed, equals(1.0));
    });

    test('pause, resume, stop, and seek call underlying AudioPlayer methods', () async {
      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.resume()).thenAnswer((_) async {});
      when(() => mockPlayer.stop()).thenAnswer((_) async {});
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

      await manager.pause();
      verify(() => mockPlayer.pause()).called(1);

      await manager.resume();
      verify(() => mockPlayer.resume()).called(1);

      await manager.seek(const Duration(seconds: 10));
      verify(() => mockPlayer.seek(const Duration(seconds: 10))).called(1);
      expect(manager.position, equals(const Duration(seconds: 10)));

      await manager.stop();
      verify(() => mockPlayer.stop()).called(1);
      expect(manager.currentAudioPath, isNull);
      expect(manager.position, equals(Duration.zero));
    });
  });
}
