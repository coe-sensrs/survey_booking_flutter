import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(
            color: isOutlined ? AppColors.primary : AppColors.surface,
          ),
        ),
      );
    }

    if (isOutlined) {
      return OutlinedButton(onPressed: onPressed, child: _buildChild());
    }

    return ElevatedButton(onPressed: onPressed, child: _buildChild());
  }

  Widget _buildChild() {
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(text)],
      );
    }
    return Text(text);
  }
}
