import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/audio_recorder_service.dart';

/// Temporary validation screen for SPIKE-1.
///
/// Provides a minimal UI to:
/// 1. Record audio in WAV 16 kHz Mono 16-bit.
/// 2. Measure the start-up latency of the recording.
/// 3. Play back the recorded file to confirm it is valid.
///
/// This screen is meant to be removed once the spike is validated.
class SpikeRecorderScreen extends StatefulWidget {
  const SpikeRecorderScreen({super.key});

  @override
  State<SpikeRecorderScreen> createState() => _SpikeRecorderScreenState();
}

class _SpikeRecorderScreenState extends State<SpikeRecorderScreen> {
  final AudioRecorderService _recorderService = AudioRecorderService();
  final AudioPlayer _player = AudioPlayer();

  // --- State ---
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _filePath;
  int? _startLatencyMs;
  int? _fileSizeBytes;
  bool? _encoderSupported;
  bool? _permissionGranted;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkCapabilities();

    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _checkCapabilities() async {
    try {
      final supported = await _recorderService.isEncoderSupported();
      final permission = await _recorderService.hasPermission();
      if (mounted) {
        setState(() {
          _encoderSupported = supported;
          _permissionGranted = permission;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Capability check failed: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
      _filePath = null;
      _fileSizeBytes = null;
      _startLatencyMs = null;
    });

    try {
      // Build output path
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/spike_recording_$timestamp.wav';

      // Measure start latency
      final stopwatch = Stopwatch()..start();
      await _recorderService.start(path);
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _isRecording = true;
          _startLatencyMs = stopwatch.elapsedMilliseconds;
          _filePath = path;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Start failed: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final outputPath = await _recorderService.stop();
      int? size;
      if (outputPath != null) {
        final file = File(outputPath);
        if (await file.exists()) {
          size = await file.length();
        }
      }
      if (mounted) {
        setState(() {
          _isRecording = false;
          _filePath = outputPath;
          _fileSizeBytes = size;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _errorMessage = 'Stop failed: $e';
        });
      }
    }
  }

  Future<void> _playRecording() async {
    if (_filePath == null) return;
    try {
      setState(() => _isPlaying = true);
      await _player.play(DeviceFileSource(_filePath!));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _errorMessage = 'Playback failed: $e';
        });
      }
    }
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _recorderService.dispose();
    _player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPIKE-1 · WAV Recorder Validation'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Capabilities card ---
            _buildCapabilitiesCard(),
            const SizedBox(height: 16),

            // --- Record button ---
            _buildRecordButton(),
            const SizedBox(height: 24),

            // --- Results card ---
            if (_startLatencyMs != null || _filePath != null)
              _buildResultsCard(),

            // --- Error message ---
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Capabilities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _capabilityRow(
              'AudioEncoder.wav supported',
              _encoderSupported,
            ),
            const SizedBox(height: 8),
            _capabilityRow(
              'Microphone permission',
              _permissionGranted,
            ),
            const SizedBox(height: 8),
            _capabilityRow(
              'Target format',
              true,
              overrideLabel: 'PCM 16 kHz · Mono · 16-bit',
            ),
          ],
        ),
      ),
    );
  }

  Widget _capabilityRow(String label, bool? value, {String? overrideLabel}) {
    final IconData icon;
    final Color color;
    final String status;

    if (value == null) {
      icon = Icons.hourglass_empty;
      color = Colors.grey;
      status = 'Checking…';
    } else if (value) {
      icon = Icons.check_circle;
      color = Colors.green;
      status = overrideLabel ?? 'YES';
    } else {
      icon = Icons.cancel;
      color = Colors.red;
      status = overrideLabel ?? 'NO';
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildRecordButton() {
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        onPressed: _toggleRecording,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              _isRecording ? 'STOP RECORDING' : 'START RECORDING',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final latencyPass = _startLatencyMs != null && _startLatencyMs! < 300;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Results',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),

            // Latency
            if (_startLatencyMs != null) ...[
              Row(
                children: [
                  Icon(
                    latencyPass ? Icons.check_circle : Icons.cancel,
                    color: latencyPass ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('Start latency:'),
                  const Spacer(),
                  Text(
                    '${_startLatencyMs}ms',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: latencyPass ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    latencyPass ? '< 300ms ✓' : '>= 300ms ✗',
                    style: TextStyle(
                      color: latencyPass ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // File path
            if (_filePath != null && !_isRecording) ...[
              const Text('File path:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SelectableText(
                _filePath!,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
            ],

            // File size
            if (_fileSizeBytes != null) ...[
              Row(
                children: [
                  const Icon(Icons.insert_drive_file, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('File size:'),
                  const Spacer(),
                  Text(
                    _formatBytes(_fileSizeBytes!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Play button
            if (_filePath != null && !_isRecording)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPlaying ? _stopPlayback : _playRecording,
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(_isPlaying ? 'STOP PLAYBACK' : 'PLAY RECORDING'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlaying ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
