import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../orders/data/admin_order_repository.dart';

// ── Inventory row model ───────────────────────────────────────────────────────

class InventoryRow {
  const InventoryRow({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.reservedQuantity,
    required this.minStockLevel,
    required this.updatedAt,
  });
  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final int reservedQuantity;
  final int minStockLevel;
  final DateTime updatedAt;

  bool get isLowStock => quantity <= minStockLevel;

  factory InventoryRow.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>? ?? {};
    return InventoryRow(
      productId: json['product_id'] as String,
      productName: product['name'] as String? ?? '',
      sku: product['sku'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      reservedQuantity: json['reserved_quantity'] as int? ?? 0,
      minStockLevel: json['min_stock_level'] as int? ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

// ── Inventory transaction model ───────────────────────────────────────────────

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.transactionType,
    required this.quantityDelta,
    required this.reason,
    required this.createdAt,
    this.createdByEmail,
  });
  final String id;
  final String transactionType;
  final int quantityDelta;
  final String reason;
  final DateTime createdAt;
  final String? createdByEmail;

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return InventoryTransaction(
      id: json['id'] as String,
      transactionType: json['transaction_type'] as String,
      quantityDelta: json['quantity_delta'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdByEmail: profile?['email'] as String?,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final adminInventoryRepositoryProvider =
    Provider<AdminInventoryRepository>((ref) {
  return AdminInventoryRepository(ref.read(supabaseClientProvider));
});

class AdminInventoryRepository {
  AdminInventoryRepository(this._client);
  final SupabaseClient _client;

  /// Returns a page of inventory rows.
  /// [lowStockOnly] is a client-side filter applied after fetching the page.
  /// [query] filters by product name or SKU (case-insensitive).
  Future<Paginated<InventoryRow>> list({
    String? query,
    bool lowStockOnly = false,
    required int page,
  }) async {
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      var q = _client.from('inventory').select(
          'product_id, quantity, reserved_quantity, min_stock_level, updated_at, products(name, sku)');

      if (query != null && query.trim().isNotEmpty) {
        final escaped = query.trim().replaceAll('%', r'\%');
        q = q.or(
            'products.name.ilike.%$escaped%, products.sku.ilike.%$escaped%');
      }

      final res = await q
          .order('quantity', ascending: true)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      var rows = (res.data as List)
          .map((e) => InventoryRow.fromJson(e as Map<String, dynamic>))
          .toList();

      if (lowStockOnly) {
        rows = rows.where((r) => r.isLowStock).toList();
      }

      return Paginated(
        items: rows,
        total: res.count,
        page: page,
        pageSize: pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Calls adjust_inventory RPC.
  /// [transactionType]: 'RESTOCK' maps to 'PURCHASE'; 'CORRECTION' maps to 'ADJUSTMENT'.
  Future<Map<String, dynamic>> adjust({
    required String productId,
    required int delta,
    required String transactionType,
    required String reason,
  }) async {
    try {
      // Map UI labels to RPC-accepted enum values.
      final rpcType = transactionType == 'RESTOCK' ? 'PURCHASE' : 'ADJUSTMENT';
      final result = await _client.rpc('adjust_inventory', params: {
        'p_product_id': productId,
        'p_delta': delta,
        'p_transaction_type': rpcType,
        'p_reason': reason,
      });
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Returns the last [limit] inventory transactions for [productId].
  Future<List<InventoryTransaction>> transactions(
    String productId, {
    int limit = 50,
  }) async {
    try {
      final res = await _client
          .from('inventory_transactions')
          .select(
              'id, transaction_type, quantity_delta, reason, created_at, profiles(email)')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((e) => InventoryTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
