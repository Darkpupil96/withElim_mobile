import 'package:flutter/material.dart';
import '../app/app_lang.dart'; // ← 引入全局语言作用域

class LoginEmailPage extends StatefulWidget {
  const LoginEmailPage({super.key});
  @override
  State<LoginEmailPage> createState() => _LoginEmailPageState();
}

class _LoginEmailPageState extends State<LoginEmailPage> {
  final _emailCtrl = TextEditingController();
  bool _valid = false;

  bool _isValidEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() {
      setState(() => _valid = _isValidEmail(_emailCtrl.text));
    });
  }

  void _toPwd() {
    final email = _emailCtrl.text.trim();
    if (_isValidEmail(email)) {
      Navigator.pushNamed(context, '/loginPassword', arguments: email);
    }
  }

  void _backToHome() {
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = LangScope.of(context).lang;
    final isCn = lang == 't_cn';

    return Scaffold(
      backgroundColor: const Color(0xFF2A9D8F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white, onPressed: _backToHome),
        title: Text(
          'WithElim',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: const TextStyle(color: Colors.white70),
              errorStyle:
                  const TextStyle(color: Color.fromARGB(255, 245, 171, 165)),
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
                  isCn
                      ? '请输入你的邮箱以继续'
                      : 'To get started, first enter your email',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isCn ? '邮箱' : 'Email',
                    errorText: _emailCtrl.text.isEmpty || _valid
                        ? null
                        : (isCn ? '邮箱格式不正确' : 'Invalid email'),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(isCn ? '注册' : 'Register'),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF264653),
                        side: const BorderSide(color: Colors.white),
                      ),
                      onPressed: _valid ? _toPwd : null,
                      child: Text(isCn ? '下一步' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


