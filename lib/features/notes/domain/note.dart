import 'dart:convert';
import 'note_status.dart';

/// Domain entity representing an audio note, its metadata, transcription,
/// AI summary outputs, and pipeline processing status.
class Note {
  const Note({
    required this.id,
    required this.timestamp,
    required this.duration,
    required this.audioPath,
    this.transcript,
    this.title,
    this.summary,
    this.actionItems = const [],
    this.status = NoteStatus.recorded,
  });

  /// Unique identifier (UUID or timestamp-based string).
  final String id;

  /// Timestamp when the note was recorded.
  final DateTime timestamp;

  /// Duration of the audio recording.
  final Duration duration;

  /// Local filesystem path to the saved WAV audio file.
  final String audioPath;

  /// Raw STT transcription text.
  final String? transcript;

  /// AI-generated smart title.
  final String? title;

  /// AI-generated executive summary.
  final String? summary;

  /// AI-extracted list of action items / tasks.
  final List<String> actionItems;

  /// Pipeline execution status.
  final NoteStatus status;

  /// Creates a copy of this [Note] with modified fields.
  Note copyWith({
    String? id,
    DateTime? timestamp,
    Duration? duration,
    String? audioPath,
    String? transcript,
    String? title,
    String? summary,
    List<String>? actionItems,
    NoteStatus? status,
  }) {
    return Note(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      audioPath: audioPath ?? this.audioPath,
      transcript: transcript ?? this.transcript,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      actionItems: actionItems ?? this.actionItems,
      status: status ?? this.status,
    );
  }

  /// Converts this [Note] instance to a Database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'duration': duration.inMilliseconds,
      'audio_path': audioPath,
      'transcript': transcript,
      'title': title,
      'summary': summary,
      'action_items': jsonEncode(actionItems),
      'status': status.toDbString(),
    };
  }

  /// Deserializes a [Note] instance from a Database map.
  factory Note.fromMap(Map<String, dynamic> map) {
    List<String> parsedActionItems = [];
    if (map['action_items'] != null) {
      final rawItems = map['action_items'];
      if (rawItems is String && rawItems.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawItems);
          if (decoded is List) {
            parsedActionItems = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          parsedActionItems = [];
        }
      } else if (rawItems is List) {
        parsedActionItems = rawItems.map((e) => e.toString()).toList();
      }
    }

    return Note(
      id: map['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      duration: Duration(milliseconds: map['duration'] as int),
      audioPath: map['audio_path'] as String,
      transcript: map['transcript'] as String?,
      title: map['title'] as String?,
      summary: map['summary'] as String?,
      actionItems: parsedActionItems,
      status: NoteStatusX.fromDbString(map['status'] as String? ?? 'recorded'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timestamp == other.timestamp &&
          duration == other.duration &&
          audioPath == other.audioPath &&
          transcript == other.transcript &&
          title == other.title &&
          summary == other.summary &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      timestamp.hashCode ^
      duration.hashCode ^
      audioPath.hashCode ^
      transcript.hashCode ^
      title.hashCode ^
      summary.hashCode ^
      status.hashCode;

  @override
  String toString() {
    return 'Note(id: $id, timestamp: $timestamp, duration: $duration, audioPath: $audioPath, title: $title, status: $status)';
  }
}
