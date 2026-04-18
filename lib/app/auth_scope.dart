// lib/app/auth_scope.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTokenKey = 'auth_token';
const _kUserKey = 'auth_user';

class AppUser {
  final int id;
  final String username;
  final String email;
  final String? avatar;
  final String language;
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
        id: (j['id'] as num).toInt(),
        username: j['username'] as String,
        email: j['email'] as String,
        avatar: j['avatar'] as String?,
        language: (j['language'] as String?) ?? 't_kjv',
        readingBook: (j['reading_book'] as num?)?.toInt(),
        readingChapter: (j['reading_chapter'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar': avatar,
        'language': language,
        'reading_book': readingBook,
        'reading_chapter': readingChapter,
      };

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
  bool _bootstrapped = false;

  String? get token => _token;
  AppUser? get user => _user;

  /// 仅表示当前内存里有 token + user
  bool get isAuthed => _token != null && _user != null;

  /// 是否完成了启动时的自动恢复检查
  bool get isBootstrapped => _bootstrapped;

  /* ===================== 登录成功后设置 session ===================== */

  Future<void> setSession(String token, AppUser user) async {
    _token = token;
    _user = user;
    await _saveToCache();
    notifyListeners();
  }

  /* ===================== App 启动时自动恢复 ===================== */
  /// 使用方式：
  /// await auth.tryAutoLogin(
  ///   validateToken: (token) async {
  ///     final res = await http.get(...Authorization: Bearer $token...);
  ///     return res.statusCode == 200;
  ///   },
  /// );
 Future<bool> tryAutoLogin({
  Future<bool> Function(String token)? validateToken,
}) async {
  final prefs = await SharedPreferences.getInstance();

  final cachedToken = prefs.getString(_kTokenKey);
  final userJson = prefs.getString(_kUserKey);

  if (cachedToken == null || cachedToken.isEmpty || userJson == null) {
    _bootstrapped = true;
    notifyListeners();
    return false;
  }

  try {
    _token = cachedToken;
    _user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);

    if (validateToken != null) {
      final ok = await validateToken(cachedToken);
      if (!ok) {
        await signOut(notify: false);
        _bootstrapped = true;
        notifyListeners();
        return false;
      }
    }

    _bootstrapped = true;
    notifyListeners();
    return true;
  } catch (_) {
    await signOut(notify: false);
    _bootstrapped = true;
    notifyListeners();
    return false;
  }
}

  /* ===================== 401 / token 失效时统一处理 ===================== */

  Future<void> handleUnauthorized() async {
    await signOut();
  }

  /* ===================== 登出 ===================== */

  Future<void> signOut({bool notify = true}) async {
    _token = null;
    _user = null;
    await _clearCache();

    if (notify) {
      notifyListeners();
    }
  }

  /* ===================== 乐观更新 user ===================== */

  void setUser(AppUser user) {
    if (!isAuthed) return;
    _user = user;
    _saveUserOnly();
    notifyListeners();
  }

  void updateLanguage(String language) {
    if (!isAuthed || _user == null) return;
    _user = _user!.copyWith(language: language);
    _saveUserOnly();
    notifyListeners();
  }

  void updateReading({
    required int book,
    required int chapter,
  }) {
    if (!isAuthed || _user == null) return;
    _user = _user!.copyWith(
      readingBook: book,
      readingChapter: chapter,
    );
    _saveUserOnly();
    notifyListeners();
  }

  /* ===================== 内部缓存方法 ===================== */

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();

    if (_token != null) {
      await prefs.setString(_kTokenKey, _token!);
    }

    if (_user != null) {
      await prefs.setString(_kUserKey, jsonEncode(_user!.toJson()));
    }
  }

  Future<void> _saveUserOnly() async {
    final prefs = await SharedPreferences.getInstance();

    if (_user != null) {
      await prefs.setString(_kUserKey, jsonEncode(_user!.toJson()));
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
  }
}

/* ===================== Scope ===================== */

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(
          notifier: controller,
        );

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope not found in context');
    return scope!.notifier!;
  }

  static AuthController? maybeOf(
    BuildContext context, {
    bool listen = false,
  }) {
    if (listen) {
      return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
    }

    final element =
        context.getElementForInheritedWidgetOfExactType<AuthScope>();
    final widget = element?.widget;
    return widget is AuthScope ? widget.notifier : null;
  }

  @override
  bool updateShouldNotify(covariant AuthScope oldWidget) => true;
}
