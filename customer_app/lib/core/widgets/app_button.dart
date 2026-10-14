import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonType { primary, secondary, danger, text }

/// Reusable button with loading / disabled states.
/// Min height 44 dp per design system.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.loading = false,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool loading;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDisabled = loading || !enabled || onPressed == null;

    final Widget child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label),
                ],
              )
            : Text(label));

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );

    switch (type) {
      case AppButtonType.primary:
        return SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.primary.withAlpha(100),
              shape: shape,
            ),
            child: child,
          ),
        );

      case AppButtonType.secondary:
        return SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: isDisabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: shape,
            ),
            child: child,
          ),
        );

      case AppButtonType.danger:
        return SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.error.withAlpha(100),
              shape: shape,
            ),
            child: child,
          ),
        );

      case AppButtonType.text:
        return SizedBox(
          height: 44,
          child: TextButton(
            onPressed: isDisabled ? null : onPressed,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: child,
          ),
        );
    }
  }
}
