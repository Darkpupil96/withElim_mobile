import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/bible.dart';
import 'app/app_lang.dart';
import 'pages/login_step_one.dart';
import 'pages/login_step_two.dart';
import 'pages/register.dart';
import 'app/auth_scope.dart';  
import 'pages/search_page.dart'; // ⬅️ 新增：引入搜索页
import 'dart:convert';
import 'package:http/http.dart' as http;
void main() => runApp(const WithElimApp());

class WithElimApp extends StatefulWidget {
  const WithElimApp({super.key});

  @override
  State<WithElimApp> createState() => _WithElimAppState();
}

class _WithElimAppState extends State<WithElimApp> {
  final _lang = LangController(); // 全局语言状态 
  final _auth = AuthController(); // 全局登录状态
 @override
  void dispose() {
    _lang.dispose(); // 很重要：避免内存泄漏
    _auth.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return LangScope( // 语言
    controller: _lang,
    child: AuthScope( // ✅ 新增：登录会话
      controller: _auth,
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
        routes: {
          '/bible': (ctx) {
    final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
    final b = (args?['b'] as num?)?.toInt();
    final c = (args?['c'] as num?)?.toInt();
    final v = (args?['v'] as num?)?.toInt();
    return HomeScreen(
      initialBibleTarget: (b != null && c != null && v != null)
          ? {'b': b, 'c': c, 'v': v}
          : null,
    );
  },
          '/loginEmail': (_) => const LoginEmailPage(),
          '/loginPassword': (ctx) {
            final email = ModalRoute.of(ctx)!.settings.arguments as String;
            return LoginPasswordPage(email: email);
          },
          '/register': (_) => const RegisterPage(),
        },
      ),
    ),
  );
}
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key,this.initialBibleTarget});
 // 新增：当通过 /bible 路由进入时会带上 {'b','c','v'}
  final Map<String, int>? initialBibleTarget;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _current = 0;
 // 控制 BiblePage 的跳转（你已在 bible.dart 实现 BibleJumpController）
  final BibleJumpController _bibleCtl = BibleJumpController();

  // 把 controller 传给 BiblePage（注意这段你已有的话就保持一致）
  late final List<Widget> _pages = [
    const HomeTab(key: PageStorageKey('home')),
    BiblePage(key: const PageStorageKey('bible'), controller: _bibleCtl),
    const _PrayerTab(key: PageStorageKey('prayer')),
    const _CommunityTab(key: PageStorageKey('community')),
  ];
  @override
  void initState() {
    super.initState();
     // 如果是通过 /bible 路由进来的，首帧切到 Bible 并定位
    if (widget.initialBibleTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _current = 1); // Bible tab index
        final t = widget.initialBibleTarget!;
        _bibleCtl.jumpTo(t['b']!, t['c']!, t['v']!);
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context); // 读取全局语言（变化时本页会自动重建）
    final auth = AuthScope.of(context); // 读取全局登录状态
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
       
Builder(
  builder: (ctx) {
    final auth = AuthScope.of(ctx); // 读取全局登录状态

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Scaffold.of(ctx).openEndDrawer(), // 打开右侧抽屉
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: const Color.fromARGB(179, 142, 228, 221),
          backgroundImage: auth.isAuthed && (auth.user?.avatar?.isNotEmpty ?? false)
              ? NetworkImage(auth.user!.avatar!) as ImageProvider
              : null,
          child: !(auth.isAuthed && (auth.user?.avatar?.isNotEmpty ?? false))
              ? const Icon(Icons.person, size: 24) // 未登录默认头像
              : null,
        ),
      ),
    );
  },
),

        ],
      ),
 // ✅ 右侧抽屉（从右到左滑入）
  endDrawer: const _AuthEndDrawer(),

  // 可选：手势滑出开关（默认 true）
  endDrawerEnableOpenDragGesture: true,

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


class _AuthEndDrawer extends StatelessWidget {
  const _AuthEndDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    final auth = AuthScope.of(context);
    final isCn = lang.lang == 't_cn';

    if (!auth.isAuthed) {
      // —— 未登录：你原来的版本 ——
      return Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding:  const EdgeInsets.only(top: 10),),
                      Text(isCn ? '未登录' : 'Visitor',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(isCn ? '语言：' : 'Language:'),
                          const SizedBox(width: 6),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: lang.lang,
                              items: const [
                                DropdownMenuItem(value: 't_kjv', child: Text('English')),
                                DropdownMenuItem(value: 't_cn', child: Text('中文')),
                              ],
                              onChanged: (v) => v != null ? lang.setLang(v) : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () { Navigator.of(context).pop(); Navigator.pushNamed(context, '/loginEmail'); },
                      child: Text(isCn ? '登录' : 'Log in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () { Navigator.of(context).pop(); Navigator.pushNamed(context, '/register'); },
                      child: Text(isCn ? '注册' : 'Sign Up'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // —— 已登录：按你发的图样式 ——
    final u = auth.user!;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 24,
                  backgroundImage: (u.avatar?.isNotEmpty ?? false)
                    ? NetworkImage(u.avatar!)
                    : null,
                  child: (u.avatar?.isEmpty ?? true) ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(u.email, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(isCn ? '语言：' : 'Language:'),
                          const SizedBox(width: 6),
DropdownButtonHideUnderline(
  child: DropdownButton<String>(
    value: lang.lang,
    items: const [
      DropdownMenuItem(value: 't_kjv', child: Text('English')),
      DropdownMenuItem(value: 't_cn',  child: Text('中文')),
    ],
    onChanged: (v) async {
      if (v == null) return;

      // 1) 本地立即生效（optimistic）
      final prev = lang.lang;
      lang.setLang(v);

      // 2) 若未登录，仅本地切换即可
      final auth = AuthScope.of(context);
      if (!auth.isAuthed) return;

      // 3) 已登录：同步到后端
      try {
        final resp = await http.post(
          Uri.parse('https://withelim.com/api/auth/update'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode({'language': v}),
        );

        if (resp.statusCode == 200) {
          // 可选：如果后端返回 user，用它刷新本地会话，保证前后端一致
          final body = jsonDecode(resp.body);
          if (body is Map && body['user'] != null) {
            auth.setSession(auth.token!, AppUser.fromJson(body['user']));
          }
        } else {
          // 同步失败：回滚语言并提示
          lang.setLang(prev);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update language')),
            );
          }
        }
      } catch (_) {
        // 网络异常：回滚并提示
        lang.setLang(prev);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network error')),
          );
        }
      }
    },
  ),
),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            ListTile(leading: const Icon(Icons.person),          title: const Text('Profile'),       onTap: (){}),
            ListTile(leading: const Icon(Icons.sticky_note_2),   title: const Text('My prayers'),    onTap: (){}),
            ListTile(leading: const Icon(Icons.group),           title: const Text('Friends'),       onTap: (){}),
            ListTile(leading: const Icon(Icons.notifications),   title: const Text('Notification'),  onTap: (){}),

            const SizedBox(height: 24),
            const Divider(),

            const SizedBox(height: 24),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                onPressed: () { Navigator.of(context).pop(); auth.signOut(); },
                child: Text(isCn ? '退出登录' : 'Log out'),
              ),
            ),
          ],
        ),
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
