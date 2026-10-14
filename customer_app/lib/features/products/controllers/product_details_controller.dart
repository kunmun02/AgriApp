import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/product_detail.dart';
import '../data/product_repository.dart';

/// Provides the [ProductDetail] for a given product id.
///
/// Usage:
/// ```dart
/// final detail = ref.watch(productDetailsControllerProvider('prod-uuid'));
/// ```
///
/// Returns `AsyncData<ProductDetail>` on success, `AsyncError<AppFailure>` on
/// any failure (including NOT_FOUND for unpublished / invalid ids).
final productDetailsControllerProvider =
    FutureProvider.family<ProductDetail, String>(
  (ref, productId) =>
      ref.read(productRepositoryProvider).productDetails(productId),
);
