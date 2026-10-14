/// Lightweight order model used in the C13 order list.
///
/// JSON shape: orders row — id, order_number, status, total, created_at.
/// NUMERIC columns arrive as JSON strings — parsed with [num.tryParse].
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.createdAt,
  });

  final String id;
  final String orderNumber;

  /// Raw status string matching the 8-value order status enum.
  final String status;
  final double total;
  final DateTime createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      total: num.tryParse(json['total']?.toString() ?? '')?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
