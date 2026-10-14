import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/attributes/data/admin_attribute_repository.dart';
import 'package:admin_app/features/attributes/data/models/category_attribute.dart';
import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/auth/data/models/profile.dart';
import 'package:admin_app/features/categories/data/admin_category_repository.dart';
import 'package:admin_app/features/categories/data/models/category.dart';
import 'package:admin_app/features/products/data/admin_product_repository.dart';
import 'package:admin_app/features/products/data/product_draft.dart';
import 'package:admin_app/features/products/presentation/product_editor_page.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminProductRepository extends Mock
    implements AdminProductRepository {}

class MockAdminCategoryRepository extends Mock
    implements AdminCategoryRepository {}

class MockAdminAttributeRepository extends Mock
    implements AdminAttributeRepository {}

class MockAdminAuthRepository extends Mock implements AdminAuthRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kProductId = 'prod-1';
const _kCategoryId = 'cat-1';
const _kCategoryId2 = 'cat-2';

Profile _adminProfile() => Profile(
      id: 'admin-1',
      fullName: 'Admin',
      email: 'admin@example.com',
      role: ProfileRole.admin,
      isActive: true,
      createdAt: DateTime(2024),
    );

Category _category1() => const Category(
      id: _kCategoryId,
      name: 'Seeds',
      slug: 'seeds',
      displayOrder: 0,
      isActive: true,
    );

Category _category2() => const Category(
      id: _kCategoryId2,
      name: 'Fertilizers',
      slug: 'fertilizers',
      displayOrder: 1,
      isActive: true,
    );

CategoryAttribute _requiredNumberAttr() => const CategoryAttribute(
      id: 'attr-1',
      categoryId: _kCategoryId,
      name: 'Nitrogen %',
      attributeKey: 'nitrogen_pct',
      dataType: AttributeType.number,
      options: [],
      isRequired: true,
      displayOrder: 0,
      isActive: true,
    );

CategoryAttribute _optionalTextAttr() => const CategoryAttribute(
      id: 'attr-2',
      categoryId: _kCategoryId2,
      name: 'Variant',
      attributeKey: 'variant',
      dataType: AttributeType.text,
      options: [],
      isRequired: false,
      displayOrder: 0,
      isActive: true,
    );

