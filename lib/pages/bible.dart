// lib/pages/bible.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/search_bar.dart';
import '../app/app_lang.dart';         // LangScope（语言）
import '../app/auth_scope.dart';       // AuthScope（登录）
import 'book_chapter_picker.dart';     // 书卷章节选择页

const _baseUrl = 'https://withelim.com';
typedef BibleLang = String; // 't_kjv' / 't_cn'

// 书卷英文/中文名 & 章数
const List<String> bookNamesEn = [
  "Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel",
  "1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs",
  "Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos",
  "Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark",
  "Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians",
  "1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter",
  "1 John","2 John","3 John","Jude","Revelation"
];

const List<String> bookNamesCn = [
  "创世记","出埃及记","利未记","民数记","申命记","约书亚记","士师记","路得记","撒母耳记上","撒母耳记下",
  "列王纪上","列王纪下","历代志上","历代志下","以斯拉记","尼希米记","以斯帖记","约伯记","诗篇","箴言",
  "传道书","雅歌","以赛亚书","耶利米书","耶利米哀歌","以西结书","但以理书","何西阿书","约珥书","阿摩司书",
  "俄巴底亚书","约拿书","弥迦书","那鸿书","哈巴谷书","西番雅书","哈该书","撒迦利亚书","玛拉基书","马太福音","马可福音",
  "路加福音","约翰福音","使徒行传","罗马书","哥林多前书","哥林多后书","加拉太书","以弗所书","腓立比书","歌罗西书",
  "帖撒罗尼迦前书","帖撒罗尼迦后书","提摩太前书","提摩太后书","提多书","腓利门书","希伯来书","雅各书","彼得前书","彼得后书",
  "约翰一书","约翰二书","约翰三书","犹大书","启示录"
];

const List<int> _chapterCounts = [
  // OT 39
  50,40,27,36,34,24,21,4,31,24,22,25,29,36,10,13,10,42,150,31,12,8,66,52,5,48,12,14,3,9,1,4,7,3,3,3,2,14,4,
  // NT 27
  28,16,24,21,28,16,16,13,6,6,4,4,5,3,6,4,3,1,13,5,5,3,5,1,1,1,22
];
class BibleJumpController {
  void Function(int b, int c, int v)? _jump;
  void attach(void Function(int,int,int) f) => _jump = f;
  void detach() => _jump = null;
  void jumpTo(int b, int c, int v) => _jump?.call(b, c, v);
  
}

class BiblePage extends StatefulWidget {
  const BiblePage({
    super.key,
    this.bookId = 41, // Mark
    this.chapter = 6, // Mark 6 这是初始化页面，登录用户会被服务端覆盖
    this.controller,      
  });

  final int bookId;
  final int chapter;
  final BibleJumpController? controller; // ← 新增
  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  late int _bookId; //在State 中初始化
  late int _chapter;
  late BibleLang _lang;                // 当前语言（来自全局）
  late Future<List<_Verse>> _future;

  // 滚动控制
  final ScrollController _scrollCtrl = ScrollController();

  // ====== 新增：用于“跳到相关文本”的状态 ======
  final Map<int, GlobalKey> _verseKeys = {}; // v -> key
  int? _pendingVerse;                        // 待滚到的节
  bool _handledDeepLink = false;             // 仅处理一次路由参数

  // 依赖 & 同步控制
  bool _depsReady = false;             // 首次获取全局语言的标记 这个标记用于控制首次加载时的逻辑
  bool _restoredOnce = false;          // 恢复阅读进度只做一次
  Timer? _syncDebounce;                // 阅读进度上传节流，防止频繁点击翻页时多次请求
  bool _wasAuthed = false; // 记录上一次的登录状态
// 🔹临时高亮：支持多节并发高亮（比如快速多次跳转）
  final Set<int> _highlightedVerses = <int>{};
  final Map<int, Timer> _highlightTimers = {};

  // Prayer selection state
  final Set<int> _selectedVerseNumbers = <int>{};
  int? _activeVerseNumber;
  bool _isPrayerPrivate = false;

