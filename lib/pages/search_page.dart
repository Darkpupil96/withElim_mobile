import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app/app_lang.dart';
import 'bible.dart'; // 你自己的 bible.dart（已在上方 import）

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialWord = ''});
  final String initialWord;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const String _baseUrl = 'https://withelim.com';
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String _error = '';
  String _word = '';

  Map<int, List<_VerseHit>> _grouped = {};
  List<int> _orderedBooks = [];
  int? _initialOpenBookId;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialWord;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String word) async {
    final lang = LangScope.of(context).lang; // 't_cn' or 't_kjv'
    if (word.trim().isEmpty) {
      setState(() {
        _word = '';
        _grouped = {};
        _orderedBooks = [];
        _error = '';
        _initialOpenBookId = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _word = word.trim();
      _grouped = {};
      _orderedBooks = [];
      _initialOpenBookId = null;
    });

    // 路由前缀与 Web 保持一致：/api/bible/...
    final path = lang == 't_cn'
        ? '/api/bible/Chinese/search'
        : '/api/bible/English/search';
    final uri = Uri.parse('$_baseUrl$path?word=${Uri.encodeQueryComponent(_word)}');

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (json['verses'] as List).cast<Map<String, dynamic>>();

      final hits = list.map((m) => _VerseHit.fromJson(m)).toList();

      // 分组：book -> verses
      final Map<int, List<_VerseHit>> grouped = {};
      for (final h in hits) {
        grouped.putIfAbsent(h.b, () => []).add(h);
      }
      final ordered = grouped.keys.toList()..sort();

      setState(() {
        _grouped = grouped;
        _orderedBooks = ordered;
        _initialOpenBookId = ordered.isNotEmpty ? ordered.first : null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String bookName(int b, {required bool isCn}) {
    final idx = b - 1;
    if (idx < 0) return '';
    return isCn ? bookNamesCn[idx] : bookNamesEn[idx]; // 直接用你 bible.dart 的公开常量
  }

  // ⬇️ 跳转到 Bible，并把目标书/章/节传过去
void _goToBible(_VerseHit v) {
  Navigator.pop(context, {
    'b': v.b,
    'c': v.c,
    'v': v.v,
  });
}
  @override
  Widget build(BuildContext context) {
    final isCn = LangScope.of(context).lang == 't_cn';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _SearchBox(
          controller: _controller,
          hint: isCn ? '搜索经文…' : 'Search verses…',
          onSubmitted: _doSearch,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _ErrorView(message: _error, onRetry: () => _doSearch(_controller.text))
              : _orderedBooks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isCn ? '输入关键词开始搜索' : 'Type a keyword to search',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  : ListView(
                      // ✅ 统一宽度：只保留小边距，卡片占满可用宽度
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        ExpansionPanelList.radio(
                          expandedHeaderPadding: EdgeInsets.zero,
                          elevation: 0,
                          children: _orderedBooks.map((bookId) {
                            final verses = _grouped[bookId]!;
                            final title = bookName(bookId, isCn: isCn);
                            return ExpansionPanelRadio(
                              value: bookId,
                              canTapOnHeader: true,
                              headerBuilder: (_, __) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              body: Column(
                                children: [
                                  for (final v in verses)
                                    // ✅ 让卡片占满：外面包一层 SizedBox 宽度撑满
                                    SizedBox(
                                      width: double.infinity,
                                      child: _VerseCard(
                                        verse: v,
                                        query: _word,
                                        isCn: isCn,
                                        textColor: cs.onSurface,
                                        highlightColor: cs.primary,
                                        onTapVerse: () => _goToBible(v),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          initialOpenPanelValue: _initialOpenBookId,
                        ),
                      ],
                    ),
    );
  }
}

// 顶部输入框（AppBar）
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({
    required this.verse,
    required this.query,
    required this.isCn,
    required this.textColor,
    required this.highlightColor,
    required this.onTapVerse,
  });

  final _VerseHit verse;
  final String query;
  final bool isCn;
  final Color textColor;
  final Color highlightColor;
  final VoidCallback onTapVerse;

  @override
  Widget build(BuildContext context) {
    return Card(
      // ✅ 宽度一致：只保留底部间距
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapVerse,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 章/节信息（保持简洁）
              Text(
                isCn ? '第 ${verse.v} 节' : 'Verse ${verse.v}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              // ✅ 文字高亮（无背景）
              RichText(
                text: _buildHighlightedSpan(
                  verse.t,
                  query,
                  isCn: isCn,
                  normalStyle: TextStyle(
                    color: textColor.withOpacity(0.92),
                    height: 1.35,
                  ),
                  highlightStyle: TextStyle(
                    color: highlightColor,        // ← 仅颜色高亮
                    fontWeight: FontWeight.w700,  // ← 略加粗
                    // 无背景、无下划线
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedSpan(
    String source,
    String query, {
    required bool isCn,
    required TextStyle normalStyle,
    required TextStyle highlightStyle,
  }) {
    if (query.isEmpty) return TextSpan(text: source, style: normalStyle);

    final reg = RegExp(
      RegExp.escape(query),
      caseSensitive: isCn, // 中文区分大小写无意义；英文不区分大小写
      unicode: true,
    );

    final spans = <TextSpan>[];
    int start = 0;
    for (final m in reg.allMatches(source)) {
      if (m.start > start) {
        spans.add(TextSpan(text: source.substring(start, m.start), style: normalStyle));
      }
      spans.add(TextSpan(text: source.substring(m.start, m.end), style: highlightStyle));
      start = m.end;
    }
    if (start < source.length) {
      spans.add(TextSpan(text: source.substring(start), style: normalStyle));
    }
    return TextSpan(children: spans);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _VerseHit {
  final String version; // 't_cn' or 't_kjv'
  final int b; // book
  final int c; // chapter
  final int v; // verse
  final String t; // text

  _VerseHit({
    required this.version,
    required this.b,
    required this.c,
    required this.v,
    required this.t,
  });

  factory _VerseHit.fromJson(Map<String, dynamic> m) => _VerseHit(
        version: m['version'] as String,
        b: (m['b'] as num).toInt(),
        c: (m['c'] as num).toInt(),
        v: (m['v'] as num).toInt(),
        t: m['t'] as String,
      );
}
