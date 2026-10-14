import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The 7 forward order statuses in display order.
const _kSteps = [
  'NEW',
  'CONFIRMED',
  'PROCESSING',
  'PACKED',
  'SHIPPED',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
];

const _kStepLabels = {
  'NEW': 'Order Placed',
  'CONFIRMED': 'Confirmed',
  'PROCESSING': 'Processing',
  'PACKED': 'Packed',
  'SHIPPED': 'Shipped',
  'OUT_FOR_DELIVERY': 'Out for Delivery',
  'DELIVERED': 'Delivered',
};

/// Vertical status timeline for C14.
///
/// - When [status] is `CANCELLED`, renders a red banner with [cancelReason]
///   and hides the forward timeline entirely.
/// - Otherwise renders all 7 steps: completed (filled green), current
///   (pulsing amber dot), and future (grey).
class OrderStatusTimeline extends StatefulWidget {
  const OrderStatusTimeline({
    super.key,
    required this.status,
    this.cancelReason,
  });

  final String status;
  final String? cancelReason;

  @override
  State<OrderStatusTimeline> createState() => _OrderStatusTimelineState();
}

class _OrderStatusTimelineState extends State<OrderStatusTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(_pulse);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == 'CANCELLED') {
      return _CancelBanner(reason: widget.cancelReason);
    }

    final currentIndex = _kSteps.indexOf(widget.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_kSteps.length, (i) {
        final stepStatus = _kSteps[i];
        final isCompleted = i < currentIndex;
        final isCurrent = i == currentIndex;
        final isLast = i == _kSteps.length - 1;

        return _TimelineRow(
          label: _kStepLabels[stepStatus] ?? stepStatus,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: isLast,
          pulseAnim: isCurrent ? _pulseAnim : null,
        );
      }),
    );
  }
}

// ── Cancel banner ─────────────────────────────────────────────────────────────

class _CancelBanner extends StatelessWidget {
  const _CancelBanner({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cancel_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.statusCancelledBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_outlined,
                  color: AppColors.error, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Order Cancelled',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              reason!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Single timeline row ───────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    this.pulseAnim,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;
  final Animation<double>? pulseAnim;

  @override
  Widget build(BuildContext context) {
    const dotSize = 16.0;
    const lineWidth = 2.0;

    final Color dotColor = isCompleted
        ? AppColors.primary
        : isCurrent
            ? AppColors.secondary
            : AppColors.outline;

    final Color lineColor = isCompleted ? AppColors.primary : AppColors.outline;

    final textStyle = isCompleted || isCurrent
        ? Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600)
        : Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary);

    Widget dot;
    if (isCurrent && pulseAnim != null) {
      dot = AnimatedBuilder(
        animation: pulseAnim!,
        builder: (_, __) => Opacity(
          opacity: pulseAnim!.value,
          child: _buildDot(dotSize, dotColor),
        ),
      );
    } else if (isCompleted) {
      dot = Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 10, color: Colors.white),
      );
    } else {
      dot = _buildDot(dotSize, dotColor);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot + connector line column.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                dot,
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: lineWidth,
                        color: lineColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Label.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 0,
                bottom: isLast ? 0 : AppSpacing.xl,
              ),
              child: Text(label, style: textStyle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
