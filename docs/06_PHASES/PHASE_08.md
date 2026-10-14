# PHASE_08 — Product details (C07) + add-to-cart subset

## Goal
Full product detail screen (gallery, pricing with tax note, stock, dynamic specs) with a working
Add-to-Cart backed by the minimal cart repository subset (full cart UI is Phase 09).

## Prerequisites
- PHASE_07. Read: `04_UI/02_CUSTOMER_SCREENS.md` C07, `03_FLUTTER/03` ProductRepository +
  CartRepository, `02_BACKEND/01_DATA_CONTRACTS.md` §product detail embed.

## Deliverables — exact files
```
customer_app/lib/features/products/data/product_repository.dart      (+ productDetails)
customer_app/lib/features/products/data/models/product_detail.dart
customer_app/lib/features/cart/data/cart_repository.dart             (SUBSET now: ensureCart, addItem, itemCount; full in Phase 09)
customer_app/lib/features/products/presentation/product_details_page.dart (C07)
customer_app/lib/features/products/widgets/specification_table.dart
customer_app/lib/features/products/controllers/product_details_controller.dart (FutureProvider.family)
customer_app/lib/features/cart/controllers/cart_badge_controller.dart
test/features/products/presentation/product_details_page_test.dart
```

## Tasks
1. `productDetails` embed exactly per 02_BACKEND/01 (attributes join category_attributes ordered by
   display_order; images by display_order; availability via view) — unpublished → NOT_FOUND.
2. C07 layout per 04_UI/02: 4:3 PageView carousel with indicator (placeholder when no images),
   price row (price + strikethrough MRP + "Incl. {tax}% tax"), stock badge from boolean,
   QuantityStepper 1–99, Add to Cart (disabled out-of-stock), Specifications from attributes,
   Description.
3. Add to Cart: `ensureCart` → `addItem(quantity)` (row exists → `min(existing+qty, 99)` per
   repository rule) → snackbar "Added to cart" + badge increment via `CartBadgeController`.
4. Widget tests incl. "double-tap creates ONE cart item with quantity 2" (mocktail: assert single
   repo call) and DB-verified manual.

## Database impact
None (DML via policies).

## Verification commands
```
cd customer_app && dart format . && flutter analyze && flutter test
# after tapping Add to Cart twice:
select quantity from cart_items;   -- expect single row, quantity 2
```

## Acceptance criteria
- [ ] C07 acceptance criteria of 04_UI/02 all demonstrated (4 Gherkin lines).
- [ ] Specs render in display_order with correct typed display values (BOOLEAN → "Yes/No",
      NUMBER → plain number, SELECT → option text).
- [ ] Out-of-stock product disables Add to Cart (grey).
- [ ] Invalid/unpublished id → error state with back.
- [ ] Add twice → ONE cart_items row with quantity 2 (SQL proof above).

## Report
Use the templates in PHASE_00 § Report templates.
