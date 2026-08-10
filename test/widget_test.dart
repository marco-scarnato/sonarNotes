import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sonar_notes/features/audio_recording/data/audio_player_manager.dart';
import 'package:sonar_notes/features/audio_recording/data/audio_player_provider.dart';
import 'package:sonar_notes/features/notes/data/notes_providers.dart';
import 'package:sonar_notes/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAudioPlayerManager extends Mock implements AudioPlayerManager {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App renders Sonar Notes smoke test', (WidgetTester tester) async {
    final mockPlayerManager = MockAudioPlayerManager();
    when(() => mockPlayerManager.playerStateStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockPlayerManager.positionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockPlayerManager.durationStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockPlayerManager.speedStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockPlayerManager.state).thenReturn(PlayerState.stopped);
    when(() => mockPlayerManager.position).thenReturn(Duration.zero);
    when(() => mockPlayerManager.duration).thenReturn(Duration.zero);
    when(() => mockPlayerManager.speed).thenReturn(1.0);
    when(() => mockPlayerManager.dispose()).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListProvider.overrideWith((ref) => Stream.value([])),
          audioPlayerManagerProvider.overrideWithValue(mockPlayerManager),
        ],
        child: const SonarNotesApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Sonar Notes'), findsOneWidget);
  });
}
