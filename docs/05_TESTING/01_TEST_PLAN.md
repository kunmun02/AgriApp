# 01_TEST_PLAN.md — complete test file list and named cases

Stack: `flutter_test` (unit + widget), `integration_test` (customer app E2E), plain SQL scripts for
DB/RLS (psql / Supabase SQL editor), `mocktail` for fakes. CI run order: format → analyze → unit →
widget → DB scripts (against a disposable project or local supabase) → integration.

Rules:
- One test file per production file under the mirrored `test/` path.
- A phase is not done until its listed cases pass; report actual `flutter test` output lines.
- DB scripts are idempotent-safe to re-run on a fresh project; never run against production.
- Never commit real credentials; integration tests use `--dart-define-from-file=.env.test`.

## customer_app/test/

| File | Level | Named cases |
|---|---|---|
| `core/utils/formatters_test.dart` | unit | `inr formats 1234567.5 as ₹12,34,567.50`; `inr handles 0`; `dateShort formats dd MMM yyyy` |
| `core/utils/validators_test.dart` | unit | `email rejects missing @`; `phone rejects 5-start`; `phone accepts 9876543210`; `postal rejects 6 digits starting 0`; `postal accepts 560001`; `quantity rejects 0 and 100`; `sku lowercase rejected`; `password min length` |
| `core/errors/error_mapper_test.dart` | unit | `P0001 json body maps to ApiFailure code`; `P0001 non-json → INTERNAL_ERROR`; `42501 → FORBIDDEN`; `PGRST116 → NOT_FOUND`; `SocketException → NetworkFailure`; `unknown → INTERNAL_ERROR` |
| `core/utils/category_tree_test.dart` | unit | `builds nested tree from flat list`; `orphans attach to roots`; `keeps display_order` |
| `features/auth/data/profile_dto_test.dart` | unit | `fromJson role customer`; `fromJson role admin`; `unknown role → customer` |
| `features/products/data/models_test.dart` | unit | `ProductCard.fromJson price string parsed`; `in_stock bool read`; `ProductDetail attributes+images embedded parse`; `OrderItem snapshot keys read (product_name_snapshot, sku_snapshot)`; `OrderStatus fromJson exact strings` |
| `features/cart/cart_controller_test.dart` | unit (mocktail) | `addItem existing row bumps quantity capped at 99`; `removeItem filters list`; `totals = Σ line totals`; `unavailable items excluded from totals` |
| `features/checkout/checkout_controller_test.dart` | unit (mocktail) | `createOrder success navigates payload returned`; `OUT_OF_STOCK maps to friendly message`; `PRODUCT_UNAVAILABLE maps to unavailable dialog with skipped names`; `DUPLICATE_REQUEST treated as success (replay)`; `generates UUID idempotency key once per submit` |
| `features/orders/order_details_controller_test.dart` | unit (mocktail) | `NOT_FOUND for foreign order id → error state` |
| `features/auth/presentation/login_page_test.dart` | widget | `renders email+password`; `invalid email shows inline error, no repo call`; `wrong credentials shows server message`; `success navigates /home`; `button disabled while submitting` |
| `features/auth/presentation/register_page_test.dart` | widget | `mismatch confirm blocks submit`; `duplicate email message` |
| `features/products/presentation/product_card_test.dart` | widget | `shows price, strike MRP when mrp>price`; `out-of-stock chip`; `placeholder image when none` |
| `features/products/presentation/product_details_page_test.dart` | widget | `specs render in display order`; `out of stock disables add-to-cart`; `add-to-cart double-tap single call` |
| `features/cart/presentation/cart_page_test.dart` | widget | `quantity stepper updates line total`; `remove asks confirm`; `empty state with CTA`; `checkout disabled when cart empty` |
| `features/addresses/presentation/address_form_page_test.dart` | widget | `postal 5 digits enforced`; `phone pattern enforced`; `save calls repo with parsed values`; `default toggle clears others (repo called)` |
| `features/checkout/presentation/checkout_page_test.dart` | widget | `shows address, totals, ₹delivery`; `subtotal ≥ threshold → FREE`; `place-order double-tap creates ONE order (button locks)`; `OUT_OF_STOCK dialog with item names`; `success navigates /order-success/:id` |
| `features/orders/presentation/order_details_page_test.dart` | widget | `timeline renders created→current`; `no cancel action exists for customers (out of scope)`; `cancelled order shows reason banner, no timeline` |
| `features/notifications/presentation/notifications_page_test.dart` | widget | `unread dot`; `tap marks read via rpc repo` |
| `core/router/router_test.dart` | widget | `signed-out /home redirects /login`; `signed-in /login redirects /home`; `unknown → not-found screen`; `deep link /orders/:id after sign-in lands on it` |

