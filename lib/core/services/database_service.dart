import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/notes/domain/note.dart';

/// Database service managing SQLite storage, Full-Text Search (FTS5) indices,
/// CRUD operations, and reactive data streams for [Note] entities.
class DatabaseService {
  DatabaseService({Database? db}) : _db = db;

  Database? _db;
  String? _dbPath;
  final StreamController<List<Note>> _notesStreamController =
      StreamController<List<Note>>.broadcast();

  /// Gets the initialized [Database] instance or initializes a new one.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await initDatabase(dbPath: _dbPath);
    return _db!;
  }

  /// Initializes the SQLite database.
  /// Pass [dbPath] for in-memory testing (e.g. [inMemoryDatabasePath]).
  Future<Database> initDatabase({String? dbPath}) async {
    _dbPath = dbPath;
    // Initialize FFI for desktop (Windows, Linux, macOS) or unit testing
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on web platform.');
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || dbPath == inMemoryDatabasePath) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = dbPath ?? await _getDatabasePath();

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<String> _getDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'sonar_notes.db');
  }

  /// Creates database schema and FTS5 index tables + triggers.
  static Future<void> _onCreate(Database db, int version) async {
    // Main notes table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        audio_path TEXT NOT NULL,
        transcript TEXT,
        title TEXT,
        summary TEXT,
        action_items TEXT,
        status TEXT NOT NULL
      );
    ''');

    // FTS5 Virtual Table for Full-Text Search
    await db.execute('''
      CREATE VIRTUAL TABLE notes_fts USING fts5(
        note_id UNINDEXED,
        transcript,
        title,
        summary
      );
    ''');

    // Trigger on INSERT: sync to FTS5
    await db.execute('''
      CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
        INSERT INTO notes_fts(note_id, transcript, title, summary)
        VALUES (new.id, COALESCE(new.transcript, ''), COALESCE(new.title, ''), COALESCE(new.summary, ''));
      END;
    ''');

    // Trigger on DELETE: sync to FTS5
    await db.execute('''
      CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
        DELETE FROM notes_fts WHERE note_id = old.id;
      END;
    ''');

    // Trigger on UPDATE: sync to FTS5
    await db.execute('''
      CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
        UPDATE notes_fts 
        SET transcript = COALESCE(new.transcript, ''),
            title = COALESCE(new.title, ''),
            summary = COALESCE(new.summary, '')
        WHERE note_id = old.id;
      END;
    ''');
  }

  // ---------------------------------------------------------------------------
  // CRUD Operations
  // ---------------------------------------------------------------------------

  /// Creates a new [Note] record in the database.
  Future<void> createNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyNotesChanged();
  }

  /// Fetches a single [Note] by its [id].
  Future<Note?> getNoteById(String id) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  /// Fetches all [Note] records ordered by timestamp descending.
  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query(
      'notes',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  /// Updates an existing [Note].
  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await _notifyNotesChanged();
  }

  /// Deletes a [Note] by its [id].
  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notifyNotesChanged();
  }

  // ---------------------------------------------------------------------------
  // Full-Text Search (FTS5)
  // ---------------------------------------------------------------------------

  /// Searches notes matching [query] using the FTS5 index on transcript, title, and summary.
  /// If [query] is empty or whitespace, returns all notes.
  Future<List<Note>> searchNotes(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAllNotes();

    final db = await database;

    // Format FTS5 query: append wildcard '*' to match partial words if desired
    // Sanitizes input quote chars for safety
    final sanitizedQuery = trimmed.replaceAll("'", "''");
    final ftsQuery = '$sanitizedQuery*';

    final maps = await db.rawQuery('''
      SELECT n.* FROM notes n
      INNER JOIN notes_fts fts ON n.id = fts.note_id
      WHERE notes_fts MATCH '$ftsQuery'
      ORDER BY n.timestamp DESC;
    ''');

    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Reactive Stream
  // ---------------------------------------------------------------------------

  /// Returns a stream emitting updated lists of [Note] entities on change.
  Stream<List<Note>> watchAllNotes() {
    // Immediately emit current notes on subscribe
    getAllNotes().then((notes) {
      if (!_notesStreamController.isClosed) {
        _notesStreamController.add(notes);
      }
    });
    return _notesStreamController.stream;
  }

  Future<void> _notifyNotesChanged() async {
    if (_notesStreamController.hasListener && !_notesStreamController.isClosed) {
      final updatedNotes = await getAllNotes();
      _notesStreamController.add(updatedNotes);
    }
  }

  /// Closes database connection and stream controller.
  Future<void> dispose() async {
    await _notesStreamController.close();
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
  }
}
