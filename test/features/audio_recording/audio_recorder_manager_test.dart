import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:sonar_notes/features/audio_recording/data/audio_recorder_manager.dart';
import 'package:sonar_notes/features/audio_recording/domain/recording_state.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  setUpAll(() {
    registerFallbackValue(const RecordConfig());
  });

  group('AudioRecorderManager Tests', () {
    late MockAudioRecorder mockRecorder;
    late AudioRecorderManager manager;

    setUp(() {
      mockRecorder = MockAudioRecorder();
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      manager = AudioRecorderManager(recorder: mockRecorder);
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('initial state is RecordingState.idle', () {
      expect(manager.state, equals(RecordingState.idle));
      expect(manager.elapsedDuration, equals(Duration.zero));
      expect(manager.currentFilePath, isNull);
    });

    test('hasPermission proxies to AudioRecorder.hasPermission', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);

      final hasPermission = await manager.hasPermission();

      expect(hasPermission, isTrue);
      verify(() => mockRecorder.hasPermission()).called(1);
    });

    test('startRecording transitions state to recording when permission granted', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});

      final path = await manager.startRecording(customPath: '/tmp/test.wav');

      expect(path, equals('/tmp/test.wav'));
      expect(manager.state, equals(RecordingState.recording));
      expect(manager.currentFilePath, equals('/tmp/test.wav'));
      verify(() => mockRecorder.start(any(), path: '/tmp/test.wav')).called(1);
    });

    test('startRecording throws exception when permission denied', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

      expect(
        () => manager.startRecording(customPath: '/tmp/test.wav'),
        throwsA(isA<Exception>()),
      );

      expect(manager.state, equals(RecordingState.idle));
    });

    test('pauseRecording transitions state to paused', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
      when(() => mockRecorder.pause()).thenAnswer((_) async {});

      await manager.startRecording(customPath: '/tmp/test.wav');
      await manager.pauseRecording();

      expect(manager.state, equals(RecordingState.paused));
      verify(() => mockRecorder.pause()).called(1);
    });

    test('resumeRecording transitions state back to recording', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
      when(() => mockRecorder.pause()).thenAnswer((_) async {});
      when(() => mockRecorder.resume()).thenAnswer((_) async {});

      await manager.startRecording(customPath: '/tmp/test.wav');
      await manager.pauseRecording();
      await manager.resumeRecording();

      expect(manager.state, equals(RecordingState.recording));
      verify(() => mockRecorder.resume()).called(1);
    });

    test('stopRecording stops recorder and resets state to idle', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
      when(() => mockRecorder.stop()).thenAnswer((_) async => '/tmp/test.wav');

      await manager.startRecording(customPath: '/tmp/test.wav');
      final stoppedPath = await manager.stopRecording();

      expect(stoppedPath, equals('/tmp/test.wav'));
      expect(manager.state, equals(RecordingState.idle));
      expect(manager.currentFilePath, isNull);
      verify(() => mockRecorder.stop()).called(1);
    });
  });
}
