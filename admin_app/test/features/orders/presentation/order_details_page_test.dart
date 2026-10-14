import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/errors/app_failure.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/orders/data/admin_order_repository.dart';
import 'package:admin_app/features/orders/presentation/order_details_page.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminOrderRepository extends Mock implements AdminOrderRepository {}

class MockAdminAuthRepository extends Mock implements AdminAuthRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kOrderId = 'order-1';

OrderDetail _newOrder() => OrderDetail(
      id: _kOrderId,
      orderNumber: 'ORD-2024-0001',
      status: 'NEW',
      subtotal: 200,
      deliveryFee: 50,
      tax: 10,
      total: 260,
      createdAt: DateTime(2024, 6, 1, 10, 0),
      updatedAt: DateTime(2024, 6, 1, 10, 0),
      cancelReason: null,
      items: [
        const OrderItem(
          id: 'item-1',
          productName: 'Tomato Seeds',
          skuSnapshot: 'SEED-TOM-001',
          unitPrice: 100,
          quantity: 2,
          productId: 'p1',
        ),
      ],
      payment: OrderPayment(
        method: 'COD',
        status: 'PENDING',
        amount: 260,
        updatedAt: DateTime(2024, 6, 1, 10, 0),
      ),
      customer: const CustomerProfile(
        userId: 'u1',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '9876543210',
      ),
      shippingAddress: const ShippingAddress(
        recipientName: 'John Doe',
        phone: '9876543210',
        line1: '123 Main St',
        line2: '',
        city: 'Mumbai',
        state: 'Maharashtra',
        postalCode: '400001',
      ),
    );

OrderDetail _withStatus(String status, {String? cancelReason}) {
  final o = _newOrder();
  return OrderDetail(
    id: o.id,
    orderNumber: o.orderNumber,
    status: status,
    subtotal: o.subtotal,
    deliveryFee: o.deliveryFee,
    tax: o.tax,
    total: o.total,
    createdAt: o.createdAt,
    updatedAt: o.updatedAt,
    cancelReason: cancelReason,
    items: o.items,
    payment: status == 'DELIVERED'
        ? OrderPayment(
            method: 'COD',
            status: 'COLLECTED',
            amount: o.total,
            updatedAt: DateTime(2024, 6, 2),
          )
        : status == 'CANCELLED'
            ? OrderPayment(
                method: 'COD',
                status: 'CANCELLED',
                amount: o.total,
                updatedAt: DateTime(2024, 6, 2),
              )
            : o.payment,
    customer: o.customer,
    shippingAddress: o.shippingAddress,
  );
}

