/// Flat category row from Supabase.
class Category {
  const Category({
    required this.id,
    this.parentId,
    required this.name,
    required this.slug,
    this.description,
    this.imagePath,
    required this.displayOrder,
    required this.isActive,
  });

  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? description;
  final String? imagePath;
  final int displayOrder;
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        parentId: json['parent_id'] as String?,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        imagePath: json['image_path'] as String?,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// Single node in the client-side category tree.
class CategoryTreeNode {
  const CategoryTreeNode({
    required this.category,
    required this.children,
  });

  final Category category;
  final List<CategoryTreeNode> children;

  bool get isLeaf => children.isEmpty;
}

/// Builds a tree from a flat active-category list.
abstract final class CategoryTree {
  /// Returns root nodes (no parent), sorted by [Category.displayOrder].
  static List<CategoryTreeNode> build(List<Category> flat) {
    final Map<String?, List<Category>> byParent = {};
    for (final c in flat) {
      byParent.putIfAbsent(c.parentId, () => []).add(c);
    }

    // Sort each group by displayOrder.
    for (final list in byParent.values) {
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    List<CategoryTreeNode> buildChildren(String? parentId) {
      return (byParent[parentId] ?? [])
          .map((c) => CategoryTreeNode(
                category: c,
                children: buildChildren(c.id),
              ))
          .toList();
    }

    return buildChildren(null);
  }

  /// Returns all descendant ids for a given root id (inclusive of root).
  static List<String> subtreeIds(List<Category> flat, String rootId) {
    final ids = <String>[rootId];
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final c in flat) {
        if (c.parentId == parent) {
          ids.add(c.id);
          queue.add(c.id);
        }
      }
    }
    return ids;
  }
}
