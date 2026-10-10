import 'package:flutter/material.dart';

/// A reusable wrapper widget that dismisses the on-screen keyboard when a user
/// taps on neutral/blank areas of the screen.
///
/// Uses [HitTestBehavior.translucent] so interactive child widgets (buttons,
/// pickers, cards, dropdowns) receive touch events without hindrance.
class AppKeyboardDismiss extends StatelessWidget {
  final Widget child;

  const AppKeyboardDismiss({super.key, required this.child});

  /// Unfocuses the current focus node across the entire application or the
  /// provided [context] scope.
  static void dismiss([BuildContext? context]) {
    if (context != null) {
      FocusScope.of(context).unfocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Standard [TapRegionCallback] used for [TextField.onTapOutside] and
  /// [TextFormField.onTapOutside].
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
