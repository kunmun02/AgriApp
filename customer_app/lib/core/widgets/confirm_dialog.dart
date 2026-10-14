import 'package:flutter/material.dart';

/// Generic confirmation dialog used throughout the customer app.
///
/// Returns `true` if the user confirms, `false`/null if they cancel.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.isDanger = true,
  });

  final String title;
  final String message;
  final String confirmLabel;

  /// When true the confirm button uses the error colour.
  final bool isDanger;

  /// Convenience static helper — shows the dialog and awaits the result.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDanger = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDanger: isDanger,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(title),
      content: Text(message, style: theme.textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm_action'),
          style: TextButton.styleFrom(
            foregroundColor:
                isDanger ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
