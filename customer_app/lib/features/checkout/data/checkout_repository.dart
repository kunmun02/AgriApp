import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/app_settings.dart';

final checkoutRepositoryProvider = Provider<CheckoutRepository>(
  (ref) => CheckoutRepository(ref.read(supabaseClientProvider)),
);

class CheckoutRepository {
  CheckoutRepository(this._sb);

  final SupabaseClient _sb;

  /// Fetches the single-row app_settings (delivery_charge, free_delivery_threshold).
  Future<AppSettings> fetchSettings() async {
    try {
      final row = await _sb.from('app_settings').select().single();
      return AppSettings.fromJson(row);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Calls the `create_order` RPC and returns the raw jsonb result.
  ///
  /// Returns `{"duplicate": bool, "order_id": uuid, "order_number"?: text, "total"?: numeric}`.
  /// Throws a typed [AppFailure] on any error.
  Future<Map<String, dynamic>> createOrder({
    required String addressId,
    required String idempotencyKey,
  }) async {
    try {
      final result = await _sb.rpc('create_order', params: {
        'p_address_id': addressId,
        'p_idempotency_key': idempotencyKey,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
