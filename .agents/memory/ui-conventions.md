---
type: project
created: 2026-08-14
updated: 2026-08-18
---

# UI Conventions

- **Dark Mode & Color Scheme Rule**: NEVER use static color constants (e.g., `AppColors.textPrimary` - the `AppColors` class is removed) or hardcoded Colors (e.g., `Colors.grey`, `Colors.black87`) directly in UI code.
  - ALWAYS use `Theme.of(context).colorScheme` (e.g. `colorScheme.primary`, `colorScheme.primaryContainer`, `colorScheme.surface`, `colorScheme.error`, `colorScheme.outlineVariant`, `colorScheme.onPrimary`) to ensure seamless support for both light and dark themes.
  - For semantic entity status badges (e.g., pending, inProgress, approved, rejected, clarification), use `AppStatusColors` from `lib/core/theme/app_colors.dart`.
- **Theme Engine Architecture**: Built with `FlexColorScheme v8.4.0` using `FlexScheme.greenM3`, `FlexSubThemesData` (M3 dividers, outlined inputs with 10dp radius, 12dp card radius, navigation bar label behavior), and Google Fonts Inter typography. Wrapped with `ResponsiveTheme.fromTheme(...)` from `flutter_screenutil_plus`.
- **Button Constraints in Layouts**: `AppTheme` defines `minimumSize: const Size.fromHeight(50)` on `elevatedButtonTheme` and `outlinedButtonTheme` (setting minimum width to `double.infinity`). Therefore:
  - Inside a `Row`, buttons MUST be wrapped in `Expanded` (e.g., `Expanded(flex: 3, child: OutlinedButton(...))`) or explicitly styled with `style: OutlinedButton.styleFrom(minimumSize: Size.zero)`. Never place a bare button without `Expanded` in horizontal flex layouts.
  - Inside `ListTile.trailing`, NEVER place an unconstrained `ElevatedButton` or `OutlinedButton` without `minimumSize: Size.zero` (or use `TextButton`, `IconButton`, or custom `Row` in a `Card`).
- **Radio Buttons in Flutter 3.32+**: Wrap radio lists in `RadioGroup<T>(groupValue: ..., onChanged: ...)` rather than placing deprecated `groupValue`/`onChanged` on individual `RadioListTile`/`Radio` widgets.
- **Modal Action Sheets**: Use `showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`, and container decoration with `borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))` for all complex bottom sheets (e.g., `AssignReviewerSheet`, `AssignTaskSheet`, `SetConfirmedDateSheet`, `_showPhotoOptionsSheet`).
- **Form State vs. Visual Defaults**: Never set a visual default fallback with `??` in UI code if the underlying state is `null`. Either initialize the default value in the state class (e.g. `WizardStateData`), or keep the UI unselected so the user makes an explicit choice and validation works consistently.
- **Centralized Status Badges (`AppointmentStatusBadge`)**: ALWAYS use `AppointmentStatusBadge(status: item.status)` from `lib/core/widgets/appointment_status_badge.dart`. NEVER declare private `_buildStatusBadge` methods or manual Container/pill widgets in screen files. This enforces unified padding, icons, labels, and dark-theme compatible color resolution via `AppStatusColors`.
- **Centralized Appointment Cards (`AppointmentBookingCard`)**: ALWAYS use `AppointmentBookingCard(appointment: item, onTap: ...)` from `lib/core/widgets/appointment_booking_card.dart` for rendering appointment list cards. Do NOT reimplement card layouts in individual feature screens.
- **Form State & Keyboard Focus Guard**: When building reply text fields or modal input sheets within reactive screens, avoid invoking wide-tree `setState()` calls on focus or text change. Extensive parent rebuilds can cause the virtual keyboard to dismiss and lose focus. Encapsulate form state or manage loading/submission states via Riverpod ViewModels/Controllers.
- **Modal Action Sheet Dismissal & Global Snackbar Sequence (Pop-Before-Snackbar)**:
  - When triggering an asynchronous mutation from inside a `showModalBottomSheet` (e.g., `AssignTaskSheet`, `AssignReviewerSheet`, `SetConfirmedDateSheet`), ALWAYS dismiss the modal first via `if (context.canPop()) context.pop()` BEFORE calling `AppSnackbar.showGlobalSuccess(...)` or `AppSnackbar.showGlobalError(...)`.
  - Calling context-bound snackbars (`AppSnackbar.show(context, ...)`) inside the sheet causes the snackbar to attach to the modal's route context or render behind the barrier, making it invisible or dismissed along with the sheet. Using `AppSnackbar.showGlobal*` dispatches to the root `scaffoldMessengerKey` on the parent view.
  - ALWAYS wrap action bottom sheets with `PopScope(canPop: !_isSubmitting)` to disable Android back-gesture, system back button, or modal backdrop taps while a network mutation is in flight.
- **Material Canvas Requirement for ListTile & RadioListTile in Decorated Containers**:
  - `ListTile` and `RadioListTile` paint their background and ink splash effects onto the nearest `Material` ancestor. If wrapped inside a `Container` with `BoxDecoration` without an intervening `Material`, the framework throws: `ListTile background color or ink splashes may be invisible. The ListTile is wrapped in a DecoratedBox that has a background color...`.
  - Fix: Wrap the child `ListView` or list contents in `Material(color: Colors.transparent)`.
  - For Flutter 3.32+ radio lists, stack widgets cleanly:
    ```dart
    Material(
      color: Colors.transparent,
      child: RadioGroup<T>(
        groupValue: selectedValue,
        onChanged: (val) => setState(() => selectedValue = val),
        child: ListView.separated(
          itemBuilder: (context, index) => RadioListTile<T>(
            value: items[index],
            title: Text(...),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    )
    ```
