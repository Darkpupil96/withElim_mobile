// lib/app/auth_scope.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTokenKey = 'auth_token';
const _kExpiryKey = 'auth_expiry';

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
        id: j['id'] as int,
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

  String? get token => _token;
  AppUser? get user => _user;
  bool get isAuthed => _token != null && _user != null;

  /* ===================== 核心：登录 ===================== */

  Future<void> setSession(String token, AppUser user) async {
    _token = token;
    _user = user;

    await _saveToCache(token, user);
    notifyListeners();
  }

  /* ===================== 核心：自动恢复 ===================== */

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(_kTokenKey);
    final expiry = prefs.getInt(_kExpiryKey);
    final userJson = prefs.getString('user');

    if (token == null || expiry == null || userJson == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < expiry) {
      _token = token;
      _user = AppUser.fromJson(jsonDecode(userJson));

      // 🔥 自动续期
      await _refreshTTL();

      notifyListeners();
    } else {
      await _clearCache();
    }
  }

  /* ===================== 核心：登出 ===================== */

  Future<void> signOut() async {
    _token = null;
    _user = null;
    await _clearCache();
    notifyListeners();
  }

  /* ===================== 乐观更新 ===================== */

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

  void updateReading({required int book, required int chapter}) {
    if (!isAuthed || _user == null) return;
    _user = _user!.copyWith(readingBook: book, readingChapter: chapter);
    _saveUserOnly();
    notifyListeners();
  }

  /* ===================== TTL 刷新 ===================== */

  Future<void> refreshSession() async {
    if (!isAuthed) return;
    await _refreshTTL();
  }

  /* ===================== 内部方法 ===================== */

  Future<void> _saveToCache(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();

    final expiry =
        DateTime.now().add(const Duration(days: 14)).millisecondsSinceEpoch;

    await prefs.setString(_kTokenKey, token);
    await prefs.setInt(_kExpiryKey, expiry);
    await prefs.setString('user', jsonEncode(user.toJson()));
  }

  Future<void> _saveUserOnly() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      await prefs.setString('user', jsonEncode(_user!.toJson()));
    }
  }

  Future<void> _refreshTTL() async {
    final prefs = await SharedPreferences.getInstance();

    final newExpiry =
        DateTime.now().add(const Duration(days: 14)).millisecondsSinceEpoch;

    await prefs.setInt(_kExpiryKey, newExpiry);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kExpiryKey);
    await prefs.remove('user');
  }
}

/* ===================== Scope ===================== */

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

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
  bool updateShouldNotify(
          covariant InheritedNotifier<AuthController> oldWidget) =>
      true;
}
