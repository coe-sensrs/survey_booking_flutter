/// Spacing and shape constants from the Sage & Stone design system.
/// Base unit: 8px grid. Place in lib/theme/app_spacing.dart.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 48;
  static const double gutter = 16;
  static const double marginMobile = 16;
}

/// Corner radii from the design system's "Rounded" shape language.
class AppRadii {
  AppRadii._();

  static const double sm = 4;      // 0.25rem
  static const double base = 8;    // 0.5rem — buttons, inputs
  static const double md = 12;     // 0.75rem
  static const double lg = 16;     // 1rem — cards, containers
  static const double xl = 24;     // 1.5rem — prominent feature sections
  static const double full = 9999; // pill-shaped chips
}
