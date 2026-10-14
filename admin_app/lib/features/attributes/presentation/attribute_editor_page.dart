import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/attribute_key_generator.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_attribute_repository.dart';
import '../data/models/category_attribute.dart';
import '../widgets/attribute_options_editor.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

/// A06 — Attribute editor
/// Route: `/admin/categories/:categoryId/attributes/new`
///        `/admin/categories/:categoryId/attributes/:attributeId/edit`
class AttributeEditorPage extends ConsumerStatefulWidget {
  const AttributeEditorPage({
    super.key,
    required this.categoryId,
    this.attributeId,
  });

  final String categoryId;

  /// null → create mode; non-null → edit mode.
  final String? attributeId;

  @override
  ConsumerState<AttributeEditorPage> createState() =>
      _AttributeEditorPageState();
}

class _AttributeEditorPageState extends ConsumerState<AttributeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');

  AttributeType _dataType = AttributeType.text;
  List<String> _options = [];
  bool _isRequired = false;
  bool _isActive = true;

  /// Set to true once the user manually edits the key field.
  bool _keyEdited = false;
  bool _saving = false;
  bool _loading = true;
  String? _serverError;

  /// True when the save was attempted and SELECT has 0 options.
  bool _showOptionsError = false;

  CategoryAttribute? _existing; // populated in edit mode

  bool get _isEdit => widget.attributeId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_isEdit) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final repo = ref.read(adminAttributeRepositoryProvider);
    try {
      final attrs = await repo.fetchForCategory(widget.categoryId);
      final attr = attrs.firstWhere((a) => a.id == widget.attributeId!);
      if (!mounted) return;
      _existing = attr;
      _nameCtrl.text = attr.name;
      _keyCtrl.text = attr.attributeKey;
      _dataType = attr.dataType;
      _options = List<String>.from(attr.options);
      _isRequired = attr.isRequired;
      _orderCtrl.text = attr.displayOrder.toString();
      _isActive = attr.isActive;
      _keyEdited = true; // Lock auto-suggest in edit mode.
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _serverError = e.toString();
        });
      }
    }
  }

  void _onNameChanged() {
    // Auto-suggest key from name only in create mode before user edits the key.
    if (!_isEdit && !_keyEdited) {
      final suggested = AttributeKeyGenerator.fromName(_nameCtrl.text);
      _keyCtrl.text = suggested;
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() {
      _serverError = null;
      _showOptionsError = false;
    });

    // SELECT requires at least 1 option.
    if (_dataType == AttributeType.select && _options.isEmpty) {
      setState(() => _showOptionsError = true);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final repo = ref.read(adminAttributeRepositoryProvider);

    try {
      final name = _nameCtrl.text.trim();
      final key = _keyCtrl.text.trim();
      final order = int.tryParse(_orderCtrl.text) ?? 0;

      if (_isEdit) {
        await repo.update(
          _existing!.copyWith(
            name: name,
            options: _dataType == AttributeType.select ? _options : [],
            isRequired: _isRequired,
            displayOrder: order,
            isActive: _isActive,
          ),
        );
      } else {
        await repo.create(
          categoryId: widget.categoryId,
          name: name,
          attributeKey: key,
          dataType: _dataType,
          options: _dataType == AttributeType.select ? _options : [],
          isRequired: _isRequired,
          displayOrder: order,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attribute saved')),
      );
      context.go('/admin/categories/${widget.categoryId}/attributes');
    } catch (e) {
      if (mounted) {
        // 23505 unique violation → friendly inline message.
        final msg = e.toString();
        setState(() => _serverError = msg.contains('CONFLICT') ||
                msg.contains('already exists') ||
                msg.contains('VALIDATION_ERROR')
            ? 'Key already exists for this category.'
            : msg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Attribute' : 'New Attribute';
    return AdminShell(
      title: title,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Name ──────────────────────────────────────────────
              TextFormField(
                key: const Key('name_field'),
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Name must be at least 2 characters.';
                  }
                  if (v.trim().length > 60) {
                    return 'Name must be 60 characters or fewer.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Attribute key ─────────────────────────────────────
              TextFormField(
                key: const Key('key_field'),
                controller: _keyCtrl,
                enabled: !_isEdit,
                decoration: InputDecoration(
                  labelText: 'Attribute key *',
                  helperText: _isEdit
                      ? 'Key is locked once created'
                      : 'Auto-suggested from name; editable',
                ),
                onChanged: (_) {
                  if (!_isEdit) setState(() => _keyEdited = true);
                },
                validator: (v) {
                  if (_isEdit) return null; // locked — skip
                  if (v == null || v.trim().isEmpty) {
                    return 'Key is required.';
                  }
                  if (!AttributeKeyGenerator.isValid(v.trim())) {
                    return 'Key must match ^[a-z][a-z0-9_]{1,39}\$.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Data type ─────────────────────────────────────────
              DropdownButtonFormField<AttributeType>(
                key: const Key('data_type_dropdown'),
                initialValue: _dataType,
                decoration: InputDecoration(
                  labelText: 'Data type',
                  helperText: _isEdit ? 'Type is locked once created' : null,
                ),
                items: AttributeType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: _isEdit
                    ? null
                    : (v) => setState(() {
                          _dataType = v!;
                          _showOptionsError = false;
                        }),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Options editor (SELECT only) ───────────────────────
              if (_dataType == AttributeType.select) ...[
                AttributeOptionsEditor(
                  key: const Key('options_editor'),
                  options: _options,
                  onChanged: (opts) => setState(() {
                    _options = opts;
                    if (opts.isNotEmpty) _showOptionsError = false;
                  }),
                  showError: _showOptionsError,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Required + Order + Active ─────────────────────────
              Row(children: [
                const Text('Required'),
                Switch(
                  key: const Key('required_switch'),
                  value: _isRequired,
                  onChanged: (v) => setState(() => _isRequired = v),
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    key: const Key('order_field'),
                    controller: _orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Display order'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null) return 'Must be a number.';
                      if (n < 0) return 'Must be ≥ 0.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Text('Active'),
                Switch(
                  key: const Key('active_switch'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ]),

              // ── Server error ──────────────────────────────────────
              if (_serverError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _serverError!,
                  key: const Key('server_error'),
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Footer ────────────────────────────────────────────
              Row(children: [
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    key: const Key('cancel_button'),
                    onPressed: () => context.go(
                        '/admin/categories/${widget.categoryId}/attributes'),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('save_button'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
