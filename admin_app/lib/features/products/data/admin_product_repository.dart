import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../orders/data/admin_order_repository.dart';
import '../../attributes/data/models/category_attribute.dart';
import 'product_draft.dart';

// ── Filter enum ───────────────────────────────────────────────────────────────

enum ProductAdminFilter { all, published, draft, inactive }

// ── Models ────────────────────────────────────────────────────────────────────

class AdminProductCard {
  const AdminProductCard({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.isPublished,
    required this.isActive,
    this.primaryImagePath,
    this.stock,
  });
  final String id;
  final String name;
  final String sku;
  final String categoryId;
  final String categoryName;
  final double price;
  final bool isPublished;
  final bool isActive;
  final String? primaryImagePath;
  final int? stock;

  factory AdminProductCard.fromJson(Map<String, dynamic> json) {
    final catRaw = json['category'] as Map<String, dynamic>?;
    // Primary image: pick the embedded image with the smallest display_order.
    final images = (json['product_images'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    String? primaryPath;
    if (images.isNotEmpty) {
      images.sort((a, b) => (a['display_order'] as int? ?? 0)
          .compareTo(b['display_order'] as int? ?? 0));
      primaryPath = images.first['storage_path'] as String?;
    }
    // Stock from inventory embed.
    // inventory has a 1-to-1 PK relationship, so PostgREST returns a single
    // object (or null), not an array.
    final invRaw = json['inventory'];
    int? stock;
    if (invRaw is Map<String, dynamic>) {
      stock = invRaw['quantity'] as int?;
    }

    return AdminProductCard(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String,
      categoryId: catRaw?['id'] as String? ?? '',
      categoryName: catRaw?['name'] as String? ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0,
      isPublished: json['is_published'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      primaryImagePath: primaryPath,
      stock: stock,
    );
  }
}

class ProductAttributeValue {
  const ProductAttributeValue({
    required this.categoryAttributeId,
    required this.name,
    required this.attributeKey,
    required this.dataType,
    required this.options,
    this.valueText,
    this.valueNumber,
    this.valueBoolean,
  });
  final String categoryAttributeId;
  final String name;
  final String attributeKey;
  final AttributeType dataType;
  final List<String> options;
  final String? valueText;
  final double? valueNumber;
  final bool? valueBoolean;

  factory ProductAttributeValue.fromJson(Map<String, dynamic> json) {
    final attrRaw = json['attribute'] as Map<String, dynamic>?;
    return ProductAttributeValue(
      categoryAttributeId: json['category_attribute_id'] as String,
      name: attrRaw?['name'] as String? ?? '',
      attributeKey: attrRaw?['attribute_key'] as String? ?? '',
      dataType:
          AttributeType.fromDb((attrRaw?['data_type'] as String?) ?? 'text'),
      options: (attrRaw?['options'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      valueText: json['value_text'] as String?,
      valueNumber: json['value_number'] != null
          ? double.tryParse(json['value_number'].toString())
          : null,
      valueBoolean: json['value_boolean'] as bool?,
    );
  }
}

class ProductImage {
  const ProductImage({
    required this.id,
    required this.storagePath,
    required this.isPrimary,
    required this.displayOrder,
  });
  final String id;
  final String storagePath;
  final bool isPrimary;
  final int displayOrder;

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        id: json['id'] as String,
        storagePath: json['storage_path'] as String,
        isPrimary: json['is_primary'] as bool? ?? false,
        displayOrder: json['display_order'] as int? ?? 0,
      );
}

class AdminProductDetail {
  const AdminProductDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.sku,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.mrp,
    required this.taxPercent,
    required this.isPublished,
    required this.isActive,
    this.brand,
    this.description,
    this.images = const [],
    this.attributes = const [],
  });
  final String id;
  final String name;
  final String slug;
  final String sku;
  final String categoryId;
  final String categoryName;
  final double price;
  final double mrp;
  final double taxPercent;
  final bool isPublished;
  final bool isActive;
  final String? brand;
  final String? description;
  final List<ProductImage> images;
  final List<ProductAttributeValue> attributes;

  factory AdminProductDetail.fromJson(Map<String, dynamic> json) {
    final catRaw = json['category'] as Map<String, dynamic>?;
    final images = (json['product_images'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ProductImage.fromJson)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final attrs = (json['product_attributes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ProductAttributeValue.fromJson)
        .toList();

    return AdminProductDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      sku: json['sku'] as String,
      categoryId: catRaw?['id'] as String? ?? '',
      categoryName: catRaw?['name'] as String? ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0,
      mrp: double.tryParse(json['mrp'].toString()) ?? 0,
      taxPercent: double.tryParse(json['tax_percent'].toString()) ?? 0,
      isPublished: json['is_published'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      brand: json['brand'] as String?,
      description: json['description'] as String?,
      images: images,
      attributes: attrs,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final adminProductRepositoryProvider = Provider<AdminProductRepository>((ref) {
  return AdminProductRepository(ref.read(supabaseClientProvider));
});

class AdminProductRepository {
  AdminProductRepository(this._client);
  final SupabaseClient _client;

  // ── List ──────────────────────────────────────────────────────────────

  Future<Paginated<AdminProductCard>> list({
    String? query,
    String? sku,
    String? categoryId,
    ProductAdminFilter filter = ProductAdminFilter.all,
    required int page,
  }) async {
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      var filterQ = _client
          .from('products')
          .select('id, name, sku, price, is_published, is_active,'
              'category:categories(id,name),'
              'product_images(storage_path,display_order),'
              'inventory(quantity)');

      // Status filter.
      switch (filter) {
        case ProductAdminFilter.published:
          filterQ = filterQ.eq('is_published', true).eq('is_active', true);
          break;
        case ProductAdminFilter.draft:
          filterQ = filterQ.eq('is_published', false).eq('is_active', true);
          break;
        case ProductAdminFilter.inactive:
          filterQ = filterQ.eq('is_active', false);
          break;
        case ProductAdminFilter.all:
          break;
      }

      if (query != null && query.isNotEmpty) {
        filterQ = filterQ.ilike('name', '%$query%');
      }
      if (sku != null && sku.isNotEmpty) {
        filterQ = filterQ.eq('sku', sku.toUpperCase());
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        filterQ = filterQ.eq('category_id', categoryId);
      }

      final res = await filterQ
          .order('created_at', ascending: false)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      return Paginated(
        items: (res.data as List)
            .map((e) => AdminProductCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: res.count,
        page: page,
        pageSize: pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Count (for A02 KPI) ───────────────────────────────────────────────

  Future<int> countProducts() async {
    try {
      final res = await _client
          .from('products')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Details ───────────────────────────────────────────────────────────

  Future<AdminProductDetail> details(String id) async {
    try {
      final data = await _client
          .from('products')
          .select('*, category:categories(id,name,slug),'
              'product_attributes(category_attribute_id,value_text,value_number,value_boolean,'
              'attribute:category_attributes(name,attribute_key,data_type,options,display_order)),'
              'product_images(id,storage_path,is_primary,display_order)')
          .eq('id', id)
          .single();
      return AdminProductDetail.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Create ────────────────────────────────────────────────────────────

  Future<AdminProductDetail> create(ProductDraft d) async {
    try {
      final productData = await _client
          .from('products')
          .insert({
            'name': d.name,
            'slug': d.slug,
            'sku': d.sku,
            'category_id': d.categoryId,
            'price': d.price,
            'mrp': d.mrp,
            'tax_percent': d.taxPercent,
            if (d.brand != null && d.brand!.isNotEmpty) 'brand': d.brand,
            if (d.description != null && d.description!.isNotEmpty)
              'description': d.description,
            'is_published': false,
          })
          .select()
          .single();

      final productId = productData['id'] as String;

      // Insert initial inventory row.
      await _client.from('inventory').insert({
        'product_id': productId,
        'quantity': d.initialQuantity ?? 0,
        'reserved_quantity': 0,
        'min_stock_level': 0,
      });

      // Insert attribute values if any.
      if (d.attributeValues.isNotEmpty) {
        await saveAttributes(productId, d.attributeValues);
      }

      return await details(productId);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    } catch (e) {
      // Re-throw AppFailures (already mapped) or wrap anything unexpected.
      rethrow;
    }
  }

  // ── Update ────────────────────────────────────────────────────────────

  Future<AdminProductDetail> update(ProductDraft d) async {
    try {
      await _client.from('products').update({
        'name': d.name,
        'slug': d.slug,
        'sku': d.sku,
        'price': d.price,
        'mrp': d.mrp,
        'tax_percent': d.taxPercent,
        'brand': d.brand,
        'description': d.description,
      }).eq('id', d.id!);

      await saveAttributes(d.id!, d.attributeValues);
      return await details(d.id!);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    } catch (e) {
      rethrow;
    }
  }

  // ── Publish toggle ────────────────────────────────────────────────────

  Future<void> publish(String id, bool published) async {
    try {
      await _client
          .from('products')
          .update({'is_published': published}).eq('id', id);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Deactivate (soft delete) ──────────────────────────────────────────

  Future<void> deactivate(String id) async {
    try {
      await _client.from('products').update({'is_active': false}).eq('id', id);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Save attributes (replace-set) ────────────────────────────────────
  //
  // Sequential per spec 03_FLUTTER/03: no all-or-nothing guarantee in MVP.

  Future<void> saveAttributes(
      String productId, List<ProductAttributeInput> values) async {
    try {
      // Delete all existing attribute rows for this product.
      await _client
          .from('product_attributes')
          .delete()
          .eq('product_id', productId);

      if (values.isEmpty) return;

      // Upsert provided rows.
      final rows = values
          .map((v) => {
                'product_id': productId,
                'category_attribute_id': v.categoryAttributeId,
                if (v.valueText != null) 'value_text': v.valueText,
                if (v.valueNumber != null)
                  'value_number': v.valueNumber.toString(),
                if (v.valueBoolean != null) 'value_boolean': v.valueBoolean,
              })
          .toList();

      await _client.from('product_attributes').insert(rows);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
