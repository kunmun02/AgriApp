import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Coloured status chip for order/payment statuses.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  static (String, Color, Color) _resolve(String status) {
    switch (status.toUpperCase()) {
      case 'NEW':
        return ('New', AppColors.statusNewBg, AppColors.statusNewFg);
      case 'CONFIRMED':
        return (
          'Confirmed',
          AppColors.statusConfirmedBg,
          AppColors.statusConfirmedFg
        );
      case 'PROCESSING':
        return (
          'Processing',
          AppColors.statusProcessingBg,
          AppColors.statusProcessingFg
        );
      case 'PACKED':
        return ('Packed', AppColors.statusPackedBg, AppColors.statusPackedFg);
      case 'SHIPPED':
        return (
          'Shipped',
          AppColors.statusShippedBg,
          AppColors.statusShippedFg
        );
      case 'OUT_FOR_DELIVERY':
        return (
          'Out for delivery',
          AppColors.statusOutForDeliveryBg,
          AppColors.statusOutForDeliveryFg
        );
      case 'DELIVERED':
        return (
          'Delivered',
          AppColors.primaryContainer,
          AppColors.onPrimaryContainer
        );
      case 'CANCELLED':
        return (
          'Cancelled',
          AppColors.statusCancelledBg,
          AppColors.statusCancelledFg
        );
      case 'PENDING':
        return (
          'Pending',
          AppColors.statusProcessingBg,
          AppColors.statusProcessingFg
        );
      case 'COLLECTED':
        return (
          'Collected',
          AppColors.primaryContainer,
          AppColors.onPrimaryContainer
        );
      default:
        return (status, AppColors.outline, AppColors.textSecondary);
    }
  }
}
