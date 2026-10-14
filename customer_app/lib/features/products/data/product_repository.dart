import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/models/category.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/supabase_client.dart';
import '../../categories/data/category_repository.dart';
import 'models/product_card.dart';
import 'models/product_detail.dart';

enum ProductSort { newest, priceAsc, priceDesc }

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(
    ref.read(supabaseClientProvider),
    ref.read(categoryRepositoryProvider),
  ),
);

/// Supabase product_images + availability embed projection (list / card).
const _kProductCardSelect = 'id,name,slug,sku,brand,price,mrp,tax_percent,'
    'product_images(storage_path,is_primary,display_order),'
    'v_product_availability(in_stock)';

/// Full detail embed per 02_BACKEND/01_DATA_CONTRACTS §products DETAIL.
const _kProductDetailSelect = '*,'
    'category:categories(id,name,slug),'
    'product_attributes('
    'category_attribute_id,value_text,value_number,value_boolean,value_json,'
    'attribute:category_attributes(name,attribute_key,data_type,options,display_order)'
    '),'
    'product_images(id,storage_path,is_primary,display_order),'
    'v_product_availability(in_stock)';

class ProductRepository {
  ProductRepository(this._sb, this._categoryRepo);

  final SupabaseClient _sb;
  final CategoryRepository _categoryRepo;

  /// Lists published products with optional filtering and pagination.
  ///
  /// When [categoryId] is provided, the query includes all descendant
  /// category ids (subtree) resolved via [CategoryRepository].
  Future<Paginated<ProductCard>> listProducts({
    String? query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    ProductSort sort = ProductSort.newest,
    required int page,
  }) async {
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      // Resolve subtree ids before building the query.
      List<String>? categoryIds;
      if (categoryId != null) {
        final allCategories = await _categoryRepo.fetchActiveCategories();
        categoryIds = CategoryTree.subtreeIds(allCategories, categoryId);
      }

      // Build filter chain.
      var builder = _sb
          .from('products')
          .select(_kProductCardSelect)
          .eq('is_active', true)
          .eq('is_published', true);

      if (query != null && query.isNotEmpty) {
        builder = builder.ilike('name', '%$query%');
      }
      if (categoryIds != null) {
        builder = builder.inFilter('category_id', categoryIds);
      }
      if (minPrice != null) {
        builder = builder.gte('price', minPrice);
      }
      if (maxPrice != null) {
        builder = builder.lte('price', maxPrice);
      }

      // Sort column and direction.
      final sortColumn = switch (sort) {
        ProductSort.newest => 'created_at',
        ProductSort.priceAsc => 'price',
        ProductSort.priceDesc => 'price',
      };
      final ascending = sort != ProductSort.priceDesc;

      // Chain order + range + count; count() changes return to PostgrestResponse.
      final res = await builder
          .order(sortColumn, ascending: ascending)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      final items = (res.data as List)
          .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
          .toList();

      return Paginated<ProductCard>(
        items: items,
        total: res.count,
        page: page,
        pageSize: pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Full product detail for C07.
  ///
  /// Unpublished or inactive products → NOT_FOUND (via PGRST116 or missing row).
  Future<ProductDetail> productDetails(String productId) async {
    try {
      final res = await _sb
          .from('products')
          .select(_kProductDetailSelect)
          .eq('id', productId)
          .eq('is_active', true)
          .eq('is_published', true)
          .single();
      return ProductDetail.fromJson(res);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// First 8 published products ordered by created_at desc (home popular grid).
  Future<List<ProductCard>> popularProducts({int limit = 8}) async {
    try {
      final res = await _sb
          .from('products')
          .select(_kProductCardSelect)
          .eq('is_active', true)
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
