import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/paginated_table_controls.dart';
import '../../../features/auth/data/models/profile.dart';
import '../../../features/orders/data/admin_order_repository.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_customer_repository.dart';

// ── Filter state ──────────────────────────────────────────────────────────────

class _CustomersFilter {
  const _CustomersFilter({this.query = '', this.page = 1});
  final String query;
  final int page;

  _CustomersFilter copyWith({String? query, int? page}) => _CustomersFilter(
        query: query ?? this.query,
        page: page ?? this.page,
      );
}

final _customersFilterProvider =
    StateProvider<_CustomersFilter>((ref) => const _CustomersFilter());

// ── Async provider ─────────────────────────────────────────────────────────────

final _customersPageProvider = FutureProvider.autoDispose
    .family<Paginated<Profile>, _CustomersFilter>((ref, filter) {
  final repo = ref.watch(adminCustomerRepositoryProvider);
  return repo.list(
    query: filter.query.isEmpty ? null : filter.query,
    page: filter.page,
  );
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// A13 — Customers list `/admin/customers`.
class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl =
        TextEditingController(text: ref.read(_customersFilterProvider).query);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(_customersFilterProvider.notifier).update(
            (f) => f.copyWith(query: value, page: 1),
          );
    });
  }

  void _goPage(int page) {
    ref.read(_customersFilterProvider.notifier).update(
          (f) => f.copyWith(page: page),
        );
  }

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
      ref.invalidate(_customersPageProvider);
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_customersFilterProvider);
    final customersAsync = ref.watch(_customersPageProvider(filter));

    return AdminShell(
      title: 'Customers',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search
            SizedBox(
              width: 320,
              child: TextField(
                key: const Key('customers_search'),
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search by name or email…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Table
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    e is AppFailure ? e.userMessage : e.toString(),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (paginated) {
                  if (paginated.items.isEmpty) {
                    return const Center(child: Text('No customers found.'));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Joined')),
                        DataColumn(label: Text('Active')),
                      ],
                      rows: paginated.items.map((customer) {
                        return DataRow(
                          key: ValueKey('customer_row_${customer.id}'),
                          onSelectChanged: (_) =>
                              context.push('/admin/customers/${customer.id}'),
                          cells: [
                            DataCell(Text(customer.fullName)),
                            DataCell(Text(customer.email)),
                            DataCell(Text(customer.phone ?? '—')),
                            DataCell(
                                Text(Formatters.dateShort(customer.createdAt))),
                            DataCell(
                              Switch(
                                key: Key('active_switch_${customer.id}'),
                                value: customer.isActive,
                                onChanged: (v) => _toggleActive(customer, v),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            customersAsync.when(
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
