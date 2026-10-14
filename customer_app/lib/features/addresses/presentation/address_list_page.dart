import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../data/address_repository.dart';
import '../data/models/address.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _addressListProvider =
    FutureProvider.autoDispose<List<Address>>((ref) async {
  return ref.read(addressRepositoryProvider).fetchAddresses();
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// C09 — Address List screen.
///
/// Pushed in **select mode** from C11 (returns the tapped [Address] to
/// the caller via `context.pop(address)`). Otherwise used for management
/// (edit / delete).
class AddressListPage extends ConsumerWidget {
  const AddressListPage({super.key, this.selectMode = false});

  /// When true, tapping an address pops with that address as the result.
  final bool selectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAddresses = ref.watch(_addressListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(selectMode ? 'Select Address' : 'My Addresses'),
        actions: [
          if (!selectMode)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add address',
              onPressed: () async {
                await context.push('/addresses/new');
                ref.invalidate(_addressListProvider);
              },
            ),
        ],
      ),
      body: asyncAddresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is AppFailure ? e.message : 'Failed to load addresses.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_addressListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (addresses) => addresses.isEmpty
            ? _EmptyAddresses(
                onAdd: () async {
                  await context.push('/addresses/new');
                  ref.invalidate(_addressListProvider);
                },
              )
            : _AddressList(
                addresses: addresses,
                selectMode: selectMode,
                onRefresh: () => ref.invalidate(_addressListProvider),
                onEdit: (addr) async {
                  await context.push('/addresses/${addr.id}/edit', extra: addr);
                  ref.invalidate(_addressListProvider);
                },
                onDelete: (addr) async {
                  final confirmed = await _confirmDelete(context, addr);
                  if (!confirmed) return;
                  try {
                    await ref
                        .read(addressRepositoryProvider)
                        .deleteAddress(addr.id);
                    ref.invalidate(_addressListProvider);
                  } on AppFailure catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  }
                },
              ),
      ),
      floatingActionButton: selectMode
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/addresses/new');
                ref.invalidate(_addressListProvider);
              },
              label: const Text('Add Address'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Address addr) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete address?'),
            content: Text(
                'Remove "${addr.label}" address for ${addr.recipientName}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AddressList extends StatelessWidget {
  const _AddressList({
    required this.addresses,
    required this.selectMode,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Address> addresses;
  final bool selectMode;
  final VoidCallback onRefresh;
  final Future<void> Function(Address) onEdit;
  final Future<void> Function(Address) onDelete;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.md),
        itemCount: addresses.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final addr = addresses[index];
          return _AddressCard(
            address: addr,
            selectMode: selectMode,
            onEdit: () => onEdit(addr),
            onDelete: () => onDelete(addr),
          );
        },
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selectMode,
    required this.onEdit,
    required this.onDelete,
  });

  final Address address;
  final bool selectMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: selectMode ? () => context.pop(address) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _LabelChip(label: address.label),
                        if (address.isDefault) ...[
                          const SizedBox(width: AppSpacing.xs),
                          _DefaultChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      address.recipientName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '+91-${address.phone}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatAddress(address),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!selectMode) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  color: AppColors.error,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatAddress(Address a) {
    final parts = [
      a.line1,
      if (a.line2 != null && a.line2!.isNotEmpty) a.line2!,
      a.city,
      a.state,
      a.postalCode,
    ];
    return parts.join(', ');
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

class _DefaultChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Text(
        'Default',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  const _EmptyAddresses({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text('No addresses yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add an address to proceed with delivery.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(onPressed: onAdd, label: 'Add Address'),
          ],
        ),
      ),
    );
  }
}
