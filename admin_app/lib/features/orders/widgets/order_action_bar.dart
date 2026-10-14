import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../data/admin_order_repository.dart';

/// Transition matrix (server-enforced, mirrored here for UI rendering only).
///
/// Key = current status → Value = list of allowed next statuses.
const _transitions = <String, List<String>>{
  'NEW': ['CONFIRMED', 'CANCELLED'],
  'CONFIRMED': ['PROCESSING', 'CANCELLED'],
  'PROCESSING': ['PACKED', 'CANCELLED'],
  'PACKED': ['SHIPPED'],
  'SHIPPED': ['OUT_FOR_DELIVERY'],
  'OUT_FOR_DELIVERY': ['DELIVERED'],
  'DELIVERED': [],
  'CANCELLED': [],
};

/// Labels shown on action buttons for each target status.
const _buttonLabels = <String, String>{
  'CONFIRMED': 'Confirm',
  'PROCESSING': 'Start Processing',
  'PACKED': 'Mark Packed',
  'SHIPPED': 'Mark Shipped',
  'OUT_FOR_DELIVERY': 'Mark Out for Delivery',
  'DELIVERED': 'Mark Delivered',
  'CANCELLED': 'Cancel Order',
};

/// Renders only the allowed transition buttons for [currentStatus].
/// Calls [onStatusChanged] with the result snackbar message on success.
class OrderActionBar extends ConsumerWidget {
  const OrderActionBar({
    super.key,
    required this.orderId,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  final String orderId;
  final String currentStatus;
  final VoidCallback onStatusChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = _transitions[currentStatus] ?? [];
    if (targets.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: targets.map((target) {
        final label = _buttonLabels[target] ?? target;
        final isCancel = target == 'CANCELLED';
        return _ActionButton(
          key: Key('action_$target'),
          label: label,
          isDestructive: isCancel,
          onPressed: () => _handleAction(context, ref, target),
        );
      }).toList(),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String target,
  ) async {
    String? reason;

    if (target == 'CANCELLED') {
      // Require cancel reason via dialog.
      reason = await _showCancelReasonDialog(context);
      if (reason == null) return; // user dismissed
    } else {
      // Confirm positive transitions.
      final label = _buttonLabels[target] ?? target;
      final confirmed = await ConfirmDialog.show(
        context,
        title: label,
        message: 'Are you sure you want to $label?',
        confirmLabel: label,
        isDanger: false,
      );
      if (!confirmed) return;
    }

    final repo = ref.read(adminOrderRepositoryProvider);
    try {
      await repo.changeStatus(
        orderId: orderId,
        target: target,
        reason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Order marked ${target.replaceAll('_', ' ').toLowerCase()}'),
          ),
        );
        onStatusChanged();
      }
    } on AppFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.userMessage),
            backgroundColor: Colors.red.shade700,
          ),
        );
        // Refetch on CONFLICT or OUT_OF_STOCK so UI shows current truth.
        if (e.code == 'CONFLICT' || e.code == 'OUT_OF_STOCK') {
          onStatusChanged();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<String?> _showCancelReasonDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CancelReasonDialog(),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.isDestructive,
    required this.onPressed,
  });
  final String label;
  final bool isDestructive;
  final Future<void> Function() onPressed;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Override minimumSize to prevent infinite-width assertion when Wrap
    // measures the button in an unconstrained horizontal context.
    final baseStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(64, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return ElevatedButton(
      style: widget.isDestructive
          ? baseStyle.copyWith(
              backgroundColor: WidgetStatePropertyAll(theme.colorScheme.error),
              foregroundColor:
                  WidgetStatePropertyAll(theme.colorScheme.onError),
            )
          : baseStyle,
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                await widget.onPressed();
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.label),
    );
  }
}

// ── Cancel reason dialog ──────────────────────────────────────────────────────

class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Order'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 340,
          child: TextFormField(
            key: const Key('cancel_reason'),
            controller: _ctrl,
            decoration: const InputDecoration(labelText: 'Reason (required)'),
            maxLength: 200,
            maxLines: 3,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length < 3) return 'At least 3 characters';
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        ElevatedButton(
          key: const Key('cancel_confirm'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_ctrl.text.trim());
            }
          },
          child: const Text('Cancel Order'),
        ),
      ],
    );
  }
}
