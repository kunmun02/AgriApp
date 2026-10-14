import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Colour-coded status chip for order status values.
///
/// Covers all 8 statuses defined in 00_MASTER §state machine.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, fgColor) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
      ),
    );
  }

  static (String label, Color bg, Color fg) _resolve(String status) {
    switch (status) {
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
          'Out for Delivery',
          AppColors.statusOutForDeliveryBg,
          AppColors.statusOutForDeliveryFg
        );
      case 'DELIVERED':
        return (
          'Delivered',
          AppColors.statusDeliveredBg,
          AppColors.statusDeliveredFg
        );
      case 'CANCELLED':
        return (
          'Cancelled',
          AppColors.statusCancelledBg,
          AppColors.statusCancelledFg
        );
      default:
        return (status, AppColors.statusDefaultBg, AppColors.statusDefaultFg);
    }
  }
}
