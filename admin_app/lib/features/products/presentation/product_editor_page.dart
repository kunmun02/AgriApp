import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/slugifier.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../../attributes/data/admin_attribute_repository.dart';
import '../../attributes/data/models/category_attribute.dart';
import '../../categories/data/admin_category_repository.dart';
import '../../categories/data/models/category.dart';
import '../data/admin_media_repository.dart';
import '../data/admin_product_repository.dart';
import '../data/product_draft.dart';
import '../widgets/dynamic_attribute_form.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

/// A08 — Product editor
/// Route: `/admin/products/new` and `/admin/products/:productId/edit`
class ProductEditorPage extends ConsumerStatefulWidget {
  const ProductEditorPage({super.key, this.productId});

  /// null → create mode; non-null → edit mode.
  final String? productId;

  @override
  ConsumerState<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _ProductEditorPageState extends ConsumerState<ProductEditorPage> {
  // ── Form controllers ──────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');
  final _qtyCtrl = TextEditingController(text: '0');

  bool _slugEdited = false;

  // ── Selection state ───────────────────────────────────────────────────
  String? _categoryId;
  Map<String, dynamic> _attrValues = {};

  // ── Data ──────────────────────────────────────────────────────────────
  List<Category> _categories = [];
  List<CategoryAttribute> _categoryAttributes = [];

  // ── UI state ──────────────────────────────────────────────────────────
  bool _loadingData = true;
  bool _saving = false;
  String? _serverError;
  List<String> _publishErrors = [];
  bool _validateRequired = false;

  // ── Media state ───────────────────────────────────────────────────────
  List<ProductImage> _images = [];
  String? _uploadProgress;

  /// Product id created silently when the user uploads images on a new product
  /// before explicitly saving the draft. Once set, the form stays on the page
  /// (no navigation) until the user hits Save draft / Publish, at which point
  /// [_saveDraft] / [_publish] update the already-created product and navigate
  /// to edit mode as usual.
  String? _pendingProductId;

  // ── Field-level errors (inline) ───────────────────────────────────────
  String? _priceError;
  String? _mrpError;
  String? _taxError;
  String? _skuError;

  bool get _isEdit => widget.productId != null;

  // Footer height = button height (36) + vertical padding (12 × 2) + divider (1)
  static const double _kFooterHeight = 61;

  /// The product id to use for media operations.
  /// On an existing product this is [widget.productId]; on a new product it
  /// may be [_pendingProductId] after a silent auto-save triggered by upload.
  String? get _effectiveProductId => widget.productId ?? _pendingProductId;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _skuCtrl.dispose();
    _brandCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _mrpCtrl.dispose();
    _taxCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!_slugEdited) {
      _slugCtrl.text = Slugifier.slugify(_nameCtrl.text);
    }
  }

  // ── Load ──────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      final catRepo = ref.read(adminCategoryRepositoryProvider);
      final cats = await catRepo.fetchAll(includeInactive: false);
      if (!mounted) return;
      setState(() => _categories = cats);

      if (_isEdit) {
        final detail = await ref
            .read(adminProductRepositoryProvider)
            .details(widget.productId!);
        if (!mounted) return;
        // All field + state assignments in one setState so the
        // form rebuilds completely with the loaded data.
        setState(() {
          _nameCtrl.text = detail.name;
          _slugCtrl.text = detail.slug;
          _skuCtrl.text = detail.sku;
          _brandCtrl.text = detail.brand ?? '';
          _descCtrl.text = detail.description ?? '';
          _priceCtrl.text = detail.price.toStringAsFixed(2);
          _mrpCtrl.text = detail.mrp.toStringAsFixed(2);
          _taxCtrl.text = detail.taxPercent.toStringAsFixed(2);
          _slugEdited = true;
          _categoryId = detail.categoryId;
        });

        // Load attributes for the locked category.
        await _loadAttributesFor(detail.categoryId);

        // Populate existing attribute values.
        if (!mounted) return;
        setState(() {
          _attrValues = attributeMapFromValues(
            detail.attributes,
            _categoryAttributes,
          );
        });

        // Load images.
        await _reloadImages();
      }
    } catch (e) {
      if (mounted) setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _loadAttributesFor(String catId) async {
    try {
      final attrs = await ref
          .read(adminAttributeRepositoryProvider)
          .fetchForCategory(catId);
      if (!mounted) return;
      setState(() {
        _categoryAttributes = attrs.where((a) => a.isActive).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        // Clear values when category changes on create.
        if (!_isEdit) _attrValues = {};
      });
    } catch (_) {
      // Non-fatal — attribute section shows empty.
    }
  }

  // ── Media helpers ─────────────────────────────────────────────────────

  Future<void> _reloadImages() async {
    final pid = _effectiveProductId;
    if (pid == null) return;
    try {
      final imgs = await ref
          .read(adminMediaRepositoryProvider)
          .fetchImages(pid);
      if (mounted) setState(() => _images = imgs);
    } catch (_) {
      // Non-fatal — grid stays empty.
    }
  }

  static const _kAllowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const _kMaxBytes = 5 * 1024 * 1024; // 5 MB

  Future<void> _pickAndUpload() async {
    final pid = _effectiveProductId;
    if (pid == null) return; // should never happen — callers ensure it's set

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAllowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploadProgress = null);
    final uploadErrors = <String>[];
    final files = result.files;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      if (!mounted) break;
      setState(() => _uploadProgress = 'Uploading ${i + 1} of ${files.length}…');

      if (file.bytes == null) {
        uploadErrors.add('"${file.name}" — could not read file.');
        continue;
      }
      final ext = (file.extension ?? '').toLowerCase();
      if (!_kAllowedExtensions.contains(ext)) {
        uploadErrors.add('"${file.name}" — only jpg, png, webp allowed.');
        continue;
      }
      if (file.bytes!.length > _kMaxBytes) {
        uploadErrors.add('"${file.name}" exceeds 5 MB.');
        continue;
      }
      try {
        await ref.read(adminMediaRepositoryProvider).upload(
              productId: pid,
              bytes: file.bytes!,
              fileName: file.name,
              makePrimary: _images.isEmpty && i == 0,
            );
        await _reloadImages();
      } catch (e) {
        uploadErrors.add('"${file.name}" — ${e.toString()}');
      }
    }

    if (mounted) {
      setState(() => _uploadProgress = null);
      if (uploadErrors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(uploadErrors.join('\n')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Auto-save then upload (new product flow) ──────────────────────────

  /// Called when the user clicks "Upload images" on a brand-new product.
  ///
  /// 1. Validates the required draft fields (name, category, SKU, price).
  /// 2. Creates the product record silently so we have a product id.
  /// 3. Stores the id in [_pendingProductId] — the page stays on the new-product
  ///    URL so the rest of the form remains editable.
  /// 4. Immediately opens the file picker via [_pickAndUpload].
  ///
  /// The next time the user hits "Save draft" or "Publish", [_saveDraft] /
  /// [_publish] will detect the pending id via [_buildDraft] (which reads
  /// [widget.productId] for the DB upsert key) — but since the product is
  /// already created we update it and then navigate to edit mode as normal.
  Future<void> _autoSaveAndUpload() async {
    // Clear any stale errors.
    setState(() {
      _serverError = null;
      _publishErrors = [];
      _validateRequired = false;
    });

    if (_hasBaseErrors()) return;

    final draft = _buildDraft();
    final baseErrors = draft.validateForDraft();
    if (baseErrors.isNotEmpty) {
      setState(() => _serverError = baseErrors.first);
      return;
    }

    setState(() => _saving = true);
    try {
      final created =
          await ref.read(adminProductRepositoryProvider).create(draft);
      if (!mounted) return;
      // Store the id locally — do NOT navigate yet.
      setState(() => _pendingProductId = created.id);
    } catch (e) {
      if (mounted) setState(() => _serverError = _errorMessage(e));
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    // Product exists now — open the file picker.
    await _pickAndUpload();

    // After upload, switch to proper edit mode so the URL reflects the id
    // and the page reloads with the full edit UI.
    if (mounted && _pendingProductId != null) {
      context.replace('/admin/products/$_pendingProductId/edit');
    }
  }

  // ── Inline validation ─────────────────────────────────────────────────

  void _validatePriceFields() {
    final price = double.tryParse(_priceCtrl.text);
    final mrp = double.tryParse(_mrpCtrl.text);
    final tax = double.tryParse(_taxCtrl.text);
    setState(() {
      _priceError = (price == null || price <= 0) ? 'Price must be > 0.' : null;
      _mrpError = (mrp != null && price != null && mrp < price)
          ? 'MRP must be ≥ price.'
          : null;
      _taxError =
          (tax == null || tax < 0 || tax > 100) ? 'Tax % must be 0–100.' : null;
    });
  }

  void _validateSku() {
    final sku = _skuCtrl.text.toUpperCase();
    setState(() {
      _skuError = RegExp(r'^[A-Z0-9\-]{3,40}$').hasMatch(sku)
          ? null
          : 'SKU: 3–40 uppercase letters, digits, or hyphens.';
    });
  }

  bool _hasBaseErrors() {
    _validatePriceFields();
    _validateSku();
    return _priceError != null ||
        _mrpError != null ||
        _taxError != null ||
        _skuError != null;
  }

  // ── Build draft ───────────────────────────────────────────────────────

  ProductDraft _buildDraft() {
    return ProductDraft(
      id: _isEdit ? widget.productId : null,
      name: _nameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      sku: _skuCtrl.text.toUpperCase().trim(),
      categoryId: _categoryId ?? '',
      price: double.tryParse(_priceCtrl.text) ?? 0,
      mrp: double.tryParse(_mrpCtrl.text) ?? 0,
      taxPercent: double.tryParse(_taxCtrl.text) ?? 0,
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      initialQuantity: int.tryParse(_qtyCtrl.text) ?? 0,
      attributeValues: attributeInputsFromMap(_attrValues, _categoryAttributes),
    );
  }

  // ── Save draft ────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    setState(() {
      _serverError = null;
      _publishErrors = [];
      _validateRequired = false;
    });

    if (_hasBaseErrors()) return;

    final draft = _buildDraft();
    final baseErrors = draft.validateForDraft();
    if (baseErrors.isNotEmpty) {
      setState(() => _serverError = baseErrors.first);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ref.read(adminProductRepositoryProvider).update(draft);
      } else {
        final created =
            await ref.read(adminProductRepositoryProvider).create(draft);
        if (!mounted) return;
        // Stay on page in edit mode after first save.
        context.replace('/admin/products/${created.id}/edit');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved')));
    } catch (e) {
      if (mounted) setState(() => _serverError = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Publish ───────────────────────────────────────────────────────────

  Future<void> _publish() async {
    setState(() {
      _serverError = null;
      _validateRequired = true;
    });

    if (_hasBaseErrors()) return;

    final draft = _buildDraft();
    final requiredIds = _categoryAttributes
        .where((a) => a.isRequired)
        .map((a) => a.id)
        .toList();
    final idToName = {for (final a in _categoryAttributes) a.id: a.name};
    final errors = draft.validateForPublish(requiredIds, idToName);
    if (errors.isNotEmpty) {
      setState(() => _publishErrors = errors);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ref.read(adminProductRepositoryProvider).update(draft);
        await ref
            .read(adminProductRepositoryProvider)
            .publish(widget.productId!, true);
      } else {
        final created =
            await ref.read(adminProductRepositoryProvider).create(draft);
        await ref
            .read(adminProductRepositoryProvider)
            .publish(created.id, true);
        if (!mounted) return;
        context.replace('/admin/products/${created.id}/edit');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product published')));
      // Reload to reflect published state.
      _loadData();
    } catch (e) {
      if (mounted) setState(() => _serverError = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Extracts a user-readable message from any thrown value.
  String _errorMessage(Object e) {
    if (e is AppFailure) return e.message;
    return e.toString();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Product' : 'New Product';
    return AdminShell(
      title: title,
      child: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
        // ── Scrollable form body ────────────────────────────────
        Positioned.fill(
          bottom: _kFooterHeight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Publish error summary bar ──────────────────
                if (_publishErrors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _PublishErrorBar(
                      errors: _publishErrors,
                      onDismiss: () => setState(() => _publishErrors = []),
                    ),
                  ),
                _buildBasicsSection(context),
                const SizedBox(height: AppSpacing.xl),
                _buildPricingSection(context),
                const SizedBox(height: AppSpacing.xl),
                _buildAttributesSection(context),
                if (!_isEdit) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildStockSection(context),
                ],
                const SizedBox(height: AppSpacing.xl),
                _buildMediaSection(context),
                if (_serverError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _serverError!,
                    key: const Key('server_error'),
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),

        // ── Sticky footer ───────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _StickyFooter(
            saving: _saving,
            onSaveDraft: _saveDraft,
            onPublish: _publish,
            onCancel: () => context.go('/admin/products'),
          ),
        ),
      ],
    ),  // Stack
    );  // SizedBox.expand
  }

  // ── Section builders ──────────────────────────────────────────────────

  Widget _buildBasicsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Basics'),
        const SizedBox(height: AppSpacing.md),

        // Category dropdown — disabled on edit.
        // ValueKey on _categoryId forces the widget to reconstruct (and pick
        // up the new initialValue) whenever the loaded category changes.
        DropdownButtonFormField<String?>(
          key: ValueKey('category_dropdown_$_categoryId'),
          decoration: InputDecoration(
            labelText: 'Category *',
            helperText: _isEdit
                ? 'Category is locked after creation because attribute values are bound to it.'
                : null,
          ),
          initialValue: _categoryId,
          onChanged: _isEdit
              ? null
              : (v) {
                  setState(() {
                    _categoryId = v;
                    _categoryAttributes = [];
                    _attrValues = {};
                  });
                  if (v != null) _loadAttributesFor(v);
                },
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Select category')),
            ..._categories.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(_categoryPath(c)),
                )),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Name
        TextFormField(
          key: const Key('name_field'),
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Name *'),
          maxLength: 120,
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
        ),
        const SizedBox(height: AppSpacing.md),

        // SKU
        TextFormField(
          key: const Key('sku_field'),
          controller: _skuCtrl,
          decoration: InputDecoration(
            labelText: 'SKU *',
            errorText: _skuError,
          ),
          inputFormatters: [UpperCaseTextFormatter()],
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => _validateSku(),
        ),
        const SizedBox(height: AppSpacing.md),

        // Brand
        TextFormField(
          key: const Key('brand_field'),
          controller: _brandCtrl,
          decoration: const InputDecoration(labelText: 'Brand'),
          maxLength: 60,
        ),
        const SizedBox(height: AppSpacing.md),

        // Description
        TextFormField(
          key: const Key('description_field'),
          controller: _descCtrl,
          maxLines: 4,
          maxLength: 5000,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
      ],
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Pricing'),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('price_field'),
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price ₹ *',
                  errorText: _priceError,
                ),
                onChanged: (_) => _validatePriceFields(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextFormField(
                key: const Key('mrp_field'),
                controller: _mrpCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'MRP ₹',
                  errorText: _mrpError,
                ),
                onChanged: (_) => _validatePriceFields(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextFormField(
                key: const Key('tax_field'),
                controller: _taxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tax %',
                  helperText: 'Applied per product at checkout',
                  errorText: _taxError,
                ),
                onChanged: (_) => _validatePriceFields(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttributesSection(BuildContext context) {
    final catName = _categoryId != null
        ? _categories
            .where((c) => c.id == _categoryId)
            .map((c) => c.name)
            .firstOrNull
        : null;
    final heading = catName != null ? 'Attributes — $catName' : 'Attributes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: heading),
        const SizedBox(height: AppSpacing.md),
        DynamicAttributeForm(
          key: ValueKey(_categoryId ?? 'no_cat'),
          attributes: _categoryAttributes,
          values: _attrValues,
          validateRequiredOnPublish: _validateRequired,
          onChanged: (v) => setState(() => _attrValues = v),
        ),
      ],
    );
  }

  Widget _buildStockSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Stock'),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 200,
          child: TextFormField(
            key: const Key('initial_qty_field'),
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Initial quantity',
              helperText: 'Can be adjusted later via Inventory.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection(BuildContext context) {
    final mediaRepo = ref.read(adminMediaRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Media'),
        const SizedBox(height: AppSpacing.md),

        // ── New product: upload button (auto-saves draft first) ───────
        if (!_isEdit) ...[
          Row(
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  key: const Key('upload_images_button'),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload images'),
                  onPressed: (_saving || _uploadProgress != null)
                      ? null
                      : _autoSaveAndUpload,
                ),
              ),
              if (_saving || _uploadProgress != null) ...[
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    _uploadProgress ?? 'Saving draft…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Accepted: jpg, png, webp — max 5 MB each. The draft will be saved automatically.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],

        // ── Edit product: inline upload + thumbnail grid ───────────────
        if (_isEdit) ...[
          // Upload button row
          Row(
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  key: const Key('upload_images_button'),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload images'),
                  onPressed: _uploadProgress != null ? null : _pickAndUpload,
                ),
              ),
              if (_uploadProgress != null) ...[
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(_uploadProgress!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Accepted: jpg, png, webp — max 5 MB each.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          // Thumbnail grid
          if (_images.isEmpty)
            Text(
              'No images yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final img in _images)
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: img.isPrimary
                                ? AppColors.primary
                                : AppColors.outline,
                            width: img.isPrimary ? 2 : 1,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.card - 1),
                          child: Image.network(
                            mediaRepo.publicUrl(img.storagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      if (img.isPrimary)
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('Primary',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            key: const Key('manage_media_button'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Manage all images (reorder, delete, set primary)'),
            onPressed: () =>
                context.go('/admin/products/${widget.productId}/media'),
          ),
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _categoryPath(Category c) {
    if (c.parentId == null) return c.name;
    final parent = _categories.where((p) => p.id == c.parentId).firstOrNull;
    if (parent == null) return c.name;
    return '${parent.name} › ${c.name}';
  }
}

// ── Sticky footer ─────────────────────────────────────────────────────────────

class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.saving,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onCancel,
  });
  final bool saving;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    // ButtonStyle.minimumSize must be bounded (not Size(x, y) with x=double.infinity).
    const buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(64, 36)),
    );
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(children: [
          OutlinedButton(
            key: const Key('cancel_button'),
            style: buttonStyle,
            onPressed: saving ? null : onCancel,
            child: const Text('Cancel'),
          ),
          const Spacer(),
          OutlinedButton(
            key: const Key('save_draft_button'),
            style: buttonStyle,
            onPressed: saving ? null : onSaveDraft,
            child: saving ? const _SmallLoader() : const Text('Save draft'),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            key: const Key('publish_button'),
            style: buttonStyle,
            onPressed: saving ? null : onPublish,
            child: const Text('Publish'),
          ),
        ]),
      ),
    );
  }
}

// ── Publish error summary bar ─────────────────────────────────────────────────

class _PublishErrorBar extends StatelessWidget {
  const _PublishErrorBar({required this.errors, required this.onDismiss});
  final List<String> errors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('publish_error_bar'),
      color: AppColors.error.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cannot publish — fix the following:',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                for (final e in errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• $e',
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.error,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SmallLoader extends StatelessWidget {
  const _SmallLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Forces input to uppercase on every keystroke.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