  // 高亮并在 1s 后恢复
  void _flashVerse(int v, {Duration duration = const Duration(seconds: 1)}) {
    // 若已有定时器，先取消，避免过早清除
    _highlightTimers[v]?.cancel();
    setState(() {
      _highlightedVerses.add(v);
    });
    _highlightTimers[v] = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _highlightedVerses.remove(v);
      });
      _highlightTimers.remove(v);
    });
  }
  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
    _chapter = widget.chapter;
    _lang = 't_kjv';                   // 占位，真正的值在 didChangeDependencies 同步
    _future = Future.value(const <_Verse>[]); // 等待 didChangeDependencies 触发真实请求
    
  }

  /* -------------------- 数据请求 & 同步 -------------------- */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ 注册对 AuthScope 的依赖：后续登录状态变化会触发本方法
    final auth = AuthScope.of(context);
    final newLang = LangScope.of(context).lang;

    if (!_depsReady) { //如果还没准备好
      // 首次初始化：直接按当前状态走一遍
      _lang = newLang;

      if (auth.isAuthed) {
        _wasAuthed = true;
        _initFromServerFirst();   // 先 /api/auth/me，再决定拉哪一章
      } else {
        setState(() {
          _depsReady = true;      // 访客：直接按默认拉
          _future = _fetchChapter();// 用“默认的”书卷+章节+语言拉经文
        });
        // 首次已就绪时尝试处理路由参数
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLinkIfAny());
      }
      return;
    }

    // ✅ 监听“未登录 → 已登录”的过渡：刚登录完也要首帧初始化一次
    if (auth.isAuthed && !_wasAuthed) {
      _wasAuthed = true;
      _restoredOnce = false;      // 允许再次从服务端恢复
      _initFromServerFirst();
      return;                     // 等待首帧流程结束
    }

    // 监听“已登录 → 退出登录”的过渡：这里不强制回到默认章节
    if (!auth.isAuthed && _wasAuthed) {
      _wasAuthed = false;
      // 退出登录后继续保持当前章节，但不再从服务端恢复
    }

    // ✅ 语言变化：刷新并同步到服务端
    if (newLang != _lang) {
      setState(() {
        _lang = newLang;
        _future = _fetchChapter();
      });
      _maybeSyncLanguage(newLang);
    }

    // 已经就绪时，每次依赖变化后都尝试处理一次路由参数（只会生效一次）
    _handleDeepLinkIfAny();
  }

  Future<void> _initFromServerFirst() async {
    await _tryRestoreFromServer(firstInit: true); // 会在内部设置 _bookId/_chapter/_lang
    if (!mounted) return;
    setState(() {
      _depsReady = true;           // ✅ 到这一步再放开 UI
      _future = _fetchChapter();   // 用“（可能被服务端纠正后的）书卷+章节+语言”拉经文
    });
    // 首帧加载后尝试处理路由参数
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLinkIfAny());
  }

  @override
  void dispose() {
        for (final t in _highlightTimers.values) {
      t.cancel();
    }
    _highlightTimers.clear();
    _syncDebounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<List<_Verse>> _fetchChapter() async {
    final uri = Uri.parse('$_baseUrl/api/bible?book=$_bookId&chapter=$_chapter&v=$_lang');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final verses = (data['verses'] as List)
        .map((e) => _Verse(number: (e['verse'] as num).toInt(), text: e['text'] as String))
        .toList();
    return verses;
  }

  // ← 登录用户时，从服务器恢复阅读进度 & 语言
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
      final String? serverLang = j['language'] as String?;

      // 以服务端语言为准（和 Web 一致）
      if (serverLang != null && serverLang != _lang) {
        LangScope.of(context).setLang(serverLang);
        _lang = serverLang; // 本地也立刻对齐，供后续 _fetchChapter 使用
      }

      // 以服务端阅读进度为准
      if (rb != null && rc != null && rb >= 1 && rb <= 66 && rc >= 1) {
        _bookId = rb;
        _chapter = rc;
        // 首帧模式：这里只修正状态，不立即 setState+_fetchChapter（交给 _initFromServerFirst 统一触发）
        if (!firstInit) {
          setState(() { _future = _fetchChapter(); });
          _scrollToTop();
        }
      }
    } catch (_) {
      // 可加 debugPrint 便于排错
    }
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

  // —— 阅读进度：去抖 + 覆盖写入（支持乐观）
  void _scheduleSyncReading() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 300), _maybeSyncReading);
  }

  Future<void> _maybeSyncReading() async {
    final auth = AuthScope.of(context);
    if (!auth.isAuthed) return;

    // ✅ 乐观更新到全局（其它页面立刻拿到最新“正在读”）
    auth.updateReading(book: _bookId, chapter: _chapter);

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/auth/update-reading'),
        headers: _authedJsonHeaders(auth.token!),
        body: jsonEncode({'reading_book': _bookId, 'reading_chapter': _chapter}),
      );
    } catch (_) {/* 通常不回滚 */}
  }

  /* -------------------- 跳到相关经文（核心新增） -------------------- */

  /// 切换到目标书卷/章节并等待加载完成
  Future<void> _gotoChapter(int b, int c) async {
    setState(() {
      _bookId = b;
      _chapter = c;
      _future = _fetchChapter();
    });
    await _future; // 等待 FutureBuilder 的数据准备好
     _scheduleSyncReading(); // ✅ 节流上传
  }

  /// 滚动到第 v 节（使用 GlobalKey，更稳）
  void _scrollToVerse(int v) {
    final key = _verseKeys[v];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    }
  }

  /// 接收 Search 页传来的 {'b','c','v'}，完成“切章 + 定位”
  void _handleDeepLinkIfAny() {
    if (_handledDeepLink) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final int b = (args['b'] as num?)?.toInt() ?? 1;
    final int c = (args['c'] as num?)?.toInt() ?? 1;
    final int v = (args['v'] as num?)?.toInt() ?? 1;

    _handledDeepLink = true;
    _pendingVerse = v;

    final bool needReload = (_bookId != b) || (_chapter != c);

    if (needReload) {
      _gotoChapter(b, c).whenComplete(() {
        if (!mounted || _pendingVerse == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToVerse(_pendingVerse!);
            _flashVerse(v);
          _pendingVerse = null;
        });
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(v);
         _flashVerse(_pendingVerse!);
        _pendingVerse = null;
      });
    }
  }

  /* -------------------- 交互 & 导航 -------------------- */

  // 滚到顶部（已挂载就直接滚；未挂载就下一帧滚）
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

  // 统一的“重新取数 + 回到顶部”
  void _reload() {
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
      _reload();
      _scheduleSyncReading(); // ✅ 节流上传
      return;
    }
    if (_bookId > 1) {
      setState(() {
        _bookId -= 1;
        _chapter = _chapterCounts[_bookId - 1];
        _future = _fetchChapter();
      });
      _reload();
      _scheduleSyncReading(); // ✅ 节流上传
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
      _reload();
      _scheduleSyncReading(); // ✅ 节流上传
      return;
    }
    if (_bookId < 66) {
      setState(() {
        _bookId += 1;
        _chapter = 1;
        _future = _fetchChapter();
      });
      _reload();
      _scheduleSyncReading(); // ✅ 节流上传
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already at the last chapter')),
      );
    }
  }

