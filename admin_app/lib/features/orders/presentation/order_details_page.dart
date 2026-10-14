import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_order_repository.dart';
import '../widgets/order_action_bar.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDetail, String>((ref, orderId) {
  final repo = ref.watch(adminOrderRepositoryProvider);
  return repo.details(orderId);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class OrderDetailsPage extends ConsumerWidget {
  const OrderDetailsPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_orderDetailProvider(orderId));

    return AdminShell(
      title: 'Order Details',
      child: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: Colors.red)),
        ),
        data: (order) => _OrderDetailBody(
          order: order,
          onRefresh: () => ref.refresh(_orderDetailProvider(orderId)),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order, required this.onRefresh});
  final OrderDetail order;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      order.orderNumber,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(status: order.status),
                  ],
                ),
              ),
              // Action bar (top-right)
              OrderActionBar(
                orderId: order.id,
                currentStatus: order.status,
                onStatusChanged: onRefresh,
              ),
            ],
          ),
          // Cancel reason banner
          if (order.cancelReason != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'This order was cancelled. Reason: ${order.cancelReason}',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // ── Customer block ───────────────────────────────────────────
          _SectionCard(
            title: 'Customer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Name', value: order.customer.name),
                _InfoRow(label: 'Email', value: order.customer.email),
                _InfoRow(label: 'Phone', value: order.customer.phone),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Items ────────────────────────────────────────────────────
          _SectionCard(
            title: 'Items',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Unit Price'), numeric: true),
                  DataColumn(label: Text('Qty'), numeric: true),
                  DataColumn(label: Text('Total'), numeric: true),
                ],
                rows: order.items.map((item) {
                  final isDeleted = item.productId == null;
                  return DataRow(cells: [
                    DataCell(Text(
                      item.productName,
                      style: isDeleted
                          ? const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            )
                          : null,
                    )),
                    DataCell(Text(item.skuSnapshot)),
                    DataCell(Text(Formatters.inr(item.unitPrice))),
                    DataCell(Text(item.quantity.toString())),
                    DataCell(Text(Formatters.inr(item.lineTotal))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Totals ───────────────────────────────────────────────────
          _SectionCard(
            title: 'Totals',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _TotalRow(label: 'Subtotal', value: order.subtotal),
                _TotalRow(label: 'Delivery', value: order.deliveryFee),
                _TotalRow(label: 'Tax', value: order.tax),
                const Divider(),
                _TotalRow(
                  label: 'Total',
                  value: order.total,
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Shipping address ─────────────────────────────────────────
          _SectionCard(
            title: 'Shipping Address',
            subtitle: 'Snapshot at order time',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.shippingAddress.recipientName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(order.shippingAddress.phone),
                Text(order.shippingAddress.line1),
                if (order.shippingAddress.line2.isNotEmpty)
                  Text(order.shippingAddress.line2),
                Text(
                  '${order.shippingAddress.city}, ${order.shippingAddress.state} — ${order.shippingAddress.postalCode}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Payment ──────────────────────────────────────────────────
          _SectionCard(
            title: 'Payment',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Method', value: order.payment.method),
                Row(
                  children: [
                    const Text('Status',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54)),
                    const SizedBox(width: 8),
                    StatusBadge(status: order.payment.status),
                  ],
                ),
                _InfoRow(
                    label: 'Amount',
                    value: Formatters.inr(order.payment.amount)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Timeline ─────────────────────────────────────────────────
          _SectionCard(
            title: 'Timeline',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildTimeline(order),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(OrderDetail order) {
    final events = <_TimelineEvent>[
      _TimelineEvent(
        label: 'Order placed',
        time: order.createdAt,
      ),
      _TimelineEvent(
        label: 'Payment ${order.payment.status.toLowerCase()}',
        time: order.payment.updatedAt,
      ),
      _TimelineEvent(
        label: 'Status: ${order.status.replaceAll('_', ' ').toLowerCase()}',
        time: order.updatedAt,
        isRed: order.status == 'CANCELLED',
      ),
    ];
    // Sort chronologically.
    events.sort((a, b) => a.time.compareTo(b.time));

    return events.map((e) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8),
            const SizedBox(width: 8),
            Text(
              Formatters.dateTimeShort(e.time),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              e.label,
              style: TextStyle(
                color: e.isRed ? Colors.red.shade700 : null,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.label,
    required this.time,
    this.isRed = false,
  });
  final String label;
  final DateTime time;
  final bool isRed;
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});
  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });
  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: style),
          const SizedBox(width: 24),
          SizedBox(
            width: 120,
            child: Text(
              Formatters.inr(value),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
