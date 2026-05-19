class PracticeSession {
  final int? id;
  final DateTime date;
  final int durationMinutes;
  final String pluginId;

  const PracticeSession({
    this.id,
    required this.date,
    required this.durationMinutes,
    required this.pluginId,
  });
}

class Piece {
  final int? id;
  final String title;
  final String composer;
  final int difficulty;
  final String status;

  const Piece({
    this.id,
    required this.title,
    required this.composer,
    required this.difficulty,
    this.status = 'todo',
  });

  Piece copyWith({
    int? id,
    String? title,
    String? composer,
    int? difficulty,
    String? status,
  }) =>
      Piece(
        id: id ?? this.id,
        title: title ?? this.title,
        composer: composer ?? this.composer,
        difficulty: difficulty ?? this.difficulty,
        status: status ?? this.status,
      );
}

class AppDatabase {
  final List<PracticeSession> _sessions = [];
  final List<Piece> _pieces = [];
  int _nextSessionId = 1;
  int _nextPieceId = 1;

  static Future<AppDatabase> open(String path) async {
    // TODO: replace with SQLite when network access is restored
    return AppDatabase();
  }

  static Future<AppDatabase> memory() async {
    return AppDatabase();
  }

  Future<List<PracticeSession>> get allPracticeSessions async {
    return _sessions.toList();
  }

  Future<void> insertPracticeSession({
    required DateTime date,
    required int durationMinutes,
    required String pluginId,
  }) async {
    _sessions.add(PracticeSession(
      id: _nextSessionId++,
      date: date,
      durationMinutes: durationMinutes,
      pluginId: pluginId,
    ));
  }

  Future<List<Piece>> get allPieces async {
    return _pieces.toList();
  }

  Future<int> insertPiece({
    required String title,
    required String composer,
    required int difficulty,
    String status = 'todo',
  }) async {
    final id = _nextPieceId++;
    _pieces.add(Piece(
      id: id,
      title: title,
      composer: composer,
      difficulty: difficulty,
      status: status,
    ));
    return id;
  }

  Future<Piece?> getPiece(int id) async {
    try {
      return _pieces.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    _sessions.clear();
    _pieces.clear();
  }
}
