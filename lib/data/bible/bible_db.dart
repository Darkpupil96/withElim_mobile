import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
}