import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/paginated_table_controls.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../features/auth/data/models/profile.dart';
import '../../../features/orders/data/admin_order_repository.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_customer_repository.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _customerDetailProvider =
    FutureProvider.autoDispose.family<Profile, String>((ref, userId) {
  return ref.watch(adminCustomerRepositoryProvider).details(userId);
});

final _customerOrdersPageProvider = FutureProvider.autoDispose
    .family<Paginated<OrderSummary>, ({String userId, int page})>((ref, args) {
  return ref
      .watch(adminCustomerRepositoryProvider)
      .ordersOf(args.userId, page: args.page);
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// A14 — Customer Details `/admin/customers/:userId`.
class CustomerDetailsPage extends ConsumerStatefulWidget {
  const CustomerDetailsPage({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<CustomerDetailsPage> createState() =>
      _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends ConsumerState<CustomerDetailsPage> {
  int _ordersPage = 1;

  Future<void> _toggleActive(Profile customer, bool newValue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newValue ? 'Activate customer?' : 'Deactivate customer?'),
        content: Text(
          newValue
              ? 'This will allow ${customer.fullName} to sign in again.'
              : 'Deactivate this customer? They will not be able to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(adminCustomerRepositoryProvider)
          .setActive(customer.id, newValue);
      ref.invalidate(_customerDetailProvider(widget.userId));
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_customerDetailProvider(widget.userId));

    return AdminShell(
      title: 'Customer Details',
      child: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final isNotFound = e is ApiFailure && e.code == 'NOT_FOUND';
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined,
                    size: 48, color: AppColors.textSecondary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isNotFound
                      ? 'Customer not found.'
                      : (e is AppFailure ? e.userMessage : e.toString()),
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          );
        },
        data: (customer) => _CustomerDetailBody(
          customer: customer,
          userId: widget.userId,
          ordersPage: _ordersPage,
          onToggleActive: (v) => _toggleActive(customer, v),
          onOrdersPageChanged: (p) => setState(() => _ordersPage = p),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CustomerDetailBody extends ConsumerWidget {
  const _CustomerDetailBody({
    required this.customer,
    required this.userId,
    required this.ordersPage,
    required this.onToggleActive,
    required this.onOrdersPageChanged,
  });

  final Profile customer;
  final String userId;
  final int ordersPage;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<int> onOrdersPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(
      _customerOrdersPageProvider((userId: userId, page: ordersPage)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile card ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      customer.fullName.isNotEmpty
                          ? customer.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.fullName,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.xs),
                        Text(customer.email),
                        if (customer.phone != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(customer.phone!),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Joined ${Formatters.dateShort(customer.createdAt)}',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                customer.isActive ? 'Active' : 'Inactive',
                              ),
                              backgroundColor: customer.isActive
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Flexible(
                              child: OutlinedButton(
                                key: Key('toggle_active_${customer.id}'),
                                onPressed: () =>
                                    onToggleActive(!customer.isActive),
                                child: Text(customer.isActive
                                    ? 'Deactivate'
                                    : 'Activate'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ── Orders section ───────────────────────────────────────────
          Text('Orders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                e is AppFailure ? e.userMessage : e.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (paginated) {
              if (paginated.items.isEmpty) {
                return const Text('No orders yet.',
                    style: TextStyle(color: AppColors.textSecondary));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Order #')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: paginated.items.map((o) {
                        return DataRow(
                          key: ValueKey('order_row_${o.id}'),
                          onSelectChanged: (_) =>
                              context.push('/admin/orders/${o.id}'),
                          cells: [
                            DataCell(Text(
                              o.orderNumber,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                            DataCell(
                                Text(Formatters.dateTimeShort(o.createdAt))),
                            DataCell(Text(Formatters.inr(o.total))),
                            DataCell(StatusBadge(status: o.status)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  PaginatedTableControls(
                    page: ordersPage,
                    total: paginated.total,
                    pageSize: paginated.pageSize,
                    onPrev: ordersPage > 1
                        ? () => onOrdersPageChanged(ordersPage - 1)
                        : null,
                    onNext: paginated.hasMore
                        ? () => onOrdersPageChanged(ordersPage + 1)
                        : null,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
