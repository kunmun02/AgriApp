import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_media_repository.dart';
import '../data/admin_product_repository.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kAllowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
const _kMaxBytes = 5 * 1024 * 1024; // 5 MB

// ── Page ──────────────────────────────────────────────────────────────────────

/// A09 — Media manager (`/admin/products/:productId/media`)
class MediaManagerPage extends ConsumerStatefulWidget {
  const MediaManagerPage({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<MediaManagerPage> createState() => _MediaManagerPageState();
}

class _MediaManagerPageState extends ConsumerState<MediaManagerPage> {
  List<ProductImage> _images = [];
  bool _loading = true;
  String? _error;

  // Progress text shown during multi-upload ("Uploading 2 of 3…").
  String? _uploadProgress;

  // Per-file errors from the last upload batch.
  final List<String> _uploadErrors = [];

  String? _productName;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final imgs = await ref
          .read(adminMediaRepositoryProvider)
          .fetchImages(widget.productId);
      // Also fetch product name for header.
      if (_productName == null) {
        try {
          final detail = await ref
              .read(adminProductRepositoryProvider)
              .details(widget.productId);
          if (mounted) _productName = detail.name;
        } catch (_) {}
      }
      if (mounted) setState(() => _images = imgs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAllowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _uploadErrors.clear();
      _uploadProgress = null;
    });

    final files = result.files;
    for (var i = 0; i < files.length; i++) {
      if (!mounted) break;
      final file = files[i];
      setState(
          () => _uploadProgress = 'Uploading ${i + 1} of ${files.length}…');

      if (file.bytes == null) {
        _uploadErrors.add('"${file.name}" — could not read file.');
        continue;
      }
      final ext = (file.extension ?? '').toLowerCase();
      if (!_kAllowedExtensions.contains(ext)) {
        _uploadErrors
            .add('"${file.name}" — only jpg, png, webp images are allowed.');
        continue;
      }
      if (file.bytes!.length > _kMaxBytes) {
        _uploadErrors.add('"${file.name}" exceeds 5 MB.');
        continue;
      }

      try {
        await ref.read(adminMediaRepositoryProvider).upload(
              productId: widget.productId,
              bytes: file.bytes!,
              fileName: file.name,
              makePrimary: _images.isEmpty && i == 0,
            );
        // Reload so we see the new image immediately.
        await _reloadImages();
      } catch (e) {
        _uploadErrors.add('"${file.name}" — ${e.toString()}');
      }
    }

    if (mounted) {
      setState(() => _uploadProgress = null);
      if (_uploadErrors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_uploadErrors.join('\n')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _reloadImages() async {
    final imgs = await ref
        .read(adminMediaRepositoryProvider)
        .fetchImages(widget.productId);
    if (mounted) setState(() => _images = imgs);
  }

  // ── Set primary ───────────────────────────────────────────────────────

  Future<void> _setPrimary(ProductImage img) async {
    try {
      await ref.read(adminMediaRepositoryProvider).setPrimary(
            productId: widget.productId,
            imageId: img.id,
          );
      await _reloadImages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // ── Move left / right ─────────────────────────────────────────────────

  Future<void> _move(int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _images.length) return;

    final updated = List<ProductImage>.from(_images);
    final tmp = updated[index];
    updated[index] = updated[newIndex];
    updated[newIndex] = tmp;

    final orderedIds = updated.map((i) => i.id).toList();
    try {
      await ref
          .read(adminMediaRepositoryProvider)
          .reorder(widget.productId, orderedIds);
      await _reloadImages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────

  Future<void> _delete(ProductImage img) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete image?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    try {
      await ref.read(adminMediaRepositoryProvider).delete(img);
      await _reloadImages();

      // If deleted image was primary, promote next (first remaining).
      final current = await ref
          .read(adminMediaRepositoryProvider)
          .fetchImages(widget.productId);
      if (current.isNotEmpty && !current.any((i) => i.isPrimary)) {
        await ref.read(adminMediaRepositoryProvider).setPrimary(
              productId: widget.productId,
              imageId: current.first.id,
            );
      }
      await _reloadImages();
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
    final title =
        _productName != null ? 'Media — $_productName' : 'Media Manager';

    return AdminShell(
      title: title,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _loadImages)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to editor'),
              onPressed: () =>
                  context.go('/admin/products/${widget.productId}/edit'),
            ),
            const Spacer(),
            if (_uploadProgress != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Text(_uploadProgress!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ElevatedButton.icon(
              key: const Key('upload_images_button'),
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Upload images'),
              onPressed: _uploadProgress != null ? null : _pickAndUpload,
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The first image is the primary image shown to customers.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Image grid
          if (_images.isEmpty)
            const _EmptyState()
          else
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (var i = 0; i < _images.length; i++)
                  _ImageTile(
                    image: _images[i],
                    imageUrl: ref
                        .read(adminMediaRepositoryProvider)
                        .publicUrl(_images[i].storagePath),
                    index: i,
                    total: _images.length,
                    onSetPrimary: () => _setPrimary(_images[i]),
                    onMoveLeft: i > 0 ? () => _move(i, -1) : null,
                    onMoveRight:
                        i < _images.length - 1 ? () => _move(i, 1) : null,
                    onDelete: () => _delete(_images[i]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Image tile ────────────────────────────────────────────────────────────────

class _ImageTile extends StatefulWidget {
  const _ImageTile({
    required this.image,
    required this.imageUrl,
    required this.index,
    required this.total,
    required this.onSetPrimary,
    required this.onDelete,
    this.onMoveLeft,
    this.onMoveRight,
  });
  final ProductImage image;
  final String imageUrl;
  final int index;
  final int total;
  final VoidCallback onSetPrimary;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final VoidCallback onDelete;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(
            color:
                widget.image.isPrimary ? AppColors.primary : AppColors.outline,
            width: widget.image.isPrimary ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textSecondary),
                ),
              ),

              // Primary badge
              if (widget.image.isPrimary)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    key: const Key('primary_badge'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Primary',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

              // Hover overlay with actions
              if (_hovered)
                Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!widget.image.isPrimary)
                        _OverlayButton(
                          key: const Key('set_primary_button'),
                          label: 'Set primary',
                          onTap: widget.onSetPrimary,
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _OverlayIconButton(
                            icon: Icons.arrow_back,
                            tooltip: 'Move left',
                            onTap: widget.onMoveLeft,
                          ),
                          _OverlayIconButton(
                            icon: Icons.arrow_forward,
                            tooltip: 'Move right',
                            onTap: widget.onMoveRight,
                          ),
                        ],
                      ),
                      _OverlayIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete',
                        onTap: widget.onDelete,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    super.key,
    required this.label,
    required this.onTap,
  });
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon:
            Icon(icon, color: onTap != null ? color : Colors.white38, size: 20),
        onPressed: onTap,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 48, color: AppColors.textSecondary),
          SizedBox(height: AppSpacing.md),
          Text('No images yet. Upload some above.'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(error),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
