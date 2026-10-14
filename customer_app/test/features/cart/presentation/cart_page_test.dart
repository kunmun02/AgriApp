import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/core/models/cart_item.dart';
import 'package:customer_app/features/cart/controllers/cart_controller.dart';
import 'package:customer_app/features/cart/presentation/cart_page.dart';
import 'package:customer_app/features/products/data/models/product_card.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockCartController extends StateNotifier<CartState>
    implements CartController {
  MockCartController(super.state);

  @override
  Future<void> fetch() async {}

  @override
  Future<AppFailure?> addItem(
          {required String productId, required int quantity}) async =>
      null;

  @override
  Future<AppFailure?> updateQuantity(
          {required String itemId, required int quantity}) async =>
      null;

  @override
  Future<AppFailure?> removeItem(String itemId) async => null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

CartItem _availableItem({String id = 'i1', String productId = 'p1'}) =>
    CartItem(
      id: id,
      productId: productId,
      quantity: 2,
      product: ProductCard(
        id: productId,
        name: 'Tomato Seeds',
        slug: 'tomato-seeds',
        sku: 'SKU-001',
        price: 149.0,
        taxPercent: 5,
        inStock: true,
      ),
      isActive: true,
      isPublished: true,
    );

CartItem _unavailableItem({String id = 'i2', String productId = 'p2'}) =>
    CartItem(
      id: id,
      productId: productId,
      quantity: 1,
      product: ProductCard(
        id: productId,
        name: 'Inactive Product',
        slug: 'inactive-product',
        sku: 'SKU-002',
        price: 99.0,
        taxPercent: 5,
        inStock: false,
      ),
      isActive: false,
      isPublished: true,
    );

/// Pumps a [CartPage] with [state] provided via an overridden provider.
Future<void> _pumpCart(
  WidgetTester tester,
  CartState state,
) async {
  final mockCtrl = MockCartController(state);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider.overrideWith((ref) => mockCtrl),
      ],
      child: const MaterialApp(
        home: CartPage(),
      ),
    ),
  );

  await tester.pump(); // settle initial frame
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('CartPage — empty state', () {
    testWidgets('shows EmptyState when cart is empty', (tester) async {
      await _pumpCart(tester, const CartState());

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse products'), findsOneWidget);
    });

    testWidgets('does not show checkout button when cart is empty',
        (tester) async {
      await _pumpCart(tester, const CartState());

      expect(find.text('Proceed to Checkout'), findsNothing);
    });
  });

  group('CartPage — loading state', () {
    testWidgets('shows spinner when loading with no items', (tester) async {
      await _pumpCart(tester, const CartState(isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('CartPage — with available items', () {
    testWidgets('renders item name and checkout button', (tester) async {
      await _pumpCart(tester, CartState(items: [_availableItem()]));

      expect(find.text('Tomato Seeds'), findsOneWidget);
      expect(find.text('Proceed to Checkout'), findsOneWidget);
    });

    testWidgets('checkout button is enabled when ≥1 available item',
        (tester) async {
      await _pumpCart(tester, CartState(items: [_availableItem()]));

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Proceed to Checkout'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('remove icon is present for available items', (tester) async {
      await _pumpCart(tester, CartState(items: [_availableItem()]));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  group('CartPage — with unavailable items', () {
    testWidgets('shows Unavailable chip for inactive product', (tester) async {
      await _pumpCart(tester, CartState(items: [_unavailableItem()]));

      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('checkout button is disabled when all items are unavailable',
        (tester) async {
      await _pumpCart(tester, CartState(items: [_unavailableItem()]));

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Proceed to Checkout'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'checkout button enabled when mixed available + unavailable items',
        (tester) async {
      await _pumpCart(
        tester,
        CartState(items: [_availableItem(), _unavailableItem()]),
      );

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Proceed to Checkout'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('unavailable item has no quantity stepper', (tester) async {
      await _pumpCart(tester, CartState(items: [_unavailableItem()]));

      // QuantityStepper only renders the +/- buttons; only unavailable items
      // should show "Qty: 1" text instead.
      expect(find.textContaining('Qty:'), findsOneWidget);
    });
  });

  group('CartPage — price summary', () {
    testWidgets('summary card shows "Delivery calculated at checkout"',
        (tester) async {
      await _pumpCart(tester, CartState(items: [_availableItem()]));

      expect(find.text('Delivery calculated at checkout'), findsOneWidget);
    });

    testWidgets('summary card shows Subtotal label', (tester) async {
      await _pumpCart(tester, CartState(items: [_availableItem()]));

      expect(find.text('Subtotal'), findsOneWidget);
    });
  });

  group('CartPage — remove confirmation dialog', () {
    testWidgets('tapping trash icon shows confirmation dialog', (tester) async {
      await _pumpCart(tester, CartState(items: [_availableItem()]));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Remove item?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('cancelling dialog keeps item in list', (tester) async {
      await _pumpCart(tester, CartState(items: [_availableItem()]));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed; item still shown.
      expect(find.text('Tomato Seeds'), findsOneWidget);
    });
  });
}
