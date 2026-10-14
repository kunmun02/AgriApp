# PHASE_11 — Customer orders (C13/C14)

## Goal
Order history with status filters and the order details screen with status timeline, items, bill
and shipping snapshot. Customers observe; only admins change status (cancel is out of scope
customer-side).

## Prerequisites
- PHASE_10 (real orders exist). Read: `04_UI/02_CUSTOMER_SCREENS.md` C13/C14, `03_FLUTTER/03`
  OrderRepository, `02_BACKEND/01` §orders rows, `00_MASTER` §state machine.

## Deliverables — exact files
```
customer_app/lib/features/orders/data/order_repository.dart
customer_app/lib/features/orders/data/models/order_summary.dart, order_detail.dart, order_item.dart
customer_app/lib/features/orders/presentation/order_list_page.dart     (C13)
customer_app/lib/features/orders/presentation/order_details_page.dart  (C14)
customer_app/lib/features/orders/widgets/order_status_timeline.dart
customer_app/lib/features/orders/widgets/order_status_chip.dart
test/features/orders/presentation/order_details_page_test.dart
test/features/orders/order_details_controller_test.dart
```

## Tasks
1. Repository per 03_FLUTTER/03 (own orders, newest first, status filter, page 20; details embed
   items + payment; 0 rows → NOT_FOUND).
2. C13: status dropdown (All + 8), cards/rows (number, date, total, chip), pagination, empty state
   "No orders yet" + "Start shopping".
3. C14: header card, vertical timeline (completed/current/future; CANCELLED → red banner with
   reason instead), items (snapshot name/sku + line totals + line tax), payment row
   ("Cash on Delivery — {status}"), shipping snapshot card, bill card.
4. NO cancel button or action anywhere in customer orders (00_MASTER §out of scope).
5. Tests per 05_TESTING/01 (timeline, banner, no-cancel, NOT_FOUND).

## Database impact
None.

## Verification commands
```
cd customer_app && dart format . && flutter analyze && flutter test
```
Manual: place order → appears in list; admin confirms (Phase 12 UI or SQL) → customer refresh
shows CONFIRMED in timeline; open another user's order id → NOT_FOUND state (never data).

## Acceptance criteria
- [ ] C13 + C14 acceptance criteria of 04_UI/02 all demonstrated (incl. cross-user NOT_FOUND).
- [ ] Timeline matches status after each admin transition (walk one order through 3 states).
- [ ] Cancelled order renders banner + reason, timeline hidden.
- [ ] `grep -rin "cancel" lib/features/orders/presentation/` → no customer cancel action.
- [ ] Filters + pagination verified with > 20 orders (SQL-insert extras if needed).

## Report
Use the templates in PHASE_00 § Report templates.
