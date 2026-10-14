import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/paginated_table_controls.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../../orders/data/admin_order_repository.dart' show Paginated;
import '../data/admin_inventory_repository.dart';
import '../widgets/adjust_stock_dialog.dart';
import '../widgets/transaction_history_dialog.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _inventoryPageProvider =
    StateNotifierProvider.autoDispose<_InventoryNotifier, _InventoryState>(
  (ref) => _InventoryNotifier(ref.watch(adminInventoryRepositoryProvider)),
);

class _InventoryState {
  const _InventoryState({
    this.page = 1,
    this.query = '',
    this.lowStockOnly = false,
    this.paginated,
    this.isLoading = false,
    this.error,
  });
  final int page;
  final String query;
  final bool lowStockOnly;
  final Paginated<InventoryRow>? paginated;
  final bool isLoading;
  final String? error;

  _InventoryState copyWith({
    int? page,
    String? query,
    bool? lowStockOnly,
    Paginated<InventoryRow>? paginated,
    bool? isLoading,
    Object? error = _sentinel,
  }) =>
      _InventoryState(
        page: page ?? this.page,
        query: query ?? this.query,
        lowStockOnly: lowStockOnly ?? this.lowStockOnly,
        paginated: paginated ?? this.paginated,
        isLoading: isLoading ?? this.isLoading,
        error: error == _sentinel ? this.error : error as String?,
      );
}

const _sentinel = Object();

class _InventoryNotifier extends StateNotifier<_InventoryState> {
  _InventoryNotifier(this._repo) : super(const _InventoryState()) {
    fetch();
  }
  final AdminInventoryRepository _repo;

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final p = await _repo.list(
        query: state.query.isEmpty ? null : state.query,
        lowStockOnly: state.lowStockOnly,
        page: state.page,
      );
      state = state.copyWith(isLoading: false, paginated: p);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setQuery(String q) {
    state = state.copyWith(query: q, page: 1);
    fetch();
  }

  void setLowStockOnly(bool v) {
    state = state.copyWith(lowStockOnly: v, page: 1);
    fetch();
  }

  void goPage(int p) {
    state = state.copyWith(page: p);
    fetch();
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_inventoryPageProvider);
    final notifier = ref.read(_inventoryPageProvider.notifier);

    return AdminShell(
      title: 'Inventory',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterRow(
              query: state.query,
              lowStockOnly: state.lowStockOnly,
              onQuery: notifier.setQuery,
              onLowStockOnly: notifier.setLowStockOnly,
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (state.error != null)
              Center(
                  child: Text(state.error!,
                      style: const TextStyle(color: Colors.red)))
            else if (state.paginated != null)
              _InventoryTable(
                rows: state.paginated!.items,
                onRefresh: notifier.fetch,
              ),
            if (state.paginated != null)
              PaginatedTableControls(
                page: state.page,
                total: state.paginated!.total,
                pageSize: state.paginated!.pageSize,
                onPrev: state.page > 1
                    ? () => notifier.goPage(state.page - 1)
                    : null,
                onNext: state.paginated!.hasMore
                    ? () => notifier.goPage(state.page + 1)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatefulWidget {
  const _FilterRow({
    required this.query,
    required this.lowStockOnly,
    required this.onQuery,
    required this.onLowStockOnly,
  });
  final String query;
  final bool lowStockOnly;
  final ValueChanged<String> onQuery;
  final ValueChanged<bool> onLowStockOnly;

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            key: const Key('inventory_search'),
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'Search name or SKU…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onSubmitted: widget.onQuery,
            onChanged: (v) {
              if (v.isEmpty) widget.onQuery('');
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Row(
          children: [
            Checkbox(
              key: const Key('low_stock_only'),
              value: widget.lowStockOnly,
              onChanged: (v) => widget.onLowStockOnly(v ?? false),
            ),
            const Text('Low stock only'),
          ],
        ),
      ],
    );
  }
}

class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.rows, required this.onRefresh});
  final List<InventoryRow> rows;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No inventory items match.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Quantity'), numeric: true),
          DataColumn(label: Text('Reserved'), numeric: true),
          DataColumn(label: Text('Min Level'), numeric: true),
          DataColumn(label: Text('Last Updated')),
          DataColumn(label: Text('Actions')),
        ],
        rows: rows.map((row) {
          final isLow = row.isLowStock;
          final rowColor =
              isLow ? WidgetStateProperty.all(Colors.red.shade50) : null;
          return DataRow(
            color: rowColor,
            cells: [
              DataCell(Text(
                row.productName,
                style: isLow
                    ? const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)
                    : null,
              )),
              DataCell(Text(row.sku)),
              DataCell(Text(
                row.quantity.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isLow ? Colors.red : null,
                ),
              )),
              DataCell(Text(row.reservedQuantity.toString())),
              DataCell(Text(row.minStockLevel.toString())),
              DataCell(Text(Formatters.dateShort(row.updatedAt))),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: Key('adjust_${row.productId}'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openAdjust(context, row),
                    child: const Text('Adjust'),
                  ),
                  IconButton(
                    key: Key('history_${row.productId}'),
                    icon: const Icon(Icons.history, size: 18),
                    tooltip: 'History',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _openHistory(context, row),
                  ),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openAdjust(BuildContext context, InventoryRow row) async {
    final refreshed = await showDialog<bool>(
      context: context,
      builder: (_) => AdjustStockDialog(row: row),
    );
    if (refreshed == true) onRefresh();
  }

  Future<void> _openHistory(BuildContext context, InventoryRow row) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TransactionHistoryDialog(row: row),
    );
  }
}
