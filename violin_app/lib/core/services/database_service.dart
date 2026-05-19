import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path/path.dart' as p;

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

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'duration_minutes': durationMinutes,
        'plugin_id': pluginId,
      };

  factory PracticeSession.fromMap(Map<String, dynamic> map) =>
      PracticeSession(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        durationMinutes: map['duration_minutes'] as int,
        pluginId: map['plugin_id'] as String,
      );
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

  Map<String, dynamic> toMap() => {
        'title': title,
        'composer': composer,
        'difficulty': difficulty,
        'status': status,
      };

  factory Piece.fromMap(Map<String, dynamic> map) => Piece(
        id: map['id'] as int?,
        title: map['title'] as String,
        composer: map['composer'] as String,
        difficulty: map['difficulty'] as int,
        status: map['status'] as String? ?? 'todo',
      );
}

class AppDatabase {
  final Database _db;

  AppDatabase._(this._db);

  static Future<AppDatabase> open(String path) async {
    _ensureFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      p.join(path, 'violin.db'),
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    return AppDatabase._(db);
  }

  static Future<AppDatabase> memory() async {
    _ensureFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    return AppDatabase._(db);
  }

  static void _ensureFfiInit() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE practice_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        plugin_id TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pieces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        composer TEXT NOT NULL,
        difficulty INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'todo'
      )
    ''');
  }

  Future<List<PracticeSession>> get allPracticeSessions async {
    final maps = await _db.query('practice_sessions', orderBy: 'date DESC');
    return maps.map(PracticeSession.fromMap).toList();
  }

  Future<void> insertPracticeSession({
    required DateTime date,
    required int durationMinutes,
    required String pluginId,
  }) async {
    await _db.insert('practice_sessions', {
      'date': date.toIso8601String(),
      'duration_minutes': durationMinutes,
      'plugin_id': pluginId,
    });
  }

  Future<List<Piece>> get allPieces async {
    final maps = await _db.query('pieces', orderBy: 'title');
    return maps.map(Piece.fromMap).toList();
  }

  Future<int> insertPiece({
    required String title,
    required String composer,
    required int difficulty,
    String status = 'todo',
  }) async {
    return _db.insert('pieces', {
      'title': title,
      'composer': composer,
      'difficulty': difficulty,
      'status': status,
    });
  }

  Future<Piece?> getPiece(int id) async {
    final maps = await _db.query('pieces', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Piece.fromMap(maps.first);
  }

  Future<void> close() async => _db.close();
}