## admin_app/test/

| File | Level | Named cases |
|---|---|---|
| `core/utils/formatters_test.dart` | unit | same as customer (shared copy) |
| `core/errors/error_mapper_test.dart` | unit | same as customer |
| `features/products/presentation/product_editor_page_test.dart` | widget | `category locked on edit (disabled dropdown + helper)`; `required attribute empty blocks publish but not draft`; `MRP < price inline error`; `tax 0–100 enforced`; `sku uppercase enforced`; `switching category re-renders attribute fields` |
| `features/attributes/presentation/attribute_editor_page_test.dart` | widget | `key suggested from name snake_case`; `key+type disabled on edit`; `SELECT requires ≥1 option` |
| `features/inventory/presentation/inventory_page_test.dart` | widget | `adjust dialog negative preview blocks submit`; `success snackbar shows 30 → 45`; `low stock row red` |
| `features/orders/presentation/order_details_page_test.dart` | widget | `NEW renders only Confirm/Cancel`; `cancel requires reason`; `delivered renders no actions`; `CONFLICT error refetches details` |
| `features/notifications/presentation/broadcast_dialog_test.dart` | widget | `empty title/body inline errors`; `double-submit locked` |
| `features/settings/presentation/settings_page_test.dart` | widget | `negative charge blocked`; `threshold 0 helper shows disabled text` |
| `core/router/router_test.dart` | widget | `customer-role sign-in bounced to /admin/login + signed out`; `signed-out /admin/dashboard → /admin/login` |

## database/ (scripts, not dart test)

Runner note: execute top to bottom on a fresh project; each script prints PASS/FAIL per case and
must end with zero FAIL lines. Full case text lives in `05_TESTING/02_E2E_AND_SECURITY.md`
(RLS-C01…C12, RPC-R1…R11, SM-1…8, MONEY-1…3).

| Script | Covers |
|---|---|
| `database/tests/01_rls_cases.sql` | RLS-C01…C12 (02_E2E_AND_SECURITY §A) |
| `database/tests/02_rpc_cases.sql` | RPC-R1…R11 (02_E2E_AND_SECURITY §B) |
| `database/tests/03_state_machine.sql` | SM-1…8 (transition matrix) |
| `database/tests/04_money_math.sql` | MONEY-1…3 (tax rounding, totals identity, free delivery) |

## integration_test/ (customer app, Android emulator or Chrome)

Driver: `flutter test integration_test --dart-define-from-file=.env.test`. Seeded accounts:
`test-customer@example.com` / `Test!2345` and one admin (used only to seed data via SQL before run).

| File | Journey |
|---|---|
| `e2e_01_auth_shop_checkout.dart` | register → logout → login → browse → add to cart → address → checkout → success (E2E-1) |
| `e2e_02_search_and_filters.dart` | search, sort, price filter, empty state (E2E-2) |
| `e2e_03_cart_lifecycle.dart` | add, bump qty cap 99, remove, unavailable excluded (E2E-3) |
| `e2e_04_orders_status_tracking.dart` | order list → details timeline reflects admin status changes; cancelled shows reason banner (E2E-4) |
| `e2e_05_notifications.dart` | broadcast appears, unread badge clears (E2E-5) |

(E2E-6…10 in 02_E2E_AND_SECURITY §C are executed as scripted manual/SQL hybrid runs where a
second device/emulator is impractical; each has an executable SQL assertion.)

## Exit criteria per phase

1. `dart format --set-exit-if-changed .` → clean.
2. `flutter analyze` → 0 issues.
3. `flutter test` → all listed files green (paste the summary line in the report).
4. Phase DB scripts (if touched) → 0 FAIL.
5. Acceptance criteria of the phase's screens demonstrate in running app (screenshots in report).
