import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/admin_notification_repository.dart';

// ── Provider for live active customer count ───────────────────────────────────

final _activeCustomerCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return ref.read(adminNotificationRepositoryProvider).activeCustomerCount();
});

// ── Dialog ────────────────────────────────────────────────────────────────────

/// Broadcast composer dialog (spec A15).
///
/// Pops [true] when a broadcast was sent (even partially);
/// pops [false] or null on cancel.
class BroadcastDialog extends ConsumerStatefulWidget {
  const BroadcastDialog({super.key});

  @override
  ConsumerState<BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends ConsumerState<BroadcastDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  String? _dialogError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(int recipientCount) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _sending = true;
      _dialogError = null;
    });

    try {
      final repo = ref.read(adminNotificationRepositoryProvider);
      final result = await repo.broadcast(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);

      final msg = result.isPartialFailure
          ? 'Sent to ${result.sent} of ${result.total} customers'
          : 'Broadcast sent to ${result.sent} customers';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on AppFailure catch (e) {
      setState(() {
        _dialogError = e.userMessage;
        _sending = false;
      });
    } catch (_) {
      setState(() {
        _dialogError = 'Something went wrong. Please try again.';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final countAsync = ref.watch(_activeCustomerCountProvider);
    final recipientCount = countAsync.value ?? 0;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('New broadcast'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title field
              TextFormField(
                key: const Key('broadcast_title'),
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Price drop on fertilizers',
                ),
                maxLength: 80,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Title is required';
                  if (v.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacingBroadcast.sm),
              // Body field
              TextFormField(
                key: const Key('broadcast_body'),
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  hintText: 'Message content…',
                ),
                maxLength: 500,
                maxLines: 4,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Body is required';
                  if (v.trim().length < 3) {
                    return 'Body must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacingBroadcast.sm),
              // Live recipient count
              countAsync.when(
                loading: () => const Text(
                  'Loading recipient count…',
                  style: TextStyle(color: Colors.grey),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (count) => Text(
                  'Will be sent to $count active customer${count == 1 ? '' : 's'}',
                  key: const Key('recipient_count_text'),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
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
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('broadcast_submit'),
          // Locked while sending (double-submit prevention).
          onPressed: _sending ? null : () => _submit(recipientCount),
          child: _sending
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Sending…'),
                  ],
                )
              : const Text('Send broadcast'),
        ),
      ],
    );
  }
}

// ── Local spacing constants (avoids importing admin theme) ────────────────────

class AppSpacingBroadcast {
  static const double sm = 8.0;
}
