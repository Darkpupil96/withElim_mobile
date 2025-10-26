// lib/app/auth_scope.dart
import 'package:flutter/material.dart';

class AppUser {
  final int id;
  final String username;
  final String email;
  final String? avatar;
  final String language;

  // ✅ 新增：阅读进度（可空，未同步/未读时为 null）
  final int? readingBook;
  final int? readingChapter;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    required this.language,
    this.readingBook,
    this.readingChapter,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as int,
    username: j['username'] as String,
    email: j['email'] as String,
    avatar: j['avatar'] as String?,
    language: (j['language'] as String?) ?? 't_kjv',
    // ✅ /auth/me 会返回这两个字段；/login 可能没有，处理为可空
    readingBook: (j['reading_book'] as num?)?.toInt(),
    readingChapter: (j['reading_chapter'] as num?)?.toInt(),
  );

  // ✅ 便于乐观更新
  AppUser copyWith({
    String? username,
    String? email,
    String? avatar,
    String? language,
    int? readingBook,
    int? readingChapter,
  }) {
    return AppUser(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      language: language ?? this.language,
      readingBook: readingBook ?? this.readingBook,
      readingChapter: readingChapter ?? this.readingChapter,
    );
  }
}


class AuthController extends ChangeNotifier {
  String? _token;
  AppUser? _user;

  String? get token => _token;
  AppUser? get user => _user;
  bool get isAuthed => _token != null && _user != null;

  void setSession(String token, AppUser user) {
    _token = token;
    _user  = user;
    notifyListeners();
  }

  void signOut() {
    _token = null;
    _user = null;
    notifyListeners();
  }

  // ✅ 新增：只更新 user（例如拉到最新的 /auth/me）
  void setUser(AppUser user) {
    if (!isAuthed) return;
    _user = user;
    notifyListeners();
  }

  // ✅ 新增：乐观更新语言（/auth/update 成功后或前置乐观）
  void updateLanguage(String language) {
    if (!isAuthed || _user == null) return;
    _user = _user!.copyWith(language: language);
    notifyListeners();
  }

  // ✅ 新增：乐观更新阅读进度（/auth/update-reading 成功后或前置乐观）
  void updateReading({required int book, required int chapter}) {
    if (!isAuthed || _user == null) return;
    _user = _user!.copyWith(readingBook: book, readingChapter: chapter);
    notifyListeners();
  }
}


/// Inherited/Notifier封装
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({super.key, required AuthController controller, required Widget child})
      : super(notifier: controller, child: child);

  static AuthController of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(w != null, 'AuthScope not found in context');
    return w!.notifier!;
  }
static AuthController? maybeOf(BuildContext context, {bool listen = false}) {
    if (listen) {
      final w = context.dependOnInheritedWidgetOfExactType<AuthScope>();
      return w?.notifier;
    } else {
      final el = context.getElementForInheritedWidgetOfExactType<AuthScope>();
      final w = el?.widget as AuthScope?;
      return w?.notifier;
    }
  }
  @override
  bool updateShouldNotify(covariant InheritedNotifier<AuthController> oldWidget) => true;
}
