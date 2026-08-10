import 'package:flutter_test/flutter_test.dart';
import 'package:sonar_notes/core/services/database_service.dart';
import 'package:sonar_notes/features/notes/domain/note.dart';
import 'package:sonar_notes/features/notes/domain/note_status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Note Model Tests', () {
    test('serialization toMap and fromMap works correctly', () {
      final now = DateTime.now();
      final note = Note(
        id: const Uuid().v4(),
        timestamp: now,
        duration: const Duration(seconds: 45),
        audioPath: '/tmp/test.wav',
        transcript: 'This is a test transcript for voice notes.',
        title: 'Meeting Notes',
        summary: 'Discussed project architecture and SQLite setup.',
        actionItems: const ['Task 1', 'Task 2'],
        status: NoteStatus.done,
      );

      final map = note.toMap();
      final restored = Note.fromMap(map);

      expect(restored.id, equals(note.id));
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        equals(note.timestamp.millisecondsSinceEpoch),
      );
      expect(restored.duration, equals(note.duration));
      expect(restored.audioPath, equals(note.audioPath));
      expect(restored.transcript, equals(note.transcript));
      expect(restored.title, equals(note.title));
      expect(restored.summary, equals(note.summary));
      expect(restored.actionItems, equals(note.actionItems));
      expect(restored.status, equals(note.status));
    });

    test('copyWith modifies requested fields while keeping others intact', () {
      final note = Note(
        id: 'note-1',
        timestamp: DateTime(2026, 8, 10),
        duration: const Duration(seconds: 10),
        audioPath: '/audio/path.wav',
        status: NoteStatus.recorded,
      );

      final updated = note.copyWith(
        transcript: 'Updated transcript',
        status: NoteStatus.transcribing,
      );

      expect(updated.id, equals('note-1'));
      expect(updated.transcript, equals('Updated transcript'));
      expect(updated.status, equals(NoteStatus.transcribing));
      expect(updated.audioPath, equals('/audio/path.wav'));
    });
  });

  group('DatabaseService CRUD & FTS Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initDatabase(dbPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await dbService.dispose();
    });

    test('createNote and getNoteById', () async {
      final note = Note(
        id: 'test-id-1',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 30),
        audioPath: '/storage/note1.wav',
        title: 'First Note',
        status: NoteStatus.recorded,
      );

      await dbService.createNote(note);
      final retrieved = await dbService.getNoteById('test-id-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test-id-1'));
      expect(retrieved.title, equals('First Note'));
      expect(retrieved.status, equals(NoteStatus.recorded));
    });

    test('getAllNotes returns notes ordered by timestamp descending', () async {
      final note1 = Note(
        id: 'note-old',
        timestamp: DateTime(2026, 8, 1),
        duration: const Duration(seconds: 10),
        audioPath: '/audio/old.wav',
      );
      final note2 = Note(
        id: 'note-new',
        timestamp: DateTime(2026, 8, 10),
        duration: const Duration(seconds: 20),
        audioPath: '/audio/new.wav',
      );

      await dbService.createNote(note1);
      await dbService.createNote(note2);

      final allNotes = await dbService.getAllNotes();
      expect(allNotes.length, equals(2));
      expect(allNotes.first.id, equals('note-new'));
      expect(allNotes.last.id, equals('note-old'));
    });

    test('updateNote modifies existing record and syncs FTS', () async {
      final note = Note(
        id: 'upd-1',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 15),
        audioPath: '/audio/upd.wav',
        status: NoteStatus.recorded,
      );

      await dbService.createNote(note);

      final updated = note.copyWith(
        transcript: 'Transcribed audio content successfully.',
        title: 'Architecture Meeting',
        summary: 'Summary of discussion on SQLite and Flutter.',
        actionItems: ['Review PR', 'Deploy build'],
        status: NoteStatus.done,
      );

      await dbService.updateNote(updated);

      final retrieved = await dbService.getNoteById('upd-1');
      expect(retrieved!.status, equals(NoteStatus.done));
      expect(retrieved.transcript, equals('Transcribed audio content successfully.'));
      expect(retrieved.actionItems, equals(['Review PR', 'Deploy build']));
    });

    test('deleteNote removes record and cleans FTS index', () async {
      final note = Note(
        id: 'del-1',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 5),
        audioPath: '/audio/del.wav',
        transcript: 'Secret information to be deleted',
      );

      await dbService.createNote(note);
      expect(await dbService.getNoteById('del-1'), isNotNull);

      await dbService.deleteNote('del-1');
      expect(await dbService.getNoteById('del-1'), isNull);

      final searchResults = await dbService.searchNotes('Secret');
      expect(searchResults, isEmpty);
    });

    test('searchNotes FTS5 matches transcript, title, and summary', () async {
      final note1 = Note(
        id: 'fts-1',
        timestamp: DateTime(2026, 8, 10, 10, 0),
        duration: const Duration(seconds: 60),
        audioPath: '/audio/1.wav',
        title: 'Quantum Computing Briefing',
        transcript: 'We discussed qubit stability and error correction.',
        summary: 'Overview of quantum hardware progress.',
      );

      final note2 = Note(
        id: 'fts-2',
        timestamp: DateTime(2026, 8, 10, 11, 0),
        duration: const Duration(seconds: 40),
        audioPath: '/audio/2.wav',
        title: 'Grocery List',
        transcript: 'Buy milk, apples, and sourdough bread.',
        summary: 'Weekly shopping plan.',
      );

      await dbService.createNote(note1);
      await dbService.createNote(note2);

      // Match in transcript
      final search1 = await dbService.searchNotes('qubit');
      expect(search1.length, equals(1));
      expect(search1.first.id, equals('fts-1'));

      // Match in title
      final search2 = await dbService.searchNotes('Grocery');
      expect(search2.length, equals(1));
      expect(search2.first.id, equals('fts-2'));

      // Match in summary
      final search3 = await dbService.searchNotes('shopping');
      expect(search3.length, equals(1));
      expect(search3.first.id, equals('fts-2'));

      // Partial word prefix match
      final search4 = await dbService.searchNotes('stab');
      expect(search4.length, equals(1));
      expect(search4.first.id, equals('fts-1'));

      // No match
      final search5 = await dbService.searchNotes('nonexistentword');
      expect(search5, isEmpty);

      // Empty query returns all
      final search6 = await dbService.searchNotes('');
      expect(search6.length, equals(2));
    });
  });
}
