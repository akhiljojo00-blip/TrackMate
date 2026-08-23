import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/widgets/custom_button.dart';
import 'package:trackmate/widgets/custom_text_field.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('CustomButton renders and triggers onPressed', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Click Me',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      await tester.tap(find.text('Click Me'));
      expect(pressed, true);
    });

    testWidgets('CustomTextField renders label and accepts input', (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              controller: controller,
              labelText: 'Email',
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'test@trackmate.com');
      expect(controller.text, 'test@trackmate.com');
    });
  });
}
