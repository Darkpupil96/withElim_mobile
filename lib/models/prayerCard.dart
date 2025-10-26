// lib/models/prayerCard.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/auth_scope.dart'; // maybeOf 拿 token/user

const _kBase = 'https://withelim.com/api';
const _kHost = 'https://withelim.com';

// —— 删除权限结果的简单内存缓存：viewerId:prayerId:commentId -> bool
class _DeletePermCache {
  static final Map<String, bool> _map = {};
  static String _k(int uid, int pid, int cid) => '$uid:$pid:$cid';
  static bool? get(int uid, int pid, int cid) => _map[_k(uid, pid, cid)];
  static void set(int uid, int pid, int cid, bool v) => _map[_k(uid, pid, cid)] = v;
  static void clearForUser(int uid) => _map.removeWhere((k, _) => k.startsWith('$uid:'));
}

class Verse {
  final String version;
  final int b, c, v;
  final String text;
  const Verse({
    required this.version,
    required this.b,
    required this.c,
    required this.v,
    required this.text,
  });

  Map<String, dynamic> toPayload() => {'version': version, 'b': b, 'c': c, 'v': v};
}

class PrayerUser {
  final int id;
  final String username;
  final String? avatar;
  const PrayerUser({required this.id, required this.username, this.avatar});
}

class Prayer {
  final int id;
  final String title;
  final String content;
  final bool isPrivate;
  final DateTime createdAt;
  final PrayerUser user;
  final List<Verse> verses;

  final int likeCount;
  final bool likedByMe;

