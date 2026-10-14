import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/slugifier.dart';
import 'admin_product_repository.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final adminMediaRepositoryProvider = Provider<AdminMediaRepository>((ref) {
  return AdminMediaRepository(ref.read(supabaseClientProvider));
});

class AdminMediaRepository {
  AdminMediaRepository(this._client);
  final SupabaseClient _client;

  static const _kBucket = 'product-images';
  static const _kMaxBytes = 5 * 1024 * 1024; // 5 MB per spec A09

  // ── Fetch ─────────────────────────────────────────────────────────────

  Future<List<ProductImage>> fetchImages(String productId) async {
    try {
      final data = await _client
          .from('product_images')
          .select('id, storage_path, is_primary, display_order')
          .eq('product_id', productId)
          .order('display_order', ascending: true);
      return (data as List)
          .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────

  /// Uploads [bytes] to storage, then inserts a product_images row.
  /// Returns the saved [ProductImage].
  ///
  /// [makePrimary] should be true when this is the first image for a product.
  /// Throws [ApiFailure('FILE_TOO_LARGE', …)] if [bytes.length] > 5 MB.
  Future<ProductImage> upload({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    bool makePrimary = false,
  }) async {
    if (bytes.length > _kMaxBytes) {
      throw ApiFailure('FILE_TOO_LARGE',
          '"$fileName" exceeds 5 MB. Please choose a smaller file.');
    }

    try {
      final sanitized = Slugifier.sanitizeFileName(fileName);
      final epoch = DateTime.now().millisecondsSinceEpoch;
      final path = '$productId/$epoch-$sanitized';

      await _client.storage.from(_kBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeFromName(fileName),
              upsert: false,
            ),
          );

      // Determine display_order: max existing + 1 (or 0 if first).
      final existing = await fetchImages(productId);
      final nextOrder = existing.isEmpty
          ? 0
          : existing.map((i) => i.displayOrder).reduce(
                    (a, b) => a > b ? a : b,
                  ) +
              1;

      final row = await _client
          .from('product_images')
          .insert({
            'product_id': productId,
            'storage_path': path,
            'is_primary': makePrimary || existing.isEmpty,
            'display_order': nextOrder,
          })
          .select()
          .single();

      return ProductImage.fromJson(row);
    } on StorageException catch (e) {
      throw ApiFailure('STORAGE_ERROR', e.message);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Set primary (two-op swap) ─────────────────────────────────────────

  Future<void> setPrimary({
    required String productId,
    required String imageId,
  }) async {
    try {
      // Clear all primaries for this product.
      await _client
          .from('product_images')
          .update({'is_primary': false}).eq('product_id', productId);
      // Set the new primary.
      await _client
          .from('product_images')
          .update({'is_primary': true}).eq('id', imageId);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Reorder ───────────────────────────────────────────────────────────

  /// Assigns each image id in [imageIdsInOrder] its new display_order
  /// (0-based index). Sequential per spec.
  Future<void> reorder(String productId, List<String> imageIdsInOrder) async {
    try {
      for (var i = 0; i < imageIdsInOrder.length; i++) {
        await _client
            .from('product_images')
            .update({'display_order': i}).eq('id', imageIdsInOrder[i]);
      }
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────

  /// Removes the storage object first, then deletes the DB row.
  /// If the storage object is already gone the row delete still proceeds.
  Future<void> delete(ProductImage img) async {
    try {
      await _client.storage.from(_kBucket).remove([img.storagePath]);
    } on StorageException {
      // Object already gone — proceed to row delete.
    }
    try {
      await _client.from('product_images').delete().eq('id', img.id);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Public URL ────────────────────────────────────────────────────────

  /// Returns the fully-qualified public URL for a [storagePath] inside the
  /// `product-images` bucket.  Use this for every [Image.network] call.
  String publicUrl(String storagePath) {
    return _client.storage.from(_kBucket).getPublicUrl(storagePath);
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
