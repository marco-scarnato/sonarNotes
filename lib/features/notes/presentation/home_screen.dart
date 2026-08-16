import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../audio_recording/data/audio_player_manager.dart';
import '../../audio_recording/data/audio_player_provider.dart';
import '../../audio_recording/presentation/live_recording_screen.dart';
import '../data/notes_providers.dart';
import '../domain/note.dart';
import '../domain/note_status.dart';
import '../../speech_to_text/presentation/spike_whisper_screen.dart';
import 'note_detail_screen.dart';

/// Screen 1: Home / Feed Screen (Task 5).
///
/// Features:
/// - Top Search Bar with real-time FTS query filtering.
/// - Reactive Feed List powered by [notesListProvider] and SQLite.
/// - Note Card displaying Title, Date, Duration, and Status Badge.
/// - Tap Note Card ➔ Navigates to [NoteDetailScreen] (Screen 3).
/// - FAB REC Button ➔ Instantly launches [LiveRecordingScreen] (Screen 2).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openLiveRecording() {
    LiveRecordingScreen.show(context);
  }

  void _openNoteDetail(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final playerManager = ref.watch(audioPlayerManagerProvider);
    final activeNoteId = ref.watch(activePlayingNoteIdProvider);

    final searchQuery = ref.watch(notesSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.graphic_eq, color: AppTheme.primaryLight),
            SizedBox(width: 8),
            Text('Sonar Notes'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined, color: AppTheme.accent),
            tooltip: 'Spike 1-AI Whisper FFI',
            onPressed: () => SpikeWhisperScreen.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Top Search Bar ---
          _buildSearchBar(),

          // --- Reactive Notes Feed ---
          Expanded(
            child: notesAsync.when(
              data: (notes) => notes.isEmpty
                  ? _buildEmptyState(searchQuery)
                  : _buildNotesList(notes, playerManager, activeNoteId),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Errore nel caricamento note: $err'),
              ),
            ),
          ),
        ],
      ),

      // --- FAB REC Button ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLiveRecording,
        backgroundColor: AppTheme.recordingRed,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.mic, size: 28),
        label: const Text(
          'REC',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          ref.read(notesSearchQueryProvider.notifier).state = value;
        },
        decoration: InputDecoration(
          hintText: 'Cerca per titolo, trascrizione o sintesi...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(notesSearchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppTheme.surfaceLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppTheme.surfaceLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    final isSearching = query.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.mic_none_rounded,
                size: 64,
                color: AppTheme.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'Nessun risultato trovato' : 'Nessuna nota salvata',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Nessuna nota corrisponde alla ricerca "$query". Prova con parole chiave diverse.'
                  : 'Il tuo archivio è vuoto. Premi il pulsante "REC" in basso a destra per registrare la tua prima nota vocale.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(
    List<Note> notes,
    AudioPlayerManager playerManager,
    String? activeNoteId,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isPlayingThis = activeNoteId == note.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openNoteDetail(note),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Status Badge Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title ?? _defaultTitle(note.timestamp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(note.status),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Date & Duration Chips Row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(note.timestamp),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.timer_outlined,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(note.duration),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),

                  // Snippet (if transcript or summary exists)
                  if (note.summary != null && note.summary!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      note.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ] else if (note.transcript != null &&
                      note.transcript!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      note.transcript!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Card Bottom Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPlayingThis ? '▶ Riproduzione attiva' : 'Tocca per aprire il dettaglio',
                        style: TextStyle(
                          fontSize: 11,
                          color: isPlayingThis ? AppTheme.primaryLight : AppTheme.textMuted,
                          fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(NoteStatus status) {
    final String label;
    final Color color;

    switch (status) {
      case NoteStatus.recorded:
        label = 'Registrato';
        color = AppTheme.primaryLight;
        break;
      case NoteStatus.transcribing:
        label = 'Trascrizione…';
        color = AppTheme.pausedAmber;
        break;
      case NoteStatus.summarizing:
        label = 'Analisi AI…';
        color = AppTheme.accent;
        break;
      case NoteStatus.done:
        label = 'Completato';
        color = AppTheme.successGreen;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _defaultTitle(DateTime timestamp) {
    return 'Nota del ${_formatDate(timestamp)}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
