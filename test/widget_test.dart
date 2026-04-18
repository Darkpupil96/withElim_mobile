// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:withelim_mobile/main.dart';
import 'package:withelim_mobile/app/auth_scope.dart';
import 'package:withelim_mobile/app/app_lang.dart';

void main() {
  testWidgets('app renders', (WidgetTester tester) async {
    final authController = AuthController();
    final langController = LangController();

    await tester.pumpWidget(
      AuthScope(
        controller: authController,
        child: LangScope(
          controller: langController,
          child: WithElimApp(authController: authController),
        ),
      ),
    );

    expect(find.text('WithElim'), findsOneWidget);
  });
}