  const Prayer({
    required this.id,
    required this.title,
    required this.content,
    required this.isPrivate,
    required this.createdAt,
    required this.user,
    required this.verses,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  Prayer copyWith({
    String? title,
    String? content,
    bool? isPrivate,
    int? likeCount,
    bool? likedByMe,
  }) {
    return Prayer(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt,
      user: user,
      verses: verses,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class PrayerComment {
  final int id;
  final String content;
  final DateTime createdAt;
  final int userId;
  final String username;
  final String? avatar;
  const PrayerComment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.userId,
    required this.username,
    this.avatar,
  });

  static PrayerComment fromJson(Map<String, dynamic> j) {
    return PrayerComment(
      id: (j['id'] as num).toInt(),
      content: j['content'] ?? '',
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      userId: (j['user_id'] as num?)?.toInt() ?? -1,
      username: j['username'] ?? '',
      avatar: j['avatar'] as String?,
    );
  }
}

class CurrentUser {
  final int id;
  final String username;
  final String language; // 't_cn' | 't_kjv'
  const CurrentUser({required this.id, required this.username, this.language = 't_kjv'});
}

// 回调
typedef ToggleLike = Future<bool> Function(int prayerId, bool nextLike);
typedef SubmitComment = Future<bool> Function(int prayerId, String content);
typedef SavePrayer = Future<bool> Function(Prayer updated);
typedef DeletePrayer = Future<bool> Function(int prayerId);
typedef CanDeleteComment = Future<bool> Function(int prayerId, int commentId);
typedef DeleteComment = Future<bool> Function(int prayerId, int commentId);
typedef UpdateComment = Future<bool> Function(int prayerId, int commentId, String newContent);

class PrayerCard extends StatefulWidget {
  const PrayerCard({
    super.key,
    required this.prayer,
    required this.currentUser,
    required this.comments,
    this.onToggleLike,
    this.onSubmitComment,
    this.onSavePrayer,
    this.onDeletePrayer,
    this.onCanDeleteComment,
    this.onDeleteComment,
    this.onUpdateComment,
    this.onTapUser,
    this.fullscreen = false,
  });

  final Prayer prayer;
  final CurrentUser? currentUser;
  final List<PrayerComment> comments;

  final ToggleLike? onToggleLike;
  final SubmitComment? onSubmitComment;
  final SavePrayer? onSavePrayer;
  final DeletePrayer? onDeletePrayer;
  final CanDeleteComment? onDeleteComment;
  final DeleteComment? onCanDeleteComment;
  final UpdateComment? onUpdateComment;

  final void Function(int userId)? onTapUser;

  /// 是否全屏详情模式
  final bool fullscreen;

  @override
  State<PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<PrayerCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Prayer _prayer;
  List<PrayerComment> _comments = [];

  bool _hasLiked = false;
  int _likeCount = 0;

  // 编辑祷文
  bool _isEditing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _editPrivate = false;

  // 评论编辑
  int? _editingCommentId;
  final TextEditingController _editCommentCtrl = TextEditingController();
  final Map<int, bool> _commentPermissions = {};

  String get _lang => widget.currentUser?.language ?? 't_kjv';
  bool get _isCn => _lang == 't_cn';

  @override
  void initState() {
    super.initState();
    _prayer = widget.prayer;
    _comments = List.of(widget.comments);
    _hasLiked = _prayer.likedByMe;
    _likeCount = _prayer.likeCount;

    _titleCtrl = TextEditingController(text: _prayer.title);
    _contentCtrl = TextEditingController(text: _prayer.content);
    _editPrivate = _prayer.isPrivate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapFromApi();
    });
  }

  Future<void> _bootstrapFromApi() async {
    await Future.wait([
      _fetchLikeCount(),
      _fetchLikedByMe(),
      _fetchCommentsAndPerms(),
    ]);
  }

  @override
  void didUpdateWidget(covariant PrayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prayer.id != widget.prayer.id) {
      _prayer = widget.prayer;
      _titleCtrl.text = _prayer.title;
      _contentCtrl.text = _prayer.content;
      _editPrivate = _prayer.isPrivate;
      _comments = List.of(widget.comments);
      _hasLiked = _prayer.likedByMe;
      _likeCount = _prayer.likeCount;
      _commentPermissions.clear();
      _bootstrapFromApi();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _editCommentCtrl.dispose();
    super.dispose();
  }

  // --------------------- 小工具：确认对话框 ---------------------
  Future<bool> _confirmDelete({
    required String title,
    required String message,
    String? cancelLabel,
    String? deleteLabel,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel ?? (_isCn ? '取消' : 'Cancel')),
            ),
            FilledButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith((_) => cs.error),
                foregroundColor: MaterialStateProperty.resolveWith((_) => cs.onError),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(deleteLabel ?? (_isCn ? '删除' : 'Delete')),
            ),
          ],
        );
      },
    );
    return res == true;
  }

  // --------------------- 网络：读取 ---------------------
  Future<void> _fetchLikeCount() async {
    try {
      final r = await http.get(Uri.parse('$_kBase/prayers/${_prayer.id}/likes'));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (mounted) setState(() => _likeCount = (j['likeCount'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _fetchLikedByMe() async {
    final appUser = AuthScope.maybeOf(context)?.user;
    final token = AuthScope.maybeOf(context)?.token;
    if (appUser == null) return;
    try {
      final r = await http.get(
        Uri.parse('$_kBase/prayers/${_prayer.id}/isliked/${appUser.id}'),
        headers: token == null ? {} : {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (mounted) setState(() => _hasLiked = j['liked'] == true);
      }
    } catch (_) {}
  }

  Future<void> _fetchCommentsAndPerms() async {
    try {
      final r = await http.get(Uri.parse('$_kBase/prayers/${_prayer.id}/comments'));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        final list = (j['comments'] as List? ?? []).map((e) => PrayerComment.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _comments = list;
            _commentPermissions.clear();
          });
        }
        await _initCommentPermissions();
      }
    } catch (_) {}
  }

  Future<void> _initCommentPermissions() async {
    // 外部回调优先
    if (widget.onCanDeleteComment != null) {
      for (final c in _comments) {
        final ok = await widget.onCanDeleteComment!.call(_prayer.id, c.id);
        _commentPermissions[c.id] = ok;
      }
      if (mounted) setState(() {});
      return;
    }

    final viewer = AuthScope.maybeOf(context)?.user;
    final token = AuthScope.maybeOf(context)?.token;

    // 祷文作者：直接允许全部
    final isPrayerOwner =
        viewer != null && (viewer.id == _prayer.user.id || viewer.username == _prayer.user.username);
    if (isPrayerOwner) {
      for (final c in _comments) {
        _commentPermissions[c.id] = true;
        if (viewer != null) _DeletePermCache.set(viewer.id, _prayer.id, c.id, true);
      }
      if (mounted) setState(() {});
      return;
    }

    // 自己的评论：允许
    for (final c in _comments) {
      final isMine = viewer != null && (c.userId == viewer.id || (c.userId <= 0 && c.username == viewer.username));
      if (isMine) {
        _commentPermissions[c.id] = true;
        if (viewer != null) _DeletePermCache.set(viewer.id, _prayer.id, c.id, true);
      }
    }

    // 缓存补齐
    if (viewer != null) {
      for (final c in _comments) {
        if (_commentPermissions[c.id] == true) continue;
        final cached = _DeletePermCache.get(viewer.id, _prayer.id, c.id);
        if (cached != null) _commentPermissions[c.id] = cached;
      }
    }

    // 未登录或已覆盖全部
    if (token == null || _commentPermissions.length == _comments.length) {
      if (mounted) setState(() {});
      return;
    }

    // 其余请求 /candelete
    final futures = <Future<void>>[];
    for (final c in _comments) {
      if (_commentPermissions[c.id] == true) continue;
      futures.add(() async {
        try {
          final r = await http.get(
            Uri.parse('$_kBase/prayers/${_prayer.id}/comment/${c.id}/candelete'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (r.statusCode == 200) {
            final j = jsonDecode(r.body);
            final ok = j['canDelete'] == true;
            _commentPermissions[c.id] = ok;
            if (viewer != null) _DeletePermCache.set(viewer.id, _prayer.id, c.id, ok);
          }
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  // --------------------- 网络：写入 ---------------------
  Future<void> _toggleLike() async {
    final next = !_hasLiked;

    if (widget.onToggleLike != null) {
      final ok = await widget.onToggleLike!.call(_prayer.id, next);
      if (ok && mounted) {
        setState(() {
          _hasLiked = next;
          _likeCount += next ? 1 : -1;
        });
      }
      return;
    }

    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) {
      _snack(context, _isCn ? '请先登录' : 'Please log in first');
      return;
    }

    // 乐观更新
    setState(() {
      _hasLiked = next;
      _likeCount += next ? 1 : -1;
    });

    try {
      if (next) {
        final r = await http.post(
          Uri.parse('$_kBase/prayers/${_prayer.id}/like'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (r.statusCode == 200) return;

        final body = r.body;
        if (!body.contains('already')) throw Exception('like failed');
        final del = await http.delete(
          Uri.parse('$_kBase/prayers/${_prayer.id}/unlike'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (del.statusCode != 200) throw Exception('unlike failed');
        if (mounted) {
          setState(() {
            _hasLiked = false;
            _likeCount = (_likeCount - 1).clamp(0, 1 << 30);
          });
        }
      } else {
        final del = await http.delete(
          Uri.parse('$_kBase/prayers/${_prayer.id}/unlike'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (del.statusCode != 200) throw Exception('unlike failed');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasLiked = !next;
          _likeCount += next ? -1 : 1;
        });
      }
    }
  }

  // 提供给“回复输入页”的提交方法
  Future<bool> submitCommentText(String text) async {
    final content = text.trim();
    if (content.isEmpty) return false;

    if (widget.onSubmitComment != null) {
      final ok = await widget.onSubmitComment!.call(_prayer.id, content);
      if (ok) _fetchCommentsAndPerms();
      return ok;
    }

    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) {
      _snack(context, _isCn ? '请先登录' : 'Please log in first');
      return false;
    }

    try {
      final r = await http.post(
        Uri.parse('$_kBase/prayers/${_prayer.id}/comment'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'content': content}),
      );
      if (r.statusCode == 200) {
        _fetchCommentsAndPerms();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _savePrayer() async {
    if (widget.onSavePrayer != null) {
      final ok = await widget.onSavePrayer!.call(_prayer.copyWith(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        isPrivate: _editPrivate,
      ));
      if (ok && mounted) {
        setState(() {
          _prayer = _prayer.copyWith(
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
            isPrivate: _editPrivate,
          );
          _isEditing = false;
        });
      }
      return;
    }

    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) {
      _snack(context, _isCn ? '请先登录' : 'Please log in first');
      return;
    }

    try {
      final r = await http.put(
        Uri.parse('$_kBase/prayers/${_prayer.id}'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
          'is_private': _editPrivate,
          'verses': _prayer.verses.map((e) => e.toPayload()).toList(),
        }),
      );
      if (r.statusCode == 200 && mounted) {
        setState(() {
          _prayer = _prayer.copyWith(
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
            isPrivate: _editPrivate,
          );
          _isEditing = false;
        });
        _snack(context, _isCn ? '已更新' : 'Updated');
      } else {
        _snack(context, _isCn ? '更新失败' : 'Update failed');
      }
    } catch (_) {
      _snack(context, _isCn ? '更新失败' : 'Update failed');
    }
  }

  Future<void> _deletePrayer() async {
    // —— 新增：确认弹窗
    final confirmed = await _confirmDelete(
      title: _isCn ? '删除祷文' : 'Delete Prayer',
      message: _isCn ? '确定要删除这条祷文吗？此操作不可恢复。' : 'Are you sure you want to delete this prayer? This action cannot be undone.',
    );
    if (!confirmed) return;

    if (widget.onDeletePrayer != null) {
      final ok = await widget.onDeletePrayer!.call(_prayer.id);
      if (ok && mounted) {
        _snack(context, _isCn ? '已删除祷文' : 'Prayer deleted');
        if (widget.fullscreen && mounted) Navigator.of(context).maybePop();
      }
      return;
    }

    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) {
      _snack(context, _isCn ? '请先登录' : 'Please log in first');
      return;
    }
    try {
      final r = await http.delete(
        Uri.parse('$_kBase/prayers/${_prayer.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        _snack(context, _isCn ? '已删除祷文' : 'Prayer deleted');
        if (widget.fullscreen && mounted) Navigator.of(context).maybePop();
      } else {
        _snack(context, _isCn ? '删除失败' : 'Delete failed');
      }
    } catch (_) {
      _snack(context, _isCn ? '删除失败' : 'Delete failed');
    }
  }

  Future<void> _deleteComment(int id) async {
    // —— 新增：确认弹窗
    final confirmed = await _confirmDelete(
      title: _isCn ? '删除评论' : 'Delete Comment',
      message: _isCn ? '确定要删除这条评论吗？此操作不可恢复。' : 'Are you sure you want to delete this comment? This action cannot be undone.',
    );
    if (!confirmed) return;

    if (widget.onDeleteComment != null) {
      final ok = await widget.onDeleteComment!.call(_prayer.id, id);
      if (ok && mounted) {
        setState(() => _comments.removeWhere((e) => e.id == id));
      }
      return;
    }

    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) return;
    try {
      final r = await http.delete(
        Uri.parse('$_kBase/prayers/${_prayer.id}/comment/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) _fetchCommentsAndPerms();
    } catch (_) {}
  }

  Future<void> _saveCommentEdit() async {
    final id = _editingCommentId;
    if (id == null) return;

    if (widget.onUpdateComment != null) {
      final ok = await widget.onUpdateComment!.call(_prayer.id, id, _editCommentCtrl.text.trim());
      if (ok && mounted) {
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == id);
          if (idx >= 0) {
            final c = _comments[idx];
            _comments[idx] = PrayerComment(
              id: c.id,
              content: _editCommentCtrl.text.trim(),
              createdAt: c.createdAt,
              userId: c.userId,
              username: c.username,
              avatar: c.avatar,
            );
          }
          _editingCommentId = null;
          _editCommentCtrl.clear();
        });
      }
      return;
    }

    final token = AuthScope.maybeOf(context)?.token;
    if (token == null) return;

    try {
      final r = await http.put(
        Uri.parse('$_kBase/prayers/${_prayer.id}/comment/$id'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'content': _editCommentCtrl.text.trim()}),
      );
      if (r.statusCode == 200) {
        _editingCommentId = null;
        _editCommentCtrl.clear();
        _fetchCommentsAndPerms();
      }
    } catch (_) {}
  }

  // --------------------- 路由 ---------------------
  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrayerDetailPage(
          prayer: _prayer,
          currentUser: widget.currentUser,
          comments: _comments,
          onToggleLike: widget.onToggleLike,
          onSubmitComment: widget.onSubmitComment,
          onSavePrayer: widget.onSavePrayer,
          onDeletePrayer: widget.onDeletePrayer,
          onCanDeleteComment: widget.onCanDeleteComment,
          onDeleteComment: widget.onDeleteComment,
          onUpdateComment: widget.onUpdateComment,
          onTapUser: widget.onTapUser,
          isCn: _isCn,
        ),
      ),
    );
  }

  void _openReplyInput() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrayerReplyPage(
          prayer: _prayer,
          isCn: _isCn,
          onSubmit: submitCommentText,
        ),
        fullscreenDialog: true,
      ),
    );
    if (ok == true) _fetchCommentsAndPerms();
  }

  // --------------------- UI ---------------------
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    final card = Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部：头像/用户名/时间
                  Row(
                    children: [
                      _buildUserAvatar(_prayer.user, cs, radius: 16),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => widget.onTapUser?.call(_prayer.user.id),
                        child: Text(
                          _prayer.user.username,
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatTime(_prayer.createdAt),
                          style: TextStyle(fontSize: 12, color: cs.outline)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (!_isEditing)
                    Text(_prayer.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),

                  if (_isEditing) ...[
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        hintText: _isCn ? '标题' : 'Title',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: _isCn ? '内容' : 'Content',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          value: _editPrivate,
                          onChanged: (v) => setState(() => _editPrivate = v ?? false),
                        ),
                        Text(_isCn ? '私密' : 'Private'),
                        const Spacer(),
                        FilledButton(onPressed: _savePrayer, child: Text(_isCn ? '保存' : 'Save')),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _titleCtrl.text = _prayer.title;
                              _contentCtrl.text = _prayer.content;
                              _editPrivate = _prayer.isPrivate;
                            });
                          },
                          child: Text(_isCn ? '取消' : 'Cancel'),
                        ),
                      ],
                    ),
                  ] else ...[
  const SizedBox(height: 4),
  if (widget.fullscreen)
    // 详情页：显示全文
    Text(_prayer.content, style: const TextStyle(fontSize: 15, height: 1.5))
  else
    // 列表卡片：显示前10行 + Show more
    _ContentPreview(
      text: _prayer.content,
      isCn: _isCn,
      onShowMore: _openDetail, // 跳到你这页（PrayerDetailPage）
    ),
],

                  const SizedBox(height: 12),
                   if (widget.fullscreen) ...[
                  Text(_isCn ? '关联经文' : 'Related scriptures',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (_prayer.verses.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _prayer.verses
                          .map((v) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child:
                                    Text('[${v.v}] ${v.text}', style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                    )
                  else
                    Text(_isCn ? '无' : 'None', style: TextStyle(color: cs.outline)),

                  const SizedBox(height: 8),
                   ],
                  // 操作区：点赞、回复图标
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _toggleLike,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.add,
                                  size: 22,
                                  color: _hasLiked ? Colors.red.shade700 : const Color(0xFF388683)),
                              const SizedBox(width: 4),
                              Text('$_likeCount'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // 评论图标：无论列表/全屏都进入全屏输入页
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _openReplyInput,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.mode_comment_outlined, size: 20),
                              const SizedBox(width: 4),
                              Text('${_comments.length}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // —— 评论区：仅在全屏显示
                  if (widget.fullscreen && _comments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(color: cs.outlineVariant),
                    const SizedBox(height: 6),
                    ..._comments.map(_buildCommentTile).toList(),
                  ],
                ],
              ),
            ),

            // 右上角图标：仅在全屏且非编辑态显示；顺序：编辑在左、删除在右
            if (widget.fullscreen &&
                !_isEditing &&
                widget.currentUser?.username == _prayer.user.username) ...[
              Positioned(
                right: 40,
                top: -2,
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                  tooltip: _isCn ? '编辑祷文' : 'Edit',
                  onPressed: () => setState(() => _isEditing = true),
                ),
              ),
              Positioned(
                right: 0,
                top: -2,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  tooltip: _isCn ? '删除祷文' : 'Delete',
                  onPressed: _deletePrayer,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // 居中+宽度控制：列表更窄，全屏更宽
    final centeredCard = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.fullscreen ? 720 : 560),
        child: card,
      ),
    );

    if (widget.fullscreen) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: centeredCard,
      );
    }

    // 列表态：点击整张卡片 -> 全屏详情
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openDetail,
      child: centeredCard,
    );
  }

  /// 用户头像（若无则显示首字母）
  Widget _buildUserAvatar(PrayerUser user, ColorScheme cs, {double radius = 16}) {
    final raw0 = user.avatar?.trim();
    final String? raw = (raw0 == null || raw0.isEmpty || raw0.toLowerCase() == 'null') ? null : raw0;

    String? url;
    if (raw != null) {
      url = raw.startsWith('http') ? raw : '$_kHost${raw.startsWith('/') ? '' : '/'}$raw';
      if (url.startsWith('http://withelim.com')) {
        url = url.replaceFirst('http://', 'https://');
      }
    }

    return CircleAvatar(
      key: ValueKey('avatar_${user.id}_${raw ?? ''}'),
      radius: radius,
      backgroundColor: cs.secondaryContainer,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: (url == null)
          ? Text(
              (user.username.isNotEmpty ? user.username[0] : '?').toUpperCase(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            )
          : null,
    );
  }

  /// 评论头像 + 文本 + 右侧操作，整体对齐
  Widget _buildCommentTile(PrayerComment c) {
    final cs = Theme.of(context).colorScheme;
    final isMine = widget.currentUser != null &&
        (widget.currentUser!.id == c.userId ||
            (c.userId <= 0 && widget.currentUser!.username == c.username));
    final isPrayerOwner = widget.currentUser != null &&
        (widget.currentUser!.id == _prayer.user.id ||
            widget.currentUser!.username == _prayer.user.username);

    final canDelete = isMine || isPrayerOwner || _commentPermissions[c.id] == true;
    final canEdit = widget.currentUser?.username == c.username;

    // 头像 URL 处理
    String? url;
    final raw0 = c.avatar?.trim();
    final String? raw = (raw0 == null || raw0.isEmpty || raw0.toLowerCase() == 'null') ? null : raw0;
    if (raw != null) {
      url = raw.startsWith('http') ? raw : '$_kHost${raw.startsWith('/') ? '' : '/'}$raw';
      if (url.startsWith('http://withelim.com')) {
        url = url.replaceFirst('http://', 'https://');
      }
    }

    if (_editingCommentId == c.id) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.secondaryContainer,
              backgroundImage: url != null ? NetworkImage(url) : null,
              child: url == null
                  ? Text((c.username.isNotEmpty ? c.username[0] : '?').toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _editCommentCtrl..text = _editCommentCtrl.text.isEmpty ? c.content : _editCommentCtrl.text,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      FilledButton(onPressed: _saveCommentEdit, child: Text(_isCn ? '保存' : 'Save')),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _editingCommentId = null;
                            _editCommentCtrl.clear();
                          });
                        },
                        child: Text(_isCn ? '取消' : 'Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.secondaryContainer,
            backgroundImage: url != null ? NetworkImage(url) : null,
            child: url == null
                ? Text((c.username.isNotEmpty ? c.username[0] : '?').toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户名 + 时间
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (c.userId > 0) widget.onTapUser?.call(c.userId);
                      },
                      child: Text(
                        c.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatTime(c.createdAt), style: TextStyle(color: cs.outline, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(c.content, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),

          // 右侧操作：与文字行顶部对齐、统一大小
          if ((canEdit || canDelete) && widget.currentUser != null) ...[
            const SizedBox(width: 6),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () {
                  setState(() {
                    _editingCommentId = c.id;
                    _editCommentCtrl.text = c.content;
                  });
                },
                tooltip: _isCn ? '编辑' : 'Edit',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _deleteComment(c.id), // 会先弹出确认
                tooltip: _isCn ? '删除' : 'Delete',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ],
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final m2 = ScaffoldMessenger.maybeOf(context);
        m2
          ?..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
      });
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  String _formatTime(DateTime t) {
    return '${t.year.toString().padLeft(4, '0')}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ================= 全屏详情页（只显示返回 X；评论在正文下方） =================

class PrayerDetailPage extends StatelessWidget {
  const PrayerDetailPage({
    super.key,
    required this.prayer,
    required this.currentUser,
    required this.comments,
    this.onToggleLike,
    this.onSubmitComment,
    this.onSavePrayer,
    this.onDeletePrayer,
    this.onCanDeleteComment,
    this.onDeleteComment,
    this.onUpdateComment,
    this.onTapUser,
    required this.isCn,
  });

  final Prayer prayer;
  final CurrentUser? currentUser;
  final List<PrayerComment> comments;

  final ToggleLike? onToggleLike;
  final SubmitComment? onSubmitComment;
  final SavePrayer? onSavePrayer;
  final DeletePrayer? onDeletePrayer;
  final CanDeleteComment? onCanDeleteComment;
  final DeleteComment? onDeleteComment;
  final UpdateComment? onUpdateComment;

  final void Function(int userId)? onTapUser;
  final bool isCn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: isCn ? '关闭' : 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(isCn ? '祷文详情' : 'Prayer'),
      ),
      body: SafeArea(
        child: PrayerCard(
          prayer: prayer,
          currentUser: currentUser,
          comments: comments,
          onToggleLike: onToggleLike,
          onSubmitComment: onSubmitComment,
          onSavePrayer: onSavePrayer,
          onDeletePrayer: onDeletePrayer,
          onCanDeleteComment: onCanDeleteComment,
          onDeleteComment: onDeleteComment,
          onUpdateComment: onUpdateComment,
          onTapUser: onTapUser,
          fullscreen: true,
        ),
      ),
    );
  }
}

