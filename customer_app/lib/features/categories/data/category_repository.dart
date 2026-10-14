import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/models/category.dart';
import '../../../core/network/supabase_client.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.read(supabaseClientProvider)),
);

class CategoryRepository {
  CategoryRepository(this._sb);

  final SupabaseClient _sb;

  /// Returns all active categories (flat, ordered by display_order).
  /// Tree is built client-side via [CategoryTree.build].
  Future<List<Category>> fetchActiveCategories() async {
    try {
      final res = await _sb
          .from('categories')
          .select(
              'id,parent_id,name,slug,description,image_path,display_order,is_active')
          .eq('is_active', true)
          .order('display_order');
      return (res as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