OrderDetail _orderWithDeletedProduct() {
  final o = _newOrder();
  return OrderDetail(
    id: o.id,
    orderNumber: o.orderNumber,
    status: 'NEW',
    subtotal: o.subtotal,
    deliveryFee: o.deliveryFee,
    tax: o.tax,
    total: o.total,
    createdAt: o.createdAt,
    updatedAt: o.updatedAt,
    cancelReason: null,
    items: const [
      OrderItem(
        id: 'item-2',
        productName: '(deleted product)',
        skuSnapshot: 'OLD-SKU',
        unitPrice: 100,
        quantity: 1,
        productId: null,
      ),
    ],
    payment: o.payment,
    customer: o.customer,
    shippingAddress: o.shippingAddress,
  );
}

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pumpPage(
  WidgetTester tester,
  MockAdminOrderRepository repo,
  String orderId,
) async {
  final mockAuthRepo = MockAdminAuthRepository();

  final router = GoRouter(
    initialLocation: '/admin/orders/$orderId',
    routes: [
      GoRoute(
        path: '/admin/orders/:orderId',
        builder: (_, state) =>
            OrderDetailsPage(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/admin/orders',
        builder: (_, __) => const Scaffold(body: Text('Orders list')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminOrderRepositoryProvider.overrideWithValue(repo),
        adminAuthRepositoryProvider.overrideWithValue(mockAuthRepo),
        adminAuthControllerProvider.overrideWith(
          (ref) =>
              AdminAuthController(mockAuthRepo)..state = const AsyncData(null),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAdminOrderRepository repo;

  setUp(() {
    repo = MockAdminOrderRepository();
  });

  group('OrderDetailsPage — state machine buttons', () {
    testWidgets('NEW order shows exactly Confirm and Cancel Order buttons',
        (tester) async {
      when(() => repo.details(_kOrderId)).thenAnswer((_) async => _newOrder());

      await _pumpPage(tester, repo, _kOrderId);

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byKey(const Key('action_CANCELLED')), findsOneWidget);
      // No other forward-transition buttons.
      expect(find.text('Start Processing'), findsNothing);
      expect(find.text('Mark Packed'), findsNothing);
      expect(find.text('Mark Shipped'), findsNothing);
    });

    testWidgets('CONFIRMED order shows Start Processing and Cancel Order',
        (tester) async {
      when(() => repo.details(_kOrderId))
          .thenAnswer((_) async => _withStatus('CONFIRMED'));

      await _pumpPage(tester, repo, _kOrderId);

      expect(find.text('Start Processing'), findsOneWidget);
      expect(find.byKey(const Key('action_CANCELLED')), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('DELIVERED order shows no action buttons', (tester) async {
      when(() => repo.details(_kOrderId))
          .thenAnswer((_) async => _withStatus('DELIVERED'));

      await _pumpPage(tester, repo, _kOrderId);

      expect(find.text('Confirm'), findsNothing);
      expect(find.byKey(const Key('action_CANCELLED')), findsNothing);
      expect(find.text('Mark Delivered'), findsNothing);
    });

    testWidgets('CANCELLED order shows no action buttons', (tester) async {
      when(() => repo.details(_kOrderId)).thenAnswer((_) async => _withStatus(
          'CANCELLED',
          cancelReason: 'Customer requested cancellation'));

      await _pumpPage(tester, repo, _kOrderId);

      expect(find.text('Confirm'), findsNothing);
      expect(find.byKey(const Key('action_CANCELLED')), findsNothing);
    });
  });

  group('OrderDetailsPage — cancel flow', () {
    testWidgets('Cancel button opens reason dialog', (tester) async {
      when(() => repo.details(_kOrderId)).thenAnswer((_) async => _newOrder());

      await _pumpPage(tester, repo, _kOrderId);

      await tester.tap(find.byKey(const Key('action_CANCELLED')));
      // pump (not pumpAndSettle): while the dialog is open the action button
      // shows a CircularProgressIndicator which never settles.
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('cancel_reason')), findsOneWidget);
    });

    testWidgets('Cancel dialog blocks empty reason', (tester) async {
      when(() => repo.details(_kOrderId)).thenAnswer((_) async => _newOrder());

      await _pumpPage(tester, repo, _kOrderId);

      await tester.tap(find.byKey(const Key('action_CANCELLED')));
      await tester.pump();
      await tester.pump();

      // Try to confirm without entering reason.
      await tester.tap(find.byKey(const Key('cancel_confirm')));
      // pump (not pumpAndSettle): the action button behind the dialog keeps
      // a CircularProgressIndicator spinning while the dialog is open.
      await tester.pump();
      await tester.pump();

      expect(find.text('Required'), findsOneWidget);
      verifyNever(() => repo.changeStatus(
            orderId: any(named: 'orderId'),
            target: any(named: 'target'),
            reason: any(named: 'reason'),
          ));
    });
  });

  group('OrderDetailsPage — CONFLICT snackbar', () {
    testWidgets('CONFLICT error on Confirm shows snackbar and refetches',
        (tester) async {
      var callCount = 0;
      when(() => repo.details(_kOrderId)).thenAnswer((_) async {
        callCount++;
        return _newOrder();
      });
      when(() => repo.changeStatus(
            orderId: _kOrderId,
            target: 'CONFIRMED',
            reason: any(named: 'reason'),
          )).thenThrow(
        const ApiFailure('CONFLICT', 'illegal transition NEW -> CONFIRMED'),
      );

      await _pumpPage(tester, repo, _kOrderId);
      final detailsCallsBefore = callCount;

      await tester.tap(find.byKey(const Key('action_CONFIRMED')));
      // pump (not pumpAndSettle): while the ConfirmDialog is open the button
      // shows a CircularProgressIndicator which never settles.
      await tester.pump();
      await tester.pump();

      // Confirm in the ConfirmDialog.
      await tester.tap(find.byKey(const Key('confirm_action')));
      // pump (not pumpAndSettle): snackbar stays visible for 4 s; also the
      // loading indicator continues until the async path finishes.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // CONFLICT snackbar visible.
      expect(find.text('illegal transition NEW -> CONFIRMED'), findsOneWidget);
      // Details were refetched.
      expect(callCount, greaterThan(detailsCallsBefore));
    });
  });

  group('OrderDetailsPage — content', () {
    testWidgets('shows cancel reason banner when order is CANCELLED',
        (tester) async {
      when(() => repo.details(_kOrderId)).thenAnswer((_) async => _withStatus(
          'CANCELLED',
          cancelReason: 'Customer requested cancellation'));

      await _pumpPage(tester, repo, _kOrderId);

      expect(
        find.textContaining('Customer requested cancellation'),
        findsOneWidget,
      );
    });

    testWidgets('null product_id shown as (deleted product)', (tester) async {
      when(() => repo.details(_kOrderId))
          .thenAnswer((_) async => _orderWithDeletedProduct());

      await _pumpPage(tester, repo, _kOrderId);

      expect(find.text('(deleted product)'), findsOneWidget);
    });

    testWidgets('DELIVERED order shows COLLECTED payment status',
        (tester) async {
      when(() => repo.details(_kOrderId))
          .thenAnswer((_) async => _withStatus('DELIVERED'));

      await _pumpPage(tester, repo, _kOrderId);

      expect(find.text('Collected'), findsOneWidget);
    });
  });
}
