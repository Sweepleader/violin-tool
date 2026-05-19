class TraceEntry {
  final String id;
  final String source;
  final String action;
  final Map<String, dynamic>? input;
  final Map<String, dynamic>? output;
  final int durationMs;
  final bool success;
  final DateTime timestamp;

  const TraceEntry({
    required this.id,
    required this.source,
    required this.action,
    this.input,
    this.output,
    required this.durationMs,
    required this.success,
    required this.timestamp,
  });
}

class TraceLogger {
  final List<TraceEntry> _entries = [];
  int _idCounter = 0;

  List<TraceEntry> get entries => _entries.toList();

  Future<TraceEntry> logAction({
    required String source,
    required String action,
    Map<String, dynamic>? input,
    Map<String, dynamic>? output,
    required int durationMs,
    required bool success,
  }) async {
    final entry = TraceEntry(
      id: 'trace_${_idCounter++}',
      source: source,
      action: action,
      input: input,
      output: output,
      durationMs: durationMs,
      success: success,
      timestamp: DateTime.now(),
    );
    _entries.add(entry);
    return entry;
  }

  List<TraceEntry> getBySource(String source) =>
      _entries.where((e) => e.source == source).toList();

  void clear() => _entries.clear();
}
