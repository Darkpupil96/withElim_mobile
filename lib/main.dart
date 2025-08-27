import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/bible.dart';
import 'app/app_lang.dart';

void main() => runApp(const WithElimApp());

class WithElimApp extends StatefulWidget {
  const WithElimApp({super.key});

  @override
  State<WithElimApp> createState() => _WithElimAppState();
}

class _WithElimAppState extends State<WithElimApp> {
  final _lang = LangController(); // 全局语言状态 

 @override
  void dispose() {
    _lang.dispose(); // 很重要：避免内存泄漏
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LangScope( // ⬅️ 挂载全局语言  
      controller: _lang,
      child: MaterialApp(
        title: 'WithElim',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
          cardTheme: CardThemeData(
            margin: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0.5,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _current = 0;

  // 四个 Tab 页面（BiblePage 内部自己读取 LangScope）
  final List<Widget> _pages = const [
    HomeTab(key: PageStorageKey('home')),
    BiblePage(key: PageStorageKey('bible')),
    _PrayerTab(key: PageStorageKey('prayer')),
    _CommunityTab(key: PageStorageKey('community')),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context); // 读取全局语言（变化时本页会自动重建）
    final isCn = lang.lang == 't_cn'; // 判断当前语言

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: const [
            _Logo(),
            SizedBox(width: 12),
            Text(
              'WithElim',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF388683)),
            ),
          ],
        ),
        actions: [
          // 头部右侧语言切换，全局生效
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate),
            initialValue: lang.lang,
            onSelected: (v) => lang.setLang(v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 't_kjv', child: Text('English (KJV)')),
              PopupMenuItem(value: 't_cn',  child: Text('中文')),
            ],
          ),
        ],
      ),

      // IndexedStack 保留各 Tab 状态
      body: IndexedStack(index: _current, children: _pages),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _current,
        onDestinationSelected: (i) => setState(() => _current = i),
        // ⚠️ 这里不能用 const，因为 label 依赖运行时语言
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: isCn ? '主页' : 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: isCn ? '圣经' : 'Bible',
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: isCn ? '祷告' : 'Prayer',
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: isCn ? '社区' : 'Community',
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo.png', height: 34, fit: BoxFit.contain);
  }
}

class _PrayerTab extends StatelessWidget {
  const _PrayerTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Prayer (WIP)', style: TextStyle(fontWeight: FontWeight.w600)));
  }
}

class _CommunityTab extends StatelessWidget {
  const _CommunityTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Community (WIP)', style: TextStyle(fontWeight: FontWeight.w600)));
  }
}
