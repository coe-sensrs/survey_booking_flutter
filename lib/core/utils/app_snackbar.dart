import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

/// Centralized global snackbar service powered by [AwesomeSnackbarContent].
class AppSnackbar {
  /// Global ScaffoldMessengerState key to trigger snackbars without a BuildContext when needed.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Shows an awesome snackbar using a [BuildContext].
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType contentType,
    Duration duration = const Duration(seconds: 4),
  }) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration,
      content: AwesomeSnackbarContent(
        title: title,
        message: message,
        contentType: contentType,
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Shows a success snackbar using [BuildContext].
  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      message: message,
      contentType: ContentType.success,
      duration: duration,
    );
  }

  /// Shows an error/failure snackbar using [BuildContext].
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      message: message,
      contentType: ContentType.failure,
      duration: duration,
    );
  }

  /// Shows a warning snackbar using [BuildContext].
  static void showWarning(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      message: message,
      contentType: ContentType.warning,
      duration: duration,
    );
  }

  /// Shows an info/help snackbar using [BuildContext].
  static void showInfo(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      message: message,
      contentType: ContentType.help,
      duration: duration,
    );
  }

  /// Shows an awesome snackbar globally using [scaffoldMessengerKey] without requiring BuildContext.
  static void showGlobal({
    required String title,
    required String message,
    required ContentType contentType,
    Duration duration = const Duration(seconds: 4),
  }) {
    final state = scaffoldMessengerKey.currentState;
    if (state != null) {
      final snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: duration,
        content: AwesomeSnackbarContent(
          title: title,
          message: message,
          contentType: contentType,
        ),
      );
      state
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    }
  }

  /// Shows a global success snackbar.
  static void showGlobalSuccess({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showGlobal(
      title: title,
      message: message,
      contentType: ContentType.success,
      duration: duration,
    );
  }

  /// Shows a global error snackbar.
  static void showGlobalError({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showGlobal(
      title: title,
      message: message,
      contentType: ContentType.failure,
      duration: duration,
    );
  }

  /// Shows a global warning snackbar.
  static void showGlobalWarning({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showGlobal(
      title: title,
      message: message,
      contentType: ContentType.warning,
      duration: duration,
    );
  }

  /// Shows a global info snackbar.
  static void showGlobalInfo({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showGlobal(
      title: title,
      message: message,
      contentType: ContentType.help,
      duration: duration,
    );
  }
}
