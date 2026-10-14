import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/network/supabase_client.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.read(supabaseClientProvider)),
);

/// Full CartRepository.
///
/// Phase 08 methods: [ensureCart], [addItem], [itemCount].
/// Phase 09 additions: [fetchItems], [updateQuantity], [removeItem].
class CartRepository {
  CartRepository(this._sb);

  final SupabaseClient _sb;

  // ── Phase 08 ──────────────────────────────────────────────────────────────

  /// Returns the current user's cart id, creating one if none exists.
  Future<String> ensureCart() async {
    try {
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) {
        throw const ApiFailure('AUTH_REQUIRED', 'Not signed in.');
      }

      final existing = await _sb
          .from('carts')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      final created = await _sb
          .from('carts')
          .insert({'user_id': userId})
          .select('id')
          .single();
      return created['id'] as String;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Adds [quantity] of [productId] to [cartId].
  ///
  /// Merges into an existing row capped at 99.
  Future<void> addItem({
    required String cartId,
    required String productId,
    required int quantity,
  }) async {
    try {
      final existing = await _sb
          .from('cart_items')
          .select('id,quantity')
          .eq('cart_id', cartId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing == null) {
        await _sb.from('cart_items').insert({
          'cart_id': cartId,
          'product_id': productId,
          'quantity': quantity.clamp(1, 99),
        });
      } else {
        final existingQty = (existing['quantity'] as num).toInt();
        final newQty = (existingQty + quantity).clamp(1, 99);
        await _sb
            .from('cart_items')
            .update({'quantity': newQty}).eq('id', existing['id'] as String);
      }
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Returns the total number of distinct items in the user's cart (badge).
  Future<int> itemCount() async {
    try {
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) return 0;

      final cart = await _sb
          .from('carts')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      if (cart == null) return 0;

      final cartId = cart['id'] as String;
      final res = await _sb
          .from('cart_items')
          .select('id')
          .eq('cart_id', cartId)
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Phase 09 ──────────────────────────────────────────────────────────────

  /// Fetches all items in [cartId] with their embedded product data.
  ///
  /// Query per 02_BACKEND/01 §2 — embeds product fields, images, and
  /// availability view so unavailability can be detected client-side.
  Future<List<CartItem>> fetchItems(String cartId) async {
    try {
      final rows = await _sb
          .from('cart_items')
          .select(
            'id,quantity,'
            'product:products('
            'id,name,slug,sku,brand,price,mrp,tax_percent,'
            'is_active,is_published,'
            'product_images(storage_path,is_primary,display_order),'
            'v_product_availability(in_stock)'
            ')',
          )
          .eq('cart_id', cartId)
          .order('created_at');

      return (rows as List)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Updates the quantity of a single cart item.
  ///
  /// [quantity] must be 1–99; this is enforced here and by the server CHECK.
  Future<void> updateQuantity({
    required String itemId,
    required int quantity,
  }) async {
    assert(quantity >= 1 && quantity <= 99,
        'quantity must be 1–99, got $quantity');
    try {
      await _sb
          .from('cart_items')
          .update({'quantity': quantity.clamp(1, 99)}).eq('id', itemId);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Permanently removes an item row from the cart.
  Future<void> removeItem(String itemId) async {
    try {
      await _sb.from('cart_items').delete().eq('id', itemId);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
