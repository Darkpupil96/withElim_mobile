import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../models/bible_search_result.dart';

class BibleVerse {
  final int bookId;
  final int chapter;
  final int verse;
  final String text;
  final String versionCode;

  const BibleVerse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.versionCode,
  });

  factory BibleVerse.fromMap(Map<String, Object?> map) {
    return BibleVerse(
      bookId: map['book_id'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      text: map['text'] as String,
      versionCode: map['version_code'] as String,
    );
  }
}

class BibleDb {
  static const _assetPath = 'assets/data/bible_flutter.sqlite';
  static const _dbFileName = 'bible_flutter.sqlite';

  static Database? _db;

  Future<Database> database() async {
    if (_db != null) return _db!;

    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, _dbFileName);

    final exists = await databaseExists(dbPath);
    if (!exists) {
      await Directory(p.dirname(dbPath)).create(recursive: true);
      final data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    _db = await openDatabase(dbPath, readOnly: false);
    return _db!;
  }

  Future<List<BibleVerse>> getChapter({
    required int bookId,
    required int chapter,
    required String versionCode,
  }) async {
    final db = await database();

    final rows = await db.query(
      'verses',
      columns: ['version_code', 'book_id', 'chapter', 'verse', 'text'],
      where: 'version_code = ? AND book_id = ? AND chapter = ?',
      whereArgs: [versionCode, bookId, chapter],
      orderBy: 'verse ASC',
    );

    return rows.map(BibleVerse.fromMap).toList();
  }

 Future<List<BibleSearchResult>> searchVerses({
  required String query,
  required String versionCode,
  int limit = 3000,
}) async {
  final db = await database();

  final tokens = query
      .trim()
      .split(RegExp(r'\s+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  if (tokens.isEmpty) return const [];

  List<Map<String, Object?>> rows = [];

  // 先 AND
  final andWhereParts = <String>['version_code = ?'];
  final andWhereArgs = <Object>[versionCode];

  for (final token in tokens) {
    andWhereParts.add('text LIKE ?');
    andWhereArgs.add('%$token%');
  }
  andWhereArgs.add(limit);

  rows = await db.rawQuery(
    '''
    SELECT book_id, chapter, verse, text, version_code
    FROM verses
    WHERE ${andWhereParts.join(' AND ')}
    ORDER BY book_id ASC, chapter ASC, verse ASC
    LIMIT ?
    ''',
    andWhereArgs,
  );

  // 如果 AND 没结果，再 OR
  if (rows.isEmpty && tokens.length > 1) {
    final orWhereArgs = <Object>[versionCode];
    final likeParts = <String>[];

    for (final token in tokens) {
      likeParts.add('text LIKE ?');
      orWhereArgs.add('%$token%');
    }
    orWhereArgs.add(limit);

    rows = await db.rawQuery(
      '''
      SELECT book_id, chapter, verse, text, version_code
      FROM verses
      WHERE version_code = ?
        AND (${likeParts.join(' OR ')})
      ORDER BY book_id ASC, chapter ASC, verse ASC
      LIMIT ?
      ''',
      orWhereArgs,
    );
  }

  return rows.map((e) => BibleSearchResult.fromMap(e)).toList();
}
}