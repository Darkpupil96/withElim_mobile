import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_lang.dart';
import '../data/bible/bible_db.dart';
import '../data/bible/bible_repository.dart';
import '../models/bible_search_result.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialWord = '',
  });

  final String initialWord;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  late final BibleRepository _repo;

  Timer? _debounce;
  bool _loading = false;
  String _keyword = '';
  List<BibleSearchResult> _results = const [];

  /// 当前展开的书
  final Set<int> _expandedBooks = <int>{};

  /// 当前展开的章节组 key，格式：bookId-chapter
  final Set<String> _expandedChapters = <String>{};

  static const List<String> bookNamesEn = [
    "Genesis",
    "Exodus",
    "Leviticus",
    "Numbers",
    "Deuteronomy",
    "Joshua",
    "Judges",
    "Ruth",
    "1 Samuel",
    "2 Samuel",
    "1 Kings",
    "2 Kings",
    "1 Chronicles",
    "2 Chronicles",
    "Ezra",
    "Nehemiah",
    "Esther",
    "Job",
    "Psalms",
    "Proverbs",
    "Ecclesiastes",
    "Song of Solomon",
    "Isaiah",
    "Jeremiah",
    "Lamentations",
    "Ezekiel",
    "Daniel",
    "Hosea",
    "Joel",
    "Amos",
    "Obadiah",
    "Jonah",
    "Micah",
    "Nahum",
    "Habakkuk",
    "Zephaniah",
    "Haggai",
    "Zechariah",
    "Malachi",
    "Matthew",
    "Mark",
    "Luke",
    "John",
    "Acts",
    "Romans",
    "1 Corinthians",
    "2 Corinthians",
    "Galatians",
    "Ephesians",
    "Philippians",
    "Colossians",
    "1 Thessalonians",
    "2 Thessalonians",
    "1 Timothy",
    "2 Timothy",
    "Titus",
    "Philemon",
    "Hebrews",
    "James",
    "1 Peter",
    "2 Peter",
    "1 John",
    "2 John",
    "3 John",
    "Jude",
    "Revelation"
  ];

  static const List<String> bookNamesCn = [
    "创世记",
    "出埃及记",
    "利未记",
    "民数记",
    "申命记",
    "约书亚记",
    "士师记",
    "路得记",
    "撒母耳记上",
    "撒母耳记下",
    "列王纪上",
    "列王纪下",
    "历代志上",
    "历代志下",
    "以斯拉记",
    "尼希米记",
    "以斯帖记",
    "约伯记",
    "诗篇",
    "箴言",
    "传道书",
    "雅歌",
    "以赛亚书",
    "耶利米书",
    "耶利米哀歌",
    "以西结书",
    "但以理书",
    "何西阿书",
    "约珥书",
    "阿摩司书",
    "俄巴底亚书",
    "约拿书",
    "弥迦书",
    "那鸿书",
    "哈巴谷书",
    "西番雅书",
    "哈该书",
    "撒迦利亚书",
    "玛拉基书",
    "马太福音",
    "马可福音",
    "路加福音",
    "约翰福音",
    "使徒行传",
    "罗马书",
    "哥林多前书",
    "哥林多后书",
    "加拉太书",
    "以弗所书",
    "腓立比书",
    "歌罗西书",
    "帖撒罗尼迦前书",
    "帖撒罗尼迦后书",
    "提摩太前书",
    "提摩太后书",
    "提多书",
    "腓利门书",
    "希伯来书",
    "雅各书",
    "彼得前书",
    "彼得后书",
    "约翰一书",
    "约翰二书",
    "约翰三书",
    "犹大书",
    "启示录"
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWord);
    _repo = BibleRepository(BibleDb());

    if (widget.initialWord.trim().isNotEmpty) {
      _keyword = widget.initialWord.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchNow(_keyword);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _normalizeLang(String? raw) {
    switch (raw) {
      case 'cn':
      case 't_cn':
        return 't_cn';
      case 'kjv':
      case 't_kjv':
      default:
        return 't_kjv';
    }
  }

  String _bookName(int bookId, bool isCn) {
    if (bookId < 1 || bookId > 66) return '';
    return isCn ? bookNamesCn[bookId - 1] : bookNamesEn[bookId - 1];
  }

  String _chapterKey(int bookId, int chapter) => '$bookId-$chapter';

  Future<void> _searchNow(String keyword) async {
    final trimmed = keyword.trim();
    final lang = _normalizeLang(LangScope.of(context).lang);

    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _keyword = '';
        _results = const [];
        _loading = false;
        _expandedBooks.clear();
        _expandedChapters.clear();
      });
      return;
    }

    setState(() {
      _keyword = trimmed;
      _loading = true;
    });

    try {
      final rows = await _repo.searchVerses(
        keyword: trimmed,
        lang: lang,
        limit: 200,
      );

      if (!mounted) return;

      final nextExpandedBooks = <int>{};
      final nextExpandedChapters = <String>{};

      if (rows.isNotEmpty) {
        final first = rows.first;
        nextExpandedBooks.add(first.bookId);
        nextExpandedChapters.add(_chapterKey(first.bookId, first.chapter));
      }

      setState(() {
        _results = rows;
        _loading = false;

        _expandedBooks
          ..clear()
          ..addAll(nextExpandedBooks);

        _expandedChapters
          ..clear()
          ..addAll(nextExpandedChapters);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
        _expandedBooks.clear();
        _expandedChapters.clear();
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchNow(value);
    });
  }

  void _toggleBook(int bookId) {
    setState(() {
      if (_expandedBooks.contains(bookId)) {
        _expandedBooks.remove(bookId);
      } else {
        _expandedBooks.add(bookId);
      }
    });
  }

  void _toggleChapter(String key) {
    setState(() {
      if (_expandedChapters.contains(key)) {
        _expandedChapters.remove(key);
      } else {
        _expandedChapters.add(key);
      }
    });
  }

  Map<int, Map<int, List<BibleSearchResult>>> _groupByBookAndChapter(
    List<BibleSearchResult> rows,
  ) {
    final result = <int, Map<int, List<BibleSearchResult>>>{};

    for (final row in rows) {
      result.putIfAbsent(row.bookId, () => <int, List<BibleSearchResult>>{});
      result[row.bookId]!
          .putIfAbsent(row.chapter, () => <BibleSearchResult>[]);
      result[row.bookId]![row.chapter]!.add(row);
    }

    return result;
  }

  TextSpan _highlightTextSpan({
    required String source,
    required String query,
    required TextStyle normalStyle,
    required TextStyle highlightStyle,
    required bool caseSensitive,
  }) {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (tokens.isEmpty) {
      return TextSpan(text: source, style: normalStyle);
    }

    // 长词优先，避免短词先匹配把长词切碎
    tokens.sort((a, b) => b.length.compareTo(a.length));

    final pattern = tokens.map(RegExp.escape).join('|');
    final reg = RegExp(
      pattern,
      caseSensitive: caseSensitive,
      unicode: true,
    );

    final spans = <TextSpan>[];
    int start = 0;

    for (final m in reg.allMatches(source)) {
      if (m.start > start) {
        spans.add(TextSpan(
          text: source.substring(start, m.start),
          style: normalStyle,
        ));
      }

      spans.add(TextSpan(
        text: source.substring(m.start, m.end),
        style: highlightStyle,
      ));

      start = m.end;
    }

    if (start < source.length) {
      spans.add(TextSpan(
        text: source.substring(start),
        style: normalStyle,
      ));
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final isCn = _normalizeLang(LangScope.of(context).lang) == 't_cn';
    final cs = Theme.of(context).colorScheme;

    final grouped = _groupByBookAndChapter(_results);
    final bookIds = grouped.keys.toList()..sort();

    final chapterCount = grouped.values.fold<int>(
      0,
      (sum, chapterMap) => sum + chapterMap.length,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _searchNow,
            decoration: InputDecoration(
              hintText: isCn ? '搜索经文内容' : 'Search verses',
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_keyword.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    isCn
                        ? '共 ${_results.length} 节，分为 ${bookIds.length} 卷书、${chapterCount} 章'
                        : '${_results.length} verses in ${bookIds.length} books and $chapterCount chapters',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _keyword.isEmpty
                    ? Center(
                        child: Text(
                          isCn ? '输入关键词开始搜索' : 'Type keywords to search',
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              isCn ? '没有找到相关经文' : 'No verses found',
                            ),
                          )
                        : ListView.builder(
                            itemCount: bookIds.length,
                            itemBuilder: (context, index) {
                              final bookId = bookIds[index];
                              final chapterMap = grouped[bookId]!;
                              final chapterKeys = chapterMap.keys.toList()
                                ..sort();

                              final bookExpanded =
                                  _expandedBooks.contains(bookId);

                              final totalVersesInBook = chapterMap.values
                                  .fold<int>(0, (sum, list) => sum + list.length);

                              return Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _toggleBook(bookId),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 14, 16, 14),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                isCn
                                                    ? '${_bookName(bookId, true)}（${chapterKeys.length}章，${totalVersesInBook}节）'
                                                    : '${_bookName(bookId, false)} (${chapterKeys.length} chapters, $totalVersesInBook verses)',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 17,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              bookExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (bookExpanded)
                                    ...chapterKeys.map((chapter) {
                                      final items = chapterMap[chapter]!;
                                      final chapterKey =
                                          _chapterKey(bookId, chapter);
                                      final chapterExpanded =
                                          _expandedChapters.contains(chapterKey);

                                      final normalStyle = TextStyle(
                                        color: cs.onSurfaceVariant,
                                        height: 1.5,
                                        fontSize: 15,
                                      );

                                      final highlightStyle = const TextStyle(
                                        color: Color(0xFF2E7D32),
                                        backgroundColor: Color(0xFFE8F5E9),
                                        fontWeight: FontWeight.w700,
                                        height: 1.5,
                                        fontSize: 15,
                                      );

                                      return Column(
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () =>
                                                  _toggleChapter(chapterKey),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        28, 12, 16, 12),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        isCn
                                                            ? '$chapter 章'
                                                            : 'Chapter $chapter',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      isCn
                                                          ? '${items.length} 节'
                                                          : '${items.length} verses',
                                                      style: TextStyle(
                                                        color:
                                                            cs.onSurfaceVariant,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      chapterExpanded
                                                          ? Icons
                                                              .keyboard_arrow_up_rounded
                                                          : Icons
                                                              .keyboard_arrow_down_rounded,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (chapterExpanded)
                                            ...items.map((item) {
                                              return InkWell(
                                                onTap: () {
                                                  Navigator.of(context).pop({
                                                    'b': item.bookId,
                                                    'c': item.chapter,
                                                    'v': item.verse,
                                                  });
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          40, 4, 16, 12),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      SizedBox(
                                                        width: 42,
                                                        child: Text(
                                                          '[${item.verse}]',
                                                          style: TextStyle(
                                                            color: cs.primary,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: RichText(
                                                          text:
                                                              _highlightTextSpan(
                                                            source: item.text,
                                                            query: _keyword,
                                                            normalStyle:
                                                                normalStyle,
                                                            highlightStyle:
                                                                highlightStyle,
                                                            caseSensitive: isCn,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                        ],
                                      );
                                    }),
                                  const Divider(height: 1),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}