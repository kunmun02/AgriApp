import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/category.dart';
import '../../../core/theme/app_theme.dart';

// ── Public helpers ────────────────────────────────────────────────────────────

/// Shared icon + gradient helpers (kept package-private via underscore prefix).
const _kIconMap = <String, IconData>{
  'medicine': Icons.medical_services_outlined,
  'seed': Icons.grass_outlined,
  'fertilizer': Icons.eco_outlined,
  'tool': Icons.agriculture_outlined,
  'pesticide': Icons.bug_report_outlined,
  'soil': Icons.terrain_outlined,
  'irrigation': Icons.water_drop_outlined,
  'equipment': Icons.construction_outlined,
};

const _kGradients = <List<Color>>[
  [Color(0xFF1B5E20), Color(0xFF43A047)],
  [Color(0xFF004D40), Color(0xFF26A69A)],
  [Color(0xFF1A237E), Color(0xFF3949AB)],
  [Color(0xFF4A148C), Color(0xFF7B1FA2)],
  [Color(0xFFBF360C), Color(0xFFEF6C00)],
  [Color(0xFF006064), Color(0xFF00ACC1)],
];

IconData _iconFor(String name) {
  final lower = name.toLowerCase();
  for (final entry in _kIconMap.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return Icons.category_outlined;
}

List<Color> _gradientFor(int index) =>
    _kGradients[index % _kGradients.length];

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows a modal bottom sheet listing the sub-categories of [parentNode].
/// Sub-categories without further children navigate directly to
/// `/categories/:id`; deeper parents (grandchildren) open another sheet.
void showSubCategorySheet(BuildContext context, CategoryTreeNode parentNode) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SubCategorySheet(
      parentNode: parentNode,
      // Pass the navigator from the original context so go_router works
      // correctly even though the sheet has its own route context.
      rootContext: context,
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _SubCategorySheet extends StatelessWidget {
  const _SubCategorySheet({
    required this.parentNode,
    required this.rootContext,
  });

  final CategoryTreeNode parentNode;
  final BuildContext rootContext;

  @override
  Widget build(BuildContext context) {
    final children = parentNode.children;
    final parentCat = parentNode.category;

    // Cap sheet height at 75 % of screen so it never covers the full screen.
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────────────
          const _DragHandle(),

          // ── Header ──────────────────────────────────────────────────
          _SheetHeader(
            title: parentCat.name,
            onClose: () => Navigator.of(context).pop(),
          ),

          const Divider(height: 1, color: AppColors.outline),

          // ── Sub-category grid ────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.82,
                ),
                itemCount: children.length,
                itemBuilder: (_, index) => _SubCard(
                  node: children[index],
                  colorIndex: index,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (children[index].isLeaf) {
                      // Leaf — go straight to products page.
                      rootContext.push(
                          '/categories/${children[index].category.id}');
                    } else {
                      // Has grandchildren — open another sheet.
                      showSubCategorySheet(rootContext, children[index]);
                    }
                  },
                ),
              ),
            ),
          ),

          // ── "View all …" button ──────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg +
                  MediaQuery.of(context).padding.bottom, // safe area
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text(
                  'View all ${parentCat.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  rootContext.push('/categories/${parentCat.id}');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drag handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ── Sheet header ──────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // Green accent bar
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: onClose,
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ── Sub-category card (3-column, smaller) ─────────────────────────────────────

class _SubCard extends StatelessWidget {
  const _SubCard({
    required this.node,
    required this.colorIndex,
    required this.onTap,
  });

  final CategoryTreeNode node;
  final int colorIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = node.category;
    final hasChildren = !node.isLeaf;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // ── Square image tile ──────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background
                  _SubBackground(
                    imagePath: cat.imagePath,
                    categoryName: cat.name,
                    colorIndex: colorIndex,
                  ),

                  // Subtle bottom scrim for legibility
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Color(0xAA000000),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // "Has more" chevron badge
                  if (hasChildren)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Name label below the tile ──────────────────────────────
          const SizedBox(height: 5),
          Text(
            cat.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Sub-card background ───────────────────────────────────────────────────────

class _SubBackground extends StatelessWidget {
  const _SubBackground({
    required this.imagePath,
    required this.categoryName,
    required this.colorIndex,
  });

  final String? imagePath;
  final String categoryName;
  final int colorIndex;

  String? get _publicUrl {
    if (imagePath == null || imagePath!.isEmpty) return null;
    return Supabase.instance.client.storage
        .from('category-images')
        .getPublicUrl(imagePath!);
  }

  @override
  Widget build(BuildContext context) {
    final url = _publicUrl;
    final colors = _gradientFor(colorIndex);

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _gradientBox(colors),
        errorWidget: (_, __, ___) => _gradientBox(colors, showIcon: true,
            name: categoryName),
      );
    }
    return _gradientBox(colors, showIcon: true, name: categoryName);
  }

  Widget _gradientBox(List<Color> colors,
      {bool showIcon = false, String name = ''}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: showIcon
          ? Center(
              child: Icon(
                _iconFor(name),
                size: 28,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
          : null,
    );
  }
}
