class BibleSearchResult {
  final int bookId;
  final int chapter;
  final int verse;
  final String text;
  final String lang;

  const BibleSearchResult({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.lang,
  });

factory BibleSearchResult.fromMap(Map<String, dynamic> map) {
  return BibleSearchResult(
    bookId: (map['book_id'] as num).toInt(),
    chapter: (map['chapter'] as num).toInt(),
    verse: (map['verse'] as num).toInt(),
    text: map['text'] as String,
    lang: map['version_code'] as String, // ✅ 修复点
  );
}
}