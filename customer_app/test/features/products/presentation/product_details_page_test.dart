import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/cart/controllers/cart_badge_controller.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/products/controllers/product_details_controller.dart';
import 'package:customer_app/features/products/data/models/product_detail.dart';
import 'package:customer_app/features/products/data/product_repository.dart';
import 'package:customer_app/features/products/presentation/product_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockProductRepository extends Mock implements ProductRepository {}

class MockCartRepository extends Mock implements CartRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

ProductDetail _makeProduct({
  bool inStock = true,
  List<ProductAttributeValue> attributes = const [],
}) =>
    ProductDetail(
      id: 'prod-1',
      name: 'Tomato Hybrid Seeds',
      slug: 'tomato-hybrid-seeds',
      sku: 'SEED-TOM-001',
      brand: 'AgriPlus',
      price: 149,
      mrp: 199,
      taxPercent: 5,
      description: 'High yield hybrid seeds.',
      categoryId: 'cat-1',
      categoryName: 'Seeds',
      isActive: true,
      isPublished: true,
      inStock: inStock,
      images: const [],
      attributes: attributes,
    );

/// Pumps [ProductDetailsPage] with mocked providers.
Future<void> _pumpPage(
  WidgetTester tester, {
  required MockProductRepository productRepo,
  required MockCartRepository cartRepo,
  String productId = 'prod-1',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(productRepo),
        cartRepositoryProvider.overrideWithValue(cartRepo),
        // Provide a no-op badge controller so it doesn't call real network.
        cartBadgeControllerProvider.overrideWith(
          (ref) => CartBadgeController(cartRepo),
        ),
        productDetailsControllerProvider(productId).overrideWith(
          (ref) => productRepo.productDetails(productId),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: ProductDetailsPage(productId: productId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockProductRepository productRepo;
  late MockCartRepository cartRepo;

  setUp(() {
    productRepo = MockProductRepository();
    cartRepo = MockCartRepository();

    // Default stub: itemCount returns 0 (badge init).
    when(() => cartRepo.itemCount()).thenAnswer((_) async => 0);
  });

  // ── Renders correctly ─────────────────────────────────────────────────────

  testWidgets('renders product name, price and description', (tester) async {
    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct());

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    expect(find.text('Tomato Hybrid Seeds'), findsWidgets);
    expect(find.textContaining('149'), findsWidgets);
    expect(find.text('High yield hybrid seeds.'), findsOneWidget);
  });

  testWidgets('shows image placeholder when product has no images',
      (tester) async {
    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct());

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  // ── In-stock / out-of-stock ────────────────────────────────────────────────

  testWidgets('shows "In stock" badge for in-stock product', (tester) async {
    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct());

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    expect(find.text('In stock'), findsOneWidget);
  });

  testWidgets('out-of-stock product disables Add to Cart button',
      (tester) async {
    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct(inStock: false));

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    expect(find.text('Out of stock'), findsOneWidget);

    // ElevatedButton inside AppButton should have onPressed == null.
    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Add to Cart'),
    );
    expect(btn.onPressed, isNull);
  });

  // ── Error state ───────────────────────────────────────────────────────────

  testWidgets('invalid/unpublished id shows error state with back button',
      (tester) async {
    when(() => productRepo.productDetails('bad-id')).thenThrow(
      const ApiFailure('NOT_FOUND', 'The requested item could not be found.'),
    );
    when(() => cartRepo.itemCount()).thenAnswer((_) async => 0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(productRepo),
          cartRepositoryProvider.overrideWithValue(cartRepo),
          cartBadgeControllerProvider.overrideWith(
            (ref) => CartBadgeController(cartRepo),
          ),
          productDetailsControllerProvider('bad-id').overrideWith(
            (ref) => productRepo.productDetails('bad-id'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProductDetailsPage(productId: 'bad-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('could not be found'),
      findsOneWidget,
    );
    expect(find.text('Go back'), findsOneWidget);
  });

  // ── Specifications ────────────────────────────────────────────────────────

  testWidgets('specs render in displayOrder with correct displayValues',
      (tester) async {
    final attrs = [
      const ProductAttributeValue(
        categoryAttributeId: 'a1',
        name: 'Organic',
        attributeKey: 'organic',
        dataType: AttributeType.boolean,
        options: [],
        displayOrder: 1,
        valueBoolean: true,
      ),
      const ProductAttributeValue(
        categoryAttributeId: 'a2',
        name: 'Weight (kg)',
        attributeKey: 'weight_kg',
        dataType: AttributeType.number,
        options: [],
        displayOrder: 2,
        valueNumber: 0.5,
      ),
      const ProductAttributeValue(
        categoryAttributeId: 'a3',
        name: 'Variety',
        attributeKey: 'variety',
        dataType: AttributeType.select,
        options: ['Hybrid', 'Desi'],
        displayOrder: 3,
        valueText: 'Hybrid',
      ),
    ];

    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct(attributes: attrs));

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    // BOOLEAN → "Yes"
    expect(find.text('Yes'), findsOneWidget);
    // NUMBER → plain decimal string
    expect(find.text('0.5'), findsOneWidget);
    // SELECT → option text
    expect(find.text('Hybrid'), findsOneWidget);

    // Verify order by checking the rendered order in the widget tree.
    final organicOffset = tester.getTopLeft(find.text('Organic')).dy;
    final weightOffset = tester.getTopLeft(find.text('Weight (kg)')).dy;
    final varietyOffset = tester.getTopLeft(find.text('Variety')).dy;
    expect(organicOffset, lessThan(weightOffset));
    expect(weightOffset, lessThan(varietyOffset));
  });

  // ── Add-to-cart logic ─────────────────────────────────────────────────────

  testWidgets('double-tap Add to Cart creates ONE cart item with quantity 2',
      (tester) async {
    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct());
    when(() => cartRepo.ensureCart()).thenAnswer((_) async => 'cart-1');
    when(() => cartRepo.addItem(
          cartId: any(named: 'cartId'),
          productId: any(named: 'productId'),
          quantity: any(named: 'quantity'),
        )).thenAnswer((_) async {});

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    // Scroll the stepper into view, then tap "+" to increment quantity to 2.
    final stepperIncrease = find.bySemanticsLabel('Increase quantity');
    await tester.ensureVisible(stepperIncrease);
    await tester.pumpAndSettle();
    await tester.tap(stepperIncrease, warnIfMissed: false);
    await tester.pump();

    // Scroll the button into view and tap — quantity is 2 at this point.
    final addToCartBtn = find.widgetWithText(ElevatedButton, 'Add to Cart');
    await tester.ensureVisible(addToCartBtn);
    await tester.pumpAndSettle();
    await tester.tap(addToCartBtn, warnIfMissed: false);
    await tester.pumpAndSettle();

    // addItem must have been called exactly once with quantity 2,
    // not twice with quantity 1 each.
    verify(() => cartRepo.addItem(
          cartId: 'cart-1',
          productId: 'prod-1',
          quantity: 2,
        )).called(1);
    verifyNever(() => cartRepo.addItem(
          cartId: any(named: 'cartId'),
          productId: any(named: 'productId'),
          quantity: 1,
        ));
  });

  testWidgets('snackbar "Added to cart" shown after successful add',
      (tester) async {
    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct());
    when(() => cartRepo.ensureCart()).thenAnswer((_) async => 'cart-1');
    when(() => cartRepo.addItem(
          cartId: any(named: 'cartId'),
          productId: any(named: 'productId'),
          quantity: any(named: 'quantity'),
        )).thenAnswer((_) async {});

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    final addToCartBtn = find.widgetWithText(ElevatedButton, 'Add to Cart');
    await tester.ensureVisible(addToCartBtn);
    await tester.pumpAndSettle();
    await tester.tap(addToCartBtn, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Added to cart'), findsOneWidget);
  });

  testWidgets('Add to Cart not called when product is out of stock',
      (tester) async {
    when(() => productRepo.productDetails('prod-1'))
        .thenAnswer((_) async => _makeProduct(inStock: false));

    await _pumpPage(tester, productRepo: productRepo, cartRepo: cartRepo);

    // Try tapping the button — it should be disabled, nothing fires.
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Add to Cart'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    verifyNever(() => cartRepo.ensureCart());
    verifyNever(() => cartRepo.addItem(
          cartId: any(named: 'cartId'),
          productId: any(named: 'productId'),
          quantity: any(named: 'quantity'),
        ));
  });
}
