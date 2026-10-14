import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/orders/data/models/order_detail.dart';
import 'package:customer_app/features/orders/data/models/order_item.dart';
import 'package:customer_app/features/orders/data/order_repository.dart';
import 'package:customer_app/features/orders/presentation/order_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockOrderRepository extends Mock implements OrderRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

ShippingSnapshot _snap() => const ShippingSnapshot(
      recipientName: 'Ramesh Kumar',
      phone: '9876543210',
      line1: '12/4 Main Road',
      city: 'Nashik',
      state: 'Maharashtra',
      postalCode: '422001',
      country: 'India',
    );

OrderDetail _order({
  String status = 'CONFIRMED',
  String? cancelReason,
  List<OrderItem> items = const [],
}) =>
    OrderDetail(
      id: 'order-1',
      orderNumber: 'AGR-261006-A1B2',
      status: status,
      total: 538.0,
      createdAt: DateTime(2026, 10, 6),
      items: items,
      paymentMethod: 'Cash on Delivery',
      paymentStatus: 'PENDING',
      shippingSnapshot: _snap(),
      subtotal: 500.0,
      deliveryFee: 30.0,
      tax: 8.0,
      cancelReason: cancelReason,
    );

/// Pumps [OrderDetailsPage] with a mocked [OrderRepository].
Future<void> _pumpPage(
  WidgetTester tester, {
  required MockOrderRepository repo,
  String orderId = 'order-1',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderRepositoryProvider.overrideWithValue(repo),
        orderDetailsControllerProvider(orderId).overrideWith(
          (ref) => repo.orderDetails(orderId),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: OrderDetailsPage(orderId: orderId),
      ),
    ),
  );
  // Use pump(duration) rather than pumpAndSettle: the timeline widget has an
  // infinite repeating AnimationController that would make pumpAndSettle hang.
  await tester.pump(); // schedule first frame
  await tester.pump(const Duration(milliseconds: 50)); // let async resolve
  await tester.pump(); // render result
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockOrderRepository repo;

  setUp(() {
    repo = MockOrderRepository();
  });

  // ── Timeline ──────────────────────────────────────────────────────────────

  testWidgets('CONFIRMED status renders timeline (not cancel banner)',
      (tester) async {
    when(() => repo.orderDetails('order-1'))
        .thenAnswer((_) async => _order(status: 'CONFIRMED'));

    await _pumpPage(tester, repo: repo);

    // Cancel banner must NOT appear.
    expect(find.byKey(const Key('cancel_banner')), findsNothing);
    // Timeline labels present.
    expect(find.text('Confirmed'), findsWidgets);
    expect(find.text('Order Placed'), findsOneWidget);
  });

  testWidgets('DELIVERED status shows all forward steps in timeline',
      (tester) async {
    when(() => repo.orderDetails('order-1'))
        .thenAnswer((_) async => _order(status: 'DELIVERED'));

    await _pumpPage(tester, repo: repo);

    expect(find.byKey(const Key('cancel_banner')), findsNothing);
    expect(find.text('Delivered'), findsWidgets);
  });

  testWidgets('SHIPPED status renders timeline without cancel banner',
      (tester) async {
    when(() => repo.orderDetails('order-1'))
        .thenAnswer((_) async => _order(status: 'SHIPPED'));

    await _pumpPage(tester, repo: repo);

    expect(find.byKey(const Key('cancel_banner')), findsNothing);
    expect(find.text('Shipped'), findsWidgets);
  });

  // ── Cancel banner ─────────────────────────────────────────────────────────

  testWidgets('CANCELLED order shows red banner with reason, hides timeline',
      (tester) async {
    when(() => repo.orderDetails('order-1')).thenAnswer(
      (_) async => _order(
        status: 'CANCELLED',
        cancelReason: 'Out of stock at warehouse',
      ),
    );

    await _pumpPage(tester, repo: repo);

    // Cancel banner present.
    expect(find.byKey(const Key('cancel_banner')), findsOneWidget);
    // Reason text displayed.
    expect(find.text('Out of stock at warehouse'), findsOneWidget);
    // Forward timeline labels must NOT appear.
    expect(find.text('Order Placed'), findsNothing);
    expect(find.text('Confirmed'), findsNothing);
  });

  testWidgets('CANCELLED with no reason still shows banner', (tester) async {
    when(() => repo.orderDetails('order-1')).thenAnswer(
      (_) async => _order(status: 'CANCELLED', cancelReason: null),
    );

    await _pumpPage(tester, repo: repo);

    expect(find.byKey(const Key('cancel_banner')), findsOneWidget);
  });

  // ── No cancel action ──────────────────────────────────────────────────────

  testWidgets('page has no cancel button or action', (tester) async {
    when(() => repo.orderDetails('order-1'))
        .thenAnswer((_) async => _order(status: 'NEW'));

    await _pumpPage(tester, repo: repo);

    // Search by text — case-insensitive patterns.
    expect(
      find.textContaining('Cancel', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('cancel', findRichText: true),
      findsNothing,
    );
  });

  // ── NOT_FOUND ─────────────────────────────────────────────────────────────

  testWidgets(
      'NOT_FOUND failure renders not-found state, never another user data',
      (tester) async {
    when(() => repo.orderDetails('other-user-order')).thenThrow(
      const ApiFailure('NOT_FOUND', 'Order not found.'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(repo),
          orderDetailsControllerProvider('other-user-order').overrideWith(
            (ref) => repo.orderDetails('other-user-order'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OrderDetailsPage(orderId: 'other-user-order'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.byKey(const Key('order_not_found')), findsOneWidget);
    expect(find.text('Order not found'), findsOneWidget);
    // No order data from the fixture should appear.
    expect(find.text('AGR-261006-A1B2'), findsNothing);
  });

  // ── Renders core layout ───────────────────────────────────────────────────

  testWidgets('renders order number, payment row, shipping address',
      (tester) async {
    when(() => repo.orderDetails('order-1'))
        .thenAnswer((_) async => _order(status: 'PROCESSING'));

    await _pumpPage(tester, repo: repo);

    expect(find.text('AGR-261006-A1B2'), findsOneWidget);
    expect(find.textContaining('Cash on Delivery'), findsOneWidget);
    expect(find.text('Ramesh Kumar'), findsOneWidget);
  });
}
