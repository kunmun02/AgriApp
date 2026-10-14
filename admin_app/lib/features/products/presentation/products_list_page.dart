import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/paginated_table_controls.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../../categories/data/admin_category_repository.dart';
import '../../categories/data/models/category.dart';
import '../../orders/data/admin_order_repository.dart';
import '../data/admin_media_repository.dart';
import '../data/admin_product_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class _ProductListState {
  const _ProductListState({
    this.query = '',
    this.sku = '',
    this.categoryId,
    this.filter = ProductAdminFilter.all,
    this.page = 1,
  });
  final String query;
  final String sku;
  final String? categoryId;
  final ProductAdminFilter filter;
  final int page;

  _ProductListState copyWith({
    String? query,
    String? sku,
    String? categoryId,
    bool clearCategory = false,
    ProductAdminFilter? filter,
    int? page,
  }) =>
      _ProductListState(
        query: query ?? this.query,
        sku: sku ?? this.sku,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        filter: filter ?? this.filter,
        page: page ?? this.page,
      );
}

// ── Page ──────────────────────────────────────────────────────────────────────

/// A07 — Products list (`/admin/products`)
class ProductsListPage extends StatelessWidget {
  const ProductsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShell(
      title: 'Products',
      child: _ProductsBody(),
    );
  }
}

class _ProductsBody extends ConsumerStatefulWidget {
  const _ProductsBody();

  @override
  ConsumerState<_ProductsBody> createState() => _ProductsBodyState();
}

class _ProductsBodyState extends ConsumerState<_ProductsBody> {
  _ProductListState _filter = const _ProductListState();
  Paginated<AdminProductCard>? _page;
  bool _loading = true;
  String? _error;
  List<Category> _categories = [];

