import 'package:flutter/material.dart';

class AppKeyboardDismiss extends StatelessWidget {
  final Widget child;

  const AppKeyboardDismiss({super.key, required this.child});

  static void dismiss([BuildContext? context]) {
    if (context != null) {
      FocusScope.of(context).unfocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  static void onTapOutside(PointerDownEvent event) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => dismiss(context),
      child: child,
    );
  }
}
