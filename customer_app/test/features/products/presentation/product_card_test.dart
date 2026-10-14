import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/products/data/models/product_card.dart';
import 'package:customer_app/features/products/widgets/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A minimal in-stock product fixture.
const _inStock = ProductCard(
  id: 'prod-1',
  name: 'Tomato Hybrid Seeds',
  slug: 'tomato-hybrid-seeds',
  sku: 'SEED-TOM-001',
  brand: 'AgriPlus',
  price: 149,
  mrp: 199,
  taxPercent: 5,
  primaryImagePath: null,
  inStock: true,
);

// Out-of-stock variant.
const _outOfStock = ProductCard(
  id: 'prod-2',
  name: 'Wheat Seeds Premium',
  slug: 'wheat-seeds-premium',
  sku: 'SEED-WHT-001',
  price: 299,
  taxPercent: 0,
  primaryImagePath: null,
  inStock: false,
);

// Product with no MRP (no discount).
const _noDiscount = ProductCard(
  id: 'prod-3',
  name: 'Neem Oil',
  slug: 'neem-oil',
  sku: 'OIL-NEM-001',
  price: 349,
  taxPercent: 0,
  primaryImagePath: null,
  inStock: true,
);

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 400,
          child: child,
        ),
      ),
    );

void main() {
  group('ProductCardWidget', () {
    testWidgets('renders product name', (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _inStock)));
      expect(find.text('Tomato Hybrid Seeds'), findsOneWidget);
    });

    testWidgets('renders price in INR format', (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _inStock)));
      // ₹149.00 formatted via Formatters.inr
      expect(find.textContaining('149'), findsWidgets);
    });

    testWidgets('renders MRP with strikethrough when mrp > price',
        (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _inStock)));
      // MRP text should be present (₹199.xx)
      expect(find.textContaining('199'), findsWidgets);
    });

    testWidgets('shows discount badge when mrp > price', (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _inStock)));
      // 149 vs 199 → 25% off
      expect(find.textContaining('% off'), findsOneWidget);
    });

    testWidgets('does not show discount badge when no mrp', (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _noDiscount)));
      expect(find.textContaining('% off'), findsNothing);
    });

    testWidgets('shows out-of-stock overlay when inStock is false',
        (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _outOfStock)));
      expect(find.text('Out of stock'), findsOneWidget);
    });

    testWidgets('does not show out-of-stock overlay for in-stock products',
        (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _inStock)));
      expect(find.text('Out of stock'), findsNothing);
    });

    testWidgets('onTap callback is invoked when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(ProductCardWidget(product: _inStock, onTap: () => tapped = true)),
      );
      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, isTrue);
    });

    testWidgets('Add button is not present in card', (tester) async {
      await tester
          .pumpWidget(_wrap(const ProductCardWidget(product: _inStock)));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsNothing);
    });
  });
}
