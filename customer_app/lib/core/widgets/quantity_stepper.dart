import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// +/– quantity selector. Value is always 1–[max].
/// Disables − at min, + at max.
///
/// Set [compact] to true for the pill-style variant used in the
/// bottom action bar — smaller buttons and tighter spacing.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// When true, renders a compact pill-style stepper suited for
  /// tight layouts like a sticky bottom action bar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttonSize = compact ? 32.0 : 36.0;
    final iconSize = compact ? 16.0 : 18.0;
    final fontSize = compact ? 15.0 : 16.0;

    return compact
        ? _CompactStepper(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            buttonSize: buttonSize,
            iconSize: iconSize,
            fontSize: fontSize,
          )
        : _DefaultStepper(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            buttonSize: buttonSize,
            iconSize: iconSize,
            fontSize: fontSize,
          );
  }
}

// ── Default circular stepper ──────────────────────────────────────────────────

class _DefaultStepper extends StatelessWidget {
  const _DefaultStepper({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.buttonSize,
    required this.iconSize,
    required this.fontSize,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double buttonSize;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.remove,
          semanticLabel: 'Decrease quantity',
          size: buttonSize,
          iconSize: iconSize,
          enabled: value > min,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
          ),
        ),
        _CircleButton(
          icon: Icons.add,
          semanticLabel: 'Increase quantity',
          size: buttonSize,
          iconSize: iconSize,
          enabled: value < max,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

// ── Compact pill stepper ──────────────────────────────────────────────────────

class _CompactStepper extends StatelessWidget {
  const _CompactStepper({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.buttonSize,
    required this.iconSize,
    required this.fontSize,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double buttonSize;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadius.button),
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button
          _PillButton(
            icon: Icons.remove,
            semanticLabel: 'Decrease quantity',
            iconSize: iconSize,
            enabled: value > min,
            isLeft: true,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),

          // Dividers + value
          Container(width: 1, height: 44, color: AppColors.outline),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize,
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
          ),
          Container(width: 1, height: 44, color: AppColors.outline),

          // Plus button
          _PillButton(
            icon: Icons.add,
            semanticLabel: 'Increase quantity',
            iconSize: iconSize,
            enabled: value < max,
            isLeft: false,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

// ── Shared button widgets ─────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.size,
    required this.iconSize,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.semanticLabel,
    required this.iconSize,
    required this.enabled,
    required this.isLeft,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final double iconSize;
  final bool enabled;
  final bool isLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(AppRadius.button - 1);
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLeft
            ? const BorderRadius.only(topLeft: radius, bottomLeft: radius)
            : const BorderRadius.only(topRight: radius, bottomRight: radius),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
