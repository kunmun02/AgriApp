import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/data/models/profile.dart';
import '../../orders/data/admin_order_repository.dart';

final adminCustomerRepositoryProvider =
    Provider<AdminCustomerRepository>((ref) {
  return AdminCustomerRepository(ref.read(supabaseClientProvider));
});

class AdminCustomerRepository {
  AdminCustomerRepository(this._client);
  final SupabaseClient _client;

  Future<Paginated<Profile>> list({
    String? query,
    required int page,
  }) async {
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      var filterQ = _client.from('profiles').select().eq('role', 'customer');

      if (query != null && query.isNotEmpty) {
        // Search on both full_name and email (spec: name/email contains).
        filterQ = filterQ.or(
          'full_name.ilike.%$query%,email.ilike.%$query%',
        );
      }

      final res = await filterQ
          .order('created_at', ascending: false)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      return Paginated(
        items: (res.data as List)
            .map((e) => Profile.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: res.count,
        page: page,
        pageSize: pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  Future<int> countCustomers() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'customer')
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  Future<Profile> details(String userId) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .eq('role', 'customer')
          .single();
      return Profile.fromJson(res);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  Future<Paginated<OrderSummary>> ordersOf(
    String userId, {
    required int page,
  }) async {
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      // Select only flat columns — no embedded joins.
      // • profiles join needs migration 021 (FK orders.user_id → profiles.id).
      // • order_items embed can interact with the user_id filter in PostgREST
      //   when the profiles FK is absent, silently returning 0 rows.
      // The customer name and order-item count are not needed on this view:
      // the customer's name is already shown in the profile card above, and
      // itemsCount defaults to 0 gracefully in OrderSummary.fromJson.
      final res = await _client
          .from('orders')
          .select('id, order_number, status, total, created_at, user_id')
          .eq('user_id', userId)
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
    } catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  Future<void> setActive(String userId, bool active) async {
    try {
      await _client
          .from('profiles')
          .update({'is_active': active}).eq('id', userId);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
