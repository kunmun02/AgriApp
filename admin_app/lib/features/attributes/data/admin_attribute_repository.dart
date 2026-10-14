import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/category_attribute.dart';

final adminAttributeRepositoryProvider =
    Provider<AdminAttributeRepository>((ref) {
  return AdminAttributeRepository(ref.read(supabaseClientProvider));
});

class AdminAttributeRepository {
  AdminAttributeRepository(this._client);

  final SupabaseClient _client;

  // ── Fetch ─────────────────────────────────────────────────────────────

  /// Returns ALL attributes for [categoryId] — active and inactive —
  /// ordered by [display_order] ascending (per spec §03_FLUTTER/03).
  Future<List<CategoryAttribute>> fetchForCategory(String categoryId) async {
    try {
      final data = await _client
          .from('category_attributes')
          .select()
          .eq('category_id', categoryId)
          .order('display_order', ascending: true);
      return (data as List)
          .map((e) => CategoryAttribute.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Create ────────────────────────────────────────────────────────────

  Future<CategoryAttribute> create({
    required String categoryId,
    required String name,
    required String attributeKey,
    required AttributeType dataType,
    required List<String> options,
    required bool isRequired,
    required int displayOrder,
  }) async {
    try {
      final data = await _client
          .from('category_attributes')
          .insert({
            'category_id': categoryId,
            'name': name,
            'attribute_key': attributeKey,
            'data_type': dataType.dbValue,
            'options': options,
            'is_required': isRequired,
            'display_order': displayOrder,
          })
          .select()
          .single();
      return CategoryAttribute.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Update ────────────────────────────────────────────────────────────

  /// Updates mutable fields only (name, options, isRequired, displayOrder,
  /// isActive). key + data_type are immutable once created.
  Future<CategoryAttribute> update(CategoryAttribute a) async {
    try {
      final data = await _client
          .from('category_attributes')
          .update({
            'name': a.name,
            'options': a.options,
            'is_required': a.isRequired,
            'display_order': a.displayOrder,
            'is_active': a.isActive,
          })
          .eq('id', a.id)
          .select()
          .single();
      return CategoryAttribute.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Deactivate (soft delete) ──────────────────────────────────────────

  Future<void> deactivate(String id) async {
    try {
      await _client
          .from('category_attributes')
          .update({'is_active': false}).eq('id', id);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
