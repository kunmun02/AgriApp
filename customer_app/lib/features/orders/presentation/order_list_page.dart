import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/models/order_summary.dart';
import '../data/order_repository.dart';
import '../widgets/order_status_chip.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// The currently-selected status filter (null == All).
final _statusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Current page index.
final _pageProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Accumulated order list — previous pages + current page.
final _accumulatedOrdersProvider =
    StateProvider.autoDispose<List<OrderSummary>>((ref) => []);

/// Async provider that fetches the current page and appends to accumulated list.
final _orderListProvider =
    FutureProvider.autoDispose<Paginated<OrderSummary>>((ref) async {
  final status = ref.watch(_statusFilterProvider);
  final page = ref.watch(_pageProvider);
  return ref.read(orderRepositoryProvider).myOrders(status: status, page: page);
});

// ── Page ─────────────────────────────────────────────────────────────────────

const _kAllStatuses = [
  'NEW',
  'CONFIRMED',
  'PROCESSING',
  'PACKED',
  'SHIPPED',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
  'CANCELLED',
];

/// C13 — Order List screen (`/orders`).
///
/// Shows the customer's own orders, newest first, with a status dropdown
/// filter and pagination (page size 20). No cancel action anywhere.
class OrderListPage extends ConsumerStatefulWidget {
  const OrderListPage({super.key});

  @override
  ConsumerState<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends ConsumerState<OrderListPage> {
  @override
  Widget build(BuildContext context) {
    final selectedStatus = ref.watch(_statusFilterProvider);
    final asyncOrders = ref.watch(_orderListProvider);

    // When status filter changes, reset page and accumulated list.
    ref.listen<String?>(_statusFilterProvider, (prev, next) {
      if (prev != next) {
        ref.read(_pageProvider.notifier).state = 0;
        ref.read(_accumulatedOrdersProvider.notifier).state = [];
      }
    });

    // Append newly-loaded page to accumulated list.
    ref.listen<AsyncValue<Paginated<OrderSummary>>>(_orderListProvider,
        (_, next) {
      next.whenData((page) {
        final accumulated = ref.read(_accumulatedOrdersProvider);
        final existingIds = accumulated.map((o) => o.id).toSet();
        final newItems =
            page.items.where((o) => !existingIds.contains(o.id)).toList();
        if (newItems.isNotEmpty) {
          ref.read(_accumulatedOrdersProvider.notifier).state = [
            ...accumulated,
            ...newItems,
          ];
        }
      });
    });

    final orders = ref.watch(_accumulatedOrdersProvider);
    final currentPage = ref.watch(_pageProvider);
    final hasMore = asyncOrders.maybeWhen(
      data: (p) => p.hasMore,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Column(
        children: [
          // ── Status filter dropdown ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filter by status',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All'),
                ),
                ..._kAllStatuses.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s,
                    child: Text(_labelFor(s)),
                  ),
                ),
              ],
              onChanged: (val) {
                ref.read(_statusFilterProvider.notifier).state = val;
              },
            ),
          ),
          // ── Orders list ───────────────────────────────────────────────
          Expanded(
            child: asyncOrders.when(
              loading: () => orders.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(context, ref, orders, hasMore, currentPage,
                      isLoadingMore: true),
              error: (err, _) => orders.isEmpty
                  ? _ErrorState(
                      failure: err is AppFailure ? err : null,
                      onRetry: () => ref.invalidate(_orderListProvider),
                    )
                  : _buildList(context, ref, orders, hasMore, currentPage),
              data: (_) => orders.isEmpty
                  ? _EmptyState(
                      onShop: () => context.go('/home'),
                    )
                  : _buildList(context, ref, orders, hasMore, currentPage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<OrderSummary> orders,
    bool hasMore,
    int currentPage, {
    bool isLoadingMore = false,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: orders.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == orders.length) {
          // Load-more row.
          if (isLoadingMore) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: OutlinedButton(
              onPressed: () {
                ref.read(_pageProvider.notifier).state = currentPage + 1;
              },
              child: const Text('Load more'),
            ),
          );
        }

        final order = orders[index];
        return _OrderCard(order: order);
      },
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Formatters.dateShort(order.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.inr(order.total),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onShop});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No orders yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Place your first order from our store.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: onShop,
                child: const Text('Start shopping'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.failure, required this.onRetry});

  final AppFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              failure?.userMessage ?? 'Something went wrong.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 160,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _labelFor(String status) {
  const map = {
    'NEW': 'New',
    'CONFIRMED': 'Confirmed',
    'PROCESSING': 'Processing',
    'PACKED': 'Packed',
    'SHIPPED': 'Shipped',
    'OUT_FOR_DELIVERY': 'Out for Delivery',
    'DELIVERED': 'Delivered',
    'CANCELLED': 'Cancelled',
  };
  return map[status] ?? status;
}
