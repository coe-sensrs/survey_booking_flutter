import 'package:flutter/material.dart';

enum DeviceWindowSize { compact, medium, expanded }

class AppBreakpoints {
  AppBreakpoints._();

  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 840.0;

  static DeviceWindowSize getWindowSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < compactMaxWidth) {
      return DeviceWindowSize.compact;
    } else if (width < mediumMaxWidth) {
      return DeviceWindowSize.medium;
    } else {
      return DeviceWindowSize.expanded;
    }
  }

  static bool isCompact(BuildContext context) =>
      getWindowSize(context) == DeviceWindowSize.compact;
}
