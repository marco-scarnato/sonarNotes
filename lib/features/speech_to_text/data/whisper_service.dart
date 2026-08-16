import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

/// Benchmark result containing transcription text, metrics, and RTF acceptance criteria.
class WhisperBenchmarkResult {
  WhisperBenchmarkResult({
    required this.text,
    required this.inferenceTime,
    required this.audioDuration,
    required this.rtf,
    required this.language,
    required this.isSuccess,
    this.errorMessage,
  });

  final String text;
  final Duration inferenceTime;
  final Duration audioDuration;
  final double rtf;
  final String language;
  final bool isSuccess;
  final String? errorMessage;

  /// Acceptance criterion: Real-Time Factor (RTF) < 0.5 (only valid when C++ inference actually ran)
  bool get passesBenchmark => isSuccess && rtf < 0.5;
}

/// Service managing on-device Whisper.cpp speech-to-text via whisper_ggml_plus.
///
/// Uses [WhisperController] for model download/management and
/// [Whisper] for file-based batch transcription on all platforms
/// (Android, iOS, macOS, Linux, Windows).
class WhisperService {
  /// The high-level controller for model management and transcription.
  final WhisperController _controller = WhisperController();

  /// The model size to use. WhisperModel.base is ~142MB but good accuracy;
  /// use WhisperModel.tiny (~39MB) for faster downloads during spike testing.
  static const WhisperModel _defaultModel = WhisperModel.base;

  bool _modelReady = false;
  String? _initError;

  /// Returns whether the GGML model is downloaded and ready for transcription.
  bool get isModelLoaded => _modelReady;

  /// Last initialization error message, if any.
  String? get initError => _initError;

  /// Returns the local path where the GGML model file is stored.
  static Future<String?> getModelPath() async {
    try {
      final controller = WhisperController();
      final path = await controller.getPath(_defaultModel);
      return path;
    } catch (e) {
      debugPrint('[WhisperService] getModelPath error: $e');
      return null;
    }
  }

