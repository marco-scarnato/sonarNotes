/// Represents the current processing state of a [Note] within the pipeline.
enum NoteStatus {
  /// Audio has been recorded and saved locally.
  recorded,

  /// Speech-to-Text (STT) transcription is in progress.
  transcribing,

  /// Small Language Model (SLM) summarization/action items extraction in progress.
  summarizing,

  /// All processing steps completed successfully.
  done,
}

extension NoteStatusX on NoteStatus {
  /// Converts [NoteStatus] enum value to a database string.
  String toDbString() => name;

  /// Parses a database string to a [NoteStatus] enum value.
  static NoteStatus fromDbString(String value) {
    return NoteStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NoteStatus.recorded,
    );
  }
}
