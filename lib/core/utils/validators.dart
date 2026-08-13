class Validators {
  // ReDoS safe email validation
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Basic mobile number validation (10 digits)
  static final RegExp _phoneRegExp = RegExp(r'^\d{10}$');

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (value.length > 254) {
      return 'Email is too long';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    // Long Password DoS Mitigation
    if (value.length > 64) {
      return 'Password must be no more than 64 characters';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least 1 number';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!_phoneRegExp.hasMatch(value.trim())) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? validateRequired(
    String? value,
    String fieldName, {
    int? maxLength,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (maxLength != null && value.length > maxLength) {
      return '$fieldName must be no more than $maxLength characters';
    }
    return null;
  }
}
