import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/order_detail.dart';
import 'models/order_summary.dart';

// ── Paginated wrapper ─────────────────────────────────────────────────────────

/// Generic page result — [items] is the current page, [hasMore] indicates
/// whether a further page may exist.
class Paginated<T> {
  const Paginated({required this.items, required this.hasMore});

  final List<T> items;

  /// True when the page was full (== [pageSize]), so there may be more.
  final bool hasMore;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.read(supabaseClientProvider)),
);

// ── Repository ────────────────────────────────────────────────────────────────

/// Page size used for order list pagination.
const _pageSize = 20;

class OrderRepository {
  OrderRepository(this._sb);

  final SupabaseClient _sb;

  /// Returns the current user's orders, newest first, page size 20.
  ///
  /// Optionally filtered by [status] (one of the 8 order status values).
  /// Throws [ApiFailure] with code AUTH_REQUIRED if not signed in.
  Future<Paginated<OrderSummary>> myOrders({
    String? status,
    required int page,
  }) async {
    try {
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) {
        throw const ApiFailure('AUTH_REQUIRED', 'Not signed in.');
      }

      final offset = page * _pageSize;

      // Build filter query before applying ordering and range transforms.
      var filterQuery = _sb
          .from('orders')
          .select('id,order_number,status,total,created_at')
          .eq('user_id', userId);

      if (status != null) {
        filterQuery = filterQuery.eq('status', status);
      }

      final rows = await filterQuery
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);
      final list = (rows as List)
          .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
          .toList();

      return Paginated(
        items: list,
        hasMore: list.length == _pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Returns the full detail for a single order owned by the current user.
  ///
  /// Embeds order_items and payments.
  /// Returns [ApiFailure] NOT_FOUND when 0 rows match — this happens for
  /// non-existent ids AND cross-user access (RLS filters them out equally).
  Future<OrderDetail> orderDetails(String orderId) async {
    try {
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) {
        throw const ApiFailure('AUTH_REQUIRED', 'Not signed in.');
      }

      final rows = await _sb
          .from('orders')
          .select(
            'id,order_number,status,total,created_at,'
            'subtotal,delivery_charge,tax,cancel_reason,shipping_snapshot,'
            'items:order_items(id,product_name_snapshot,sku_snapshot,quantity,unit_price,line_total,line_tax),'
            'payment:payments(method,status,amount)',
          )
          .eq('id', orderId)
          .eq('user_id', userId)
          .limit(1);

      final list = rows as List;
      if (list.isEmpty) {
        throw const ApiFailure(
          'NOT_FOUND',
          'Order not found.',
        );
      }

      return OrderDetail.fromJson(list.first as Map<String, dynamic>);
    } on AppFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
