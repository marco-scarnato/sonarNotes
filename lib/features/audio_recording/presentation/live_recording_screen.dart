import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../notes/data/notes_providers.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_status.dart';
import '../../notes/presentation/note_detail_screen.dart';
import '../data/audio_recorder_manager.dart';
import '../data/audio_recorder_provider.dart';
import '../domain/recording_state.dart';

/// Screen 2: Dedicated Live Recording Minimal UI (Task 6).
///
/// Features:
/// - Prominent real-time timer display updated to the second.
/// - Resource-efficient layout (no CPU-heavy canvas waveform).
/// - Pause / Resume, Cancel, and Stop & Save controls.
/// - Automatically saves recording to SQLite and redirects to [NoteDetailScreen] on Stop.
class LiveRecordingScreen extends ConsumerStatefulWidget {
  const LiveRecordingScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveRecordingScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  ConsumerState<LiveRecordingScreen> createState() => _LiveRecordingScreenState();
}

class _LiveRecordingScreenState extends ConsumerState<LiveRecordingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Auto-start recording on screen load if idle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final manager = ref.read(audioRecorderManagerProvider);
      if (manager.state == RecordingState.idle) {
        try {
          await manager.startRecording();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Impossibile avviare registrazione: $e')),
            );
            Navigator.of(context).pop();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAndSaveRecording(AudioRecorderManager manager) async {
    final duration = manager.elapsedDuration;
    final path = await manager.stopRecording();

    if (path != null && mounted) {
      final newNote = Note(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        duration: duration,
        audioPath: path,
        status: NoteStatus.recorded,
      );

      final dbService = ref.read(databaseServiceProvider);
      await dbService.createNote(newNote);

      if (mounted) {
        // Redirect to Note Detail Screen for the newly created note
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NoteDetailScreen(note: newNote),
          ),
        );
      }
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancelRecording(AudioRecorderManager manager) async {
    await manager.cancelRecording();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(audioRecorderManagerProvider);
    final recordingStateAsync = ref.watch(recordingStateStreamProvider);
    final recordingDurationAsync = ref.watch(recordingDurationStreamProvider);

    final state = recordingStateAsync.value ?? manager.state;
    final duration = recordingDurationAsync.value ?? manager.elapsedDuration;
    final isPaused = state == RecordingState.paused;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Registrazione Live'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _cancelRecording(manager),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),

              // Animated Pulsing Mic Circle
              ScaleTransition(
                scale: isPaused
                    ? const AlwaysStoppedAnimation(1.0)
                    : Tween<double>(begin: 0.95, end: 1.15).animate(
                        CurvedAnimation(
                          parent: _pulseController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPaused
                        ? AppTheme.pausedAmber.withValues(alpha: 0.2)
                        : AppTheme.recordingRed.withValues(alpha: 0.2),
                    border: Border.all(
                      color: isPaused ? AppTheme.pausedAmber : AppTheme.recordingRed,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isPaused ? AppTheme.pausedAmber : AppTheme.recordingRed)
                            .withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPaused ? Icons.pause_rounded : Icons.mic_rounded,
                    size: 64,
                    color: isPaused ? AppTheme.pausedAmber : AppTheme.recordingRed,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Status Text
              Text(
                isPaused ? 'IN PAUSA' : 'REGISTRAZIONE IN CORSO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: isPaused ? AppTheme.pausedAmber : AppTheme.recordingRed,
                ),
              ),

              const SizedBox(height: 12),

              // Real-Time Large Timer Display (mm:ss)
              Text(
                _formatTimer(duration),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'PCM 16 kHz Mono · 16-bit',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),

              const Spacer(),

              // --- Bottom Controls ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        onPressed: () => _cancelRecording(manager),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.surfaceLight,
                          foregroundColor: AppTheme.textPrimary,
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 28),
                      ),
                      const SizedBox(height: 6),
                      const Text('Annulla', style: TextStyle(fontSize: 12)),
                    ],
                  ),

                  // Stop & Save Button (Prominent)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _stopAndSaveRecording(manager),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.recordingRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.recordingRed.withValues(alpha: 0.5),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stop_rounded, size: 30),
                            SizedBox(width: 8),
                            Text(
                              'SALVA',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Completa', style: TextStyle(fontSize: 12)),
                    ],
                  ),

                  // Pause / Resume Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        onPressed: () {
                          if (isPaused) {
                            manager.resumeRecording();
                          } else {
                            manager.pauseRecording();
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: isPaused
                              ? AppTheme.primary
                              : AppTheme.pausedAmber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: Icon(
                          isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPaused ? 'Riprendi' : 'Pausa',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimer(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
