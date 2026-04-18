// lib/pages/bible.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;

import '../models/search_bar.dart';
import '../app/app_lang.dart';
import '../app/auth_scope.dart';
import 'book_chapter_picker.dart';
import '../data/bible/bible_db.dart';
import '../data/bible/bible_repository.dart';

const _baseUrl = 'https://withelim.com';
typedef BibleLang = String; // 't_kjv' / 't_cn'

String _normalizeBibleLang(String? raw) {
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

// 书卷英文/中文名 & 章数
const List<String> bookNamesEn = [
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

const List<String> bookNamesCn = [
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

const List<int> _chapterCounts = [
  50,
  40,
  27,
  36,
  34,
  24,
  21,
  4,
  31,
  24,
  22,
  25,
  29,
  36,
  10,
  13,
  10,
  42,
  150,
  31,
  12,
  8,
  66,
  52,
  5,
  48,
  12,
  14,
  3,
  9,
  1,
  4,
  7,
  3,
  3,
  3,
  2,
  14,
  4,
  28,
  16,
  24,
  21,
  28,
  16,
  16,
  13,
  6,
  6,
  4,
  4,
  5,
  3,
  6,
  4,
  3,
  1,
  13,
  5,
  5,
  3,
  5,
  1,
  1,
  1,
  22
];

class BibleJumpController {
  void Function(int b, int c, int v)? _jump;
  void attach(void Function(int, int, int) f) => _jump = f;
  void detach() => _jump = null;
  void jumpTo(int b, int c, int v) => _jump?.call(b, c, v);
}

class BiblePage extends StatefulWidget {
  const BiblePage({
    super.key,
    this.bookId = 41,
    this.chapter = 6,
    this.controller,
  });

  final int bookId;
  final int chapter;
  final BibleJumpController? controller;

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  late int _bookId;
  late int _chapter;
  late BibleLang _lang;

  late Future<List<BibleVerse>> _future;
  final BibleRepository _repo = BibleRepository(BibleDb());

  final ScrollController _scrollCtrl = ScrollController();

  final Map<int, GlobalKey> _verseKeys = {};
  int? _pendingVerse;
  String? _lastHandledJumpKey;

  bool _depsReady = false;
  bool _restoredOnce = false;
  Timer? _syncDebounce;
  bool _wasAuthed = false;

  final Set<int> _highlightedVerses = <int>{};
  final Map<int, Timer> _highlightTimers = {};
  bool _keepSearchHighlightUntilScroll = false;

  final Set<int> _selectedVerseNumbers = <int>{};
  int? _activeVerseNumber;
  final bool _isPrayerPrivate = false;

  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
    _chapter = widget.chapter;
    _lang = 't_kjv';
    _future = Future.value(const <BibleVerse>[]);
    widget.controller?.attach(_jumpToVerseFromOutside);
  }

  @override
  void didUpdateWidget(covariant BiblePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(_jumpToVerseFromOutside);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    for (final t in _highlightTimers.values) {
      t.cancel();
    }
    _highlightTimers.clear();
    _syncDebounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _jumpToVerseFromOutside(int b, int c, int v) {
    _lastHandledJumpKey = '$b-$c-$v';
    _pendingVerse = v;

    final needReload = (_bookId != b) || (_chapter != c);
    if (needReload) {
      _gotoChapter(b, c).whenComplete(() {
        if (!mounted || _pendingVerse == null) return;
        _tryScrollToPendingVerse();
      });
    } else {
      _tryScrollToPendingVerse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = AuthScope.of(context);
    final newLang = _normalizeBibleLang(LangScope.of(context).lang);

    if (!_depsReady) {
      _lang = newLang;

      if (auth.isAuthed) {
        _wasAuthed = true;
        _initFromServerFirst();
      } else {
        setState(() {
          _depsReady = true;
          _future = _fetchChapter();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLinkIfAny());
      }
      return;
    }

    if (auth.isAuthed && !_wasAuthed) {
      _wasAuthed = true;
      _restoredOnce = false;
      _initFromServerFirst();
      return;
    }

    if (!auth.isAuthed && _wasAuthed) {
      _wasAuthed = false;
    }

    if (newLang != _lang) {
      setState(() {
        _lang = newLang;
        _future = _fetchChapter();
      });
      _maybeSyncLanguage(newLang);
    }

    _handleDeepLinkIfAny();
  }

  Future<void> _initFromServerFirst() async {
    await _tryRestoreFromServer(firstInit: true);
    if (!mounted) return;
    setState(() {
      _depsReady = true;
      _future = _fetchChapter();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLinkIfAny());
  }

  Future<List<BibleVerse>> _fetchChapter() async {
    _verseKeys.clear();
    return _repo.getChapter(
      bookId: _bookId,
      chapter: _chapter,
      lang: _lang,
    );
  }

  void _flashVerse(
    int v, {
    Duration duration = const Duration(seconds: 1),
    bool keepUntilScroll = false,
  }) {
    _highlightTimers[v]?.cancel();
    _highlightTimers.remove(v);

    setState(() {
      _highlightedVerses.add(v);
      if (keepUntilScroll) {
        _keepSearchHighlightUntilScroll = true;
      }
    });

    if (keepUntilScroll) return;

    _highlightTimers[v] = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _highlightedVerses.remove(v);
      });
      _highlightTimers.remove(v);
    });
  }

  void _clearSearchHighlightOnScroll() {
    if (!_keepSearchHighlightUntilScroll) return;

    for (final t in _highlightTimers.values) {
      t.cancel();
    }
    _highlightTimers.clear();

    if (!mounted) return;
    setState(() {
      _highlightedVerses.clear();
      _keepSearchHighlightUntilScroll = false;
    });
  }

  Future<void> _tryRestoreFromServer({bool firstInit = false}) async {
    if (_restoredOnce) return;
    _restoredOnce = true;

    final auth = AuthScope.of(context);
    if (!auth.isAuthed) return;

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: {'Authorization': 'Bearer ${auth.token!}'},
      );
      if (res.statusCode != 200) return;

      final j = json.decode(res.body) as Map<String, dynamic>;
      final int? rb = (j['reading_book'] as num?)?.toInt();
      final int? rc = (j['reading_chapter'] as num?)?.toInt();
      final String? serverLangRaw = j['language'] as String?;
      final String serverLang = _normalizeBibleLang(serverLangRaw);

      if (serverLang != _lang) {
        LangScope.of(context).setLang(serverLang);
        _lang = serverLang;
      }

      if (rb != null && rc != null && rb >= 1 && rb <= 66 && rc >= 1) {
        _bookId = rb;
        _chapter = rc;
        if (!firstInit) {
          setState(() {
            _future = _fetchChapter();
          });
          _scrollToTop();
        }
      }
    } catch (_) {}
  }

  Map<String, String> _authedJsonHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<void> _maybeSyncLanguage(String lang) async {
    final auth = AuthScope.of(context);
    if (!auth.isAuthed) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/auth/update'),
        headers: _authedJsonHeaders(auth.token!),
        body: jsonEncode({'language': lang}),
      );
    } catch (_) {}
  }

  void _scheduleSyncReading() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 300), _maybeSyncReading);
  }

  Future<void> _maybeSyncReading() async {
    final auth = AuthScope.of(context);
    if (!auth.isAuthed) return;

    auth.updateReading(book: _bookId, chapter: _chapter);

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/auth/update-reading'),
        headers: _authedJsonHeaders(auth.token!),
        body: jsonEncode({
          'reading_book': _bookId,
          'reading_chapter': _chapter,
        }),
      );
    } catch (_) {}
  }

  Future<void> _gotoChapter(int b, int c) async {
    _clearVerseSelection();
    setState(() {
      _bookId = b;
      _chapter = c;
      _future = _fetchChapter();
    });
    await _future;
    _scheduleSyncReading();
  }

  void _tryScrollToPendingVerse({int retries = 12}) {
    final v = _pendingVerse;
    if (v == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingVerse == null) return;

      final success = _scrollToVerse(_pendingVerse!);
      if (success) {
        _flashVerse(_pendingVerse!, keepUntilScroll: true);
        _pendingVerse = null;
        return;
      }

      if (retries > 0) {
        Future.delayed(const Duration(milliseconds: 50), () {
          _tryScrollToPendingVerse(retries: retries - 1);
        });
      }
    });
  }

  bool _scrollToVerse(int v) {
    final key = _verseKeys[v];
    final ctx = key?.currentContext;
    if (ctx == null) return false;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
    return true;
  }

  void _handleDeepLinkIfAny() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final int b = (args['b'] as num?)?.toInt() ?? 1;
    final int c = (args['c'] as num?)?.toInt() ?? 1;
    final int v = (args['v'] as num?)?.toInt() ?? 1;

    final jumpKey = '$b-$c-$v';
    if (_lastHandledJumpKey == jumpKey) return;
    _lastHandledJumpKey = jumpKey;

    _pendingVerse = v;

    final bool needReload = (_bookId != b) || (_chapter != c);

    if (needReload) {
      _gotoChapter(b, c).whenComplete(() {
        if (!mounted || _pendingVerse == null) return;
        _tryScrollToPendingVerse();
      });
    } else {
      _tryScrollToPendingVerse();
    }
  }

  void _scrollToTop() {
    void doJump() {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0);
      }
    }

    if (_scrollCtrl.hasClients) {
      doJump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => doJump());
    }
  }

  void _reload() {
    _clearVerseSelection();
    setState(() {
      _future = _fetchChapter();
    });
    _scrollToTop();
  }

  void _goPrev() {
    _clearVerseSelection();
    if (_chapter > 1) {
      setState(() {
        _chapter -= 1;
        _future = _fetchChapter();
      });
      _scrollToTop();
      _scheduleSyncReading();
      return;
    }

    if (_bookId > 1) {
      setState(() {
        _bookId -= 1;
        _chapter = _chapterCounts[_bookId - 1];
        _future = _fetchChapter();
      });
      _scrollToTop();
      _scheduleSyncReading();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already at the first chapter')),
      );
    }
  }

  void _goNext() {
    _clearVerseSelection();
    final max = _chapterCounts[_bookId - 1];
    if (_chapter < max) {
      setState(() {
        _chapter += 1;
        _future = _fetchChapter();
      });
      _scrollToTop();
      _scheduleSyncReading();
      return;
    }

    if (_bookId < 66) {
      setState(() {
        _bookId += 1;
        _chapter = 1;
        _future = _fetchChapter();
      });
      _scrollToTop();
      _scheduleSyncReading();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already at the last chapter')),
      );
    }
  }

  String _chapterCn(int n) {
    assert(n >= 1 && n <= 999);
    const numerals = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

    String under100(int x, {bool forceTenOne = false}) {
      if (x < 10) return numerals[x];
      if (x < 20) {
        final ones = x % 10;
        final tenHead = forceTenOne ? '一十' : '十';
        return '$tenHead${ones == 0 ? '' : numerals[ones]}';
      }
      final tens = x ~/ 10;
      final ones = x % 10;
      return '${numerals[tens]}十${ones == 0 ? '' : numerals[ones]}';
    }

    String toCn(int x) {
      if (x < 100) return under100(x);
      final hundreds = x ~/ 100;
      final rest = x % 100;
      if (rest == 0) return '${numerals[hundreds]}百';
      if (rest < 10) return '${numerals[hundreds]}百零${numerals[rest]}';
      return '${numerals[hundreds]}百${under100(rest, forceTenOne: true)}';
    }

    return '第${toCn(n)}章';
  }

  String _t(String en, String cn) => _lang == 't_cn' ? cn : en;

  String get _currentBookName =>
      _lang == 't_cn' ? bookNamesCn[_bookId - 1] : bookNamesEn[_bookId - 1];

  void _clearVerseSelection() {
    if (_selectedVerseNumbers.isEmpty && _activeVerseNumber == null) return;
    setState(() {
      _selectedVerseNumbers.clear();
      _activeVerseNumber = null;
    });
  }

  void _toggleVerseSelection(BibleVerse verse) {
    final auth = AuthScope.of(context);
    if (!auth.isAuthed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Please log in before submitting a prayer.', '请先登录后再提交祷告。'),
          ),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedVerseNumbers.contains(verse.verse)) {
        _selectedVerseNumbers.remove(verse.verse);
        if (_activeVerseNumber == verse.verse) {
          if (_selectedVerseNumbers.isEmpty) {
            _activeVerseNumber = null;
          } else {
            final sorted = _selectedVerseNumbers.toList()..sort();
            _activeVerseNumber = sorted.last;
          }
        }
      } else {
        _selectedVerseNumbers.add(verse.verse);
        _activeVerseNumber = verse.verse;
      }
    });
  }

  Future<void> _openPrayerDialog(List<BibleVerse> allVerses) async {
    final auth = AuthScope.of(context);
    if (!auth.isAuthed || _selectedVerseNumbers.isEmpty) return;

    final selected = allVerses
        .where((v) => _selectedVerseNumbers.contains(v.verse))
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));

    if (selected.isEmpty) return;

    final bool? submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _PrayerDialog(
          lang: _lang,
          bookId: _bookId,
          chapter: _chapter,
          currentBookName: _currentBookName,
          isPrayerPrivate: _isPrayerPrivate,
          selected: selected,
          token: auth.token!,
          chapterCnBuilder: _chapterCn,
          tr: _t,
        );
      },
    );

    if (!mounted) return;

    if (submitted == true) {
      _clearVerseSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Prayer submitted successfully!', '祷告已提交！'))),
      );
    }
  }

  Future<void> _openBookChapterPicker() async {
    final picked = await Navigator.push<PickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => BookChapterPickerPage(
          lang: _lang,
          initialBookId: _bookId,
          initialChapter: _chapter,
          bookNamesEn: bookNamesEn,
          bookNamesCn: bookNamesCn,
          chapterCounts: _chapterCounts,
        ),
      ),
    );

    if (picked != null) {
      _clearVerseSelection();
      setState(() {
        _bookId = picked.bookId;
        _chapter = picked.chapter;
        _future = _fetchChapter();
      });
      _scrollToTop();
      _scheduleSyncReading();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: AppSearchBar(
              onJumpToVerse: (b, c, v) {
                debugPrint(
                  'Bible search jump: $b-$c-$v, controller=${widget.controller != null}',
                );
                widget.controller?.jumpTo(b, c, v);
              },
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _clearVerseSelection,
              child: !_depsReady
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<BibleVerse>>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return _ErrorBox(
                            message: 'Failed to load: ${snap.error}',
                            onRetry: _reload,
                          );
                        }

                        final verses = snap.data ?? const <BibleVerse>[];
                        if (verses.isEmpty) {
                          return _ErrorBox(
                            message: 'No verses returned.',
                            onRetry: _reload,
                          );
                        }

                        final textTheme = Theme.of(context).textTheme;
                        final isCn = _lang == 't_cn';
                        final headerTitle = isCn
                            ? _chapterCn(_chapter)
                            : '${bookNamesEn[_bookId - 1]} $_chapter';

                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is UserScrollNotification &&
                                notification.direction != ScrollDirection.idle) {
                              _clearSearchHighlightOnScroll();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            cacheExtent: 20000,
                            padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
                            itemCount: verses.length + 1,
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 14, bottom: 28),
                                  child: Column(
                                    children: [
                                      Text(
                                        isCn
                                            ? '${bookNamesCn[_bookId - 1]} $headerTitle'
                                            : headerTitle,
                                        textAlign: TextAlign.center,
                                        style: (isCn
                                                ? textTheme.headlineMedium
                                                : textTheme.displaySmall)
                                            ?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 20),
                                      Center(
                                        child: SizedBox(
                                          width: 240,
                                          child: Divider(
                                            thickness: 1,
                                            height: 1,
                                            color: cs.outlineVariant.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final v = verses[i - 1];

                              return Align(
                                alignment: Alignment.centerLeft,
                                child: KeyedSubtree(
                                  key: _verseKeys.putIfAbsent(v.verse, () => GlobalKey()),
                                  child: _VerseParagraph(
                                    verse: v,
                                    highlighted: _highlightedVerses.contains(v.verse),
                                    selected: _selectedVerseNumbers.contains(v.verse),
                                    active: _activeVerseNumber == v.verse,
                                    onTap: () => _toggleVerseSelection(v),
                                    onCreatePrayer: () => _openPrayerDialog(verses),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
          Divider(
            height: 1,
            color: cs.outlineVariant.withOpacity(.5),
          ),
          Builder(
            builder: (context) {
              final isCn = _lang == 't_cn';
              final label =
                  isCn ? _chapterCn(_chapter) : '${bookNamesEn[_bookId - 1]} $_chapter';
              return _BottomPager(
                label: label,
                onPrev: _goPrev,
                onNext: _goNext,
                onLabelTap: _openBookChapterPicker,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(message, style: TextStyle(color: cs.onErrorContainer)),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _BottomPager extends StatelessWidget {
  const _BottomPager({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onLabelTap,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Material(
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: cs.outlineVariant.withOpacity(.5)),
          ),
          child: InkWell(
            onTap: onLabelTap,
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          onPressed: onPrev,
                          icon: const Icon(Icons.chevron_left_rounded),
                          splashRadius: 22,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          onPressed: onNext,
                          icon: const Icon(Icons.chevron_right_rounded),
                          splashRadius: 22,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerseParagraph extends StatelessWidget {
  const _VerseParagraph({
    required this.verse,
    this.highlighted = false,
    this.selected = false,
    this.active = false,
    this.onTap,
    this.onCreatePrayer,
  });

  final BibleVerse verse;
  final bool highlighted;
  final bool selected;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onCreatePrayer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emphasized = highlighted || selected;

    final body = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 20,
          height: 1.6,
          color: emphasized ? Colors.white : cs.onSurface,
          fontWeight: emphasized ? FontWeight.w500 : FontWeight.w400,
        );

    final numberStyle = body?.copyWith(
      fontSize: 12,
      color: emphasized
          ? Colors.white.withOpacity(0.9)
          : cs.onSurface.withOpacity(.60),
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: emphasized
            ? const Color.fromARGB(255, 71, 116, 88)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '[${verse.verse}]',
                          style: numberStyle,
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: verse.text,
                          style: body,
                        ),
                      ],
                    ),
                  ),
                ),
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onCreatePrayer,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.note_add_outlined,
                          size: 35,
                          color: Color.fromARGB(255, 210, 233, 224),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerDialog extends StatefulWidget {
  const _PrayerDialog({
    required this.lang,
    required this.bookId,
    required this.chapter,
    required this.currentBookName,
    required this.isPrayerPrivate,
    required this.selected,
    required this.token,
    required this.chapterCnBuilder,
    required this.tr,
  });

  final String lang;
  final int bookId;
  final int chapter;
  final String currentBookName;
  final bool isPrayerPrivate;
  final List<BibleVerse> selected;
  final String token;
  final String Function(int) chapterCnBuilder;
  final String Function(String en, String cn) tr;

  @override
  State<_PrayerDialog> createState() => _PrayerDialogState();
}

class _PrayerDialogState extends State<_PrayerDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  late bool _isPrivate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _isPrivate = widget.isPrayerPrivate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Map<String, String> _authedJsonHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<void> _submitPrayer() async {
    if (_isSubmitting) return;

    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.tr('Please enter a title and prayer content.', '请输入祷告标题和内容。'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'is_private': _isPrivate,
        'verses': widget.selected
            .map((v) => {
                  'version': widget.lang,
                  'b': widget.bookId,
                  'c': widget.chapter,
                  'v': v.verse,
                })
            .toList(),
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/api/prayers/'),
        headers: _authedJsonHeaders(widget.token),
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.tr('Submission failed, please try again.', '提交失败，请重试。')} (${res.statusCode})',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.tr('Network error, please try again later.', '网络错误，请稍后再试。'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstFive = widget.selected.take(5).toList();
    final remaining = widget.selected.skip(5).toList();

    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.tr('Write your prayer', '写下你的祷告')),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : _submitPrayer,
                child: Text(
                  _isSubmitting
                      ? widget.tr('Submitting...', '提交中...')
                      : widget.tr('Submit', '提交'),
                ),
              )
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.currentBookName} ${widget.lang == 't_cn' ? widget.chapterCnBuilder(widget.chapter) : 'Chapter ${widget.chapter}'}',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: widget.tr('Prayer Title', '祷告标题'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.tr('Visibility:', '可见性：')),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            value: false,
                            groupValue: _isPrivate,
                            title: Text(widget.tr('Public', '公开')),
                            onChanged: (v) => setState(() => _isPrivate = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            value: true,
                            groupValue: _isPrivate,
                            title: Text(widget.tr('Private', '私密')),
                            onChanged: (v) => setState(() => _isPrivate = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      minLines: 6,
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText: widget.tr('Enter your prayer here', '请输入你的祷告内容'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.tr('Selected verses:', '引用经文：'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...firstFive.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('[${item.verse}] ${item.text}'),
                      ),
                    ),
                    if (remaining.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Text(
                              widget.tr('Remaining:', '其余：'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            ...remaining.map((item) => Text('[${item.verse}]')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}