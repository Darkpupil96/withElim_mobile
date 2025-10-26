// lib/pages/prayer_tab_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/prayerCard.dart'; // Prayer / PrayerUser / PrayerCard / CurrentUser
import '../app/app_lang.dart';
import '../app/auth_scope.dart';

const _kBase = 'https://withelim.com/api';

enum PrayerTabType { public, mine }

class PrayerTabPage extends StatefulWidget {
  const PrayerTabPage({super.key});

  @override
  State<PrayerTabPage> createState() => _PrayerTabPageState();
}

class _PrayerTabPageState extends State<PrayerTabPage> {
  PrayerTabType _currentTab = PrayerTabType.public;

  List<Prayer> _publicPrayers = [];
  List<Prayer> _myPrayers = [];
  bool _loading = true;
  bool _hasMorePublic = true;
  bool _hasMoreMine = true;

  /// userId -> avatar（相对或绝对 URL；为空字符串表示拉取过但无头像）
  final Map<int, String> _avatarCache = {};

  // 记录用于“变化检测”的关键值
  String? _lastLang;
  String? _lastAuthKey; // 例如 "uid:tokenExists" -> "123:true" / "-1:false"
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初次进入加载
    if (_didInit) return;
    _didInit = true;
    _loadInitial();
  }

  /// 检查语言或 Auth 是否变化，若变化则刷新数据
  void _maybeReloadOnContextChange() {
    final lang = LangScope.of(context).lang;
    final auth = AuthScope.of(context); // ← 订阅
    final authKey = '${auth.user?.id ?? -1}:${auth.token != null}';

    final langChanged = (_lastLang != null && _lastLang != lang);
    final authChanged = (_lastAuthKey != null && _lastAuthKey != authKey);

    // 首次记录
    _lastLang ??= lang;
    _lastAuthKey ??= authKey;

    if (langChanged || authChanged) {
      _lastLang = lang;
      _lastAuthKey = authKey;

      // 登录/退出立刻刷新
      Future.microtask(() async {
        if (!mounted) return;
        setState(() {
          _loading = true;
          // 退出后回到“公共祷告墙”
          if (auth.user == null) _currentTab = PrayerTabType.public;
        });
        // 可选：登录/退出时清空头像缓存，避免权限差异带来脏数据
        _avatarCache.clear();

        await _loadInitial();

        if (mounted) setState(() => _loading = false);
      });
    }
  }

  Future<void> _loadInitial() async {
    try {
      // 公共祷告
      await _fetchPrayers(PrayerTabType.public);

      // 我的祷告（仅登录后）
      final token = AuthScope.maybeOf(context)?.token;
      if (token != null && token.isNotEmpty) {
        await _fetchPrayers(PrayerTabType.mine, token: token);
      } else {
        setState(() {
          _myPrayers = [];
          _hasMoreMine = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 一次性获取某个 Tab 的祷文列表，并为其中所有作者补齐头像
  Future<void> _fetchPrayers(PrayerTabType type, {String? token}) async {
    final uri = Uri.parse(
      type == PrayerTabType.public
          ? "$_kBase/prayers/public"
          : "$_kBase/prayers/mine",
    );

    try {
      final headers = <String, String>{};
      if (type == PrayerTabType.mine && token != null) {
        headers["Authorization"] = "Bearer $token";
      }

      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) {
        debugPrint("❌ fetch prayers ${type.name} failed: ${resp.statusCode} ${resp.body}");
        if (type == PrayerTabType.public) {
          setState(() => _hasMorePublic = false);
        } else {
          setState(() => _hasMoreMine = false);
        }
        return;
      }

      final data = jsonDecode(resp.body);
      final prayersJson = (data["prayers"] as List<dynamic>? ?? []);

      // 收集需要头像的 userId（避免重复请求）
      final Set<int> userIds = {};
      for (final p in prayersJson) {
        final u = p["user"];
        if (u is Map && u["id"] != null) {
          userIds.add((u["id"] as num).toInt());
        }
      }
      await _prefetchAvatars(userIds);

      // 构建列表
      final newPrayers = prayersJson.map<Prayer>((p) {
        final u = (p["user"] as Map<String, dynamic>);
        final uid = (u["id"] as num).toInt();
        final avatar = _avatarCache[uid];

        return Prayer(
          id: p["id"],
          title: p["title"] ?? "",
          content: p["content"] ?? "",
          isPrivate: p["is_private"] ?? false,
          createdAt: DateTime.tryParse(p["created_at"] ?? "") ?? DateTime.now(),
          user: PrayerUser(
            id: uid,
            username: (u["username"] ?? '').toString(),
            avatar: (avatar == null || avatar.isEmpty) ? null : avatar,
          ),
          verses: (p["verses"] as List<dynamic>? ?? [])
              .map<Verse>((v) => Verse(
                    version: v["version"] ?? "",
                    b: v["b"],
                    c: v["c"],
                    v: v["v"],
                    text: v["text"] ?? "",
                  ))
              .toList(),
          likeCount: 0,
          likedByMe: false,
        );
      }).toList();

      // 🔑 关键：按创建时间降序，最新在前
      newPrayers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        if (type == PrayerTabType.public) {
          _publicPrayers = newPrayers;
          _hasMorePublic = newPrayers.isNotEmpty;
        } else {
          _myPrayers = newPrayers;
          _hasMoreMine = newPrayers.isNotEmpty;
        }
      });
    } catch (e) {
      debugPrint("❌ Error fetching prayers: $e");
      if (type == PrayerTabType.public) {
        setState(() => _hasMorePublic = false);
      } else {
        setState(() => _hasMoreMine = false);
      }
    }
  }

  /// 用公开接口分批并发拉取用户资料，填充 avatar 字段
  Future<void> _prefetchAvatars(Set<int> ids) async {
    final List<int> missing = ids.where((id) => !_avatarCache.containsKey(id)).toList();
    if (missing.isEmpty) return;

    const int kConcurrency = 6;
    for (int i = 0; i < missing.length; i += kConcurrency) {
      final batch = missing.sublist(i, math.min(i + kConcurrency, missing.length));
      await Future.wait(batch.map((id) async {
        try {
          final r = await http.get(Uri.parse('$_kBase/auth/public/$id'));
          if (r.statusCode == 200) {
            final j = jsonDecode(r.body);
            final String? avatar = (j['user']?['avatar'] as String?)?.trim();
            _avatarCache[id] = avatar ?? ''; // 空串表示请求过但没有头像
          } else {
            _avatarCache[id] = '';
          }
        } catch (_) {
          _avatarCache[id] = '';
        }
      }));
    }
  }

  // —— API：点赞 / 取消点赞 ——（沿用原实现）
  Future<bool> _toggleLikeApi(int prayerId, bool nextLike) async {
    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) return false;

    final headers = {"Authorization": "Bearer $token"};
    try {
      if (nextLike) {
        final resp = await http.post(
          Uri.parse("$_kBase/prayers/$prayerId/like"),
          headers: headers,
        );
        if (resp.statusCode == 200) return true;

        if (resp.body.contains("already liked")) {
          final del = await http.delete(
            Uri.parse("$_kBase/prayers/$prayerId/unlike"),
            headers: headers,
          );
          return del.statusCode == 200;
        }
        return false;
      } else {
        final del = await http.delete(
          Uri.parse("$_kBase/prayers/$prayerId/unlike"),
          headers: headers,
        );
        return del.statusCode == 200;
      }
    } catch (e) {
      debugPrint("toggle like error: $e");
      return false;
    }
  }

  // —— API：发表评论 ——（沿用原实现）
  Future<bool> _submitCommentApi(int prayerId, String content) async {
    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) return false;

    try {
      final resp = await http.post(
        Uri.parse("$_kBase/prayers/$prayerId/comment"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"content": content}),
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint("submit comment error: $e");
      return false;
    }
  }

  Widget _buildTabButton(PrayerTabType type, String label, ColorScheme cs) {
    final selected = _currentTab == type;
    return GestureDetector(
      onTap: () async {
        // 切换标签并刷新当前标签数据
        setState(() => _currentTab = type);
        final token = AuthScope.maybeOf(context)?.token;
        setState(() => _loading = true);
        await _fetchPrayers(type, token: token);
        if (mounted) setState(() => _loading = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            decoration: selected ? TextDecoration.underline : TextDecoration.none,
            fontSize: 16,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检查语言/Auth 变化（只要 build 被触发，这里就会检查并在变化时刷新）
    _maybeReloadOnContextChange();

    final cs = Theme.of(context).colorScheme;
    final lang = LangScope.of(context).lang;
    final isCn = lang == 't_cn';

    final appUser = AuthScope.of(context).user;
    final CurrentUser? currentUser = appUser == null
        ? null
        : CurrentUser(
            id: appUser.id,
            username: appUser.username,
            language: appUser.language,
          );

    final canShowMine = currentUser != null;
    final list = _currentTab == PrayerTabType.public ? _publicPrayers : _myPrayers;
    final noMore = _currentTab == PrayerTabType.public ? !_hasMorePublic : !_hasMoreMine;

    return SafeArea(
      child: Column(
        children: [
          // 顶部切换
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTabButton(PrayerTabType.public, isCn ? "公共祷告墙" : "Public Prayers", cs),
              if (canShowMine)
                _buildTabButton(PrayerTabType.mine, isCn ? "我的祷告" : "My Prayers", cs),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Text(
                          isCn ? "暂无祷告" : "No prayers yet",
                          style: const TextStyle(fontSize: 15, color: Color.fromARGB(255, 170, 170, 170)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final token = AuthScope.maybeOf(context)?.token;
                          await _fetchPrayers(_currentTab, token: token);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(30),
                          itemCount: list.length + 1,
                          itemBuilder: (context, i) {
                            if (i == list.length) {
                              if (noMore) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      isCn ? "没有更多祷告了" : "No more prayers",
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            final p = list[i];
                            return PrayerCard(
                              prayer: p,
                              currentUser: currentUser,
                              comments: const [],
                              onToggleLike: (id, next) => _toggleLikeApi(id, next),
                              onSubmitComment: (id, text) => _submitCommentApi(id, text),
                              // 头像已在 list 层补齐，卡片无需再请求
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

