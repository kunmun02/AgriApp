/// Category model — maps to the `categories` table.
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
        displayOrder: json['display_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'parent_id': parentId,
        'name': name,
        'slug': slug,
        'description': description,
        'image_path': imagePath,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  Category copyWith({
    String? id,
    String? parentId,
    bool clearParentId = false,
    String? name,
    String? slug,
    String? description,
    bool clearDescription = false,
    String? imagePath,
    bool clearImagePath = false,
    int? displayOrder,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: clearDescription ? null : (description ?? this.description),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() => 'Category(id: $id, name: $name, slug: $slug)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Tree helpers ──────────────────────────────────────────────────────────────

class CategoryTreeNode {
  CategoryTreeNode({required this.category, this.level = 0});
  final Category category;
  final int level;
  final List<CategoryTreeNode> children = [];
}

/// Builds a depth-first flat list of [CategoryTreeNode] from a flat list,
/// sorted by [Category.displayOrder] at each level.
class CategoryTree {
  static List<CategoryTreeNode> build(List<Category> flat) {
    final roots = flat.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final result = <CategoryTreeNode>[];
    for (final root in roots) {
      final node = CategoryTreeNode(category: root, level: 0);
      _addChildren(node, flat);
      _flatten(node, result);
    }
    return result;
  }

  static void _addChildren(CategoryTreeNode node, List<Category> flat) {
    final children = flat.where((c) => c.parentId == node.category.id).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    for (final child in children) {
      final childNode =
          CategoryTreeNode(category: child, level: node.level + 1);
      node.children.add(childNode);
      _addChildren(childNode, flat);
    }
  }

  static void _flatten(CategoryTreeNode node, List<CategoryTreeNode> result) {
    result.add(node);
    for (final child in node.children) {
      _flatten(child, result);
    }
  }

  /// Returns ids of [root] and all its descendants.
  static Set<String> descendantIds(String rootId, List<Category> flat) {
    final result = <String>{rootId};
    bool added = true;
    while (added) {
      added = false;
      for (final c in flat) {
        if (c.parentId != null &&
            result.contains(c.parentId) &&
            !result.contains(c.id)) {
          result.add(c.id);
          added = true;
        }
      }
    }
    return result;
  }
}
