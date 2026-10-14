# 02_E2E_AND_SECURITY.md — executable verification scenarios

Ids match 01_TEST_PLAN.md and the checklists in 01_DATABASE/02 (§A) and 01_DATABASE/03 (§B).
All SQL cases run on a FRESH seeded project (after 001–020) via `psql` or Supabase SQL editor,
each wrapped in `begin; … rollback;` unless stated. Helper used by every script:

```sql
-- act_as(userId) switches the session to that authenticated user (RLS applies)
create or replace function tests.act_as(p_user uuid) returns void language sql as $$
  select set_config('role','authenticated', true);
  select set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
$$;
create or replace function tests.act_as_anon() returns void language sql as $$
  select set_config('role','anon', true);
  select set_config('request.jwt.claims', '', true);
$$;
-- assert helpers
create or replace function tests.expect_rows(p_label text, p_sql text, p_min bigint) ...
create or replace function tests.expect_error(p_label text, p_sql text, p_msg_like text default null) ...
```

(Implement the two helpers as dynamic-SQL plpgsql in `database/tests/00_helpers.sql`; `expect_error`
catches SQLEXCEPTION, compares SQLSTATE/message, re-raises FAIL otherwise. Both print
`PASS <label>` / `FAIL <label> <detail>`.)

Test fixture identities (create in `00_helpers.sql` by inserting into `auth.users` — the
`handle_new_user` trigger then creates matching profiles):

| alias | email |
|---|---|
| `:cust_a` | `rls-a@example.com` |
| `:cust_b` | `rls-b@example.com` |
| `:admin`  | `rls-admin@example.com` (promote: `update profiles set role='admin' where email=…`) |

---

## A. RLS-C01…C12 — authorization cases (1:1 with 02_RLS_POLICIES checklist)

| Id | Actor | Action | Expected |
|---|---|---|---|
| C01 | cust A | `select * from orders` | only A's rows |
| C02 | cust A | `select * from orders where user_id = :cust_b` | 0 rows |
| C03 | cust A | `insert into orders (…)` direct table insert | error — no INSERT policy |
| C04 | cust A | `select * from inventory` | 0 rows |
| C05 | anon | `select * from products where not is_published` | 0 rows |
| C06 | anon | `select * from categories where not is_active` | 0 rows |
| C07 | cust A | `update profiles set role='admin' where id = :cust_a` | error FORBIDDEN (guard trigger) |
| C08 | cust A | `update profiles set is_active=false where id = :cust_a` | error FORBIDDEN |
| C09 | anon | `select * from app_settings` | 0 rows (anon has no select policy) |
| C10 | cust A | `select * from v_product_availability` | seeded products, booleans only |
| C11 | cust A | `insert into cart_items (cart_id = B's cart, …)` | 0 rows affected / FK-violation style failure — never a visible write |
| C12 | anon | storage upload to `product-images` | denied (storage policy) — verify via Storage API call, not SQL |

Also required (same script): cust A can CRUD **own** address row; cust A cannot `update` B's
notification; admin (`tests.act_as(:admin)`) CAN select orders of A and update `app_settings`.

## B. RPC-R1…R11 — business-logic cases (1:1 with 03_RPC_FUNCTIONS scenarios)

Setup per case: customer cart with items, address, settings row (charge 40, threshold 500).

| Id | Setup → action | Expected |
|---|---|---|
| R1 | product qty 1 → TWO concurrent sessions run `select create_order(addr, gen_random_uuid())` simultaneously | exactly one returns success; other errors OUT_OF_STOCK; `inventory.quantity` never < 0; exactly 1 order |
| R2 | call `create_order` twice with the SAME `p_idempotency_key` | 2nd returns `duplicate:true`, same `order_id`; only 1 order row, 1 payment row |
| R3 | subtotal 600 ≥ threshold 500 | `delivery_charge = 0` on order |
| R4 | subtotal 200 < threshold | `delivery_charge = 40` |
| R5 | price 100 × qty 2, tax 5% | order.tax = 10; total = subtotal + tax + delivery; matches items |
| R6 | `tests.act_as(:cust_b)` then `change_order_status(A's order, 'CONFIRMED')` | FORBIDDEN |
| R7 | admin cancels an order already PACKED | CONFLICT |
| R8 | admin cancels NEW order with `p_reason = null` | VALIDATION_ERROR |
| R9 | admin cancels NEW order with reason | inventory restored (+delta rows in inventory_transactions), payment → CANCELLED, notification row for customer exists |
| R10 | `adjust_inventory(product, -100, 'CORRECTION', 'x')` when qty 50 | VALIDATION_ERROR; quantity still 50; no new tx row |
| R11 | attempt total manipulation: call create_order with a cart whose product price was silently updated mid-flight (update price between lock attempt and rpc — or simply audit the produced order) | order totals derive ONLY from locked-read DB prices; any client-supplied total is impossible (function takes no total params) — assert order.total = recomputed Σ |
| R12 | put an unpublished product in the cart, then `create_order` | error `PRODUCT_UNAVAILABLE`, `details.skipped` lists product names; assert 0 new orders, inventory unchanged, cart_items untouched |

R1 execution note: run session A and session B with `begin; select pg_advisory_lock(...)` is NOT
used — genuinely concurrent: two `psql` tabs, both `select create_order(...)` fired together
(script a `\watch`-free pair or use a small shell `&` launcher provided in the script header).

