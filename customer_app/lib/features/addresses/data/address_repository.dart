import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/address.dart';

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.read(supabaseClientProvider)),
);

class AddressRepository {
  AddressRepository(this._sb);

  final SupabaseClient _sb;

  /// Fetches all addresses for the current user, default first.
  Future<List<Address>> fetchAddresses() async {
    try {
      final rows = await _sb
          .from('addresses')
          .select()
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Creates a new address.
  ///
  /// If [draft.isDefault] is true, clears the existing default first
  /// (two sequential ops — no transactions in PostgREST REST layer).
  Future<Address> createAddress(Address draft) async {
    // auth.currentUser is non-null when the user is signed in. If somehow
    // called unauthenticated, throw immediately with a clear message.
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      throw const ApiFailure(
          'AUTH_REQUIRED', 'Please log in to save an address.');
    }

    try {
      if (draft.isDefault) {
        await _clearDefault();
      }
      // Build payload with the real auth UID. Do not include 'id' — the DB
      // auto-generates it. The RLS policy requires user_id = auth.uid().
      final payload = draft.toJson()
        ..remove('id')
        ..['user_id'] = uid;
      final row =
          await _sb.from('addresses').insert(payload).select().single();
      return Address.fromJson(row);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Updates an existing address row.
  ///
  /// Same two-step default handling as [createAddress].
  Future<Address> updateAddress(Address draft) async {
    try {
      if (draft.isDefault) {
        await _clearDefault(exceptId: draft.id);
      }
      final row = await _sb
          .from('addresses')
          .update(draft.toJson())
          .eq('id', draft.id)
          .select()
          .single();
      return Address.fromJson(row);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Deletes an address by id.
  Future<void> deleteAddress(String id) async {
    try {
      await _sb.from('addresses').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Sets the address with [id] as the default.
  ///
  /// Clears all other defaults first (two ops).
  Future<void> setDefault(String id) async {
    try {
      await _clearDefault(exceptId: id);
      await _sb.from('addresses').update({'is_default': true}).eq('id', id);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Clears is_default on every row owned by the current user,
  /// optionally skipping [exceptId].
  Future<void> _clearDefault({String? exceptId}) async {
    var query = _sb
        .from('addresses')
        .update({'is_default': false}).eq('is_default', true);
    if (exceptId != null) {
      query = query.neq('id', exceptId);
    }
    await query;
  }
}
