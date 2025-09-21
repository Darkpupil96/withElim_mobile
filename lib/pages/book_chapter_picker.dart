// lib/pages/book_chapter_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 选择结果：书卷 id（1..66）+ 章节（1..n）
class PickResult {
  final int bookId;
  final int chapter;
  const PickResult(this.bookId, this.chapter);
}

class BookChapterPickerPage extends StatefulWidget {
  const BookChapterPickerPage({
    super.key,
    required this.lang,            // 't_cn' 或 't_kjv'
    required this.initialBookId,   // 1..66
    required this.initialChapter,  // 1..n
    required this.bookNamesEn,
    required this.bookNamesCn,
    required this.chapterCounts,   // 长度必须是 66（顺序与书卷一致）
  }) : assert(bookNamesEn.length == 66 &&
              bookNamesCn.length == 66 &&
              chapterCounts.length == 66,
              'book names & chapter counts must all have length 66');

  final String lang;
  final int initialBookId;
  final int initialChapter;
  final List<String> bookNamesEn;
  final List<String> bookNamesCn;
  final List<int> chapterCounts;

  @override
  State<BookChapterPickerPage> createState() => _BookChapterPickerPageState();
}

class _BookChapterPickerPageState extends State<BookChapterPickerPage> {
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};     // 每个书卷卡片 key（定位滚动）
  final GlobalKey _highlightKey = GlobalKey();  // 高亮“章”用 key（首次进入定位）
  String _q = '';
  int? _expanded; // 当前展开的书卷 id（单开）
  bool _didInitialScroll = false;

  String _bookName(int id) =>
      widget.lang == 't_cn' ? widget.bookNamesCn[id - 1] : widget.bookNamesEn[id - 1];

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialBookId; // 默认展开当前书卷
    _doInitialScroll();               // 首次进入自动置顶高亮章（两步式）
  }

  /// 首次进入：让当前书卷与高亮章参与布局 → 精确滚动到高亮章
  void _doInitialScroll() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;

    final int bookId = _expanded ?? widget.initialBookId;

    // 第 1 帧：确保“书卷卡片”进入可视区（参与布局）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisibleByKey(_itemKeys[bookId]);

      // 第 2 帧：确保“高亮章方块”进入可视区（参与布局）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureVisibleByKey(_highlightKey);

        // 第 3 帧：布局稳定后，精确计算“高亮章”的 offset，贴近顶部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToKey(_highlightKey, animated: true);
        });
      });
    });
  }

  /// 兜底：把某个 key 对应的组件滚进可视区顶部（用于触发布局；动画极短）
  void _ensureVisibleByKey(GlobalKey? key) {
    final ctx = key?.currentContext;//获取组件上下文
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0, // 顶部
      duration: const Duration(milliseconds: 1),
      curve: Curves.linear,
    );
  }

  /// 精确置顶：计算某个 key 对应组件相对 viewport 的偏移并滚动
  void _scrollToKey(GlobalKey key, {bool animated = true}) {
    final ctx = key.currentContext;
    if (ctx == null) return;

    final render = ctx.findRenderObject();
    if (render == null) return;

    final vp = RenderAbstractViewport.of(render);

    double target = vp.getOffsetToReveal(render, 0.0).offset;

    // ListView 顶部有 padding: EdgeInsets.only(top: 12)，抵消以更贴顶
    const double topPadding = 12;
    if (_scroll.hasClients) {
      final double maxExtent = _scroll.position.maxScrollExtent;
      target = (target - topPadding).clamp(0.0, maxExtent);
    }

    if (!mounted || !_scroll.hasClients) return;
    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCn = widget.lang == 't_cn';

    // 根据关键字过滤书卷
    final ids = List<int>.generate(66, (i) => i + 1)
        .where((id) => _bookName(id).toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isCn ? '选择书卷与章节' : 'Choose Book & Chapter'),
      ),
      body: SafeArea(
        child: ListView( //这是一个长列表，包含搜索框和所有书卷卡片，是懒加载的，当元素进入可视区时才构建，过于大的元素会导致无法获得正确的offset，因此需要设置cacheExtent
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          cacheExtent: 5000, // 提前布局更多离屏子项，降低偏移异常
          children: [
            // 搜索框（若要换成项目里的可输入 SearchBar，这里替换）
            TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: isCn ? '搜索书卷…' : 'Search book…',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(.8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // 自定义手风琴列表：整块卡片（统一背景），无右侧图标、无下划线
            for (final id in ids) ...[
              _BookCard(
                key: _itemKeys.putIfAbsent(id, () => GlobalKey()),
                title: _bookName(id),
                expanded: _expanded == id,
                onTapHeader: () {
                  setState(() {
                    _expanded = (_expanded == id) ? null : id; // 单开
                  });
                  // 展开后：先确保卡片进入布局，再（如果是当前书卷）精确滚到高亮章
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _ensureVisibleByKey(_itemKeys[id]);
                    if (id == widget.initialBookId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _ensureVisibleByKey(_highlightKey);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToKey(_highlightKey, animated: true);
                        });
                      });
                    } else {
                      // 其他书卷：滚到该书卷卡片顶部即可
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToKey(_itemKeys[id]!, animated: true);
                      });
                    }
                  });
                },
                chapterArea: _ChapterSquares(
                  count: widget.chapterCounts[id - 1],
                  // 仅“当前阅读的书卷”里高亮当前章，并把 key 绑到那颗小方块
                  current: (id == widget.initialBookId) ? widget.initialChapter : null,
                  highlightKey: (id == widget.initialBookId) ? _highlightKey : null,
                  onPick: (n) => Navigator.pop(context, PickResult(id, n)),
                ),
              ),
              const SizedBox(height: 12), // 卡片之间的间距
            ],
          ],
        ),
      ),
    );
  }
}

/// 书卷大卡片：整块容器（圆角、统一底色）包含标题 + 章节区
class _BookCard extends StatelessWidget {
  const _BookCard({
    super.key,
    required this.title,
    required this.expanded,
    required this.onTapHeader,
    required this.chapterArea,
  });

  final String title;
  final bool expanded;
  final VoidCallback onTapHeader;
  final Widget chapterArea;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF), // 设计里的白底（如需随主题可改为 Theme.of(context).colorScheme.surface）
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTapHeader,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: chapterArea,
            ),
        ],
      ),
    );
  }
}

/// 章节小方块：固定正方形、圆角、左对齐排列
class _ChapterSquares extends StatelessWidget {
  const _ChapterSquares({
    required this.count,
    required this.onPick,
    this.current,
    this.highlightKey,
  });

  final int count;
  final int? current;                     // 需要高亮的当前章
  final GlobalKey? highlightKey;          // 高亮章的 key（用于首次进入定位）
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    const double side = 50; // 每个小 box 边长（可调 44/48/52）
    return Wrap(
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(count, (i) {
        final n = i + 1;
        final selected = current == n;

        final Color bg = selected
            ? const Color.fromARGB(255, 156, 199, 195)            // 选中：你给的色值
            : cs.surfaceContainerHighest.withValues(alpha: 0.70); // 未选中：70% 不透明
        final Color fg = selected ? const Color(0xFFFFFFFF) : cs.onSurface; // 选中文本白色

        // 只有高亮那颗方块绑定 key，其它为 null
        final Key? boxKey = (selected && highlightKey != null) ? highlightKey : null;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onPick(n),
            child: Ink(
              key: boxKey, // 把 key 绑在可渲染的 Ink 上，便于定位
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox.square(
                dimension: side, // 固定为正方形
                child: Center(
                  child: Text(
                    '$n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}