## C. E2E-1…E2E-10 — user journeys

| Id | Journey | Verified by |
|---|---|---|
| E2E-1 | Golden path: register → logout → login → browse category → product → add to cart → add address → checkout → success screen shows order number → order in list with status NEW | integration_test `e2e_01` |
| E2E-2 | Search "seed", sort price asc, price filter, nonsense query shows empty + Clear filters | integration_test `e2e_02` |
| E2E-3 | Cart: add same product twice → qty 2; bump to 99; attempt beyond → capped; remove → confirm → gone; product deactivated by admin → row greys "Unavailable", excluded from totals | integration_test `e2e_03` |
| E2E-4 | Orders: customer list → details timeline; admin confirms then cancels (A12, with reason); customer app (refresh) shows CANCELLED + reason banner; A10 history shows restock rows. Customers have NO cancel action (out of scope) | integration `e2e_04` + A12 manual + SQL assert |
| E2E-5 | Admin broadcast → customer app (60 s poll or manual refresh) shows unread → tap marks read | integration `e2e_05` + SQL assert |
| E2E-6 | Admin catalog flow: create category → add attribute (SELECT) → create product with attribute value → upload image → publish → anon API read sees it (curl/psql as anon) | admin app manual walkthrough + SQL assert |
| E2E-7 | Stock sell-down: set qty 1 → customer orders the last unit → second attempt shows OUT_OF_STOCK dialog → A10 row red at/below min | e2e_01 variant + R1 |
| E2E-8 | Full lifecycle: NEW → CONFIRMED → PROCESSING → PACKED → SHIPPED → OUT_FOR_DELIVERY → DELIVERED; payment ends COLLECTED; customer timeline matches after each step | A12 clicks + SQL asserts after each step |
| E2E-9 | Double-submit: tap Place Order twice rapidly (test pump) → exactly ONE order; repeat with same idempotency key via API → duplicate:true replay | widget test `checkout_page_test` + R2 |
| E2E-10 | Security sweep (manual + SQL): run C01–C12 plus: cust A opens `/orders/<B's id>` in app → NOT_FOUND state; customer deep-links `/admin/dashboard` in admin app → bounced; anon curl POST to orders table → 401/403 | app runs + C-cases |

## D. SM-1…8 — state machine cases (00_MASTER §Order state machine)

| Id | From → To | Expected |
|---|---|---|
| SM-1 | NEW → CONFIRMED | success; notification row inserted |
| SM-2 | CONFIRMED → CANCELLED (reason) | success; restock; payment CANCELLED |
| SM-3 | PACKED → CANCELLED | CONFLICT |
| SM-4 | OUT_FOR_DELIVERY → DELIVERED | success; payment → COLLECTED |
| SM-5 | DELIVERED → PROCESSING | CONFLICT |
| SM-6 | CANCELLED → CONFIRMED | CONFLICT |
| SM-7 | SHIPPED → PROCESSING (skip back) | CONFLICT |
| SM-8 | `p_target_status = 'MAGICAL'` | VALIDATION_ERROR (unknown status) |

## E. MONEY-1…3 — money math

| Id | Case | Expected |
|---|---|---|
| MONEY-1 | price 99.99 × 3, tax 5% | line_total 299.97; line_tax = ROUND(299.97*5/100,2) = 15.00; order.tax = 15.00 |
| MONEY-2 | subtotal 100.10 + delivery 40 + tax 5.01 − discount 0 | total = 145.11 exactly (no float drift; verify `total = subtotal+delivery_charge+tax-discount` on stored row) |
| MONEY-3 | threshold 500; subtotals 499.99 / 500.00 | delivery 40 / 0 respectively (boundary is ≥) |

## F. Security failure catalog (each = a way the build could fail; verify before release)

| # | Failure mode | Detection | Where fixed |
|---|---|---|---|
| F1 | anonanauthenticated table writes | C03/C11 | RLS: no insert/update policies |
| F2 | cross-user reads (IDOR) | C01/C02, E2E-10 | owner checks `auth.uid() = user_id` |
| F3 | customer escalates to admin via API | C07/C08 | `profiles_guard` trigger |
| F4 | service-role key shipped in app | grep repo for `service_role` / `SUPABASE_SERVICE_KEY` — must be 0 hits | .env discipline; anon key only |
| F5 | client-trusted totals/stock/status | R11 | create_order has no total param; status only via RPC |
| F6 | oversell race | R1 | `FOR UPDATE` row locks |
| F7 | duplicate orders from double-tap | R2, E2E-9 | idempotency key UNIQUE + replay |
| F8 | unpublished product leaks | C05 | product select policy |
| F9 | storage abuse (oversize/type/anonymous) | C12 + upload >5 MB rejected client & bucket policy | storage policies + file_options |
| F10 | PII/secrets in logs | grep logger calls for password/token/phone | 03_BACKEND/02 logging rules |
| F11 | applied migration edited later | `git log database/migrations` — append-only | AGENTS.md rule |
| F12 | negative stock via direct table update | C04 (no access) + R10 (no RPC path) | inventory writable only by RPC |

Release gate: 0 FAIL across scripts 01–04, all 12 RLS rows verified, F1–F12 each explicitly signed
off in the Phase 15 report.
