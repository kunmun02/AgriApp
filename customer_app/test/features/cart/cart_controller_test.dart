import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/core/models/cart_item.dart';
import 'package:customer_app/features/cart/controllers/cart_badge_controller.dart';
import 'package:customer_app/features/cart/controllers/cart_controller.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/products/data/models/product_card.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockCartRepository extends Mock implements CartRepository {}

class MockCartBadgeController extends Mock implements CartBadgeController {
  @override
  int get state => 0;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ProductCard _product({
  String id = 'p1',
  double price = 100,
}) =>
    ProductCard(
      id: id,
      name: 'Test Product',
      slug: 'test-product',
      sku: 'SKU-001',
      price: price,
      taxPercent: 0,
      inStock: true,
    );

CartItem _availableItem({
  String id = 'i1',
  String productId = 'p1',
  int quantity = 1,
  double price = 100,
}) =>
    CartItem(
      id: id,
      productId: productId,
      quantity: quantity,
      product: _product(id: productId, price: price),
      isActive: true,
      isPublished: true,
    );

CartItem _unavailableItem({
  String id = 'i2',
  String productId = 'p2',
  int quantity = 1,
}) =>
    CartItem(
      id: id,
      productId: productId,
      quantity: quantity,
      product: _product(id: productId),
      isActive: false,
      isPublished: true,
    );

/// Builds a [CartController] with stubs that return [items] on fetch.
CartController _makeController(
  MockCartRepository repo,
  MockCartBadgeController badge, {
  List<CartItem> items = const [],
}) {
  when(() => repo.ensureCart()).thenAnswer((_) async => 'cart-1');
  when(() => repo.fetchItems('cart-1')).thenAnswer((_) async => items);
  when(() => badge.refresh()).thenAnswer((_) async {});
  return CartController(repo, badge);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockCartRepository repo;
  late MockCartBadgeController badge;

  setUp(() {
    repo = MockCartRepository();
    badge = MockCartBadgeController();
  });

  group('CartState.subtotal', () {
    test('sums only available items', () {
      const state = CartState(
        items: [
          CartItem(
            id: 'i1',
            productId: 'p1',
            quantity: 2,
            product: ProductCard(
              id: 'p1',
              name: 'A',
              slug: 'a',
              sku: 'A1',
              price: 50,
              taxPercent: 0,
              inStock: true,
            ),
            isActive: true,
            isPublished: true,
          ),
          CartItem(
            id: 'i2',
            productId: 'p2',
            quantity: 3,
            product: ProductCard(
              id: 'p2',
              name: 'B',
              slug: 'b',
              sku: 'B1',
              price: 200,
              taxPercent: 0,
              inStock: true,
            ),
            isActive: false, // unavailable
            isPublished: true,
          ),
        ],
      );

      // Only item i1 (2 × 50 = 100) counts; i2 is excluded.
      expect(state.subtotal, 100.0);
    });

    test('returns 0 when all items are unavailable', () {
      final state = CartState(items: [_unavailableItem()]);
      expect(state.subtotal, 0.0);
    });

    test('sums all items when all are available', () {
      final state = CartState(items: [
        _availableItem(id: 'i1', quantity: 2, price: 150), // 300
        _availableItem(id: 'i2', quantity: 1, price: 75), // 75
      ]);
      expect(state.subtotal, 375.0);
    });
  });

  group('CartController.updateQuantity', () {
    test('optimistically updates quantity in state', () async {
      final ctrl = _makeController(repo, badge,
          items: [_availableItem(id: 'i1', quantity: 1)]);
      // Wait for initial fetch to settle.
      await Future.delayed(Duration.zero);

      when(() => repo.updateQuantity(itemId: 'i1', quantity: 5))
          .thenAnswer((_) async {});

      await ctrl.updateQuantity(itemId: 'i1', quantity: 5);

      expect(ctrl.state.items.first.quantity, 5);
    });

    test('reverts on failure and returns the AppFailure', () async {
      final ctrl = _makeController(repo, badge,
          items: [_availableItem(id: 'i1', quantity: 1)]);
      await Future.delayed(Duration.zero);

      when(() => repo.updateQuantity(itemId: 'i1', quantity: 5))
          .thenThrow(const ApiFailure('SERVER_ERROR', 'oops'));

      final failure = await ctrl.updateQuantity(itemId: 'i1', quantity: 5);

      expect(failure, isA<ApiFailure>());
      expect(failure!.code, 'SERVER_ERROR');
      // Quantity reverted.
      expect(ctrl.state.items.first.quantity, 1);
    });

    test('clamps quantity to 99 before sending to repository', () async {
      final ctrl = _makeController(repo, badge,
          items: [_availableItem(id: 'i1', quantity: 98)]);
      await Future.delayed(Duration.zero);

      when(() => repo.updateQuantity(itemId: 'i1', quantity: 99))
          .thenAnswer((_) async {});

      // Caller passes 200 (pretend stepper bypassed); controller clamps.
      await ctrl.updateQuantity(itemId: 'i1', quantity: 200);

      // Repository was called with 99 (the clamped value).
      verify(() => repo.updateQuantity(itemId: 'i1', quantity: 99)).called(1);
    });
  });

  group('CartController.removeItem', () {
    test('removes item from state after successful delete', () async {
      final ctrl = _makeController(repo, badge, items: [
        _availableItem(id: 'i1'),
        _availableItem(id: 'i2'),
      ]);
      await Future.delayed(Duration.zero);

      when(() => repo.removeItem('i1')).thenAnswer((_) async {});

      final failure = await ctrl.removeItem('i1');

      expect(failure, isNull);
      expect(ctrl.state.items.length, 1);
      expect(ctrl.state.items.first.id, 'i2');
    });

    test('reverts optimistic removal on failure', () async {
      final ctrl =
          _makeController(repo, badge, items: [_availableItem(id: 'i1')]);
      await Future.delayed(Duration.zero);

      when(() => repo.removeItem('i1')).thenThrow(const NetworkFailure());

      final failure = await ctrl.removeItem('i1');

      expect(failure, isA<NetworkFailure>());
      // Item restored.
      expect(ctrl.state.items.length, 1);
    });

    test('empty state after removing the last item', () async {
      final ctrl =
          _makeController(repo, badge, items: [_availableItem(id: 'i1')]);
      await Future.delayed(Duration.zero);

      when(() => repo.removeItem('i1')).thenAnswer((_) async {});

      await ctrl.removeItem('i1');

      expect(ctrl.state.items, isEmpty);
    });
  });

  group('CartState.availableItems', () {
    test('excludes items with is_active=false', () {
      final state = CartState(items: [
        _availableItem(id: 'i1'),
        _unavailableItem(id: 'i2'),
      ]);
      expect(state.availableItems.length, 1);
      expect(state.availableItems.first.id, 'i1');
    });

    test('excludes items with null product', () {
      const nullProductItem = CartItem(
        id: 'i3',
        productId: 'p3',
        quantity: 1,
        product: null,
      );
      final state = CartState(items: [
        _availableItem(id: 'i1'),
        nullProductItem,
      ]);
      expect(state.availableItems.length, 1);
    });
  });

  group('badge refresh', () {
    test('refresh is called after successful removeItem', () async {
      final ctrl =
          _makeController(repo, badge, items: [_availableItem(id: 'i1')]);
      await Future.delayed(Duration.zero);

      when(() => repo.removeItem('i1')).thenAnswer((_) async {});

      await ctrl.removeItem('i1');

      // Once on init + once after remove.
      verify(() => badge.refresh()).called(greaterThanOrEqualTo(1));
    });

    test('refresh is called after successful updateQuantity', () async {
      final ctrl = _makeController(repo, badge,
          items: [_availableItem(id: 'i1', quantity: 1)]);
      await Future.delayed(Duration.zero);

      when(() => repo.updateQuantity(itemId: 'i1', quantity: 2))
          .thenAnswer((_) async {});

      await ctrl.updateQuantity(itemId: 'i1', quantity: 2);

      verify(() => badge.refresh()).called(greaterThanOrEqualTo(1));
    });
  });
}
