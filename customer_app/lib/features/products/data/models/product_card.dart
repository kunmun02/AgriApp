/// Product card model — used in listing, search results, and home popular grid.
///
/// JSON shape: products row with embedded product_images and v_product_availability.
/// NUMERIC columns arrive as JSON strings — parsed with [num.tryParse].
class ProductCard {
  const ProductCard({
    required this.id,
    required this.name,
    required this.slug,
    required this.sku,
    this.brand,
    required this.price,
    this.mrp,
    required this.taxPercent,
    this.primaryImagePath,
    required this.inStock,
  });

  final String id;
  final String name;
  final String slug;
  final String sku;
  final String? brand;
  final double price;
  final double? mrp;
  final double taxPercent;
  final String? primaryImagePath;
  final bool inStock;

  factory ProductCard.fromJson(Map<String, dynamic> json) {
    // Resolve primary image from embedded product_images.
    // Supabase may return a single map instead of a list for one-row embeds.
    String? primaryImagePath;
    final imagesRaw = json['product_images'];
    final imagesList = imagesRaw is List
        ? imagesRaw
        : (imagesRaw is Map<String, dynamic> ? [imagesRaw] : <dynamic>[]);
    if (imagesList.isNotEmpty) {
      // Pick the image with the smallest display_order.
      final sorted = List<Map<String, dynamic>>.from(imagesList)
        ..sort((a, b) => ((a['display_order'] as num?) ?? 0)
            .compareTo((b['display_order'] as num?) ?? 0));
      primaryImagePath = sorted.first['storage_path'] as String?;
    }

    // Resolve in_stock from embedded v_product_availability array.
    bool inStock = false;
    final avail = json['v_product_availability'];
    if (avail is List && avail.isNotEmpty) {
      inStock =
          (avail.first as Map<String, dynamic>)['in_stock'] as bool? ?? false;
    } else if (avail is Map<String, dynamic>) {
      inStock = avail['in_stock'] as bool? ?? false;
    }

    return ProductCard(
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
      primaryImagePath: primaryImagePath,
      inStock: inStock,
    );
  }
}
