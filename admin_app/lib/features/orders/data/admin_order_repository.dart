import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';

/// Minimal Paginated wrapper used across admin repositories.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  bool get hasMore => (page * pageSize) < total;
}

// ── Order summary model ───────────────────────────────────────────────────────

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.itemsCount,
    required this.customerName,
    required this.createdAt,
  });
  final String id;
  final String orderNumber;
  final String status;
  final double total;
  final int itemsCount;
  final String customerName;
  final DateTime createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final items = json['order_items'] as List?;
    // profiles join uses 'full_name' (migration 021 FK required by PostgREST).
    // Falls back to a short user_id prefix when the join is absent (e.g. on
    // the customer details page where the join is skipped intentionally).
    final profile = json['profiles'] as Map<String, dynamic>?;
    final userId = json['user_id'] as String? ?? '';
    final fallbackName = userId.length >= 8 ? 'User …${userId.substring(userId.length - 6)}' : userId;
    return OrderSummary(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      total: double.tryParse(json['total'].toString()) ?? 0,
      itemsCount: items?.length ?? 0,
      customerName: (profile?['full_name'] as String?)?.trim().isNotEmpty == true
          ? profile!['full_name'] as String
          : fallbackName,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

// ── Order detail models ───────────────────────────────────────────────────────

class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
  });
  final String userId;
  final String name;
  final String email;
  final String phone;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        userId: json['id'] as String? ?? '',
        name: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productName,
    required this.skuSnapshot,
    required this.unitPrice,
    required this.quantity,
    this.productId,
  });
  final String id;
  final String productName;
  final String skuSnapshot;
  final double unitPrice;
  final int quantity;
  final String? productId; // null → deleted product

  double get lineTotal => unitPrice * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        productName:
            json['product_name_snapshot'] as String? ?? '(deleted product)',
        skuSnapshot: json['sku_snapshot'] as String? ?? '',
        unitPrice: double.tryParse(json['unit_price'].toString()) ?? 0,
        quantity: json['quantity'] as int? ?? 0,
        productId: json['product_id'] as String?,
      );
}

class OrderPayment {
  const OrderPayment({
    required this.method,
    required this.status,
    required this.amount,
    required this.updatedAt,
  });
  final String method;
  final String status;
  final double amount;
  final DateTime updatedAt;

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        method: json['method'] as String? ?? 'COD',
        status: json['status'] as String? ?? 'PENDING',
        amount: double.tryParse(json['amount'].toString()) ?? 0,
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class ShippingAddress {
  const ShippingAddress({
    required this.recipientName,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
  });
  final String recipientName;
  final String phone;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String postalCode;

  factory ShippingAddress.fromJson(Map<String, dynamic> json) =>
      ShippingAddress(
        recipientName: json['recipient_name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        line1: json['line1'] as String? ?? '',
        line2: json['line2'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
      );
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.payment,
    required this.customer,
    required this.shippingAddress,
    this.cancelReason,
  });
  final String id;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double total;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;
  final OrderPayment payment;
  final CustomerProfile customer;
  final ShippingAddress shippingAddress;
  final String? cancelReason;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    // payments has a UNIQUE FK on order_id → PostgREST returns it as a single
    // object (Map), not a List.
    final paymentRaw = json['payments'];
    final paymentJson = paymentRaw is Map<String, dynamic>
        ? paymentRaw
        : (paymentRaw is List && paymentRaw.isNotEmpty)
            ? paymentRaw.first as Map<String, dynamic>
            : <String, dynamic>{};
    final addrJson = json['shipping_snapshot'] as Map<String, dynamic>? ?? {};
    final itemsList = json['order_items'] as List? ?? [];

    return OrderDetail(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      deliveryFee:
          double.tryParse(json['delivery_charge']?.toString() ?? '0') ?? 0,
      tax: double.tryParse(json['tax']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: itemsList
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      payment: OrderPayment.fromJson(paymentJson),
      customer: CustomerProfile.fromJson(profile),
      shippingAddress: ShippingAddress.fromJson(addrJson),
      cancelReason: json['cancel_reason'] as String?,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final adminOrderRepositoryProvider = Provider<AdminOrderRepository>((ref) {
  return AdminOrderRepository(ref.read(supabaseClientProvider));
});

class AdminOrderRepository {
  AdminOrderRepository(this._client);
  final SupabaseClient _client;

  // ── List ──────────────────────────────────────────────────────────────

  Future<Paginated<OrderSummary>> list({
    String? status,
    String? query,
    required int page,
  }) async {
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      var filterQ = _client.from('orders').select(
          'id, order_number, status, total, created_at, user_id, profiles(full_name), order_items(id)');

      if (status != null) filterQ = filterQ.eq('status', status);
      if (query != null && query.trim().isNotEmpty) {
        filterQ = filterQ.eq('order_number', query.trim());
      }

      final res = await filterQ
          .order('created_at', ascending: false)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      return Paginated(
        items: (res.data as List)
            .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: res.count,
        page: page,
        pageSize: pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Counts for A02 KPI ────────────────────────────────────────────────

  Future<int> countOrdersCreatedToday() async {
    try {
      final startOfDay = DateTime.utc(
        DateTime.now().toUtc().year,
        DateTime.now().toUtc().month,
        DateTime.now().toUtc().day,
      ).toIso8601String();

      final res = await _client
          .from('orders')
          .select('id')
          .gte('created_at', startOfDay)
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  Future<int> countNewOrders() async {
    try {
      final res = await _client
          .from('orders')
          .select('id')
          .eq('status', 'NEW')
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Details ───────────────────────────────────────────────────────────

  Future<OrderDetail> details(String orderId) async {
    try {
      final res = await _client
          .from('orders')
          .select(
              'id, order_number, status, subtotal, delivery_charge, tax, total, created_at, updated_at, cancel_reason, shipping_snapshot, profiles(id, full_name, email, phone), payments(method, status, amount, updated_at), order_items(id, product_id, product_name_snapshot, sku_snapshot, unit_price, quantity)')
          .eq('id', orderId)
          .single();
      return OrderDetail.fromJson(res);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Change status ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> changeStatus({
    required String orderId,
    required String target,
    String? reason,
  }) async {
    try {
      final result = await _client.rpc('change_order_status', params: {
        'p_order_id': orderId,
        'p_target_status': target,
        if (reason != null) 'p_reason': reason,
      });
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
