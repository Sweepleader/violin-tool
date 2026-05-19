import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/core/services/database_service.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() async {
      db = await AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('practiceSessions is initially empty', () async {
      final sessions = await db.allPracticeSessions;
      expect(sessions, isEmpty);
    });

    test('inserts and retrieves a practice session', () async {
      await db.insertPracticeSession(
        date: DateTime(2026, 5, 16),
        durationMinutes: 30,
        pluginId: 'tuner',
      );
      final sessions = await db.allPracticeSessions;
      expect(sessions.length, 1);
      expect(sessions.first.durationMinutes, 30);
      expect(sessions.first.pluginId, 'tuner');
    });

    test('pieces is initially empty', () async {
      final pieces = await db.allPieces;
      expect(pieces, isEmpty);
    });

    test('inserts and retrieves a piece', () async {
      final id = await db.insertPiece(
        title: 'Minuet in G',
        composer: 'Bach',
        difficulty: 2,
      );
      final piece = await db.getPiece(id);
      expect(piece!.title, 'Minuet in G');
      expect(piece.composer, 'Bach');
      expect(piece.difficulty, 2);
      expect(piece.status, 'todo');
    });
  });
}
