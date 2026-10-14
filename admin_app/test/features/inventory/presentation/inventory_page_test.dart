import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/inventory/data/admin_inventory_repository.dart';
import 'package:admin_app/features/inventory/presentation/inventory_page.dart';
import 'package:admin_app/features/inventory/widgets/adjust_stock_dialog.dart';
import 'package:admin_app/features/orders/data/admin_order_repository.dart'
    show Paginated;

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminInventoryRepository extends Mock
    implements AdminInventoryRepository {}

class MockAdminAuthRepository extends Mock implements AdminAuthRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

InventoryRow _row({
  String productId = 'p1',
  String name = 'Tomato Seeds',
  String sku = 'SEED-TOM-001',
  int quantity = 50,
  int minStockLevel = 10,
}) =>
    InventoryRow(
      productId: productId,
      productName: name,
      sku: sku,
      quantity: quantity,
      reservedQuantity: 0,
      minStockLevel: minStockLevel,
      updatedAt: DateTime(2024, 6, 1),
    );

InventoryRow _lowStockRow() => _row(
      productId: 'p2',
      name: 'Low Stock Item',
      sku: 'LOW-001',
      quantity: 5,
      minStockLevel: 10,
    );

Paginated<InventoryRow> _page(List<InventoryRow> rows) => Paginated(
      items: rows,
      total: rows.length,
      page: 1,
      pageSize: 20,
    );

// ── Pump helpers ──────────────────────────────────────────────────────────────

/// Pumps the full InventoryPage inside a GoRouter.
/// Uses 800px (< _kSidebarBreak) to avoid the Sidebar ColoredBox assertion.
Future<void> _pumpPage(
  WidgetTester tester,
  MockAdminInventoryRepository repo,
) async {
  final mockAuthRepo = MockAdminAuthRepository();

  final router = GoRouter(
    initialLocation: '/admin/inventory',
    routes: [
      GoRoute(
        path: '/admin/inventory',
        builder: (_, __) => const InventoryPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminInventoryRepositoryProvider.overrideWithValue(repo),
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

/// Pumps the AdjustStockDialog directly — avoids table-scroll issues.
Future<void> _pumpAdjustDialog(
  WidgetTester tester,
  MockAdminInventoryRepository repo,
  InventoryRow row,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminInventoryRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              key: const Key('open_dialog'),
              onPressed: () => showDialog<bool>(
                context: ctx,
                builder: (_) => AdjustStockDialog(row: row),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open_dialog')));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAdminInventoryRepository repo;

  setUp(() {
    repo = MockAdminInventoryRepository();
  });

  group('InventoryRow unit', () {
    test('isLowStock — true when quantity <= minStockLevel', () {
      expect(_row(quantity: 5, minStockLevel: 10).isLowStock, isTrue);
    });

    test('isLowStock — false when quantity > minStockLevel', () {
      expect(_row(quantity: 50, minStockLevel: 10).isLowStock, isFalse);
    });

    test('isLowStock — true when quantity == minStockLevel', () {
      expect(_row(quantity: 10, minStockLevel: 10).isLowStock, isTrue);
    });
  });

  group('InventoryPage', () {
    testWidgets('renders rows from repository', (tester) async {
      when(() => repo.list(
            query: any(named: 'query'),
            lowStockOnly: any(named: 'lowStockOnly'),
            page: any(named: 'page'),
          )).thenAnswer((_) async => _page([_row(), _lowStockRow()]));

      await _pumpPage(tester, repo);

      expect(find.text('Tomato Seeds'), findsOneWidget);
      expect(find.text('Low Stock Item'), findsOneWidget);
    });

    testWidgets('low-stock-only checkbox calls repo with lowStockOnly:true',
        (tester) async {
      when(() => repo.list(
            query: any(named: 'query'),
            lowStockOnly: false,
            page: any(named: 'page'),
          )).thenAnswer((_) async => _page([_row(), _lowStockRow()]));
      when(() => repo.list(
            query: any(named: 'query'),
            lowStockOnly: true,
            page: any(named: 'page'),
          )).thenAnswer((_) async => _page([_lowStockRow()]));

      await _pumpPage(tester, repo);

      await tester.tap(find.byKey(const Key('low_stock_only')));
      await tester.pumpAndSettle();

      verify(() => repo.list(
            query: any(named: 'query'),
            lowStockOnly: true,
            page: any(named: 'page'),
          )).called(1);
    });
  });

  group('AdjustStockDialog', () {
    testWidgets('dialog has type, delta, and reason fields', (tester) async {
      await _pumpAdjustDialog(tester, repo, _row());

      expect(find.byKey(const Key('adjust_type')), findsOneWidget);
      expect(find.byKey(const Key('adjust_delta')), findsOneWidget);
      expect(find.byKey(const Key('adjust_reason')), findsOneWidget);
    });

    testWidgets('delta 0 fails validation', (tester) async {
      await _pumpAdjustDialog(tester, repo, _row());

      await tester.enterText(find.byKey(const Key('adjust_delta')), '0');
      await tester.enterText(
          find.byKey(const Key('adjust_reason')), 'Some reason');
      await tester.tap(find.byKey(const Key('adjust_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Delta cannot be zero'), findsOneWidget);
    });

    testWidgets('delta resulting in negative stock is blocked', (tester) async {
      await _pumpAdjustDialog(tester, repo, _row(quantity: 5));

      await tester.enterText(find.byKey(const Key('adjust_delta')), '-50');
      await tester.pumpAndSettle();

      // Button is disabled when preview would go negative.
      final btn =
          tester.widget<ElevatedButton>(find.byKey(const Key('adjust_submit')));
      expect(btn.onPressed, isNull);

      verifyNever(() => repo.adjust(
            productId: any(named: 'productId'),
            delta: any(named: 'delta'),
            transactionType: any(named: 'transactionType'),
            reason: any(named: 'reason'),
          ));
    });

    testWidgets('reason shorter than 3 chars fails validation', (tester) async {
      await _pumpAdjustDialog(tester, repo, _row());

      await tester.enterText(find.byKey(const Key('adjust_delta')), '10');
      await tester.enterText(find.byKey(const Key('adjust_reason')), 'ab');
      await tester.tap(find.byKey(const Key('adjust_submit')));
      await tester.pumpAndSettle();

      expect(find.text('At least 3 characters'), findsOneWidget);
    });

    testWidgets('valid adjustment calls repo.adjust', (tester) async {
      when(() => repo.adjust(
            productId: any(named: 'productId'),
            delta: any(named: 'delta'),
            transactionType: any(named: 'transactionType'),
            reason: any(named: 'reason'),
          )).thenAnswer(
        (_) async => {'product_id': 'p1', 'new_quantity': 60},
      );

      await _pumpAdjustDialog(tester, repo, _row(quantity: 50));

      await tester.enterText(find.byKey(const Key('adjust_delta')), '10');
      await tester.enterText(find.byKey(const Key('adjust_reason')), 'PO #12');
      await tester.tap(find.byKey(const Key('adjust_submit')));
      await tester.pumpAndSettle();

      verify(() => repo.adjust(
            productId: 'p1',
            delta: 10,
            transactionType: 'RESTOCK',
            reason: 'PO #12',
          )).called(1);
    });
  });
}
