import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/category.dart';
import '../../../core/theme/app_theme.dart';
import 'sub_category_sheet.dart';

// ── Icon fallback map ─────────────────────────────────────────────────────────

/// Maps common agri category keywords → an icon used as fallback when no
/// image is available.  Comparison is case-insensitive substring matching.
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

/// Fallback gradient pairs (start → end) cycling through categories.
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

// ── Public widget ─────────────────────────────────────────────────────────────

/// Renders the category list as a 2-column grid of image cards.
/// Root categories get full cards; tapping navigates to /categories/:id.
/// Categories with children show a small sub-count badge.
class CategoryGridView extends StatelessWidget {
  const CategoryGridView({super.key, required this.roots});

  final List<CategoryTreeNode> roots;

  @override
  Widget build(BuildContext context) {
    if (roots.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.95,
      ),
      itemCount: roots.length,
      itemBuilder: (context, index) => _CategoryCard(
        node: roots[index],
        colorIndex: index,
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.node, required this.colorIndex});

  final CategoryTreeNode node;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final cat = node.category;
    final subCount = node.children.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (node.isLeaf) {
            // No sub-categories → go straight to products filtered by this category.
            context.push('/categories/${cat.id}');
          } else {
            // Has sub-categories → slide up the selection sheet.
            showSubCategorySheet(context, node);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            color: AppColors.surface,
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Background: image or gradient fallback ──────────
                _Background(
                  imagePath: cat.imagePath,
                  categoryName: cat.name,
                  colorIndex: colorIndex,
                ),

                // ── Bottom gradient overlay ─────────────────────────
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.4, 1.0],
                        colors: [
                          Colors.transparent,
                          Color(0xCC000000),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Sub-category badge (top-right) ──────────────────
                if (subCount > 0)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _SubBadge(count: subCount),
                  ),

                // ── Category name label (bottom) ────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Text(
                      cat.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Color(0x88000000),
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Background: image or gradient ─────────────────────────────────────────────

class _Background extends StatelessWidget {
  const _Background({
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
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _GradientFallback(
          categoryName: categoryName,
          colorIndex: colorIndex,
          showIcon: false,
        ),
        errorWidget: (_, __, ___) => _GradientFallback(
          categoryName: categoryName,
          colorIndex: colorIndex,
        ),
      );
    }
    return _GradientFallback(
      categoryName: categoryName,
      colorIndex: colorIndex,
    );
  }
}

// ── Gradient fallback ─────────────────────────────────────────────────────────

class _GradientFallback extends StatelessWidget {
  const _GradientFallback({
    required this.categoryName,
    required this.colorIndex,
    this.showIcon = true,
  });

  final String categoryName;
  final int colorIndex;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(colorIndex);
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
                _iconFor(categoryName),
                size: 52,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── Sub-category count badge ──────────────────────────────────────────────────

class _SubBadge extends StatelessWidget {
  const _SubBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, color: Colors.white, size: 12),
        ],
      ),
    );
  }
}
