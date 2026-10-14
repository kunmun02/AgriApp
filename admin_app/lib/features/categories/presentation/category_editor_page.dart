import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/slugifier.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_category_repository.dart';
import '../data/models/category.dart';

// ── Max upload size ───────────────────────────────────────────────────────────

const _kMaxImageBytes = 5 * 1024 * 1024; // 5 MB
const _kAllowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

// ── Page ──────────────────────────────────────────────────────────────────────

/// A04 — Category editor (`/admin/categories/new` and `…/:id/edit`)
class CategoryEditorPage extends ConsumerStatefulWidget {
  const CategoryEditorPage({super.key, this.categoryId});

  /// null → create mode; non-null → edit mode.
  final String? categoryId;

  @override
  ConsumerState<CategoryEditorPage> createState() => _CategoryEditorPageState();
}

class _CategoryEditorPageState extends ConsumerState<CategoryEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');

  bool _isActive = true;
  String? _parentId;
  bool _slugEdited = false;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _serverError;
  String? _imageError;

  /// After first save in create mode, this holds the created category.
  Category? _savedCategory;

  /// All categories (for parent dropdown).
  List<Category> _allCategories = [];

  /// True only in edit mode while the existing category data is being fetched.
  /// In create mode the form renders immediately; the parent dropdown loads
  /// in the background (_loadingParents) and shows a disabled placeholder
  /// until ready.
  bool _loadingCategories = false;
  bool _loadingParents = false;

  bool get _isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    if (_isEdit) {
      // Edit mode: block form until we have the existing category data.
      _loadingCategories = true;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(adminCategoryRepositoryProvider);

    if (!_isEdit) {
      // Create mode: show the form immediately; load parent options in the
      // background so the dropdown populates once ready.
      setState(() => _loadingParents = true);
      try {
        final all = await repo.fetchAll();
        if (!mounted) return;
        setState(() {
          _allCategories = all;
          _loadingParents = false;
        });
      } catch (e) {
        if (mounted) setState(() => _loadingParents = false);
        // Non-fatal in create mode – form is still usable without parents.
      }
      return;
    }

    // Edit mode: fetch all categories, then populate fields.
    try {
      final all = await repo.fetchAll();
      if (!mounted) return;
      setState(() {
        _allCategories = all;
        _loadingCategories = false;
      });

      final cat = all.firstWhere((c) => c.id == widget.categoryId!);
      _nameCtrl.text = cat.name;
      _slugCtrl.text = cat.slug;
      _descCtrl.text = cat.description ?? '';
      _orderCtrl.text = cat.displayOrder.toString();
      _isActive = cat.isActive;
      _parentId = cat.parentId;
      _savedCategory = cat;
      _slugEdited = true; // Don't auto-update slug in edit mode.
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCategories = false;
          _serverError = e.toString();
        });
      }
    }
  }

  void _onNameChanged() {
    if (!_slugEdited) {
      _slugCtrl.text = Slugifier.slugify(_nameCtrl.text);
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final repo = ref.read(adminCategoryRepositoryProvider);

    try {
      final name = _nameCtrl.text.trim();
      final slug = _slugCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final order = int.tryParse(_orderCtrl.text) ?? 0;

      Category result;
      if (_isEdit) {
        result = await repo.update(
          _savedCategory!.copyWith(
            name: name,
            slug: slug,
            parentId: _parentId,
            clearParentId: _parentId == null,
            description: desc.isEmpty ? null : desc,
            clearDescription: desc.isEmpty,
            displayOrder: order,
            isActive: _isActive,
          ),
        );
      } else {
        result = await repo.create(
          name: name,
          parentId: _parentId,
          description: desc.isEmpty ? null : desc,
          displayOrder: order,
          slug: slug,
        );
      }

      if (!mounted) return;
      setState(() {
        _savedCategory = result;
        _slugCtrl.text = result.slug; // Show final slug after collision loop.
        _slugEdited = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category saved')),
      );

      if (!_isEdit) {
        // Stay on page so image section becomes available.
        // Update URL to edit mode without pushing a new route.
        context.replace('/admin/categories/${result.id}/edit');
      } else {
        context.go('/admin/categories');
      }
    } catch (e) {
      if (mounted) setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Image upload ──────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    setState(() => _imageError = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAllowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    if (!_kAllowedExtensions.contains(ext)) {
      setState(() => _imageError = 'Only jpg, png, webp images are allowed.');
      return;
    }
    if (file.bytes!.length > _kMaxImageBytes) {
      setState(() => _imageError = 'Image must be 5 MB or smaller.');
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final path = await ref.read(adminCategoryRepositoryProvider).uploadImage(
            categoryId: _savedCategory!.id,
            bytes: file.bytes!,
            fileName: file.name,
          );
      if (!mounted) return;
      setState(() {
        _savedCategory = _savedCategory!.copyWith(imagePath: path);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded')),
      );
    } catch (e) {
      if (mounted) setState(() => _imageError = e.toString());
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _removeImage() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove image?',
      message: 'This cannot be undone.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    // Set image_path to null in DB.
    try {
      final updated = await ref
          .read(adminCategoryRepositoryProvider)
          .update(_savedCategory!.copyWith(clearImagePath: true));
      if (!mounted) return;
      setState(() => _savedCategory = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Category' : 'New Category';
    return AdminShell(
      title: title,
      // In edit mode we wait for the category data before showing the form.
      // In create mode (_loadingCategories is always false) we show immediately.
      child: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    // Build parent dropdown items — exclude self and descendants.
    final excluded = _isEdit && _savedCategory != null
        ? CategoryTree.descendantIds(_savedCategory!.id, _allCategories)
        : <String>{};

    final parentOptions =
        _allCategories.where((c) => !excluded.contains(c.id)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Section: Details ──────────────────────────────
              const _SectionHeader(title: 'Details'),
              const SizedBox(height: AppSpacing.md),

              // Name
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

              // Slug
              TextFormField(
                key: const Key('slug_field'),
                controller: _slugCtrl,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  helperText: 'Auto-generated from name; editable',
                ),
                onChanged: (_) => setState(() => _slugEdited = true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Slug is required.';
                  }
                  final pattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
                  if (!pattern.hasMatch(v.trim())) {
                    return 'Slug: lowercase letters, digits, hyphens only.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Parent dropdown
              if (_loadingParents)
                const InputDecorator(
                  decoration: InputDecoration(labelText: 'Parent category'),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading…'),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String?>(
                  key: const Key('parent_dropdown'),
                  initialValue: _parentId,
                  decoration: const InputDecoration(labelText: 'Parent category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...parentOptions.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _parentId = v),
                ),
              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                key: const Key('description_field'),
                controller: _descCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Description'),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Section: Visibility ───────────────────────────
              const _SectionHeader(title: 'Visibility'),
              const SizedBox(height: AppSpacing.md),

              Row(children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('order_field'),
                    controller: _orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Display order'),
                    validator: (v) {
                      if (v == null || int.tryParse(v) == null) {
                        return 'Must be a number.';
                      }
                      if (int.parse(v) < 0) {
                        return 'Must be ≥ 0.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Row(children: [
                  const Text('Active'),
                  Switch(
                    key: const Key('active_switch'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ]),
              ]),

              // ── Section: Image (visible after first save) ─────
              if (_savedCategory != null) ...[
                const SizedBox(height: AppSpacing.xl),
                const _SectionHeader(title: 'Image'),
                const SizedBox(height: AppSpacing.md),
                if (_savedCategory!.imagePath != null) ...[
                  Text('Current image path:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    _savedCategory!.imagePath!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    key: const Key('remove_image_button'),
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    label: const Text('Remove image',
                        style: TextStyle(color: AppColors.error)),
                    onPressed: _uploadingImage ? null : _removeImage,
                  ),
                ],
                if (_imageError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _imageError!,
                    key: const Key('image_error'),
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('upload_image_button'),
                  icon: _uploadingImage
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined),
                  label: Text(_uploadingImage ? 'Uploading…' : 'Upload image'),
                  onPressed: _uploadingImage ? null : _pickAndUpload,
                ),
                Text(
                  'jpg, png, webp — max 5 MB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],

              // ── Server error ──────────────────────────────────
              if (_serverError != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _serverError!,
                  key: const Key('server_error'),
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Footer ────────────────────────────────────────
              Row(children: [
                SizedBox(
                  width: 100,
                  child: OutlinedButton(
                    key: const Key('cancel_button'),
                    onPressed: () => context.go('/admin/categories'),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    key: const Key('save_button'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Divider(),
      ],
    );
  }
}
