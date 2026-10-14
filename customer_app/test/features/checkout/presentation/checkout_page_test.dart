import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/core/models/cart_item.dart';
import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/addresses/data/address_repository.dart';
import 'package:customer_app/features/addresses/data/models/address.dart';
import 'package:customer_app/features/cart/controllers/cart_badge_controller.dart';
import 'package:customer_app/features/cart/controllers/cart_controller.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/checkout/data/checkout_repository.dart';
import 'package:customer_app/features/checkout/data/models/app_settings.dart';
import 'package:customer_app/features/checkout/presentation/checkout_page.dart';
import 'package:customer_app/features/products/data/models/product_card.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockCheckoutRepository extends Mock implements CheckoutRepository {}

class MockAddressRepository extends Mock implements AddressRepository {}

class MockCartRepository extends Mock implements CartRepository {}

class MockCartBadgeController extends Mock implements CartBadgeController {
  @override
  int get state => 0;
}

// ── Stub cart controller (pre-seeded, never re-fetches) ───────────────────────

/// A CartController that is pre-seeded with [CartState] and whose [fetch]
/// is a no-op, preventing pumpAndSettle() from hanging on async work.
class _StubCartController extends StateNotifier<CartState>
    implements CartController {
  _StubCartController(super.initialState);

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

const _kSettings500 = AppSettings(
  deliveryCharge: 40,
  freeDeliveryThreshold: 500,
);

Address _fakeAddress({String id = 'addr-1', bool isDefault = true}) => Address(
      id: id,
      userId: 'user-1',
      label: 'Home',
      recipientName: 'Ramesh Kumar',
      phone: '9876543210',
      line1: '12 Main Road',
      city: 'Mumbai',
      state: 'Maharashtra',
      postalCode: '400001',
      country: 'India',
      isDefault: isDefault,
    );

CartItem _cartItem({
  String id = 'ci-1',
  String productId = 'p-1',
  String name = 'Tomato Seeds',
  double price = 200,
  double taxPercent = 5,
  int quantity = 2,
}) =>
    CartItem(
      id: id,
      productId: productId,
      quantity: quantity,
      product: ProductCard(
        id: productId,
        name: name,
        slug: 'slug',
        sku: 'SKU-001',
        price: price,
        taxPercent: taxPercent,
        inStock: true,
      ),
      isActive: true,
      isPublished: true,
    );

/// Pumps [CheckoutPage] with full overrides.
///
/// Uses a [_StubCartController] pre-seeded with [cartItems] so:
/// - The cart guard never redirects away from /checkout.
/// - [pumpAndSettle] never hangs on a pending async fetch.
Future<void> _pumpCheckoutPage(
  WidgetTester tester, {
  required MockCheckoutRepository checkoutRepo,
  required MockAddressRepository addressRepo,
  required MockCartRepository cartRepo,
  required MockCartBadgeController badge,
  AppSettings settings = _kSettings500,
  List<Address>? addresses,
  List<CartItem>? cartItems,
}) async {
  final addressList = addresses ?? [_fakeAddress()];
  final items = cartItems ?? [_cartItem()];

  when(() => checkoutRepo.fetchSettings()).thenAnswer((_) async => settings);
  when(() => addressRepo.fetchAddresses()).thenAnswer((_) async => addressList);
  when(() => badge.refresh()).thenAnswer((_) async {});

  final seededCartState = CartState(items: items);

  final router = GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(
        path: '/checkout',
        builder: (_, __) => const CheckoutPage(),
      ),
      GoRoute(
        path: '/cart',
        builder: (_, __) => const Scaffold(body: Text('Cart')),
      ),
      GoRoute(
        path: '/order-success/:orderId',
        builder: (_, state) => Scaffold(
          body: Text('Success ${state.pathParameters['orderId']}'),
        ),
      ),
    ],
  );

  // Eagerly create the stub controller so it exists before the first frame.
  final stubCart = _StubCartController(seededCartState);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checkoutRepositoryProvider.overrideWithValue(checkoutRepo),
        addressRepositoryProvider.overrideWithValue(addressRepo),
        cartRepositoryProvider.overrideWithValue(cartRepo),
        cartBadgeControllerProvider.overrideWith((_) => badge),
        // Override with the pre-built stub so guard sees items immediately.
        cartControllerProvider.overrideWith((ref) => stubCart),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  // Drain async work (settings load, address fetch).
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockCheckoutRepository checkoutRepo;
  late MockAddressRepository addressRepo;
  late MockCartRepository cartRepo;
  late MockCartBadgeController badge;

  setUp(() {
    checkoutRepo = MockCheckoutRepository();
    addressRepo = MockAddressRepository();
    cartRepo = MockCartRepository();
    badge = MockCartBadgeController();
  });

  testWidgets('shows address, totals, and ₹delivery', (tester) async {
    await _pumpCheckoutPage(
      tester,
      checkoutRepo: checkoutRepo,
      addressRepo: addressRepo,
      cartRepo: cartRepo,
      badge: badge,
      settings:
          const AppSettings(deliveryCharge: 40, freeDeliveryThreshold: 500),
      cartItems: [_cartItem(price: 200, quantity: 2)], // subtotal 400 < 500
    );

    // Address shown.
    expect(find.text('Ramesh Kumar (Home)'), findsOneWidget);
    // Delivery section present.
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('subtotal ≥ threshold shows FREE delivery', (tester) async {
    await _pumpCheckoutPage(
      tester,
      checkoutRepo: checkoutRepo,
      addressRepo: addressRepo,
      cartRepo: cartRepo,
      badge: badge,
      settings:
          const AppSettings(deliveryCharge: 40, freeDeliveryThreshold: 500),
      // subtotal = 500 × 1 = 500 — exactly at threshold → FREE
      cartItems: [_cartItem(price: 500, quantity: 1, taxPercent: 0)],
    );

    expect(find.text('FREE'), findsOneWidget);
  });

  testWidgets('place-order double-tap creates ONE order (button locks)',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    when(() => checkoutRepo.createOrder(
          addressId: any(named: 'addressId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        )).thenAnswer((_) => completer.future);

    await _pumpCheckoutPage(
      tester,
      checkoutRepo: checkoutRepo,
      addressRepo: addressRepo,
      cartRepo: cartRepo,
      badge: badge,
    );

    // Select the first address row.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Scroll the Place Order button into view (ListView is lazy).
    await tester.scrollUntilVisible(
      find.byKey(const Key('placeOrderButton')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // First tap — starts the order.
    await tester.tap(find.byKey(const Key('placeOrderButton')));
    await tester.pump();

    // Second tap while loading — button is disabled, tap is ignored.
    await tester.tap(find.byKey(const Key('placeOrderButton')),
        warnIfMissed: false);
    await tester.pump();

    // Resolve the order future.
    completer.complete({
      'duplicate': false,
      'order_id': 'order-uuid-1',
      'order_number': 'AGR-261006-ABC123',
      'total': '400.00',
    });
    await tester.pumpAndSettle();

    // createOrder called exactly once despite two taps.
    verify(() => checkoutRepo.createOrder(
          addressId: any(named: 'addressId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        )).called(1);
  });

  testWidgets('OUT_OF_STOCK failure shows dialog with item names',
      (tester) async {
    when(() => checkoutRepo.createOrder(
          addressId: any(named: 'addressId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        )).thenThrow(const ApiFailure(
      'OUT_OF_STOCK',
      'insufficient stock for Tomato Seeds',
      {'product_id': 'p-1', 'available': 0},
    ));

    await _pumpCheckoutPage(
      tester,
      checkoutRepo: checkoutRepo,
      addressRepo: addressRepo,
      cartRepo: cartRepo,
      badge: badge,
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('placeOrderButton')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placeOrderButton')));
    await tester.pumpAndSettle();

    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.text('Back to Cart'), findsOneWidget);
  });

  testWidgets('success navigates to /order-success/:id', (tester) async {
    when(() => checkoutRepo.createOrder(
          addressId: any(named: 'addressId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        )).thenAnswer((_) async => {
          'duplicate': false,
          'order_id': 'order-uuid-1',
          'order_number': 'AGR-261006-ABC123',
          'total': '400.00',
        });

    await _pumpCheckoutPage(
      tester,
      checkoutRepo: checkoutRepo,
      addressRepo: addressRepo,
      cartRepo: cartRepo,
      badge: badge,
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('placeOrderButton')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placeOrderButton')));
    await tester.pumpAndSettle();

    expect(find.text('Success order-uuid-1'), findsOneWidget);
  });
}
