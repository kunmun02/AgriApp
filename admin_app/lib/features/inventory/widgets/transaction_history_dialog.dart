import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../data/admin_inventory_repository.dart';

/// Shows the last 50 inventory transactions for a product.
class TransactionHistoryDialog extends ConsumerStatefulWidget {
  const TransactionHistoryDialog({super.key, required this.row});
  final InventoryRow row;

  @override
  ConsumerState<TransactionHistoryDialog> createState() =>
      _TransactionHistoryDialogState();
}

class _TransactionHistoryDialogState
    extends ConsumerState<TransactionHistoryDialog> {
  late Future<List<InventoryTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(adminInventoryRepositoryProvider)
        .transactions(widget.row.productId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('History — ${widget.row.productName}'),
      content: SizedBox(
        width: 520,
        height: 400,
        child: FutureBuilder<List<InventoryTransaction>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            final txns = snapshot.data ?? [];
            if (txns.isEmpty) {
              return const Center(child: Text('No transactions found.'));
            }
            return Material(
              type: MaterialType.transparency,
              child: ListView.separated(
                itemCount: txns.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final t = txns[index];
                  final isPositive = t.quantityDelta >= 0;
                  return ListTile(
                    dense: true,
                    leading: Text(
                      isPositive ? '+${t.quantityDelta}' : '${t.quantityDelta}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPositive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    title: Text(
                      '${t.transactionType}  —  ${t.reason}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${Formatters.dateShort(t.createdAt)}'
                      '${t.createdByEmail != null ? '  ·  ${t.createdByEmail}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
