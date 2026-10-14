import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/features/orders/data/models/order_detail.dart';
import 'package:customer_app/features/orders/data/models/order_summary.dart';
import 'package:customer_app/features/orders/data/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockOrderRepository extends Mock implements OrderRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

OrderSummary _summary({String status = 'NEW', int index = 0}) => OrderSummary(
      id: 'order-$index',
      orderNumber: 'AGR-001-${index.toString().padLeft(4, '0')}',
      status: status,
      total: 100.0 * (index + 1),
      createdAt: DateTime(2026, 10, index + 1),
    );

ShippingSnapshot _snap() => const ShippingSnapshot(
      recipientName: 'Test User',
      phone: '9876543210',
      line1: '1 Main St',
      city: 'Pune',
      state: 'Maharashtra',
      postalCode: '411001',
      country: 'India',
    );

OrderDetail _detail({
  String id = 'order-0',
  String status = 'CONFIRMED',
  String? cancelReason,
}) =>
    OrderDetail(
      id: id,
      orderNumber: 'AGR-001-0000',
      status: status,
      total: 100.0,
      createdAt: DateTime(2026, 10, 1),
      items: const [],
      paymentMethod: 'Cash on Delivery',
      paymentStatus: 'PENDING',
      shippingSnapshot: _snap(),
      subtotal: 90.0,
      deliveryFee: 8.0,
      tax: 2.0,
      cancelReason: cancelReason,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockOrderRepository repo;

  setUp(() {
    repo = MockOrderRepository();
  });

  // ── myOrders ──────────────────────────────────────────────────────────────

  group('orderRepository.myOrders (mocked)', () {
    test('returns first page of 3 summaries — hasMore false', () async {
      final page = Paginated(
        items: List.generate(3, (i) => _summary(index: i)),
        hasMore: false,
      );
      when(() => repo.myOrders(page: 0)).thenAnswer((_) async => page);

      final result = await repo.myOrders(page: 0);

      expect(result.items.length, 3);
      expect(result.hasMore, isFalse);
    });

    test('returns full page of 20 — hasMore true', () async {
      final page = Paginated(
        items: List.generate(20, (i) => _summary(index: i)),
        hasMore: true,
      );
      when(() => repo.myOrders(page: 0)).thenAnswer((_) async => page);

      final result = await repo.myOrders(page: 0);

      expect(result.items.length, 20);
      expect(result.hasMore, isTrue);
    });

    test('returns only CONFIRMED orders when status filter applied', () async {
      final page = Paginated(
        items: [
          _summary(status: 'CONFIRMED', index: 0),
          _summary(status: 'CONFIRMED', index: 1),
        ],
        hasMore: false,
      );
      when(() => repo.myOrders(status: 'CONFIRMED', page: 0))
          .thenAnswer((_) async => page);

      final result = await repo.myOrders(status: 'CONFIRMED', page: 0);

      expect(result.items.every((o) => o.status == 'CONFIRMED'), isTrue);
    });

    test('empty page returns hasMore false', () async {
      const page = Paginated<OrderSummary>(items: [], hasMore: false);
      when(() => repo.myOrders(page: 0)).thenAnswer((_) async => page);

      final result = await repo.myOrders(page: 0);

      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
    });
  });

  // ── orderDetails ──────────────────────────────────────────────────────────

  group('orderRepository.orderDetails (mocked)', () {
    test('returns detail for own order', () async {
      when(() => repo.orderDetails('order-0'))
          .thenAnswer((_) async => _detail());

      final result = await repo.orderDetails('order-0');

      expect(result.id, 'order-0');
      expect(result.paymentMethod, 'Cash on Delivery');
    });

    test('NOT_FOUND thrown for unknown / cross-user order id', () async {
      when(() => repo.orderDetails('other-user-order')).thenThrow(
        const ApiFailure('NOT_FOUND', 'Order not found.'),
      );

      expect(
        () => repo.orderDetails('other-user-order'),
        throwsA(
          isA<ApiFailure>().having((f) => f.code, 'code', 'NOT_FOUND'),
        ),
      );
    });

    test('CANCELLED order detail includes cancelReason', () async {
      when(() => repo.orderDetails('cancelled-1')).thenAnswer(
        (_) async => _detail(
          id: 'cancelled-1',
          status: 'CANCELLED',
          cancelReason: 'Damaged goods',
        ),
      );

      final result = await repo.orderDetails('cancelled-1');

      expect(result.status, 'CANCELLED');
      expect(result.cancelReason, 'Damaged goods');
    });
  });

  // ── OrderSummary.fromJson ─────────────────────────────────────────────────

  group('OrderSummary.fromJson', () {
    test('parses NUMERIC total string correctly', () {
      final json = {
        'id': 'o1',
        'order_number': 'AGR-001',
        'status': 'NEW',
        'total': '538.50',
        'created_at': '2026-10-06T10:00:00+00:00',
      };

      final summary = OrderSummary.fromJson(json);

      expect(summary.total, closeTo(538.50, 0.001));
    });

    test('parses integer total', () {
      final json = {
        'id': 'o2',
        'order_number': 'AGR-002',
        'status': 'DELIVERED',
        'total': 200,
        'created_at': '2026-10-07T08:00:00+00:00',
      };

      final summary = OrderSummary.fromJson(json);
      expect(summary.total, 200.0);
    });
  });

  // ── OrderDetail.fromJson ──────────────────────────────────────────────────

  group('OrderDetail.fromJson', () {
    test('parses embedded items and payment correctly', () {
      final json = {
        'id': 'o3',
        'order_number': 'AGR-003',
        'status': 'PROCESSING',
        'total': '300.00',
        'created_at': '2026-10-08T09:00:00+00:00',
        'subtotal': '280.00',
        'delivery_fee': '15.00',
        'tax': '5.00',
        'cancel_reason': null,
        'shipping_snapshot': {
          'recipient_name': 'A',
          'phone': '9999999999',
          'line1': 'Street 1',
          'city': 'City',
          'state': 'State',
          'postal_code': '123456',
          'country': 'India',
        },
        'items': [
          {
            'id': 'item-1',
            'name': 'Tomato Seeds',
            'sku': 'SEED-001',
            'quantity': 2,
            'unit_price': '100.00',
            'line_total': '200.00',
            'line_tax': '10.00',
          },
        ],
        'payment': {
          'method': 'Cash on Delivery',
          'status': 'PENDING',
          'amount': '300.00',
        },
      };

      final detail = OrderDetail.fromJson(json);

      expect(detail.items.length, 1);
      expect(detail.items.first.name, 'Tomato Seeds');
      expect(detail.items.first.quantity, 2);
      expect(detail.paymentMethod, 'Cash on Delivery');
      expect(detail.paymentStatus, 'PENDING');
      expect(detail.shippingSnapshot.city, 'City');
      expect(detail.subtotal, closeTo(280.0, 0.001));
    });

    test('handles cancelled order with reason', () {
      final json = {
        'id': 'o4',
        'order_number': 'AGR-004',
        'status': 'CANCELLED',
        'total': '150.00',
        'created_at': '2026-10-09T07:00:00+00:00',
        'subtotal': '130.00',
        'delivery_fee': '15.00',
        'tax': '5.00',
        'cancel_reason': 'Item out of stock',
        'shipping_snapshot': <String, dynamic>{},
        'items': <dynamic>[],
        'payment': null,
      };

      final detail = OrderDetail.fromJson(json);

      expect(detail.status, 'CANCELLED');
      expect(detail.cancelReason, 'Item out of stock');
    });
  });
}
