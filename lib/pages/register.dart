import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app/auth_scope.dart';   // 新增：全局登录状态（上条消息里给的 AuthScope）
import '../app/app_lang.dart';     // 已有：语言作用域
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;

  static const String _base = 'https://withelim.com/api/auth';

  bool _isValidEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty &&
      _isValidEmail(_emailCtrl.text) &&
      _pwdCtrl.text.length >= 8;

  void _backToHome() {
    Navigator.popUntil(context, (r) => r.isFirst);
  }

Future<void> _register() async {
  if (!_canSubmit || _submitting) return;
  setState(() {
    _submitting = true;
    _error = null;
  });

  try {
    // 1) 先注册
    final resp = await http.post(
      Uri.parse('$_base/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _pwdCtrl.text,
      }),
    );

    if (resp.statusCode == 200) {
      // 2) 注册成功 -> 立刻自动登录拿 token + user
      final login = await http.post(
        Uri.parse('$_base/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'password': _pwdCtrl.text,
        }),
      );

      if (login.statusCode == 200) {
        final data = jsonDecode(login.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final userJson = data['user'] as Map<String, dynamic>;

        // 3) 写入全局会话 & 切语言
        final auth = AuthScope.of(context);
        final lang = LangScope.of(context);
        auth.setSession(token, AppUser.fromJson(userJson));
        lang.setLang(userJson['language'] as String? ?? 't_kjv');

        // 4) 回到首页
        if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
        return;
      } else {
        // 兜底：自动登录失败 -> 跳到密码页让用户手动登录
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/loginPassword',
              arguments: _emailCtrl.text.trim());
        }
        return;
      }
    } else {
      final data = jsonDecode(resp.body);
      setState(() {
        _error = (data is Map && data['error'] is String)
            ? data['error'] as String
            : 'Register failed';
      });
    }
  } catch (_) {
    setState(() => _error = 'Network error');
  } finally {
    if (mounted) setState(() => _submitting = false);
  }
}

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final lang = LangScope.of(context).lang;
    final isCn = lang == 't_cn';
    return Scaffold(
      backgroundColor: const Color(0xFF2A9D8F), // 背景色
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white, onPressed: _backToHome),
        title: const Text('WithElim', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: const TextStyle(color: Colors.white70),
              errorStyle: const TextStyle(color: Colors.red),
              helperStyle: const TextStyle(color: Colors.white70),
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
                  isCn?
                  '创建账户'
                  :'Create your account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Name
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration:  InputDecoration(
                    hintText: isCn?'姓名': 'Name',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Email
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: isCn?'邮箱地址':'Email',
                    errorText: _emailCtrl.text.isEmpty ||
                            _isValidEmail(_emailCtrl.text)
                        ? null
                        : (isCn ? '邮箱格式不正确' : 'Invalid email'),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Password
                TextField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: isCn?'密码':'Password',
                    helperText: _pwdCtrl.text.isEmpty
                        ? null
                        : (isCn
                            ? '密码至少8位'
                            : 'At least 8 characters'),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                ],

                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white, // 按钮文字颜色
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.white),
                    ),
                    onPressed: _canSubmit && !_submitting ? _register : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isCn?'注册':'Register'),
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

