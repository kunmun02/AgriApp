import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/paginated_table_controls.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_order_repository.dart';

// ── Filter state (survives pop-back) ─────────────────────────────────────────

class _OrdersFilter {
  const _OrdersFilter({
    this.status,
    this.query = '',
    this.page = 1,
  });
  final String? status;
  final String query;
  final int page;

  _OrdersFilter copyWith({
    Object? status = _sentinel,
    String? query,
    int? page,
  }) =>
      _OrdersFilter(
        status: status == _sentinel ? this.status : status as String?,
        query: query ?? this.query,
        page: page ?? this.page,
      );
}

const _sentinel = Object();

final ordersFilterProvider =
    StateProvider<_OrdersFilter>((ref) => const _OrdersFilter());

// ── Async provider ────────────────────────────────────────────────────────────

final _ordersPageProvider = FutureProvider.autoDispose
    .family<Paginated<OrderSummary>, _OrdersFilter>((ref, filter) async {
  final repo = ref.watch(adminOrderRepositoryProvider);
  return repo.list(
    status: filter.status,
    query: filter.query.isEmpty ? null : filter.query,
    page: filter.page,
  );
});

// Count NEW for accent dot
final _newOrderCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(adminOrderRepositoryProvider);
  return repo.countNewOrders();
});

// ── Chip statuses ─────────────────────────────────────────────────────────────

const _statusChips = [
  null, // = "All"
  'NEW',
  'CONFIRMED',
  'PROCESSING',
  'PACKED',
  'SHIPPED',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
  'CANCELLED',
];

// ── Page ──────────────────────────────────────────────────────────────────────

class OrdersListPage extends ConsumerStatefulWidget {
  const OrdersListPage({super.key});

  @override
  ConsumerState<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends ConsumerState<OrdersListPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(ordersFilterProvider);
    _searchCtrl = TextEditingController(text: filter.query);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setStatus(String? status) {
    ref.read(ordersFilterProvider.notifier).update(
          (f) => f.copyWith(status: status, page: 1),
        );
  }

  void _setQuery(String q) {
    ref.read(ordersFilterProvider.notifier).update(
          (f) => f.copyWith(query: q, page: 1),
        );
  }

  void _goPage(int p) {
    ref.read(ordersFilterProvider.notifier).update(
          (f) => f.copyWith(page: p),
        );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(ordersFilterProvider);
    final ordersAsync = ref.watch(_ordersPageProvider(filter));
    final newCountAsync = ref.watch(_newOrderCountProvider);

    return AdminShell(
      title: 'Orders',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status chip bar
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statusChips.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final s = _statusChips[i];
                  final label = s ?? 'All';
                  final selected = filter.status == s;
                  final isNew = s == 'NEW';
                  final newCount = newCountAsync.value ?? 0;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ChoiceChip(
                        key: Key('chip_${s ?? 'all'}'),
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) => _setStatus(s),
                      ),
                      if (isNew && newCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Search
            SizedBox(
              width: 300,
              child: TextField(
                key: const Key('orders_search'),
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search order number…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onSubmitted: _setQuery,
                onChanged: (v) {
                  if (v.isEmpty) _setQuery('');
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Table
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text(e.toString(),
                        style: const TextStyle(color: Colors.red))),
                data: (paginated) {
                  if (paginated.items.isEmpty) {
                    return const Center(child: Text('No orders match.'));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Order #')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Items'), numeric: true),
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
                            DataCell(Text(o.customerName)),
                            DataCell(Text(o.itemsCount.toString())),
                            DataCell(Text(Formatters.inr(o.total))),
                            DataCell(StatusBadge(status: o.status)),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            ordersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (paginated) => PaginatedTableControls(
                page: filter.page,
                total: paginated.total,
                pageSize: paginated.pageSize,
                onPrev: filter.page > 1 ? () => _goPage(filter.page - 1) : null,
                onNext:
                    paginated.hasMore ? () => _goPage(filter.page + 1) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
