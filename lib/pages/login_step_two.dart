import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/auth_scope.dart';   // 全局会话
import '../app/app_lang.dart';     // 全局语言

class LoginPasswordPage extends StatefulWidget {
  const LoginPasswordPage({super.key, required this.email});
  final String email;

  @override
  State<LoginPasswordPage> createState() => _LoginPasswordPageState();
}

class _LoginPasswordPageState extends State<LoginPasswordPage> {
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static const String _base = 'https://withelim.com/api/auth';

  // 小工具：根据语言返回文案
  String t(BuildContext context, String en, String zh) {
    final isCn = LangScope.of(context).lang == 't_cn';
    return isCn ? zh : en;
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await http.post(
        Uri.parse('$_base/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'password': _pwdCtrl.text}),
      );

      // 解析可能不是 json 的错误响应时的兜底
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {}

      if (resp.statusCode == 200) {
        final token = data['token'] as String;
        final userJson = data['user'] as Map<String, dynamic>;

        // 1) 全局写入会话
        final auth = AuthScope.of(context);
       await auth.setSession(token, AppUser.fromJson(userJson));

        // 2) 按用户语言切换 UI
        final lang = LangScope.of(context);
        lang.setLang(userJson['language'] as String? ?? 't_kjv');

        // 3) 回到首页
        if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
      } else {
        final serverMsg = (data['error'] as String?) ?? '';
        _error = serverMsg.isNotEmpty
            ? serverMsg
            : t(context, 'Invalid email or password', '邮箱或密码不正确');
        setState(() {});
      }
    } catch (e) {
      _error = t(context, 'Network error', '网络错误，请稍后重试');
      setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToHome() {
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isCn = LangScope.of(context).lang == 't_cn';

    return Scaffold(
      backgroundColor: const Color(0xFF2A9D8F), // 背景色
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: _backToHome,
        ),
        title: const Text('WithElim', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: const TextStyle(color: Colors.white70),
              errorStyle: const TextStyle(color: Colors.red),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  t(context, 'Enter your password', '请输入密码'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // 锁定邮箱
                TextFormField(
                  initialValue: widget.email,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    labelText: isCn ? '邮箱' : 'Email',
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),

                // 密码输入框
                TextField(
                  controller: _pwdCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isCn ? '密码' : 'Password',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white,
                      ),
                      tooltip: isCn ? '显示/隐藏密码' : 'Show/Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: Color.fromARGB(255, 245, 171, 165)),
                  ),
                ],

                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF264653),
                      side: const BorderSide(color: Colors.white),
                    ),
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isCn ? '登录' : 'Log in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
