import 'package:flutter/material.dart';
import '../app/app_lang.dart';
import '../pages/search_page.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.onJumpToVerse,
  });

  final void Function(int b, int c, int v)? onJumpToVerse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCn = LangScope.of(context).lang == 't_cn';
    final hint = isCn ? '搜索圣经、祷告、社群…' : 'Search Bible, prayers, communities...';

    Future<void> openSearch() async {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => const SearchPage(initialWord: ''),
        ),
      );

      if (result == null || !context.mounted) return;

      final b = (result['b'] as num?)?.toInt();
      final c = (result['c'] as num?)?.toInt();
      final v = (result['v'] as num?)?.toInt();

      if (b == null || c == null || v == null) return;

      if (onJumpToVerse != null) {
        onJumpToVerse!(b, c, v);
      } else {
        Navigator.pushNamed(
          context,
          '/bible',
          arguments: {'b': b, 'c': c, 'v': v},
        );
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: openSearch,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IgnorePointer(
          child: TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}