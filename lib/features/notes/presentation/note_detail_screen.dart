import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../audio_recording/data/audio_player_manager.dart';
import '../../audio_recording/data/audio_player_provider.dart';
import '../data/notes_providers.dart';
import '../domain/note.dart';

/// Screen 3: Note Detail & Audio Player Integration Screen (Task 7).
///
/// Features:
/// - Rename note capability with immediate SQLite DB update.
/// - Delete note capability with confirmation and file cleanup.
/// - Full Audio Player integration (Play/Pause, Slider scrubbing, 1x/1.5x/2x speed selector).
/// - Dual-Tab layout: [Summary] and [Transcript] (placeholders ready for AI Phase 3).
class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({
    super.key,
    required this.note,
  });

  final Note note;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen>
    with SingleTickerProviderStateMixin {
  late Note _currentNote;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _renameNote() async {
    final controller = TextEditingController(text: _currentNote.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Rinomina Nota'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Inserisci nuovo titolo...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('SALVA'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      final updated = _currentNote.copyWith(title: newTitle);
      final dbService = ref.read(databaseServiceProvider);
      await dbService.updateNote(updated);

      setState(() {
        _currentNote = updated;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Titolo aggiornato nel database!')),
        );
      }
    }
  }

  Future<void> _deleteNote(AudioPlayerManager playerManager) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Elimina Nota'),
        content: const Text('Sei sicuro di voler eliminare questa nota e il relativo file audio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.recordingRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (ref.read(activePlayingNoteIdProvider) == _currentNote.id) {
        await playerManager.stop();
        ref.read(activePlayingNoteIdProvider.notifier).state = null;
      }

      final dbService = ref.read(databaseServiceProvider);
      await dbService.deleteNote(_currentNote.id);

      final file = File(_currentNote.audioPath);
      if (await file.exists()) {
        await file.delete();
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _toggleAudioPlayback(
    AudioPlayerManager playerManager,
    String? activeNoteId,
    PlayerState playerState,
  ) async {
    final activeIdNotifier = ref.read(activePlayingNoteIdProvider.notifier);

    if (activeNoteId == _currentNote.id) {
      if (playerState == PlayerState.playing) {
        await playerManager.pause();
      } else if (playerState == PlayerState.paused) {
        await playerManager.resume();
      } else {
        await playerManager.play(_currentNote.audioPath);
      }
    } else {
      activeIdNotifier.state = _currentNote.id;
      final file = File(_currentNote.audioPath);
      if (await file.exists()) {
        await playerManager.play(_currentNote.audioPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File audio non trovato su disco.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerManager = ref.watch(audioPlayerManagerProvider);
    final activeNoteId = ref.watch(activePlayingNoteIdProvider);
    final playerStateAsync = ref.watch(playerStateStreamProvider);
    final positionAsync = ref.watch(playerPositionStreamProvider);
    final durationAsync = ref.watch(playerDurationStreamProvider);
    final speedAsync = ref.watch(playerSpeedStreamProvider);

    final isThisNotePlaying = activeNoteId == _currentNote.id;
    final playerState = isThisNotePlaying ? (playerStateAsync.value ?? playerManager.state) : PlayerState.stopped;
    final currentPosition = isThisNotePlaying ? (positionAsync.value ?? playerManager.position) : Duration.zero;
    final totalDuration = isThisNotePlaying ? (durationAsync.value ?? playerManager.duration) : _currentNote.duration;
    final currentSpeed = speedAsync.value ?? playerManager.speed;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_currentNote.title ?? _defaultTitle(_currentNote.timestamp)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rinomina',
            onPressed: _renameNote,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.recordingRed),
            tooltip: 'Elimina',
            onPressed: () => _deleteNote(playerManager),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Audio Player Card ---
          _buildAudioPlayerCard(
            playerManager,
            isThisNotePlaying,
            playerState,
            currentPosition,
            totalDuration > Duration.zero ? totalDuration : _currentNote.duration,
            currentSpeed,
          ),

          // --- Tab Bar Header ---
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.auto_awesome), text: 'Summary'),
                Tab(icon: Icon(Icons.description_outlined), text: 'Transcript'),
              ],
            ),
          ),

          // --- Tab Bar Content ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildTranscriptTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayerCard(
    AudioPlayerManager playerManager,
    bool isPlayingThis,
    PlayerState playerState,
    Duration position,
    Duration duration,
    double speed,
  ) {
    final isPlaying = isPlayingThis && playerState == PlayerState.playing;
    final maxMs = duration.inMilliseconds.toDouble();
    final currentMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Timeline Scrubber
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 4,
              ),
              child: Slider(
                value: currentMs,
                max: maxMs > 0 ? maxMs : 1.0,
                activeColor: AppTheme.primary,
                inactiveColor: AppTheme.surfaceLight,
                onChanged: (val) {
                  if (isPlayingThis) {
                    playerManager.seek(Duration(milliseconds: val.round()));
                  }
                },
              ),
            ),

            // Time Indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Player Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stop Button
                IconButton.outlined(
                  onPressed: isPlayingThis
                      ? () async {
                          await playerManager.stop();
                          ref.read(activePlayingNoteIdProvider.notifier).state =
                              null;
                        }
                      : null,
                  icon: const Icon(Icons.stop_rounded),
                  color: AppTheme.recordingRed,
                ),

                const SizedBox(width: 24),

                // Play / Pause Prominent Button
                ElevatedButton(
                  onPressed: () => _toggleAudioPlayback(
                    playerManager,
                    ref.read(activePlayingNoteIdProvider),
                    playerState,
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(18),
                    backgroundColor: AppTheme.primary,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 36,
                  ),
                ),

                const SizedBox(width: 24),

                // Speed Selector Pill (1.0x, 1.5x, 2.0x)
                OutlinedButton(
                  onPressed: () => playerManager.cycleSpeed(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    '${speed.toStringAsFixed(1).replaceAll('.0', '')}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    final hasSummary = _currentNote.summary != null && _currentNote.summary!.isNotEmpty;
    final hasActions = _currentNote.actionItems.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.primaryLight, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Executive Summary',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (hasSummary)
                    Text(
                      _currentNote.summary!,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.textSecondary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '🤖 Il modello SLM genererà la sintesi intelligente dell\'audio nella Fase 3.',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Items Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppTheme.successGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Action Items & Tasks',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (hasActions)
                    ..._currentNote.actionItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank,
                                size: 18, color: AppTheme.primaryLight),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                    )
                  else
                    const Text(
                      'Nessun action item identificato.',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptTab() {
    final hasTranscript =
        _currentNote.transcript != null && _currentNote.transcript!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.record_voice_over_outlined,
                      color: AppTheme.primaryLight, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Trascrizione completa',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (hasTranscript)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copia trascrizione',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _currentNote.transcript!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Trascrizione copiata negli appunti!')),
                        );
                      },
                    ),
                ],
              ),
              const Divider(height: 24),
              if (hasTranscript)
                SelectableText(
                  _currentNote.transcript!,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.graphic_eq, color: AppTheme.textSecondary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '🎙️ Il motore Whisper STT eseguirà la trascrizione nativa dell\'audio nella Fase 3.',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
