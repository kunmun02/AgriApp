import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/app_settings.dart';

/// Riverpod provider — injected with the Supabase client.
final adminSettingsRepositoryProvider =
    Provider<AdminSettingsRepository>((ref) {
  return AdminSettingsRepository(ref.read(supabaseClientProvider));
});

/// Handles read/write access to the single-row `app_settings` table.
///
/// All methods map raw PostgREST exceptions to [AppFailure] via [ErrorMapper].
class AdminSettingsRepository {
  AdminSettingsRepository(this._client);

  final SupabaseClient _client;

  /// Fetches the single `app_settings` row.
  Future<AppSettings> fetch() async {
    try {
      final data =
          await _client.from('app_settings').select().limit(1).single();
      return AppSettings.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Persists [deliveryCharge] and [freeDeliveryThreshold] to the DB.
  ///
  /// Uses UPDATE … RETURNING * so the saved values are reflected in the
  /// returned [AppSettings] (avoids a separate fetch round-trip).
  Future<AppSettings> update({
    required double deliveryCharge,
    required double freeDeliveryThreshold,
  }) async {
    try {
      final data = await _client
          .from('app_settings')
          .update({
            'delivery_charge': deliveryCharge,
            'free_delivery_threshold': freeDeliveryThreshold,
          })
          .select()
          .single();
      return AppSettings.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
