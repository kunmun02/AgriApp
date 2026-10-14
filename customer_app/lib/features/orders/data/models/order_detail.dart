import 'order_item.dart';
import 'order_summary.dart';

/// Full order detail used in the C14 screen.
///
/// Extends [OrderSummary] with embedded items, payment info, shipping
/// snapshot, and bill breakdown.
/// JSON shape:
///   orders row + items:order_items(*) + payment:payments(method,status,amount)
class OrderDetail extends OrderSummary {
  const OrderDetail({
    required super.id,
    required super.orderNumber,
    required super.status,
    required super.total,
    required super.createdAt,
    required this.items,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.shippingSnapshot,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    this.cancelReason,
  });

  final List<OrderItem> items;

  /// e.g. "Cash on Delivery"
  final String paymentMethod;

  /// e.g. "PENDING", "COLLECTED", "CANCELLED"
  final String paymentStatus;

  /// All 8 shipping address fields snapshotted at order creation.
  final ShippingSnapshot shippingSnapshot;

  final double subtotal;
  final double deliveryFee;
  final double tax;

  /// Non-null only when [status] == "CANCELLED".
  final String? cancelReason;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    // Parse items from embedded order_items array.
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // Parse payment from embedded payments object (may be list or map).
    String paymentMethod = 'Cash on Delivery';
    String paymentStatus = 'PENDING';
    final rawPayment = json['payment'];
    if (rawPayment is Map<String, dynamic>) {
      paymentMethod = rawPayment['method'] as String? ?? paymentMethod;
      paymentStatus = rawPayment['status'] as String? ?? paymentStatus;
    } else if (rawPayment is List && rawPayment.isNotEmpty) {
      final p = rawPayment.first as Map<String, dynamic>;
      paymentMethod = p['method'] as String? ?? paymentMethod;
      paymentStatus = p['status'] as String? ?? paymentStatus;
    }

    // Parse shipping snapshot from JSONB column.
    final rawSnap = json['shipping_snapshot'];
    final snapMap =
        rawSnap is Map<String, dynamic> ? rawSnap : <String, dynamic>{};
    final snapshot = ShippingSnapshot.fromJson(snapMap);

    return OrderDetail(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      total: num.tryParse(json['total']?.toString() ?? '')?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: items,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      shippingSnapshot: snapshot,
      subtotal:
          num.tryParse(json['subtotal']?.toString() ?? '')?.toDouble() ?? 0.0,
      deliveryFee:
          num.tryParse(json['delivery_charge']?.toString() ?? '')?.toDouble() ??
              0.0,
      tax: num.tryParse(json['tax']?.toString() ?? '')?.toDouble() ?? 0.0,
      cancelReason: json['cancel_reason'] as String?,
    );
  }
}

/// Snapshot of the delivery address at order creation time.
class ShippingSnapshot {
  const ShippingSnapshot({
    required this.recipientName,
    required this.phone,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  final String recipientName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  factory ShippingSnapshot.fromJson(Map<String, dynamic> json) {
    return ShippingSnapshot(
      recipientName: json['recipient_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      line1: json['line1'] as String? ?? '',
      line2: json['line2'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      country: json['country'] as String? ?? 'India',
    );
  }
}
