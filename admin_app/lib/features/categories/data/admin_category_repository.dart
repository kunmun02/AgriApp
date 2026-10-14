import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/slugifier.dart';
import 'models/category.dart';

final adminCategoryRepositoryProvider =
    Provider<AdminCategoryRepository>((ref) {
  return AdminCategoryRepository(ref.read(supabaseClientProvider));
});

class AdminCategoryRepository {
  AdminCategoryRepository(this._client);

  final SupabaseClient _client;

  // ── Fetch all (flat, no paging) ───────────────────────────────────────

  Future<List<Category>> fetchAll({bool includeInactive = true}) async {
    try {
      // Filters before .order() to stay on PostgrestFilterBuilder.
      var filterQ = _client.from('categories').select();

      if (!includeInactive) {
        filterQ = filterQ.eq('is_active', true);
      }

      final data = await filterQ.order('display_order', ascending: true);
      return (data as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Create (slug collision loop) ──────────────────────────────────────

  /// Creates a category. If the generated slug collides (23505), retries
  /// with `-2`, `-3`, … up to suffix 6 (5 retries). Final slug is returned
  /// inside the [Category] response.
  Future<Category> create({
    required String name,
    String? parentId,
    String? description,
    int displayOrder = 0,
    required String slug,
  }) async {
    String currentSlug = slug;
    for (int suffix = 2; suffix <= 7; suffix++) {
      try {
        final data = await _client
            .from('categories')
            .insert({
              'name': name,
              if (parentId != null) 'parent_id': parentId,
              if (description != null && description.isNotEmpty)
                'description': description,
              'display_order': displayOrder,
              'slug': currentSlug,
            })
            .select()
            .single();
        return Category.fromJson(data);
      } on PostgrestException catch (e) {
        if (e.code == '23505' && suffix <= 6) {
          // Slug collision — try next suffix.
          currentSlug = Slugifier.withSuffix(slug, suffix);
          continue;
        }
        throw ErrorMapper.from(e);
      }
    }
    throw const ApiFailure(
        'CONFLICT', 'Could not create a unique slug after 5 attempts.');
  }

  // ── Update ────────────────────────────────────────────────────────────

  Future<Category> update(Category c) async {
    try {
      final data = await _client
          .from('categories')
          .update({
            'name': c.name,
            'slug': c.slug,
            'parent_id': c.parentId,
            'description': c.description,
            'display_order': c.displayOrder,
            'is_active': c.isActive,
          })
          .eq('id', c.id)
          .select()
          .single();
      return Category.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Deactivate (soft) ─────────────────────────────────────────────────

  Future<void> deactivate(String id) async {
    try {
      await _client
          .from('categories')
          .update({'is_active': false}).eq('id', id);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Image upload ──────────────────────────────────────────────────────

  /// Uploads [bytes] to `category-images/{categoryId}/{epoch}-{sanitized}`
  /// and stores the path in the DB. Returns the storage path.
  Future<String> uploadImage({
    required String categoryId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final sanitized = Slugifier.sanitizeFileName(fileName);
      final epoch = DateTime.now().millisecondsSinceEpoch;
      final path = '$categoryId/$epoch-$sanitized';

      final uploadBytes =
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      await _client.storage.from('category-images').uploadBinary(
            path,
            uploadBytes,
            fileOptions: FileOptions(
              contentType: _mimeFromName(fileName),
              upsert: false,
            ),
          );

      // Persist path to DB.
      await _client
          .from('categories')
          .update({'image_path': path}).eq('id', categoryId);

      return path;
    } on StorageException catch (e) {
      throw ApiFailure('STORAGE_ERROR', e.message);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static String _mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
