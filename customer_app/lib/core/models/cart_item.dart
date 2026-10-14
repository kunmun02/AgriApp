import '../../features/products/data/models/product_card.dart';

/// A single item in the user's cart.
///
/// JSON shape: cart_items row with an embedded `product` object that contains
/// all ProductCard fields plus `is_active` and `is_published`.
///
/// An item is considered **unavailable** when its product is null, inactive,
/// or unpublished. Unavailable items are shown greyed-out and excluded from
/// totals and the checkout button.
class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    this.product,
    this.isActive = true,
    this.isPublished = true,
  });

  final String id;
  final String productId;
  final int quantity;

  /// Embedded product data. Null when the join returned nothing.
  final ProductCard? product;

  /// Raw flags from the product row — kept separately so availability
  /// can be evaluated even when [product] parsing partially fails.
  final bool isActive;
  final bool isPublished;

  /// An item is available when its product exists, is active, and is published.
  bool get isAvailable => product != null && isActive && isPublished;

  /// Line total for available items (unit price × quantity).
  double get lineTotal => isAvailable ? (product!.price * quantity) : 0;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>?;

    // Extract active/published flags directly from the embedded product object
    // (they are NOT part of the ProductCard model, which is customer-facing).
    final isActive = productJson?['is_active'] as bool? ?? true;
    final isPublished = productJson?['is_published'] as bool? ?? true;

    ProductCard? product;
    if (productJson != null) {
      // ProductCard.fromJson resolves primaryImagePath and inStock from embeds.
      try {
        product = ProductCard.fromJson(productJson);
      } catch (_) {
        product = null;
      }
    }

    return CartItem(
      id: json['id'] as String,
      productId: (productJson?['id'] as String?) ?? '',
      quantity: (json['quantity'] as num).toInt(),
      product: product,
      isActive: isActive,
      isPublished: isPublished,
    );
  }

  CartItem copyWith({
    String? id,
    String? productId,
    int? quantity,
    ProductCard? product,
    bool? isActive,
    bool? isPublished,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      product: product ?? this.product,
      isActive: isActive ?? this.isActive,
      isPublished: isPublished ?? this.isPublished,
    );
  }
}
