# PHASE_12 — Admin orders & inventory (A10/A11/A12)

## Goal
Inventory table with the adjust dialog and history, the orders list with filters, and order details
with state-machine-driven action buttons (the admin is the only actor who can change status).

## Prerequisites
- PHASE_03 (repos stubbed), PHASE_06 (products), PHASE_10/11 (orders exist). Read:
  `04_UI/03_ADMIN_SCREENS.md` A10/A11/A12, `01_DATABASE/03` change_order_status + adjust_inventory,
  `00_MASTER` §state machine transition matrix, `03_FLUTTER/03` AdminInventoryRepository +
  AdminOrderRepository.

## Deliverables — exact files
```
admin_app/lib/features/inventory/data/admin_inventory_repository.dart   (complete: list, adjust, transactions)
admin_app/lib/features/inventory/presentation/inventory_page.dart       (A10)
admin_app/lib/features/inventory/widgets/adjust_stock_dialog.dart
admin_app/lib/features/inventory/widgets/transaction_history_dialog.dart
admin_app/lib/features/orders/data/admin_order_repository.dart          (complete: list, details, changeStatus)
admin_app/lib/features/orders/presentation/orders_list_page.dart        (A11)
admin_app/lib/features/orders/presentation/order_details_page.dart      (A12)
admin_app/lib/features/orders/widgets/order_action_bar.dart             (transition buttons per current status)
test/features/inventory/presentation/inventory_page_test.dart
test/features/orders/presentation/order_details_page_test.dart (admin side)
```

## Tasks
1. A10: search + low-stock-only (client filter of page), red rows when `quantity <= min_stock_level`,
   Adjust dialog (type RESTOCK/CORRECTION, signed delta ≠ 0, reason required 3–200, live
   "X → Y" preview blocking negative), History dialog (last 50, +green/−red deltas).
2. A11: status chip bar with accent dot on NEW, order-number search, paginated table, row → A12,
   back preserves filter + page.
3. A12 per 04_UI/03: action bar renders ONLY allowed transitions (matrix in 00_MASTER); confirm
   dialogs; cancel reason dialog; post-success refetch; CONFLICT/OUT_OF_STOCK server errors →
   snackbar + refetch; customer block; items with snapshots (null product_id → "(deleted product)");
   totals; payment section; timeline (created_at, payment changes, last update).
4. Verify double-admin race: two tabs confirm the same NEW order → one success, one CONFLICT
   snackbar, both pages refetch.

## Database impact
None (RPCs exist).

## Verification commands
```
cd admin_app && dart format . && flutter analyze && flutter test
# SM-1…8 can be driven via this UI now; R7–R9 re-verified manually here:
select quantity from inventory where product_id = :p;   -- before/after cancel → restored
select status from payments where order_id = :o;        -- CANCELLED / COLLECTED as applicable
```

## Acceptance criteria
- [ ] A10–A12 acceptance criteria of 04_UI/03 all demonstrated (all Gherkin blocks).
- [ ] Adjust RESTOCK +40 reason "PO #12" → row refresh + history row; delta −50 past zero blocked
      by preview AND server.
- [ ] Walk a NEW order to DELIVERED via UI — exactly the allowed buttons appear at each step;
      payment ends COLLECTED.
- [ ] Cancel from NEW/CONFIRMED/PROCESSING restocks inventory + payment CANCELLED + reason banner;
      cancel from PACKED → CONFLICT snackbar.
- [ ] Double-admin confirm race → single success + CONFLICT on the other, both UIs consistent.
- [ ] SM-1…8 from 05_TESTING/02 §D all pass (via UI where possible, SQL otherwise).

## Report
Use the templates in PHASE_00 § Report templates.
