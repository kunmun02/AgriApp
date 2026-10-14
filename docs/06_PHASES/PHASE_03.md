# PHASE_03 — Admin shell (A01 login, A02 dashboard)

## Goal
Admin app authenticates admins only, renders the responsive shell (sidebar/rail/drawer) and the
dashboard with KPI cards, low-stock and recent-orders sections.

## Prerequisites
- PHASE_00, PHASE_01, PHASE_02 (for shared patterns). Read: `04_UI/03_ADMIN_SCREENS.md` A01/A02 +
  cross-screen rules, `04_UI/04` admin routes + guard, `03_FLUTTER/03` admin repositories.

## Deliverables — exact files
```
admin_app/lib/core/router/admin_router.dart           (full admin route table with placeholders)
admin_app/lib/features/auth/data/admin_auth_repository.dart   (signIn + requireAdminProfile)
admin_app/lib/features/auth/controllers/admin_auth_controller.dart
admin_app/lib/features/auth/presentation/admin_login_page.dart     (A01)
admin_app/lib/features/shell/presentation/admin_shell.dart         (sidebar/rail/drawer + topbar)
admin_app/lib/features/orders/data/admin_order_repository.dart     (list + countOrdersCreatedToday + countNewOrders)
admin_app/lib/features/customers/data/admin_customer_repository.dart  (list + countCustomers)
admin_app/lib/features/products/data/admin_product_repository.dart    (list + countProducts)
admin_app/lib/features/inventory/data/admin_inventory_repository.dart (list lowStockOnly — full impl lands Phase 12)
admin_app/lib/features/dashboard/presentation/dashboard_page.dart  (A02)
admin_app/lib/core/widgets/stat_card.dart, admin_app/lib/core/widgets/status_badge.dart
admin_app/lib/core/errors/error_mapper.dart (+app_failure)          (mirror of customer)
admin_app/lib/core/utils/formatters.dart                            (mirror)
test/features/auth/presentation/admin_login_page_test.dart (admin side)
test/core/router/router_test.dart (admin guard cases)
```

## Tasks
1. A01 per 04_UI/03: sign-in → `requireAdminProfile()` → non-admin gets signed out with the exact
   error copy.
2. Shell: sidebar ≥1100 px (Catalog/Sales/CRM/System sections), icon rail below, drawer <800 px;
   topbar shows screen title + admin email + logout (04_UI/04).
3. Repositories created NOW with only the methods Phase 03 needs (list pages exist as placeholders
   until their phases).
4. A02 KPI queries exactly as speced (head-counts, UTC day boundary); low-stock card consumes
   `AdminInventoryRepository.list(page:1, lowStockOnly:true)` (client filter); recent orders =
   `AdminOrderRepository.list(page:1)` first 10.
5. Admin router guard per 04_UI/04 (customer-role bounce + sign-out).
6. Tests per 05_TESTING/01 (admin router + login).

## Database impact
None.

## Verification commands
```
cd admin_app && dart format . && flutter analyze && flutter test
flutter run -d chrome   # resize across 1200 / 1000 / 700 px widths
```
Manual: sign in with fixture admin → dashboard numbers match SQL counts; sign in with `:cust_a`
credentials → bounced to `/admin/login` and signed out.

## Acceptance criteria
- [ ] A01 + A02 acceptance criteria of 04_UI/03 demonstrated (incl. non-admin bounce).
- [ ] KPI "Orders today" matches `select count(*) from orders where created_at >= date_trunc('day', now() at time zone 'utc')`.
- [ ] All three breakpoints render correctly (sidebar / rail / drawer) — screenshot each.
- [ ] `flutter test` green; analyzer 0.
- [ ] Money shown via Formatters.inr only.

## Report
Use the templates in PHASE_00 § Report templates.
