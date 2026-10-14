import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Tag-style options editor for SELECT-type attributes.
///
/// Displays the current [options] as removable chips and provides an input
/// field to add new ones. Validates:
///   - Each option is non-empty after trim.
///   - Duplicate options (case-insensitive) are rejected inline.
///   - At least one option is required (caller checks via [hasError]).
///
/// [onChanged] is called with the updated list whenever options change.
class AttributeOptionsEditor extends StatefulWidget {
  const AttributeOptionsEditor({
    super.key,
    required this.options,
    required this.onChanged,
    this.showError = false,
  });

  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  /// When true, shows the "Add at least one option" inline error.
  final bool showError;

  @override
  State<AttributeOptionsEditor> createState() => _AttributeOptionsEditorState();
}

class _AttributeOptionsEditorState extends State<AttributeOptionsEditor> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String? _inputError;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addOption() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _inputError = 'Option cannot be empty.');
      return;
    }
    // Case-insensitive duplicate check.
    final lower = raw.toLowerCase();
    final duplicate = widget.options.any((o) => o.toLowerCase() == lower);
    if (duplicate) {
      setState(() => _inputError = '"$raw" already exists.');
      return;
    }
    setState(() => _inputError = null);
    _ctrl.clear();
    widget.onChanged([...widget.options, raw]);
    _focusNode.requestFocus();
  }

  void _removeOption(String opt) {
    widget.onChanged(widget.options.where((o) => o != opt).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options *',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Existing options as chips ──────────────────────────────
        if (widget.options.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: widget.options
                .map(
                  (opt) => Chip(
                    key: Key('option_chip_$opt'),
                    label: Text(opt),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeOption(opt),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: AppSpacing.sm),

        // ── Input row ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('option_input'),
                controller: _ctrl,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Add option…',
                  errorText: _inputError,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
                onSubmitted: (_) => _addOption(),
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              key: const Key('add_option_button'),
              onPressed: _addOption,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: const Text('Add'),
            ),
          ],
        ),

        // ── Empty error (shown when save blocked) ─────────────────
        if (widget.showError && widget.options.isEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Add at least one option.',
            key: Key('options_required_error'),
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
