# PHASE_09 — Cart (C08)

## Goal
Complete cart screen: items with steppers and removal, unavailable handling, totals preview,
badge sync. Checkout still lands in Phase 10.

## Prerequisites
- PHASE_08 (cart repository subset). Read: `04_UI/02_CUSTOMER_SCREENS.md` C08, `03_FLUTTER/03`
  CartRepository (full), `02_BACKEND/01` §cart embed.

## Deliverables — exact files
```
customer_app/lib/features/cart/data/cart_repository.dart     (complete: fetchItems, updateQuantity, removeItem)
customer_app/lib/features/cart/controllers/cart_controller.dart   (StateNotifier: items, totals preview, mutations)
customer_app/lib/features/cart/presentation/cart_page.dart        (C08)
test/features/cart/cart_controller_test.dart
test/features/cart/presentation/cart_page_test.dart
```

## Tasks
1. Cart embed per 02_BACKEND/01: items join products (name, price, image primary, published+active)
   + availability view.
2. CartController: fetch, add, updateQuantity (client 1–99), remove (with confirm), derived
   subtotal and item count; unavailable rows (product unpublished/inactive) shown grey with
   "Unavailable" chip and EXCLUDED from totals.
3. C08 per 04_UI/02: summary card "Subtotal" + "Delivery calculated at checkout" note + checkout
   button (disabled when no available items).
4. Badge: `CartBadgeController` refreshes after every mutation (including Phase 08's addItem).

## Database impact
None.

## Verification commands
```
cd customer_app && dart format . && flutter analyze && flutter test
```
Manual: add product → qty 2 → bump to 99 → attempt 100 blocked; remove → confirm → gone; admin
deactivates a product in another tab → refresh shows grey row excluded from totals; badge correct
after each action; empty cart → EmptyState with "Start shopping".

## Acceptance criteria
- [ ] C08 acceptance criteria of 04_UI/02 demonstrated.
- [ ] Quantity cap 99 enforced client-side (server CHECK is the backstop).
- [ ] Unavailable item excluded from subtotal (test with real deactivated product).
- [ ] Remove requires confirmation; no accidental deletes.
- [ ] Controller tests green (cap, totals, exclusion, removal).

## Report
Use the templates in PHASE_00 § Report templates.
