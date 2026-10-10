import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_desk/core/widgets/app_text_field.dart';
import 'package:survey_desk/core/widgets/keyboard_dismiss_wrapper.dart';

void main() {
  group('AppKeyboardDismiss & Keyboard Dismissal Tests', () {
    testWidgets(
      'Tapping outside an active AppTextField dismisses focus',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AppKeyboardDismiss(
              child: Scaffold(
                body: Column(
                  children: [
                    const AppTextField(
                      label: 'Name',
                      hint: 'Enter your name',
                    ),
                    const SizedBox(height: 50),
                    Container(
                      key: const ValueKey('blank_area'),
                      height: 100,
                      width: double.infinity,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Tap inside the text field to gain focus
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

        // Tap outside on the blank area
        await tester.tap(find.byKey(const ValueKey('blank_area')));
        await tester.pump();

        // Focus should be dismissed
        expect(
          FocusManager.instance.primaryFocus?.context?.widget is EditableText,
          isFalse,
        );
      },
    );

    testWidgets(
      'Tapping between two AppTextFields transfers focus smoothly',
      (tester) async {
        final controller1 = TextEditingController();
        final controller2 = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: AppKeyboardDismiss(
              child: Scaffold(
                body: Column(
                  children: [
                    AppTextField(
                      label: 'Field 1',
                      controller: controller1,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Field 2',
                      controller: controller2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final fields = find.byType(EditableText);
        expect(fields, findsNWidgets(2));

        // Tap first field
        await tester.tap(fields.first);
        await tester.pump();
        final firstEditable = tester.widget<EditableText>(fields.first);
        expect(firstEditable.focusNode.hasFocus, isTrue);

        // Tap second field directly
        await tester.tap(fields.last);
        await tester.pump();
        final secondEditable = tester.widget<EditableText>(fields.last);
        expect(firstEditable.focusNode.hasFocus, isFalse);
        expect(secondEditable.focusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'Tapping an action button while a text field is focused fires button callback and dismisses field focus',
      (tester) async {
        bool buttonPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: AppKeyboardDismiss(
              child: Scaffold(
                body: Column(
                  children: [
                    const AppTextField(label: 'Input'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        buttonPressed = true;
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Focus the text field
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

        // Tap the button
        await tester.tap(find.text('Submit'));
        await tester.pump();

        // Button action must have fired
        expect(buttonPressed, isTrue);
        // Field focus should have been dismissed
        expect(
          FocusManager.instance.primaryFocus?.context?.widget is EditableText,
          isFalse,
        );
      },
    );

    testWidgets(
      'Custom onTapOutside override in AppTextField is respected',
      (tester) async {
        bool customOutsideTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AppTextField(
                    label: 'Custom Field',
                    onTapOutside: (_) {
                      customOutsideTapped = true;
                    },
                  ),
                  const SizedBox(height: 40),
                  const Text('Outside Content'),
                ],
              ),
            ),
          ),
        );

        // Focus field
        await tester.tap(find.byType(EditableText));
        await tester.pump();

        // Tap outside
        await tester.tap(find.text('Outside Content'));
        await tester.pump();

        expect(customOutsideTapped, isTrue);
      },
    );

    testWidgets(
      'Dragging a scrollable with onDrag dismiss behavior unfocuses the keyboard',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: SizedBox(
                  height: 1200,
                  child: Column(
                    children: const [
                      AppTextField(label: 'Top Input'),
                      SizedBox(height: 500),
                      Text('Bottom Content'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // Focus input
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

        // Drag the scroll view
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -100));
        await tester.pump();

        // Focus should be unfocused due to drag
        expect(
          FocusManager.instance.primaryFocus?.context?.widget is EditableText,
          isFalse,
        );
      },
    );
  });
}
