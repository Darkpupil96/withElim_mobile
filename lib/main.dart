// lib/main.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app/app_lang.dart';
import 'app/auth_scope.dart';
import 'pages/bible.dart';
import 'pages/home.dart';
import 'pages/login_step_one.dart';
import 'pages/login_step_two.dart';
import 'pages/prayer.dart';
import 'pages/register.dart';

Future<void> main() async {
  
  WidgetsFlutterBinding.ensureInitialized();

  final langController = LangController();
  final authController = AuthController();

  await authController.tryAutoLogin(
    validateToken: (token) async {
      final res = await http.get(
        Uri.parse('http://withelim.com/api/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return res.statusCode == 200;
    },
  );

  runApp(
    AuthScope(
      controller: authController,
      child: LangScope(
        controller: langController,
        child: WithElimApp(authController: authController),
      ),
    ),
  );
}

class WithElimApp extends StatefulWidget {
  const WithElimApp({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<WithElimApp> createState() => _WithElimAppState();
}

class _WithElimAppState extends State<WithElimApp> {
  late final LangController _lang;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _lang = LangController();
    _auth = widget.authController;
  }

  @override
  void dispose() {
    _lang.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LangScope(
      controller: _lang,
      child: AuthScope(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0.5,
            ),
          ),
          home: const HomeScreen(),
          routes: {
            '/bible': (ctx) {
              final args =
                  ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
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
  const HomeScreen({
    super.key,
    this.initialBibleTarget,
  });

  final Map<String, int>? initialBibleTarget;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _current = 0;

  final BibleJumpController _bibleCtl = BibleJumpController();

late final List<Widget> _pages = [
  HomeTab(
    key: const PageStorageKey('home'),
    onJumpToVerse: (b, c, v) {
      setState(() => _current = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bibleCtl.jumpTo(b, c, v);
      });
    },
  ),
  BiblePage(
    key: const PageStorageKey('bible'),
    controller: _bibleCtl,
  ),
  const _PrayerTab(key: PageStorageKey('prayer')),
  const _CommunityTab(key: PageStorageKey('community')),
];

  @override
  void initState() {
    super.initState();

    if (widget.initialBibleTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _current = 1);
        final t = widget.initialBibleTarget!;
        _bibleCtl.jumpTo(t['b']!, t['c']!, t['v']!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    final isCn = lang.lang == 't_cn';

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
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF388683),
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) {
              final auth = AuthScope.of(ctx);

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Scaffold.of(ctx).openEndDrawer(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color.fromARGB(179, 142, 228, 221),
                    backgroundImage:
                        auth.isAuthed && (auth.user?.avatar?.isNotEmpty ?? false)
                            ? NetworkImage(auth.user!.avatar!) as ImageProvider
                            : null,
                    child: !(auth.isAuthed &&
                            (auth.user?.avatar?.isNotEmpty ?? false))
                        ? const Icon(Icons.person, size: 24)
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      endDrawer: const _AuthEndDrawer(),
      endDrawerEnableOpenDragGesture: true,
      body: IndexedStack(
        index: _current,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _current,
        onDestinationSelected: (i) => setState(() => _current = i),
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
  const _AuthEndDrawer();

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    final auth = AuthScope.of(context);
    final isCn = lang.lang == 't_cn';

    if (!auth.isAuthed) {
      return Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 10)),
                      Text(
                        isCn ? '未登录' : 'Visitor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(isCn ? '语言：' : 'Language:'),
                          const SizedBox(width: 6),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: lang.lang,
                              items: const [
                                DropdownMenuItem(
                                  value: 't_kjv',
                                  child: Text('English'),
                                ),
                                DropdownMenuItem(
                                  value: 't_cn',
                                  child: Text('中文'),
                                ),
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
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushNamed(context, '/loginEmail');
                      },
                      child: Text(isCn ? '登录' : 'Log in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushNamed(context, '/register');
                      },
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

    final u = auth.user!;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: (u.avatar?.isNotEmpty ?? false)
                      ? NetworkImage(u.avatar!)
                      : null,
                  child: (u.avatar?.isEmpty ?? true)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u.email,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(isCn ? '语言：' : 'Language:'),
                          const SizedBox(width: 6),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: lang.lang,
                              items: const [
                                DropdownMenuItem(
                                  value: 't_kjv',
                                  child: Text('English'),
                                ),
                                DropdownMenuItem(
                                  value: 't_cn',
                                  child: Text('中文'),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;

                                final prev = lang.lang;
                                lang.setLang(v);

                                final auth = AuthScope.of(context);
                                if (!auth.isAuthed) return;

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
                                    final body = jsonDecode(resp.body);
                                    if (body is Map && body['user'] != null) {
                                      await auth.setSession(
                                        auth.token!,
                                        AppUser.fromJson(body['user']),
                                      );
                                    }
                                  } else {
                                    lang.setLang(prev);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isCn
                                                ? '语言更新失败'
                                                : 'Failed to update language',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (_) {
                                  lang.setLang(prev);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isCn
                                              ? '网络异常，请稍后重试'
                                              : 'Network error. Please try again later.',
                                        ),
                                      ),
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
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(isCn ? '个人资料' : 'Profile'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2),
              title: Text(isCn ? '我的祷告' : 'My prayers'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: Text(isCn ? '好友' : 'Friends'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(isCn ? '通知' : 'Notification'),
              onTap: () {},
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await auth.signOut();
                },
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
    return Image.asset(
      'assets/images/logo.png',
      height: 34,
      fit: BoxFit.contain,
    );
  }
}

class _PrayerTab extends StatelessWidget {
  const _PrayerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PrayerTabPage();
  }
}

class _CommunityTab extends StatelessWidget {
  const _CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Community (WIP)',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}