// ================= 全屏“输入评论”页（左 X / 右 Reply） =================

class PrayerReplyPage extends StatefulWidget {
  const PrayerReplyPage({
    super.key,
    required this.prayer,
    required this.isCn,
    required this.onSubmit,
  });

  final Prayer prayer;
  final bool isCn;
  final Future<bool> Function(String text) onSubmit;

  @override
  State<PrayerReplyPage> createState() => _PrayerReplyPageState();
}

class _PrayerReplyPageState extends State<PrayerReplyPage> {
  final TextEditingController _ctrl = TextEditingController();
  bool _posting = false;

  bool get _canSubmit => _ctrl.text.trim().isNotEmpty && !_posting;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      // 输入变化时刷新，触发按钮可用状态与样式更新
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      _snack(widget.isCn ? '请输入内容' : 'Please enter something');
      return;
    }
    setState(() => _posting = true);
    final ok = await widget.onSubmit(text);
    setState(() => _posting = false);
    if (ok) {
      Navigator.of(context).pop<bool>(true);
    } else {
      _snack(widget.isCn ? '提交失败,请先 登录' : 'Submit failed, please log in first');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCn = widget.isCn;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: isCn ? '关闭' : 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(isCn ? '写回复' : 'Reply'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: ButtonStyle(
                // 绿色可用 / 灰色禁用
                backgroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.disabled)) {
                    return Colors.grey;
                  }
                  return const Color(0xFF2A9D8F);
                }),
                // 始终白字
                foregroundColor: MaterialStateProperty.resolveWith((_) => Colors.white),
                padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
              ),
              child: Text(isCn ? '回复' : 'Reply'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.prayer.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  minLines: 6,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: isCn ? '输入你的回复…' : 'Enter your reply…',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ContentPreview extends StatelessWidget {
  const _ContentPreview({
    required this.text,
    required this.isCn,
    required this.onShowMore,
  });

  final String text;
  final bool isCn;
  final VoidCallback onShowMore;

  static const _style = TextStyle(fontSize: 15, height: 1.5);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 用 TextPainter 计算是否超过 10 行（基于视觉折行）
        final span = TextSpan(text: text, style: _style);
        final tp = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          maxLines: 10,
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);

        final exceeded = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: _style,
              maxLines: exceeded ? 10 : null,
              overflow: exceeded ? TextOverflow.ellipsis : TextOverflow.visible,
              softWrap: true,
            ),
            if (exceeded) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onShowMore,
                child: Text(
                  isCn ? '展开全文' : 'Show more',
                  style: TextStyle(
                    color: cs.primary,        // 蓝色高亮（跟随主题主色）
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
