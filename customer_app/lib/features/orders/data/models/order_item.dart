/// A single line-item inside an order (snapshot at time of purchase).
///
/// JSON shape: order_items row — name, sku, quantity, unit_price,
/// line_total, line_tax.
/// NUMERIC columns arrive as JSON strings — parsed with [num.tryParse].
class OrderItem {
  const OrderItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.lineTax,
  });

  final String id;
  final String name;
  final String sku;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final double lineTax;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      name: json['product_name_snapshot'] as String? ?? '',
      sku: json['sku_snapshot'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice:
          num.tryParse(json['unit_price']?.toString() ?? '')?.toDouble() ?? 0.0,
      lineTotal:
          num.tryParse(json['line_total']?.toString() ?? '')?.toDouble() ?? 0.0,
      lineTax:
          num.tryParse(json['line_tax']?.toString() ?? '')?.toDouble() ?? 0.0,
    );
  }
}
