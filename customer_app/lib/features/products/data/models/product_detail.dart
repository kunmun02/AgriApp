import 'product_card.dart';

// ── ProductImage ─────────────────────────────────────────────────────────────

/// A single image belonging to a product.
class ProductImage {
  const ProductImage({
    required this.id,
    required this.storagePath,
    required this.isPrimary,
    required this.displayOrder,
  });

  final String id;
  final String storagePath;
  final bool isPrimary;
  final int displayOrder;

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        id: json['id'] as String,
        storagePath: json['storage_path'] as String,
        isPrimary: json['is_primary'] as bool? ?? false,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      );
}

// ── AttributeType ────────────────────────────────────────────────────────────

enum AttributeType { text, number, boolean, select }

AttributeType _parseAttributeType(String? raw) => switch (raw) {
      'number' => AttributeType.number,
      'boolean' => AttributeType.boolean,
      'select' => AttributeType.select,
      _ => AttributeType.text,
    };

// ── ProductAttributeValue ────────────────────────────────────────────────────

/// A single product attribute value joined with its category_attribute metadata.
class ProductAttributeValue {
  const ProductAttributeValue({
    required this.categoryAttributeId,
    required this.name,
    required this.attributeKey,
    required this.dataType,
    required this.options,
    required this.displayOrder,
    this.valueText,
    this.valueNumber,
    this.valueBoolean,
    this.valueJson,
  });

  final String categoryAttributeId;
  final String name;
  final String attributeKey;
  final AttributeType dataType;
  final List<String> options;
  final int displayOrder;
  final String? valueText;
  final double? valueNumber;
  final bool? valueBoolean;
  final dynamic valueJson;

  /// Human-readable value, typed per [dataType].
  ///
  /// - BOOLEAN → "Yes" / "No"
  /// - NUMBER  → plain number string (no decimal when whole)
  /// - SELECT  → uses value_text (the option key/value stored)
  /// - TEXT    → value_text verbatim
  String get displayValue {
    switch (dataType) {
      case AttributeType.boolean:
        return (valueBoolean ?? false) ? 'Yes' : 'No';
      case AttributeType.number:
        if (valueNumber == null) return '—';
        final n = valueNumber!;
        return n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
      case AttributeType.select:
      case AttributeType.text:
        return valueText ?? '—';
    }
  }

  factory ProductAttributeValue.fromJson(Map<String, dynamic> json) {
    final attr = json['attribute'] as Map<String, dynamic>? ?? {};
    final opts = attr['options'];
    final options =
        opts is List ? opts.map((e) => e.toString()).toList() : <String>[];

    return ProductAttributeValue(
      categoryAttributeId: json['category_attribute_id'] as String,
      name: attr['name'] as String? ?? '',
      attributeKey: attr['attribute_key'] as String? ?? '',
      dataType: _parseAttributeType(attr['data_type'] as String?),
      options: options,
      displayOrder: (attr['display_order'] as num?)?.toInt() ?? 0,
      valueText: json['value_text'] as String?,
      valueNumber: json['value_number'] != null
          ? (json['value_number'] as num).toDouble()
          : null,
      valueBoolean: json['value_boolean'] as bool?,
      valueJson: json['value_json'],
    );
  }
}

// ── ProductDetail ────────────────────────────────────────────────────────────

/// Full product detail — used only in C07.
///
/// Extends [ProductCard] fields with description, category metadata,
/// image list, and attribute values.
class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.sku,
    this.brand,
    required this.price,
    this.mrp,
    required this.taxPercent,
    this.description,
    required this.categoryId,
    required this.categoryName,
    required this.isActive,
    required this.isPublished,
    required this.inStock,
    required this.images,
    required this.attributes,
  });

  final String id;
  final String name;
  final String slug;
  final String sku;
  final String? brand;
  final double price;
  final double? mrp;
  final double taxPercent;
  final String? description;
  final String categoryId;
  final String categoryName;
  final bool isActive;
  final bool isPublished;
  final bool inStock;

  /// Images sorted by display_order ascending.
  final List<ProductImage> images;

  /// Attribute values sorted by attribute.display_order ascending.
  final List<ProductAttributeValue> attributes;

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    // Parse images, sorted by display_order.
    // Supabase may return a single map instead of a list for one-row embeds.
    final imagesRaw = json['product_images'];
    final rawImages = imagesRaw is List
        ? imagesRaw
        : (imagesRaw is Map<String, dynamic> ? [imagesRaw] : <dynamic>[]);
    final images = rawImages
        .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    // Parse attributes, sorted by attribute.display_order.
    final attrsRaw = json['product_attributes'];
    final rawAttrs = attrsRaw is List
        ? attrsRaw
        : (attrsRaw is Map<String, dynamic> ? [attrsRaw] : <dynamic>[]);
    final attributes = rawAttrs
        .map((e) => ProductAttributeValue.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    // Resolve in_stock from embedded v_product_availability.
    bool inStock = false;
    final avail = json['v_product_availability'];
    if (avail is List && avail.isNotEmpty) {
      inStock =
          (avail.first as Map<String, dynamic>)['in_stock'] as bool? ?? false;
    } else if (avail is Map<String, dynamic>) {
      inStock = avail['in_stock'] as bool? ?? false;
    }

    final category = json['category'] as Map<String, dynamic>? ?? {};

    return ProductDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      sku: json['sku'] as String,
      brand: json['brand'] as String?,
      price: num.tryParse(json['price']?.toString() ?? '')?.toDouble() ?? 0,
      mrp: json['mrp'] != null
          ? num.tryParse(json['mrp'].toString())?.toDouble()
          : null,
      taxPercent:
          num.tryParse(json['tax_percent']?.toString() ?? '')?.toDouble() ?? 0,
      description: json['description'] as String?,
      categoryId: category['id'] as String? ?? '',
      categoryName: category['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
      inStock: inStock,
      images: images,
      attributes: attributes,
    );
  }

  /// Convenience: the primary [ProductCard]-compatible object for reuse.
  ProductCard toCard() => ProductCard(
        id: id,
        name: name,
        slug: slug,
        sku: sku,
        brand: brand,
        price: price,
        mrp: mrp,
        taxPercent: taxPercent,
        primaryImagePath: images.isNotEmpty ? images.first.storagePath : null,
        inStock: inStock,
      );
}