  /// Checks if a valid GGML model file is already present on local disk.
  static Future<bool> isModelSavedOnDisk() async {
    try {
      final path = await getModelPath();
      if (path == null) return false;
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        return size > 5000000; // > 5 MB is a valid model file
      }
      return false;
    } catch (e) {
      debugPrint('[WhisperService] isModelSavedOnDisk error: $e');
      return false;
    }
  }

  /// Gets size of GGML model on disk in bytes.
  static Future<int> getModelSizeBytes() async {
    try {
      final path = await getModelPath();
      if (path == null) return 0;
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Downloads the default GGML model via [WhisperController.downloadModel].
  ///
  /// The whisper_ggml_plus library downloads from the official
  /// ggerganov/whisper.cpp GGML model repository on Hugging Face.
  static Future<String?> downloadDefaultModel({
    void Function(double progress)? onProgress,
    bool forceDownload = false,
  }) async {
    final controller = WhisperController();

    debugPrint('[WhisperService] 📥 Avvio download modello GGML (${_defaultModel.name})...');

    // Check if model already exists
    if (!forceDownload) {
      final alreadySaved = await isModelSavedOnDisk();
      if (alreadySaved) {
        debugPrint('[WhisperService] 🟢 Modello già presente su disco! Download saltato.');
        final path = await controller.getPath(_defaultModel);
        return path;
      }
    }

    try {
      // If force download, delete existing file first
      if (forceDownload) {
        final path = await controller.getPath(_defaultModel);
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            debugPrint('[WhisperService] Eliminazione modello precedente per ri-download...');
            await file.delete();
          }
        }
      }

      // Download via whisper_ggml_plus controller
      // Note: whisper_ggml_plus doesn't expose download progress callback,
      // so we simulate progress updates during the download
      if (onProgress != null) onProgress(0.1);

      await controller.downloadModel(_defaultModel);

      if (onProgress != null) onProgress(1.0);

      final path = await controller.getPath(_defaultModel);
      debugPrint('[WhisperService] 🟢 Download completato! Path: $path');
      return path;
    } catch (e) {
      debugPrint('[WhisperService] ❌ Errore durante il download del modello: $e');
      rethrow;
    }
  }

  /// Initializes the whisper service: downloads model if needed and marks ready.
  Future<void> initModel({
    String? customModelPath,
    void Function(double progress)? onProgress,
    bool forceDownload = false,
  }) async {
    _initError = null;

    if (_modelReady && !forceDownload) {
      debugPrint('[WhisperService] Modello già pronto.');
      return;
    }

    _modelReady = false;

    try {
      if (customModelPath != null && await File(customModelPath).exists()) {
        debugPrint('[WhisperService] Usando modello custom: $customModelPath');
        _modelReady = true;
      } else {
        final path = await downloadDefaultModel(
          onProgress: onProgress,
          forceDownload: forceDownload,
        );

        if (path == null || !await File(path).exists()) {
          throw Exception('Impossibile reperire il file GGML su disco.');
        }

        debugPrint('[WhisperService] 🟢 Modello GGML pronto per inferenza su ${Platform.operatingSystem}');
        _modelReady = true;
      }
    } catch (e) {
      _initError = e.toString();
      _modelReady = false;
      debugPrint('[WhisperService] ❌ Init error: $e');
      rethrow;
    }
  }

  /// Transcribes a WAV audio file using whisper.cpp via whisper_ggml_plus.
  ///
  /// This is file-based batch transcription: the audio file must exist on disk.
  /// The library handles PCM conversion and native inference internally.
  Future<WhisperBenchmarkResult> transcribeAudio({
    required String audioPath,
    required Duration audioDuration,
    String language = 'it',
  }) async {
    debugPrint('[WhisperService] Request trascrizione per audio: $audioPath (Durata: ${audioDuration.inSeconds}s)');

    if (!_modelReady) {
      final msg = 'Modello GGML non pronto. ${_initError ?? "Scarica il modello GGML prima di trascrivere."}';
      debugPrint('[WhisperService] ❌ Trascrizione annullata: $msg');
      throw Exception(msg);
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      final msg = 'File audio non trovato su disco: $audioPath';
      debugPrint('[WhisperService] ❌ Error: $msg');
      throw Exception(msg);
    }

    debugPrint('[WhisperService] ⚡ Avvio inferenza whisper.cpp (whisper_ggml_plus) per file: $audioPath...');
    debugPrint('[WhisperService] Platform: OS=${Platform.operatingSystem}');

    final stopwatch = Stopwatch()..start();

    try {
      // Perform REAL whisper.cpp inference via whisper_ggml_plus
      final result = await _controller.transcribe(
        model: _defaultModel,
        audioPath: audioPath,
        lang: language,
        withTimestamps: false,
      );

      stopwatch.stop();

      if (result == null) {
        throw Exception('Trascrizione restituita nulla dal motore whisper.cpp.');
      }

      final inferenceTime = stopwatch.elapsed;
      final audioMs = audioDuration.inMilliseconds > 0
          ? audioDuration.inMilliseconds
          : 1;
      final rtf = inferenceTime.inMilliseconds / audioMs;

      final transcribedText = result.transcription.text.trim();

      debugPrint('[WhisperService] 🟢 Inferenza completata in ${(inferenceTime.inMilliseconds / 1000).toStringAsFixed(2)}s! RTF = ${rtf.toStringAsFixed(3)}');
      debugPrint('[WhisperService] Testo trascritto: "$transcribedText"');

      return WhisperBenchmarkResult(
        text: transcribedText.isEmpty
            ? '[Silenzio o nessun parlato rilevato nel file audio.]'
            : transcribedText,
        inferenceTime: inferenceTime,
        audioDuration: audioDuration,
        rtf: rtf,
        language: language,
        isSuccess: true,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[WhisperService] ❌ Errore durante inferenza: $e');
      rethrow;
    }
  }

  /// Releases native resources.
  Future<void> dispose() async {
    try {
      if (_modelReady) {
        debugPrint('[WhisperService] Disposing Whisper native context...');
        final whisper = Whisper(model: _defaultModel);
        await whisper.dispose();
      }
    } catch (e) {
      debugPrint('[WhisperService] Dispose notice: $e');
    }
    _modelReady = false;
  }
}