AdminProductDetail _productDetail() => const AdminProductDetail(
      id: _kProductId,
      name: 'Tomato Seeds',
      slug: 'tomato-seeds',
      sku: 'SEED-TOM-001',
      categoryId: _kCategoryId,
      categoryName: 'Seeds',
      price: 100,
      mrp: 120,
      taxPercent: 5,
      isPublished: false,
      isActive: true,
    );

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pumpEditor(
  WidgetTester tester, {
  required MockAdminProductRepository productRepo,
  required MockAdminCategoryRepository categoryRepo,
  required MockAdminAttributeRepository attributeRepo,
  String initialLocation = '/admin/products/new',
}) async {
  final mockAuthRepo = MockAdminAuthRepository();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/admin/products/new',
        builder: (_, __) => const ProductEditorPage(),
      ),
      GoRoute(
        path: '/admin/products/:productId/edit',
        builder: (_, state) => ProductEditorPage(
          productId: state.pathParameters['productId'],
        ),
      ),
      GoRoute(
        path: '/admin/products',
        builder: (_, __) => const Scaffold(body: Text('Products list')),
      ),
      GoRoute(
        path: '/admin/products/:productId/media',
        builder: (_, __) => const Scaffold(body: Text('Media manager')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminProductRepositoryProvider.overrideWithValue(productRepo),
        adminCategoryRepositoryProvider.overrideWithValue(categoryRepo),
        adminAttributeRepositoryProvider.overrideWithValue(attributeRepo),
        adminAuthRepositoryProvider.overrideWithValue(mockAuthRepo),
        adminAuthControllerProvider.overrideWith(
          (ref) => AdminAuthController(mockAuthRepo)
            ..state = AsyncData(_adminProfile()),
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
  late MockAdminProductRepository productRepo;
  late MockAdminCategoryRepository categoryRepo;
  late MockAdminAttributeRepository attributeRepo;

  setUpAll(() {
    registerFallbackValue(
      const ProductDraft(
        name: '',
        slug: '',
        sku: '',
        categoryId: '',
        price: 0,
        mrp: 0,
        taxPercent: 0,
      ),
    );
  });

  setUp(() {
    productRepo = MockAdminProductRepository();
    categoryRepo = MockAdminCategoryRepository();
    attributeRepo = MockAdminAttributeRepository();

    // Default stubs.
    when(() => categoryRepo.fetchAll(includeInactive: false))
        .thenAnswer((_) async => [_category1(), _category2()]);
    when(() => attributeRepo.fetchForCategory(any()))
        .thenAnswer((_) async => []);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Case 1: category locked on edit (disabled dropdown + helper)
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets('category locked on edit (disabled dropdown + helper)',
      (tester) async {
    when(() => productRepo.details(_kProductId))
        .thenAnswer((_) async => _productDetail());
    when(() => attributeRepo.fetchForCategory(_kCategoryId))
        .thenAnswer((_) async => [_requiredNumberAttr()]);

    await _pumpEditor(
      tester,
      productRepo: productRepo,
      categoryRepo: categoryRepo,
      attributeRepo: attributeRepo,
      initialLocation: '/admin/products/$_kProductId/edit',
    );

    // The category dropdown onChanged must be null (disabled).
    final dropdown = tester.widget<DropdownButtonFormField<String?>>(
      find.byKey(const Key('category_dropdown')),
    );
    expect(dropdown.onChanged, isNull);

    // Helper text explaining why it's locked must be visible.
    expect(
      find.text(
          'Category is locked after creation because attribute values are bound to it.'),
      findsOneWidget,
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Case 2: required attribute empty blocks publish but not draft
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets('required attribute empty blocks publish but not draft save',
      (tester) async {
    // Stub for create flow.
    when(() => categoryRepo.fetchAll(includeInactive: false))
        .thenAnswer((_) async => [_category1()]);
    when(() => attributeRepo.fetchForCategory(_kCategoryId))
        .thenAnswer((_) async => [_requiredNumberAttr()]);
    when(() => productRepo.create(any()))
        .thenAnswer((_) async => _productDetail());

    await _pumpEditor(
      tester,
      productRepo: productRepo,
      categoryRepo: categoryRepo,
      attributeRepo: attributeRepo,
    );

    // Select category to trigger attribute load.
    await tester.tap(find.byKey(const Key('category_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seeds').last);
    await tester.pumpAndSettle();

    // Fill required base fields.
    await tester.enterText(find.byKey(const Key('name_field')), 'Test Product');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sku_field')), 'SKU-001');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('price_field')), '100');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('mrp_field')), '120');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('tax_field')), '5');
    await tester.pump();

    // Tap Publish — required attribute is empty.
    await tester.tap(find.byKey(const Key('publish_button')));
    await tester.pumpAndSettle();

    // Publish error bar must appear.
    expect(find.byKey(const Key('publish_error_bar')), findsOneWidget);
    // The attribute name should be mentioned.
    expect(find.textContaining('Nitrogen %'), findsWidgets);

    // Dismiss bar and tap Save draft — should succeed (calls create).
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_draft_button')));
    await tester.pumpAndSettle();

    verify(() => productRepo.create(any())).called(1);
    // Error bar should NOT have appeared for draft.
    expect(find.byKey(const Key('publish_error_bar')), findsNothing);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Case 3: MRP < price inline error
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets('MRP < price shows inline error', (tester) async {
    await _pumpEditor(
      tester,
      productRepo: productRepo,
      categoryRepo: categoryRepo,
      attributeRepo: attributeRepo,
    );

    await tester.enterText(find.byKey(const Key('price_field')), '200');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('mrp_field')), '100');
    await tester.pump();
    // Trigger inline validation by tapping publish.
    await tester.tap(find.byKey(const Key('publish_button')));
    await tester.pumpAndSettle();

    expect(find.text('MRP must be ≥ price.'), findsOneWidget);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Case 4: tax 0–100 enforced
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets('tax outside 0–100 shows inline error', (tester) async {
    await _pumpEditor(
      tester,
      productRepo: productRepo,
      categoryRepo: categoryRepo,
      attributeRepo: attributeRepo,
    );

    await tester.enterText(find.byKey(const Key('tax_field')), '150');
    await tester.pump();
    await tester.tap(find.byKey(const Key('publish_button')));
    await tester.pumpAndSettle();

    expect(find.text('Tax % must be 0–100.'), findsOneWidget);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Case 5: SKU uppercase enforced on input
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets('SKU input is forced to uppercase', (tester) async {
    await _pumpEditor(
      tester,
      productRepo: productRepo,
      categoryRepo: categoryRepo,
      attributeRepo: attributeRepo,
    );

    await tester.enterText(find.byKey(const Key('sku_field')), 'abc-123');
    await tester.pump();

    final ctrl = tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('sku_field')),
            matching: find.byType(TextField),
          ),
        )
        .controller;
    expect(ctrl?.text, 'ABC-123');
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Case 6: switching category on CREATE re-renders attribute fields
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets('switching category re-renders attribute fields', (tester) async {
    // cat-1 has required number attr; cat-2 has optional text attr.
    when(() => attributeRepo.fetchForCategory(_kCategoryId))
        .thenAnswer((_) async => [_requiredNumberAttr()]);
    when(() => attributeRepo.fetchForCategory(_kCategoryId2))
        .thenAnswer((_) async => [_optionalTextAttr()]);

    await _pumpEditor(
      tester,
      productRepo: productRepo,
      categoryRepo: categoryRepo,
      attributeRepo: attributeRepo,
    );

    // Select category 1.
    await tester.tap(find.byKey(const Key('category_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seeds').last);
    await tester.pumpAndSettle();

    // Nitrogen % field should appear.
    expect(find.textContaining('Nitrogen %'), findsOneWidget);

    // Switch to category 2.
    await tester.tap(find.byKey(const Key('category_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fertilizers').last);
    await tester.pumpAndSettle();

    // Nitrogen % should be gone; Variant should appear.
    expect(find.textContaining('Nitrogen %'), findsNothing);
    expect(find.textContaining('Variant'), findsOneWidget);
  });
}
