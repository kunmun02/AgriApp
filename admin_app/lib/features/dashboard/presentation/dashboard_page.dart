import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../customers/data/admin_customer_repository.dart';
import '../../inventory/data/admin_inventory_repository.dart';
import '../../orders/data/admin_order_repository.dart';
import '../../products/data/admin_product_repository.dart';
import '../../shell/presentation/admin_shell.dart';

// ── Dashboard data state ──────────────────────────────────────────────────────

class _DashboardData {
  const _DashboardData({
    required this.ordersToday,
    required this.newOrders,
    required this.customers,
    required this.products,
    required this.recentOrders,
    required this.lowStock,
  });
  final int ordersToday;
  final int newOrders;
  final int customers;
  final int products;
  final List<OrderSummary> recentOrders;
  final List<InventoryRow> lowStock;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _dashboardProvider =
    FutureProvider.autoDispose<_DashboardData>((ref) async {
  final orders = ref.read(adminOrderRepositoryProvider);
  final customers = ref.read(adminCustomerRepositoryProvider);
  final products = ref.read(adminProductRepositoryProvider);
  final inventory = ref.read(adminInventoryRepositoryProvider);

  final results = await Future.wait([
    orders.countOrdersCreatedToday(),
    orders.countNewOrders(),
    customers.countCustomers(),
    products.countProducts(),
    orders.list(page: 1),
    inventory.list(page: 1, lowStockOnly: true),
  ]);

  return _DashboardData(
    ordersToday: results[0] as int,
    newOrders: results[1] as int,
    customers: results[2] as int,
    products: results[3] as int,
    recentOrders:
        ((results[4] as Paginated<OrderSummary>).items).take(10).toList(),
    lowStock: ((results[5] as Paginated<InventoryRow>).items).take(10).toList(),
  );
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// A02 — Dashboard (`/admin/dashboard`)
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      title: 'Dashboard',
      child: _DashboardBody(),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_dashboardProvider);

    return state.when(
      loading: () => const _DashboardSkeleton(),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(e.toString()),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => ref.invalidate(_dashboardProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) => _DashboardContent(data: data, ref: ref),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.ref});
  final _DashboardData data;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_dashboardProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI row ──────────────────────────────────────────
            _SectionHeader(
              title: 'Overview',
              onRefresh: () => ref.invalidate(_dashboardProvider),
            ),
            const SizedBox(height: AppSpacing.md),
            _KpiRow(data: data),
            const SizedBox(height: AppSpacing.xl),

            // ── Low stock + Recent orders ─────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _LowStockCard(rows: data.lowStock)),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                        child: _RecentOrdersCard(orders: data.recentOrders)),
                  ],
                );
              }
              return Column(
                children: [
                  _LowStockCard(rows: data.lowStock),
                  const SizedBox(height: AppSpacing.lg),
                  _RecentOrdersCard(orders: data.recentOrders),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── KPI Row ───────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.data});
  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      final cards = [
        StatCard(
          label: 'Orders today',
          value: data.ordersToday.toString(),
          onTap: () => context.go('/admin/orders'),
        ),
        StatCard(
          label: 'New orders',
          value: data.newOrders.toString(),
          accent: data.newOrders > 0,
          onTap: () => context.go('/admin/orders'),
        ),
        StatCard(
          label: 'Customers',
          value: data.customers.toString(),
          onTap: () => context.go('/admin/customers'),
        ),
        StatCard(
          label: 'Products',
          value: data.products.toString(),
          onTap: () => context.go('/admin/products'),
        ),
      ];

      if (isWide) {
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      }
      return Column(
        children: [
          Row(children: [
            Expanded(child: cards[0]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: cards[1]),
          ]),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(child: cards[2]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: cards[3]),
          ]),
        ],
      );
    });
  }
}

// ── Low Stock Card ────────────────────────────────────────────────────────────

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.rows});
  final List<InventoryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Low stock', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('No low stock items'),
              )
            else
              ...rows.map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text(r.productName, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(r.sku, style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    '${r.quantity} / ${r.minStockLevel}',
                    style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  onTap: () =>
                      context.go('/admin/products/${r.productId}/edit'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Orders Card ────────────────────────────────────────────────────────

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.orders});
  final List<OrderSummary> orders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent orders',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('No orders yet'),
              )
            else
              ...orders.map(
                (o) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.orderNumber,
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'monospace')),
                  subtitle: Text(
                    Formatters.dateShort(o.createdAt),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.inr(o.total),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge(status: o.status),
                    ],
                  ),
                  onTap: () => context.go('/admin/orders/${o.id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onRefresh});
  final String title;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              4,
              (_) => Expanded(
                child: Container(
                  height: 80,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
