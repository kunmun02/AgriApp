# PHASE_10 — Checkout (C09/C10/C11/C12)

## Goal
Address book + form, the COD checkout screen with server-authoritative totals preview, idempotent
place-order with failure handling, and the success screen.

## Prerequisites
- PHASE_09. Read: `04_UI/02_CUSTOMER_SCREENS.md` C09–C12, `03_FLUTTER/03` AddressRepository +
  CheckoutRepository, `02_BACKEND/01` §RPC calls + §app_settings, `01_DATABASE/03` create_order,
  `00_MASTER` §totals + §validation.

## Deliverables — exact files
```
customer_app/lib/features/addresses/data/address_repository.dart
customer_app/lib/features/addresses/data/models/address.dart
customer_app/lib/features/addresses/presentation/address_list_page.dart    (C09)
customer_app/lib/features/addresses/presentation/address_form_page.dart    (C10)
customer_app/lib/features/checkout/data/checkout_repository.dart           (fetchSettings + createOrder)
customer_app/lib/features/checkout/data/models/app_settings.dart
customer_app/lib/features/checkout/controllers/checkout_controller.dart    (totals preview + place order)
customer_app/lib/features/checkout/presentation/checkout_page.dart         (C11)
customer_app/lib/features/checkout/presentation/order_success_page.dart    (C12)
customer_app/lib/core/utils/idempotency.dart   (UUID v4 per checkout attempt; consumed on success OR replay)
test/features/addresses/presentation/address_form_page_test.dart
test/features/checkout/presentation/checkout_page_test.dart
```

## Tasks
1. Addresses: C09 list (default first), C10 form with full validation (name, `^[6-9]\d{9}$` phone,
   line1, city, state dropdown of 36 states/UTs, `^[1-9]\d{5}$` postal, country default India);
   default handling = clear-others-then-set (repository's two ops).
2. C11 layout per 04_UI/02: address picker (link to C09/C10), items summary (read-only), totals
   card = Subtotal + Delivery (`app_settings`: subtotal ≥ threshold → "FREE") + Tax
   `Σ ROUND(line × tax_percent/100, 2)` + Total, COD note, Place Order.
3. Place order: generate idempotency UUID when the user ARRIVES at C11 (one per attempt), disable
   button while loading; success → clear badge → `/order-success/:orderId`; failure mapping:
   OUT_OF_STOCK dialog listing item names + "Back to cart", PRODUCT_UNAVAILABLE same pattern,
   DUPLICATE_REQUEST → treat as success and navigate (replay), NetworkFailure → keep key, offer
   Retry with the SAME key.
4. C12: success visuals + order number + "View order" / "Continue shopping".
5. Tests per 05_TESTING/01 (checkout cases incl. double-tap single order).

## Database impact
None (RPC exists since Phase 01).

## Verification commands
```
cd customer_app && dart format . && flutter analyze && flutter test
# double-tap test + manual:
select count(*) from orders where user_id = :me;   -- exactly 1 after double-tap
select delivery_charge from orders;                 -- 0 when subtotal ≥ threshold, else setting value
```

## Acceptance criteria
- [ ] C09–C12 acceptance criteria of 04_UI/02 all demonstrated.
- [ ] Double-tap Place Order → exactly ONE order (SQL proof); button locked while loading.
- [ ] OUT_OF_STOCK failure → dialog names the items; cart still intact; retry from cart works.
- [ ] FREE delivery shown at boundary subtotal == threshold (use settings 500 vs cart 500).
- [ ] Totals on screen always match the created order row (server numbers, not client math —
      client preview is cosmetic and labeled as estimate only if it can drift).
- [ ] New default address demotes previous default (check DB).

## Report
Use the templates in PHASE_00 § Report templates.
