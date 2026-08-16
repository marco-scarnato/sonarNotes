import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../notes/data/notes_providers.dart';
import '../data/whisper_service.dart';

final whisperServiceProvider = Provider<WhisperService>((ref) {
  final service = WhisperService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Task 8 (Spike 1-AI): Screen for validating whisper.cpp FFI binding,
/// non-blocking Isolate/native thread performance (jank-free UI), and RTF < 0.5 criteria.
class SpikeWhisperScreen extends ConsumerStatefulWidget {
  const SpikeWhisperScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SpikeWhisperScreen(),
      ),
    );
  }

  @override
  ConsumerState<SpikeWhisperScreen> createState() => _SpikeWhisperScreenState();
}

class _SpikeWhisperScreenState extends ConsumerState<SpikeWhisperScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  bool _isInitializing = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isModelSavedOnDisk = false;
  int _modelSizeBytes = 0;
  bool _isTranscribing = false;
  WhisperBenchmarkResult? _lastResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 60 FPS Continuous Rotation to prove UI stays completely jank-free during inference
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkDiskModelAndInit();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _checkDiskModelAndInit() async {
    final saved = await WhisperService.isModelSavedOnDisk();
    final size = await WhisperService.getModelSizeBytes();

    if (mounted) {
      setState(() {
        _isModelSavedOnDisk = saved;
        _modelSizeBytes = size;
      });
    }

    if (saved) {
      // Model is already on disk! Load C++ FFI without re-downloading!
      _initWhisperModel(forceDownload: false);
    }
  }

  Future<void> _initWhisperModel({bool forceDownload = false}) async {
    setState(() {
      _isInitializing = true;
      _isDownloading = forceDownload;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final whisperService = ref.read(whisperServiceProvider);
      await whisperService.initModel(
        forceDownload: forceDownload,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _isDownloading = true;
              _downloadProgress = progress;
            });
          }
        },
      );

      final saved = await WhisperService.isModelSavedOnDisk();
      final size = await WhisperService.getModelSizeBytes();
      if (mounted) {
        setState(() {
          _isModelSavedOnDisk = saved;
          _modelSizeBytes = size;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Inizializzazione FFI: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _runBenchmark({required Duration targetDuration, String? customPath}) async {
    final whisperService = ref.read(whisperServiceProvider);

    if (!whisperService.isModelLoaded) {
      try {
        await _initWhisperModel(forceDownload: false);
      } catch (_) {}
    }

    if (!whisperService.isModelLoaded) {
      setState(() {
        _errorMessage =
            'Motore whisper.cpp non pronto. ${_isModelSavedOnDisk ? "Il modello è su disco ma il caricamento FFI è fallito. Riprova o riscarica il modello." : "Scarica prima il modello GGML."}';
      });
      return;
    }

    setState(() {
      _isTranscribing = true;
      _errorMessage = null;
      _lastResult = null;
    });

    try {
      final result = await whisperService.transcribeAudio(
        audioPath: customPath ?? '',
        audioDuration: targetDuration,
        language: 'it',
      );

      if (mounted) {
        setState(() {
          _lastResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final sizeMb = (_modelSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Spike 1-AI: Whisper FFI & RTF'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header & Status Card ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.memory_rounded, color: AppTheme.primaryLight),
                        SizedBox(width: 10),
                        Text(
                          'Binding FFI whisper.cpp',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Model Persistent Storage Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stato Modello GGML:'),
                        if (_isInitializing || _isDownloading)
                          Row(
                            children: [
                              Text(
                                '${(_downloadProgress * 100).toInt()}% ',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ],
                          )
                        else if (_isModelSavedOnDisk)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.successGreen),
                            ),
                            child: Text(
                              'SALVATO SU DISCO ($sizeMb MB)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => _initWhisperModel(forceDownload: true),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              backgroundColor: AppTheme.primary,
                            ),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text(
                              'Scarica Modello (~39MB)',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),

                    if (_isDownloading) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        backgroundColor: AppTheme.surfaceLight,
                        color: AppTheme.primary,
                      ),
                    ],

                    if (_isModelSavedOnDisk && !_isDownloading) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _initWhisperModel(forceDownload: true),
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textSecondary),
                          label: const Text(
                            'Riscarica modello (Forza)',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            const SizedBox(height: 16),

            // --- Anti-Jank Continuous Visualizer Card ---
            Card(
              color: AppTheme.surfaceLight.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        RotationTransition(
                          turns: _rotationController,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isTranscribing
                                  ? AppTheme.accent.withValues(alpha: 0.3)
                                  : AppTheme.primary.withValues(alpha: 0.2),
                            ),
                            child: Icon(
                              Icons.sync_rounded,
                              color: _isTranscribing ? AppTheme.accent : AppTheme.primaryLight,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isTranscribing
                                    ? 'INFERENZA FFI C++ IN CORSO...'
                                    : 'Test Anti-Jank UI (60 FPS)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isTranscribing ? AppTheme.accent : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isTranscribing
                                    ? 'L\'animazione gira in modo fluido senza scatti grazie all\'Isolate FFI C++.'
                                    : 'Seleziona una nota registrata in basso per eseguire l\'inferenza whisper.cpp reale.',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- List of Notes to Transcribe Real Audio ---
            const Text(
              'Seleziona Nota per Trascrizione Reale via whisper.cpp FFI:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            notesAsync.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surfaceLight),
                    ),
                    child: const Text(
                      'Nessuna nota registrata. Ritorna alla Home e premi REC per creare una nota vocale reale da trascrivere.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  );
                }

                return Column(
                  children: notes.map((note) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.mic, color: AppTheme.primaryLight),
                        title: Text(
                          note.title ?? 'Nota del ${_formatDate(note.timestamp)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Durata: ${_formatDuration(note.duration)} · WAV PCM 16kHz',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: _isTranscribing
                              ? null
                              : () => _runBenchmark(
                                    targetDuration: note.duration,
                                    customPath: note.audioPath,
                                  ),
                          icon: const Icon(Icons.subtitles_rounded, size: 18),
                          label: const Text('TRASCRIVI'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Errore nel recupero note: $err'),
            ),

            const SizedBox(height: 24),

            // --- Error / Benchmark Results Panel ---
            if (_errorMessage != null)
              Card(
                color: AppTheme.recordingRed.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.recordingRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.recordingRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_lastResult != null)
              _buildBenchmarkResultsCard(_lastResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkResultsCard(WhisperBenchmarkResult res) {
    final passes = res.passesBenchmark;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: passes ? AppTheme.successGreen : AppTheme.recordingRed,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Benchmark Acceptance Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Risultati Trascrizione & RTF Reale',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (passes ? AppTheme.successGreen : AppTheme.recordingRed)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: passes ? AppTheme.successGreen : AppTheme.recordingRed,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        passes ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 16,
                        color: passes ? AppTheme.successGreen : AppTheme.recordingRed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        passes ? 'PASSED (RTF < 0.5)' : 'FAILED (RTF >= 0.5)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: passes ? AppTheme.successGreen : AppTheme.recordingRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Metrics Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  'Durata Audio',
                  _formatDuration(res.audioDuration),
                  Icons.timer_outlined,
                ),
                _buildMetricItem(
                  'Tempo Inferenza',
                  '${(res.inferenceTime.inMilliseconds / 1000).toStringAsFixed(2)}s',
                  Icons.bolt_rounded,
                ),
                _buildMetricItem(
                  'Valore RTF',
                  res.rtf.toStringAsFixed(3),
                  Icons.speed_rounded,
                  highlightColor: passes ? AppTheme.successGreen : AppTheme.recordingRed,
                ),
              ],
            ),

            const Divider(height: 24),

            const Text(
              'Testo Trascritto dall\'audio (whisper.cpp FFI C++):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: SelectableText(
                res.text,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, {Color? highlightColor}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: highlightColor ?? AppTheme.primaryLight),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: highlightColor ?? AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
