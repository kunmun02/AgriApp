/// Input record for a single dynamic attribute value being saved.
class ProductAttributeInput {
  const ProductAttributeInput({
    required this.categoryAttributeId,
    this.valueText,
    this.valueNumber,
    this.valueBoolean,
  });
  final String categoryAttributeId;
  final String? valueText;
  final double? valueNumber;
  final bool? valueBoolean;
}

/// Validation-bearing draft object for the product editor.
///
/// Used by both create and update paths.  [id] is null on create.
/// [initialQuantity] is only meaningful on create (A08 §Stock section).
class ProductDraft {
  const ProductDraft({
    this.id,
    required this.name,
    required this.slug,
    required this.sku,
    required this.categoryId,
    required this.price,
    required this.mrp,
    required this.taxPercent,
    this.brand,
    this.description,
    this.initialQuantity,
    this.attributeValues = const [],
  });

  final String? id;
  final String name;
  final String slug;
  final String sku;
  final String categoryId;
  final double price;
  final double mrp;
  final double taxPercent;
  final String? brand;
  final String? description;
  final int? initialQuantity;
  final List<ProductAttributeInput> attributeValues;

  ProductDraft copyWith({
    String? id,
    String? name,
    String? slug,
    String? sku,
    String? categoryId,
    double? price,
    double? mrp,
    double? taxPercent,
    String? brand,
    String? description,
    int? initialQuantity,
    List<ProductAttributeInput>? attributeValues,
  }) =>
      ProductDraft(
        id: id ?? this.id,
        name: name ?? this.name,
        slug: slug ?? this.slug,
        sku: sku ?? this.sku,
        categoryId: categoryId ?? this.categoryId,
        price: price ?? this.price,
        mrp: mrp ?? this.mrp,
        taxPercent: taxPercent ?? this.taxPercent,
        brand: brand ?? this.brand,
        description: description ?? this.description,
        initialQuantity: initialQuantity ?? this.initialQuantity,
        attributeValues: attributeValues ?? this.attributeValues,
      );

  // ── Validation ────────────────────────────────────────────────────────

  /// Returns a list of field-level error messages.
  /// These block both draft save AND publish when they apply to base fields.
  List<String> validateBase() {
    final errors = <String>[];
    if (name.trim().length < 3 || name.trim().length > 120) {
      errors.add('Name must be 3–120 characters.');
    }
    if (slug.trim().isEmpty) {
      errors.add('Slug is required.');
    }
    if (!RegExp(r'^[A-Z0-9\-]{3,40}$').hasMatch(sku)) {
      errors.add('SKU must be 3–40 uppercase letters, digits, or hyphens.');
    }
    if (categoryId.isEmpty) {
      errors.add('Category is required.');
    }
    if (price <= 0) {
      errors.add('Price must be greater than 0.');
    }
    if (mrp < price) {
      errors.add('MRP must be ≥ price.');
    }
    if (taxPercent < 0 || taxPercent > 100) {
      errors.add('Tax % must be 0–100.');
    }
    if (brand != null && brand!.length > 60) {
      errors.add('Brand must be 60 characters or fewer.');
    }
    if (description != null && description!.length > 5000) {
      errors.add('Description must be 5000 characters or fewer.');
    }
    return errors;
  }

  /// Returns missing required-attribute names.
  /// Empty list means all required attributes are filled — publish is allowed.
  List<String> missingRequiredAttributeNames(
      List<String> requiredAttributeIds, Map<String, String> idToName) {
    final provided = attributeValues.map((v) => v.categoryAttributeId).toSet();
    return requiredAttributeIds
        .where((id) => !provided.contains(id))
        .map((id) => idToName[id] ?? id)
        .toList();
  }

  /// All validation errors that block publishing.
  /// Combines base validation + required attributes.
  List<String> validateForPublish(
      List<String> requiredAttributeIds, Map<String, String> idToName) {
    return [
      ...validateBase(),
      ...missingRequiredAttributeNames(requiredAttributeIds, idToName)
          .map((n) => 'Required attribute "$n" is empty.'),
    ];
  }

  /// Draft save only needs base field validation.
  List<String> validateForDraft() => validateBase();
}
