// lib/widgets/search_bar.dart  (你原文件路径即可)
import 'package:flutter/material.dart';
import '../app/app_lang.dart';
import '../pages/search_page.dart'; // ⬅️ 新增：引入搜索页

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCn = LangScope.of(context).lang == 't_cn';
    final hint = isCn ? '搜索圣经、祷告、社群…' : 'Search Bible, prayers, communities...';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SearchPage(
              initialWord: '',
            ),
          ),
        );
      },
      child: Container(
     
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IgnorePointer( // 保持 TextField disabled 的视觉与手势独立
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
