import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cart/controllers/cart_badge_controller.dart';

/// Cart item-count provider consumed by the shell bottom-nav badge.
///
/// Delegates to [CartBadgeController] which is backed by the real
/// CartRepository. Before Phase 08 this returned a hard-coded 0.
final cartItemCountProvider = Provider<int>(
  (ref) => ref.watch(cartBadgeControllerProvider),
);