  // Pending filter inputs (applied on "Apply").
  final _searchCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  String? _pendingCategoryId;
  ProductAdminFilter _pendingFilter = ProductAdminFilter.all;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _skuCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref
          .read(adminCategoryRepositoryProvider)
          .fetchAll(includeInactive: false);
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // Non-fatal — dropdown just stays empty.
    }
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(adminProductRepositoryProvider).list(
            query: _filter.query.isEmpty ? null : _filter.query,
            sku: _filter.sku.isEmpty ? null : _filter.sku,
            categoryId: _filter.categoryId,
            filter: _filter.filter,
            page: _filter.page,
          );
      if (mounted) setState(() => _page = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filter = _ProductListState(
        query: _searchCtrl.text.trim(),
        sku: _skuCtrl.text.trim(),
        categoryId: _pendingCategoryId,
        filter: _pendingFilter,
        page: 1,
      );
    });
    _loadPage();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _skuCtrl.clear();
    setState(() {
      _pendingCategoryId = null;
      _pendingFilter = ProductAdminFilter.all;
      _filter = const _ProductListState();
    });
    _loadPage();
  }

  Future<void> _togglePublish(AdminProductCard card) async {
    try {
      await ref
          .read(adminProductRepositoryProvider)
          .publish(card.id, !card.isPublished);
      _loadPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deactivate(AdminProductCard card) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Deactivate product?',
      message:
          'Deactivate "${card.name}"? It will no longer be visible to customers.',
      confirmLabel: 'Deactivate',
    );
    if (!confirmed) return;
    try {
      await ref.read(adminProductRepositoryProvider).deactivate(card.id);
      _loadPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Text('Products',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              SizedBox(
                width: 160,
                child: ElevatedButton.icon(
                  key: const Key('new_product_button'),
                  icon: const Icon(Icons.add),
                  label: const Text('New product'),
                  onPressed: () => context.go('/admin/products/new'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Filter row ──────────────────────────────────────────
          _FilterRow(
            searchCtrl: _searchCtrl,
            skuCtrl: _skuCtrl,
            categories: _categories,
            selectedCategoryId: _pendingCategoryId,
            selectedFilter: _pendingFilter,
            onCategoryChanged: (v) => setState(() => _pendingCategoryId = v),
            onFilterChanged: (v) =>
                setState(() => _pendingFilter = v ?? ProductAdminFilter.all),
            onApply: _applyFilters,
            onClear: _clearFilters,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Table ──────────────────────────────────────────────
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorState(error: _error!, onRetry: _loadPage)
          else if (_page == null || _page!.items.isEmpty)
            _EmptyState(onClear: _clearFilters)
          else ...[
            _ProductTable(
              items: _page!.items,
              onEdit: (id) => context.go('/admin/products/$id/edit'),
              onMedia: (id) => context.go('/admin/products/$id/media'),
              onTogglePublish: _togglePublish,
              onDeactivate: _deactivate,
              urlResolver: ref.read(adminMediaRepositoryProvider).publicUrl,
            ),
            PaginatedTableControls(
              page: _filter.page,
              total: _page!.total,
              pageSize: _page!.pageSize,
              onPrev: _filter.page > 1
                  ? () {
                      setState(() {
                        _filter = _filter.copyWith(page: _filter.page - 1);
                      });
                      _loadPage();
                    }
                  : null,
              onNext: _page!.hasMore
                  ? () {
                      setState(() {
                        _filter = _filter.copyWith(page: _filter.page + 1);
                      });
                      _loadPage();
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.searchCtrl,
    required this.skuCtrl,
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedFilter,
    required this.onCategoryChanged,
    required this.onFilterChanged,
    required this.onApply,
    required this.onClear,
  });
  final TextEditingController searchCtrl;
  final TextEditingController skuCtrl;
  final List<Category> categories;
  final String? selectedCategoryId;
  final ProductAdminFilter selectedFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<ProductAdminFilter?> onFilterChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            key: const Key('search_field'),
            controller: searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Name search',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            key: const Key('sku_field'),
            controller: skuCtrl,
            decoration: const InputDecoration(
              labelText: 'SKU',
              isDense: true,
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => onApply(),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String?>(
            key: const Key('category_filter'),
            decoration: const InputDecoration(
              labelText: 'Category',
              isDense: true,
            ),
            initialValue: selectedCategoryId,
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All categories')),
              ...categories.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: onCategoryChanged,
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<ProductAdminFilter>(
            key: const Key('status_filter'),
            decoration: const InputDecoration(
              labelText: 'Status',
              isDense: true,
            ),
            initialValue: selectedFilter,
            items: const [
              DropdownMenuItem(
                  value: ProductAdminFilter.all, child: Text('All')),
              DropdownMenuItem(
                  value: ProductAdminFilter.published,
                  child: Text('Published')),
              DropdownMenuItem(
                  value: ProductAdminFilter.draft, child: Text('Draft')),
              DropdownMenuItem(
                  value: ProductAdminFilter.inactive, child: Text('Inactive')),
            ],
            onChanged: onFilterChanged,
          ),
        ),
        SizedBox(
          width: 90,
          child: ElevatedButton(
            key: const Key('apply_filter_button'),
            onPressed: onApply,
            child: const Text('Apply'),
          ),
        ),
        SizedBox(
          width: 90,
          child: OutlinedButton(
            key: const Key('clear_filter_button'),
            onPressed: onClear,
            child: const Text('Clear'),
          ),
        ),
      ],
    );
  }
}

// ── Product table ─────────────────────────────────────────────────────────────

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.items,
    required this.onEdit,
    required this.onMedia,
    required this.onTogglePublish,
    required this.onDeactivate,
    required this.urlResolver,
  });
  final List<AdminProductCard> items;
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onMedia;
  final Future<void> Function(AdminProductCard) onTogglePublish;
  final Future<void> Function(AdminProductCard) onDeactivate;
  final String Function(String) urlResolver;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: AppSpacing.lg,
        columns: const [
          DataColumn(label: Text('Image')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Price ₹'), numeric: true),
          DataColumn(label: Text('Stock')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: items
            .map((card) => _ProductRow(
                  card: card,
                  onEdit: onEdit,
                  onMedia: onMedia,
                  onTogglePublish: onTogglePublish,
                  onDeactivate: onDeactivate,
                  urlResolver: urlResolver,
                ).build(context))
            .toList(),
      ),
    );
  }
}

class _ProductRow {
  const _ProductRow({
    required this.card,
    required this.onEdit,
    required this.onMedia,
    required this.onTogglePublish,
    required this.onDeactivate,
    required this.urlResolver,
  });
  final AdminProductCard card;
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onMedia;
  final Future<void> Function(AdminProductCard) onTogglePublish;
  final Future<void> Function(AdminProductCard) onDeactivate;
  final String Function(String) urlResolver;

  DataRow build(BuildContext context) {
    return DataRow(cells: [
      // Thumbnail
      DataCell(
        SizedBox(
          width: 40,
          height: 40,
          child: card.primaryImagePath != null
              ? Image.network(urlResolver(card.primaryImagePath!),
                  fit: BoxFit.cover)
              : const Icon(Icons.image_not_supported_outlined,
                  color: AppColors.textSecondary),
        ),
      ),
      DataCell(Text(card.name, overflow: TextOverflow.ellipsis)),
      DataCell(Text(card.sku)),
      DataCell(Text(card.categoryName)),
      DataCell(Text('₹${card.price.toStringAsFixed(2)}')),
      DataCell(Text(card.stock != null ? '${card.stock}' : '—')),
      // Status chips
      DataCell(_StatusChips(card: card)),
      // Actions
      DataCell(
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => onEdit(card.id),
          ),
          IconButton(
            tooltip: 'Media',
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            onPressed: () => onMedia(card.id),
          ),
          IconButton(
            tooltip: card.isPublished ? 'Unpublish' : 'Publish',
            icon: Icon(
              card.isPublished
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
            ),
            onPressed: () => onTogglePublish(card),
          ),
          if (card.isActive)
            IconButton(
              tooltip: 'Deactivate',
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              onPressed: () => onDeactivate(card),
            ),
        ]),
      ),
    ]);
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.card});
  final AdminProductCard card;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        if (!card.isActive)
          _chip('Inactive', AppColors.error)
        else if (card.isPublished)
          _chip('Published', AppColors.success)
        else
          _chip('Draft', AppColors.textSecondary),
      ],
    );
  }

  Widget _chip(String label, Color color) => Chip(
        label: Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white)),
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          const Text('No products match the filters'),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
              onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(error),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
