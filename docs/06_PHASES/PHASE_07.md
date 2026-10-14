# PHASE_07 — Customer catalog (C04/C05/C06 + shell)

## Goal
Customer home, category browsing, and product listing with search/sort/filters/pagination, inside
the 5-tab bottom-nav shell.

## Prerequisites
- PHASE_02 (auth), PHASE_06 (admin data exists to browse). Read: `04_UI/02_CUSTOMER_SCREENS.md`
  C04–C06, `04_UI/04`, `03_FLUTTER/03` ProductRepository, `02_BACKEND/01` §product list card +
  §search/filter contract.

## Deliverables — exact files
```
customer_app/lib/core/widgets/paginated_list_view.dart     (infinite scroll + "Page x" fallback)
customer_app/lib/core/widgets/empty_state.dart
customer_app/lib/core/widgets/error_retry.dart
customer_app/lib/core/widgets/app_button.dart, quantity_stepper.dart, cached_image.dart
customer_app/lib/features/home/presentation/home_page.dart            (C04)
customer_app/lib/features/categories/data/category_repository.dart    (fetchActiveCategories + tree)
customer_app/lib/features/categories/presentation/categories_page.dart (C05)
customer_app/lib/features/categories/widgets/category_tree_view.dart
customer_app/lib/features/products/data/product_repository.dart       (listProducts, popularProducts)
customer_app/lib/features/products/data/models/product_card.dart
customer_app/lib/features/products/presentation/product_listing_page.dart (C06)
customer_app/lib/features/products/widgets/product_card.dart
customer_app/lib/core/router/app_router.dart               (StatefulShellRoute with 5 tabs)
test/features/products/presentation/product_card_test.dart
```

## Tasks
1. Shared widgets first (they carry the states contract): AppButton loading/disabled, EmptyState,
   ErrorRetry, PaginatedListView (offset paging, pageSize 20, `hasMore`).
2. C04 per 04_UI/02 (search bar → C06 with `q`, banner card, category circles, popular grid).
3. C05 tree with search; search submits to listing with `q` (NOT a category id).
4. C06: subtree category (repo resolves children ids first), sort dropdown, price min/max, grid of
   ProductCards, in-stock-only client toggle, pull-to-refresh, empty with Clear filters.
5. Shell: 5 tabs (Home, Categories, Cart, Orders, Profile) preserving state; cart badge reads
   `itemCount` (wired properly in Phase 09 — stub 0 now with TODO-free placeholder provider).
6. ProductRepository `listProducts` exactly per 03_FLUTTER/03 (embed `v_product_availability(in_stock)`).

## Database impact
None.

## Verification commands
```
cd customer_app && dart format . && flutter analyze && flutter test
flutter run   # browse seeded catalog as fixture customer
```
Manual: 25-product category pages to "25 shown"; sort Price ↑ cheapest first; `q=zzz` → empty +
Clear; category circle → listing; back from listing keeps filters.

## Acceptance criteria
- [ ] C04–C06 acceptance criteria of 04_UI/02 all demonstrated (incl. anon-invisible drafts).
- [ ] Pagination total 25 renders all 25 across pages.
- [ ] Tab switch preserves state; back preserves scroll + filters.
- [ ] Subtree: parent category listing shows descendants' products.
- [ ] All money via Formatters.inr; product images 1:1.

## Report
Use the templates in PHASE_00 § Report templates.
