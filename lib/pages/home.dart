import 'package:flutter/material.dart';
import '../app/app_lang.dart'; // ← 引入全局语言

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = LangScope.of(context).lang;
    final isCn = lang == 't_cn';

    // 文案（随语言切换）
    final searchHint     = isCn ? '搜索圣经、祷告、社群…' : 'Search Bible, prayers, communities...';
    final dailyTitle     = isCn ? '每日经文' : 'Daily Scripture';
    final todaysReading  = isCn ? '今日阅读' : "Today's Reading";
    final shareTooltip   = isCn ? '分享' : 'Share';
    final continueText   = isCn ? '继续' : 'Continue';
    final prayerList     = isCn ? '祷告清单' : 'Prayer List';
    final addPrayerLabel = isCn ? '添加祷告' : 'Add Prayer';
    final verseRef       = isCn ? '马可福音 6:31' : 'Mark 6:31';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchBar(hint: searchHint),

            // Daily Scripture
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(dailyTitle),
                    const SizedBox(height: 8),
                    const Text(
                      '"And he said to them, \'Come away by yourselves to a desolate place and rest a while.\' '
                      'For many were coming and going, and they had no leisure even to eat."',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        verseRef,
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.ios_share_rounded),
                        color: cs.onSurfaceVariant,
                        tooltip: shareTooltip,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Today's Reading
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(todaysReading),
                    const SizedBox(height: 8),
                    const Text(
                      '"And he said to them, \'Come away by yourselves to a desolate place and rest a while.\' '
                      'For many were coming and going, and they had no leisure even to eat."',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        verseRef,
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {},
                        child: Text(continueText),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Prayer List（标题汉化，列表项内容保留原文，因为是用户生成内容）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(prayerList),
                    const SizedBox(height: 6),
                    const _PrayerListItem(text: "For my family's health and prosperity"),
                    const Divider(height: 8),
                    const _PrayerListItem(text: "Guidance for career decisions"),
                    const Divider(height: 8),
                    const _PrayerListItem(text: "Church ministry planning"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (context) => FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isCn ? '添加祷告（占位）' : 'Add Prayer (stub)')),
                    );
                  },
                  child: Text(addPrayerLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------- 小组件（可后续迁移到 lib/widgets/） ------------- */

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        enabled: false,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _PrayerListItem extends StatelessWidget {
  final String text;
  const _PrayerListItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.primary, width: 2),
        ),
      ),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {},
    );
  }
}
