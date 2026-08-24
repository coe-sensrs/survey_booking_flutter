import 'package:flutter/services.dart';

/// Mitigates Pastejacking and hidden control character injection.
class SanitizingTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip out non-printable ASCII and invisible Unicode characters
    // such as RLO (Right-to-Left Override \u202E), zero-width spaces, etc.
    final sanitizedText = newValue.text.replaceAll(
      RegExp(r'[\x00-\x1F\x7F-\x9F\u200B-\u200D\uFEFF\u202A-\u202E]'),
      '',
    );

    if (sanitizedText == newValue.text) {
      return newValue;
    }

    // Adjust selection if text was modified
    return TextEditingValue(
      text: sanitizedText,
      selection: TextSelection.collapsed(
        offset: sanitizedText.length, // Simplified cursor placement
      ),
    );
  }
}
