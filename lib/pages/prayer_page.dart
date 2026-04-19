import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://withelim.com';

class PrayerPage extends StatefulWidget {
  final String lang;
  final int bookId;
  final int chapter;
  final String currentBookName;
  final bool isPrayerPrivate;
  final List selected;
  final String token;
  final String Function(int) chapterCnBuilder;
  final String Function(String en, String cn) tr;

  const PrayerPage({
    super.key,
    required this.lang,
    required this.bookId,
    required this.chapter,
    required this.currentBookName,
    required this.isPrayerPrivate,
    required this.selected,
    required this.token,
    required this.chapterCnBuilder,
    required this.tr,
  });

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  late bool _isPrivate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // ✅ 沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _isPrivate = widget.isPrayerPrivate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Map<String, String> _headers() => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  Future<void> _submitPrayer() async {
    if (_isSubmitting) return;

    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.tr('Please enter content', '请输入内容')),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'is_private': _isPrivate,
        'verses': widget.selected
            .map((v) => {
                  'version': widget.lang,
                  'b': widget.bookId,
                  'c': widget.chapter,
                  'v': v.verse,
                })
            .toList(),
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/api/prayers/'),
        headers: _headers(),
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        Navigator.pop(context, true);
      } else {
        throw Exception();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.tr('Error', '提交失败'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstFive = widget.selected.take(5).toList();
    final remaining = widget.selected.skip(5).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.tr('Write your prayer', '写下你的祷告')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitPrayer,
            child: Text(
              _isSubmitting
                  ? widget.tr('Submitting...', '提交中...')
                  : widget.tr('Submit', '提交'),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.currentBookName} ${widget.lang == 't_cn' ? widget.chapterCnBuilder(widget.chapter) : 'Chapter ${widget.chapter}'}',
              ),
              const SizedBox(height: 12),

              /// 标题
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: widget.tr('Prayer Title', '祷告标题'),
                ),
              ),

              const SizedBox(height: 16),

              /// 可见性
              Text(widget.tr('Visibility:', '可见性')),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      value: false,
                      groupValue: _isPrivate,
                      title: Text(widget.tr('Public', '公开')),
                      onChanged: (v) => setState(() => _isPrivate = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      value: true,
                      groupValue: _isPrivate,
                      title: Text(widget.tr('Private', '私密')),
                      onChanged: (v) => setState(() => _isPrivate = v!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// 内容
              TextField(
                controller: _contentController,
                minLines: 6,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: widget.tr('Enter your prayer', '请输入祷告内容'),
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              /// 经文
              Text(widget.tr('Selected verses:', '引用经文'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 8),

              ...firstFive.map((v) => Text('[${v.verse}] ${v.text}')),

              if (remaining.isNotEmpty)
                Wrap(
                  children: remaining.map((v) => Text('[${v.verse}]')).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}