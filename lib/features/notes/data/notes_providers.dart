import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonar_notes/core/services/database_service.dart';

import '../domain/note.dart';

/// Provider for the singleton [DatabaseService] instance.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final dbService = DatabaseService();
  ref.onDispose(() {
    dbService.dispose();
  });
  return dbService;
});

/// Provider holding the current search query entered by the user.
final notesSearchQueryProvider = StateProvider<String>((ref) => '');

/// Stream/Future provider exposing the list of notes based on the current search query.
final notesListProvider = StreamProvider<List<Note>>((ref) async* {
  final dbService = ref.watch(databaseServiceProvider);
  final query = ref.watch(notesSearchQueryProvider);

  if (query.trim().isEmpty) {
    yield* dbService.watchAllNotes();
  } else {
    final searchResults = await dbService.searchNotes(query);
    yield searchResults;
  }
});
