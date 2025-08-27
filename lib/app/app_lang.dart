import 'package:flutter/material.dart';

class LangController extends ChangeNotifier {
  String _lang = 't_kjv'; // 默认英文
  String get lang => _lang;

  void setLang(String v) {
    if (v == _lang) return;
    _lang = v;
    notifyListeners();
  }
}

class LangScope extends InheritedNotifier<LangController> {
  const LangScope({
    super.key,
    required LangController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static LangController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LangScope>();
    assert(scope != null, 'LangScope not found in widget tree');
    return scope!.notifier!;
  }
}
