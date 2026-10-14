import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/admin_inventory_repository.dart';

/// Dialog for RESTOCK or CORRECTION stock adjustments.
/// Returns true to the caller if a successful adjustment was made.
class AdjustStockDialog extends ConsumerStatefulWidget {
  const AdjustStockDialog({super.key, required this.row});
  final InventoryRow row;

  @override
  ConsumerState<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<AdjustStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deltaCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _type = 'RESTOCK';
  bool _loading = false;
  String? _dialogError;

  @override
  void dispose() {
    _deltaCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  int? get _parsedDelta => int.tryParse(_deltaCtrl.text.trim());

  int? get _previewQuantity {
    final d = _parsedDelta;
    if (d == null) return null;
    return widget.row.quantity + d;
  }

  bool get _previewNegative {
    final pq = _previewQuantity;
    return pq != null && pq < 0;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_previewNegative) return; // guarded by validator too

    setState(() {
      _loading = true;
      _dialogError = null;
    });

    try {
      final repo = ref.read(adminInventoryRepositoryProvider);
      await repo.adjust(
        productId: widget.row.productId,
        delta: _parsedDelta!,
        transactionType: _type,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) {
        final newQty = _previewQuantity!;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock updated: ${widget.row.quantity} → $newQty'),
          ),
        );
      }
    } on AppFailure catch (e) {
      setState(() {
        _dialogError = e.userMessage;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _dialogError = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewQuantity;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.row.productName),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type — using InputDecorator + DropdownButton to avoid
              // the deprecated FormField.value parameter.
              InputDecorator(
                key: const Key('adjust_type'),
                decoration: const InputDecoration(labelText: 'Type'),
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'RESTOCK', child: Text('RESTOCK')),
                    DropdownMenuItem(
                        value: 'CORRECTION', child: Text('CORRECTION')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ),
              const SizedBox(height: 12),
              // Delta
              TextFormField(
                key: const Key('adjust_delta'),
                controller: _deltaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Delta (signed integer, e.g. +40 or -5)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Must be a whole number';
                  if (n == 0) return 'Delta cannot be zero';
                  if ((widget.row.quantity + n) < 0) {
                    return 'Resulting stock cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Reason
              TextFormField(
                key: const Key('adjust_reason'),
                controller: _reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLength: 200,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 3) return 'At least 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Live preview
              if (preview != null)
                Text(
                  'New quantity: ${widget.row.quantity} → $preview',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: preview < 0 ? Colors.red : Colors.green.shade700,
                  ),
                ),
              if (_dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dialogError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('adjust_submit'),
          onPressed: (_loading || _previewNegative) ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
