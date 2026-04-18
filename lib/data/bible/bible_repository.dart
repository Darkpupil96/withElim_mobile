import 'bible_db.dart';

class BibleRepository {
  final BibleDb db;

  BibleRepository(this.db);

  Future<List<BibleVerse>> getChapter({
    required int bookId,
    required int chapter,
    required String lang,
  }) {
    final versionCode = _mapLangToVersionCode(lang);
    return db.getChapter(
      bookId: bookId,
      chapter: chapter,
      versionCode: versionCode,
    );
  }

  String _mapLangToVersionCode(String lang) {
    switch (lang) {
      case 't_cn':
        return 'cn';
      case 't_kjv':
      default:
        return 'kjv';
    }
  }
}