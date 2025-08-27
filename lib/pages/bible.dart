// lib/pages/bible.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/search_bar.dart';
// 读取全局语言
import '../app/app_lang.dart';

const _baseUrl = 'https://withelim.com';
typedef BibleLang = String; // 't_kjv' / 't_cn'

// 书卷英文/中文名 & 章数
const List<String> _bookNamesEn = [
  "Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel",
  "1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs",
  "Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos",
  "Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark",
  "Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians",
  "1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter",
  "1 John","2 John","3 John","Jude","Revelation"
];

const List<String> _bookNamesCn = [
  "创世记","出埃及记","利未记","民数记","申命记","约书亚记","士师记","路得记","撒母耳记上","撒母耳记下",
  "列王纪上","列王纪下","历代志上","历代志下","以斯拉记","尼希米记","以斯帖记","约伯记","诗篇","箴言",
  "传道书","雅歌","以赛亚书","耶利米书","耶利米哀歌","以西结书","但以理书","何西阿书","约珥书","阿摩司书",
  "俄巴底亚书","约拿书","弥迦书","那鸿书","哈巴谷书","西番雅书","哈该书","撒迦利亚书","玛拉基书","马太福音","马可福音",
  "路加福音","约翰福音","使徒行传","罗马书","哥林多前书","哥林多后书","加拉太书","以弗所书","腓立比书","歌罗西书",
  "帖撒罗尼迦前书","帖撒罗尼迦后书","提摩太前书","提摩太后书","提多书","腓利门书","希伯来书","雅各书","彼得前书","彼得后书",
  "约翰一书","约翰二书","约翰三书","犹大书","启示录"
];

const List<int> _chapterCounts = [
  50,40,27,36,34,24,21,4,31,24,22,25,29,36,10,13,10,42,150,31,12,8,66,52,5,48,12,14,3,9,1,4,7,3,3,3,2,14,4,
  28,24,21,28,16,16,13,6,6,4,5,3,6,4,3,1,13,5,5,3,5,1,1,1,22
];

class BiblePage extends StatefulWidget {
  const BiblePage({
    super.key,
    this.bookId = 41, // Mark
    this.chapter = 6, // Mark 6
  });

  final int bookId;
  final int chapter;

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  late int _bookId;
  late int _chapter;
  late BibleLang _lang;           // 当前语言（来自全局）
  late Future<List<_Verse>> _future;

  bool _depsReady = false;        // 首次获取全局语言的标记

  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
    _chapter = widget.chapter;
    _lang = 't_kjv';              // 占位，真正的值在 didChangeDependencies 同步
    _future = Future.value(const <_Verse>[]); // 等待 didChangeDependencies 触发真实请求
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLang = LangScope.of(context).lang; // 读取全局语言（会注册依赖）
    if (!_depsReady) {
      _depsReady = true;
      _lang = newLang;
      _future = _fetchChapter();
      return;
    }
    if (newLang != _lang) {
      setState(() {
        _lang = newLang;
        _future = _fetchChapter(); // 语言变化 → 重新请求
      });
    }
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

  void _goPrev() {
    if (_chapter > 1) {
      setState(() { _chapter -= 1; _future = _fetchChapter(); });
      return;
    }
    if (_bookId > 1) {
      setState(() { _bookId -= 1; _chapter = _chapterCounts[_bookId - 1]; _future = _fetchChapter(); });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already at the first chapter')));
    }
  }

  void _goNext() {
    final max = _chapterCounts[_bookId - 1];
    if (_chapter < max) {
      setState(() { _chapter += 1; _future = _fetchChapter(); });
      return;
    }
    if (_bookId < 66) {
      setState(() { _bookId += 1; _chapter = 1; _future = _fetchChapter(); });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already at the last chapter')));
    }
  }

  String _chapterCn(int n) {
    const numerals = ['零','一','二','三','四','五','六','七','八','九'];
    if (n < 10) return '第${numerals[n]}章';
    if (n < 20) return '第十${n % 10 == 0 ? '' : numerals[n % 10]}章';
    final tens = n ~/ 10;
    final ones = n % 10;
    return '第${numerals[tens]}十${ones == 0 ? '' : numerals[ones]}章';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // 顶部固定：搜索框
          AppSearchBar(),

          // 中间：只滚动经文（标题作为第 0 项）
          Expanded(
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
                          onRetry: () => setState(() => _future = _fetchChapter()),
                        );
                      }
                      final verses = snap.data ?? const <_Verse>[];
                      if (verses.isEmpty) {
                        return _ErrorBox(
                          message: 'No verses returned.',
                          onRetry: () => setState(() => _future = _fetchChapter()),
                        );
                      }

                      final textTheme = Theme.of(context).textTheme;
                      final isCn = _lang == 't_cn';
                      final headerTitle = isCn
                          ? _chapterCn(_chapter)                            // 中文只显示“第…章”
                          : '${_bookNamesEn[_bookId - 1]} $_chapter';       // 英文：Book + chapter

                      return ListView.builder(
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
                                (isCn ? '${_bookNamesCn[_bookId - 1]} $headerTitle':headerTitle),
                                  textAlign: TextAlign.center,
                                  style: (isCn ? textTheme.headlineMedium : textTheme.displaySmall)
                                   ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                 const SizedBox(height: 20), // 标题与线之间留点空隙
                     Center(
                        child: SizedBox(
                          width: 240, // 你想要的宽度
                       child: Divider(
                                 thickness: 1,
                                 height: 1,
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                                      ),
                        ),
                              ],
                            ),
                            );

                          }
                          final v = verses[i - 1];
                          return _VerseParagraph(verse: v);
                        },
                      );
                    },
                  ),
          ),

          // 底部分割线 + 固定翻章条
          Divider(height: 1,  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),),
          Builder(
            builder: (context) {
              final isCn = _lang == 't_cn';
              final label = isCn
                  ? _chapterCn(_chapter)
                  : '${_bookNamesEn[_bookId - 1]} $_chapter';
              return _BottomPager(
                label: label,
                onPrev: _goPrev,
                onNext: _goNext,
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
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      // 这里保留你之前的较大内边距设置；如需更紧凑可改为 horizontal: 12
      padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 15),
      child: Row(
        children: [
          _RoundIconBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant.withOpacity(.7)),
        ),
        child: Icon(icon, size: 22, color: cs.onSurface),
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
  const _VerseParagraph({required this.verse});
  final _Verse verse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 放大正文字号（22），节号更小（12）+ 更淡；统一行高 1.6
    final body = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 20,
      height: 1.6,
      color: cs.onSurface,
    );
    final numberStyle = body?.copyWith(
      fontSize: 12,
      height: 1.6,
      color: cs.onSurface.withOpacity(.60),
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '[${verse.number}]', style: numberStyle),
            const TextSpan(text: ' '),
            TextSpan(text: verse.text, style: body),
          ],
        ),
      ),
    );
  }
}
