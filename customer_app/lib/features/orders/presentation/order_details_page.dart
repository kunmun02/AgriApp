import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/models/order_detail.dart';
import '../data/order_repository.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/order_status_timeline.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Fetches the full [OrderDetail] for a given order id.
///
/// Returns NOT_FOUND for unknown ids AND for another user's order (RLS
/// ensures the query returns 0 rows in both cases).
final orderDetailsControllerProvider =
    FutureProvider.autoDispose.family<OrderDetail, String>(
  (ref, orderId) => ref.read(orderRepositoryProvider).orderDetails(orderId),
);

// ── Page ─────────────────────────────────────────────────────────────────────

/// C14 — Order Details screen (`/orders/:orderId`).
///
/// No cancel action exists here (out of scope, customers observe only).
class OrderDetailsPage extends ConsumerWidget {
  const OrderDetailsPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(orderDetailsControllerProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorBody(
          failure: err is AppFailure ? err : null,
          onRetry: () =>
              ref.invalidate(orderDetailsControllerProvider(orderId)),
        ),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

// ── Detail body ───────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header card.
          _HeaderCard(detail: detail),
          const SizedBox(height: AppSpacing.lg),

          // 2. Status timeline (or cancel banner — handled inside widget).
          _SectionTitle(
            label: detail.status == 'CANCELLED' ? 'Cancellation' : 'Status',
          ),
          const SizedBox(height: AppSpacing.md),
          OrderStatusTimeline(
            status: detail.status,
            cancelReason: detail.cancelReason,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3. Items list.
          const _SectionTitle(label: 'Items'),
          const SizedBox(height: AppSpacing.md),
          _ItemsCard(items: detail.items),
          const SizedBox(height: AppSpacing.lg),

          // 4. Payment row.
          const _SectionTitle(label: 'Payment'),
          const SizedBox(height: AppSpacing.md),
          _PaymentCard(
            method: detail.paymentMethod,
            status: detail.paymentStatus,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 5. Shipping snapshot.
          const _SectionTitle(label: 'Delivery Address'),
          const SizedBox(height: AppSpacing.md),
          _ShippingCard(snapshot: detail.shippingSnapshot),
          const SizedBox(height: AppSpacing.lg),

          // 6. Bill card.
          const _SectionTitle(label: 'Bill'),
          const SizedBox(height: AppSpacing.md),
          _BillCard(detail: detail),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.orderNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Placed on ${Formatters.dateShort(detail.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            OrderStatusChip(status: detail.status),
          ],
        ),
      ),
    );
  }
}

// ── Items card ────────────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});

  final List items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _ItemRow(item: items[i]),
              if (i < items.length - 1) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final name = item.name as String;
    final sku = item.sku as String;
    final qty = item.quantity as int;
    final unitPrice = item.unitPrice as double;
    final lineTotal = item.lineTotal as double;
    final lineTax = item.lineTax as double;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'SKU: $sku  ·  $qty × ${Formatters.inr(unitPrice)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (lineTax > 0)
                Text(
                  'Tax: ${Formatters.inr(lineTax)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        Text(
          Formatters.inr(lineTotal),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Payment card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.method, required this.status});

  final String method;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '$method — $status',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shipping card ─────────────────────────────────────────────────────────────

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({required this.snapshot});

  final ShippingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;

    final line2Part = snapshot.line2 != null && snapshot.line2!.isNotEmpty
        ? '\n${snapshot.line2}'
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(snapshot.recipientName,
                    style: body?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(snapshot.phone, style: small),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${snapshot.line1}$line2Part\n'
              '${snapshot.city}, ${snapshot.state} — ${snapshot.postalCode}\n'
              '${snapshot.country}',
              style: small,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bill card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  const _BillCard({required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _BillRow(
              label: 'Subtotal',
              value: Formatters.inr(detail.subtotal),
            ),
            const SizedBox(height: AppSpacing.sm),
            _BillRow(
              label: 'Delivery',
              value: Formatters.inr(detail.deliveryFee),
            ),
            const SizedBox(height: AppSpacing.sm),
            _BillRow(
              label: 'Tax',
              value: Formatters.inr(detail.tax),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            _BillRow(
              label: 'Total',
              value: Formatters.inr(detail.total),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.failure, required this.onRetry});

  final AppFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure?.code == 'NOT_FOUND';
    return Center(
      key: const Key('order_not_found'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNotFound ? Icons.search_off_rounded : Icons.error_outline,
              size: 64,
              color: isNotFound ? AppColors.textSecondary : AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isNotFound
                  ? 'Order not found'
                  : (failure?.userMessage ?? 'Something went wrong.'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!isNotFound) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 160,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