String _chapterCn(int n) {
  assert(n >= 1 && n <= 999);
  const numerals = ['零','一','二','三','四','五','六','七','八','九'];

  String under100(int x, {bool forceTenOne = false}) {
    if (x < 10) return numerals[x];
    if (x < 20) {
      final ones = x % 10;
      // 10–19：在百位之后出现时用“**一**十…”，否则“十…”
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
    // 10–19 在百位后要写成“一十…”
    return '${numerals[hundreds]}百${under100(rest, forceTenOne: true)}';
  }

  return '第${toCn(n)}章';
}

  String _t(String en, String cn) => _lang == 't_cn' ? cn : en;

  String get _currentBookName => _lang == 't_cn'
      ? bookNamesCn[_bookId - 1]
      : bookNamesEn[_bookId - 1];

  void _clearVerseSelection() {
    if (_selectedVerseNumbers.isEmpty && _activeVerseNumber == null) return;
    setState(() {
      _selectedVerseNumbers.clear();
      _activeVerseNumber = null;
    });
  }

  void _toggleVerseSelection(_Verse verse) {
    final auth = AuthScope.of(context);
    if (!auth.isAuthed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please log in before submitting a prayer.', '请先登录后再提交祷告。'))),
      );
      return;
    }

    setState(() {
      if (_selectedVerseNumbers.contains(verse.number)) {
        _selectedVerseNumbers.remove(verse.number);
        if (_activeVerseNumber == verse.number) {
          if (_selectedVerseNumbers.isEmpty) {
            _activeVerseNumber = null;
          } else {
            final sorted = _selectedVerseNumbers.toList()..sort();
            _activeVerseNumber = sorted.last;
          }
        }
      } else {
        _selectedVerseNumbers.add(verse.number);
        _activeVerseNumber = verse.number;
      }
    });
  }

  Future<void> _openPrayerDialog(List<_Verse> allVerses) async {
    final auth = AuthScope.of(context);
    if (!auth.isAuthed || _selectedVerseNumbers.isEmpty) return;

    final selected = allVerses
        .where((v) => _selectedVerseNumbers.contains(v.number))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    if (selected.isEmpty) return;

    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool isPrivate = _isPrayerPrivate;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final firstFive = selected.take(5).toList();
            final remaining = selected.skip(5).toList();

            Future<void> submitPrayer() async {
              if (isSubmitting) return;
              if (titleController.text.trim().isEmpty ||
                  contentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(_t('Please enter a title and prayer content.', '请输入祷告标题和内容。'))),
                );
                return;
              }

              setModalState(() => isSubmitting = true);
              try {
                final payload = {
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'is_private': isPrivate,
                  'verses': selected
                      .map((v) => {
                            'version': _lang,
                            'b': _bookId,
                            'c': _chapter,
                            'v': v.number,
                          })
                      .toList(),
                };

                final res = await http.post(
                  Uri.parse('$_baseUrl/api/prayers/'),
                  headers: _authedJsonHeaders(auth.token!),
                  body: jsonEncode(payload),
                );

                if (!mounted) return;
                if (res.statusCode >= 200 && res.statusCode < 300) {
                  _isPrayerPrivate = isPrivate;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(_t('Prayer submitted successfully!', '祷告已提交！'))),
                  );
                  _clearVerseSelection();
                } else {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(_t('Submission failed, please try again.', '提交失败，请重试。'))),
                  );
                }
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(_t('Network error, please try again later.', '网络错误，请稍后再试。'))),
                );
              } finally {
                if (mounted) {
                  setModalState(() => isSubmitting = false);
                }
              }
            }

            return AlertDialog(
              title: Text(_t('Write your prayer', '写下你的祷告')),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_currentBookName ${_lang == 't_cn' ? _chapterCn(_chapter) : 'Chapter $_chapter'}'),
                      const SizedBox(height: 12),
                      ...firstFive.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('[${item.number}] ${item.text}'),
                        ),
                      ),
                      if (remaining.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Text(
                                _t('Remaining verses:', '其余经文：'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              ...remaining.map((item) => Text('[${item.number}]')),
                            ],
                          ),
                        ),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: _t('Prayer Title', '祷告标题'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_t('Visibility:', '可见性：')),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              value: false,
                              groupValue: isPrivate,
                              title: Text(_t('Public', '公开')),
                              onChanged: (v) => setModalState(() => isPrivate = v ?? false),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              value: true,
                              groupValue: isPrivate,
                              title: Text(_t('Private', '私密')),
                              onChanged: (v) => setModalState(() => isPrivate = v ?? true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: contentController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: _t('Enter your prayer here', '请输入你的祷告内容'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(_t('Cancel', '取消')),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submitPrayer,
                  child: Text(isSubmitting ? _t('Submitting...', '提交中...') : _t('Submit', '提交')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openBookChapterPicker() async {
    final picked = await Navigator.push<PickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => BookChapterPickerPage(
          lang: _lang,
          initialBookId: _bookId,
          initialChapter: _chapter, // 用于高亮
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
      _reload();
      _scheduleSyncReading(); // ✅ 节流上传
    }
  }

  /* -------------------- UI -------------------- */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // 顶部固定：搜索框
             const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 0), // 左16  顶10 右16  底0
        child: AppSearchBar(),
      ),

          // 中间：只滚动经文（标题作为第 0 项）
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _clearVerseSelection,
              child: !_depsReady
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<_Verse>>(
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
                      final verses = snap.data ?? const <_Verse>[];
                      if (verses.isEmpty) {
                        return _ErrorBox(
                          message: 'No verses returned.',
                          onRetry: _reload,
                        );
                      }

                      final textTheme = Theme.of(context).textTheme;
                      final isCn = _lang == 't_cn';
                      final headerTitle = isCn
                          ? _chapterCn(_chapter)                          // 中文只显示“第…章”
                          : '${bookNamesEn[_bookId - 1]} $_chapter';     // 英文：Book + chapter

                      return ListView.builder(
                        controller: _scrollCtrl,
                          cacheExtent: 20000, // 粗暴地多建一些 缓存，避免快速翻页时白屏
                        padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
                        itemCount: verses.length + 1, // +1 给标题
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            // ✅ 标题放入滚动区域
                            return Padding(
                              padding: const EdgeInsets.only(top: 14, bottom: 28),
                              child: Column(
                                children: [
                                  Text(
                                    (isCn
                                        ? '${bookNamesCn[_bookId - 1]} $headerTitle'
                                        : headerTitle),
                                    textAlign: TextAlign.center,
                                    style: (isCn ? textTheme.headlineMedium : textTheme.displaySmall)
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: SizedBox(
                                      width: 240,
                                      child: Divider(
                                        thickness: 1,
                                        height: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final v = verses[i - 1];

                          // ✅ 关键：给“每一节”挂上 key，便于 ensureVisible 精准定位
return Align(
  alignment: Alignment.centerLeft,
  child: KeyedSubtree(
    key: _verseKeys.putIfAbsent(v.number, () => GlobalKey()),
    child: _VerseParagraph(
      verse: v,
      highlighted: _highlightedVerses.contains(v.number),
      selected: _selectedVerseNumbers.contains(v.number),
      active: _activeVerseNumber == v.number,
      onTap: () => _toggleVerseSelection(v),
      onCreatePrayer: () => _openPrayerDialog(verses),
    ),
  ),
);

                        },
                      );
                    },
                  ),
            ),
          ),

          // 底部分割线 + 固定翻章条
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.5),
          ),
          Builder(
            builder: (context) {
              final isCn = _lang == 't_cn';
              final label = isCn ? _chapterCn(_chapter) : '${bookNamesEn[_bookId - 1]} $_chapter';
              return _BottomPager(
                label: label,
                onPrev: _goPrev,
                onNext: _goNext,
                onLabelTap: _openBookChapterPicker, // 点击标题打开选择器
              );
            },
          ),
        ],
      ),
    );
  }
}

/* -------------------- UI bits -------------------- */

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

/// 底部固定翻章条：左右按钮在两侧，中间标题
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), // 外边距
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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

class _Verse {
  final int number;
  final String text;
  const _Verse({required this.number, required this.text});
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

  final _Verse verse;
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
        color: emphasized ? const Color.fromARGB(255, 71, 116, 88): Colors.transparent,
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
                        TextSpan(text: '[${verse.number}]', style: numberStyle),
                        const TextSpan(text: ' '),
                        TextSpan(text: verse.text, style: body),
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
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.note_add_outlined,
                          size: 35,
                         color: const Color.fromARGB(255, 210, 233, 224),
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
