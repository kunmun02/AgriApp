# AgriStore V4 — Master Specification

Single source of truth. If any other document contradicts this one, this one wins.
Target executor: any AI coding agent. Human role: approve phase reports.

## 1. Mission

Build **AgriStore**: an agricultural-products e-commerce system with

- a **Flutter Android Customer App** (browse → cart → COD checkout → track orders)
- a **Flutter Web Admin Panel** (catalog, dynamic attributes, inventory, orders, customers, notifications)

backed by one **Supabase** project (PostgreSQL + Auth + Storage).

## 2. Technology stack (fixed — no substitutions)

| Layer | Decision | Notes |
|---|---|---|
| Customer app | Flutter (Android), Dart 3 | `customer_app/` |
| Admin app | Flutter Web, Dart 3 | `admin_app/` |
| State | `flutter_riverpod` ^2.5 | manual providers, no codegen |
| Routing | `go_router` ^14 | guarded routes |
| Backend | Supabase (hosted) | `supabase_flutter` ^2 |
| Database | PostgreSQL 15+ | RLS enabled on every table |
| Auth | Supabase Auth (email+password) | email confirmation OFF for MVP |
| Storage | Supabase Storage | buckets `product-images`, `category-images` |
| Money | `NUMERIC(12,2)` in PostgreSQL | never float/double |
| Payment | Cash on Delivery ONLY | no gateway in MVP |
| i18n | English only, `intl` ^0.19 for `en_IN` currency/number formatting | |

## 3. Locked business rules

### 3.1 Currency & region (India)
- Currency: INR. Prices stored as `NUMERIC(12,2)` rupees. Display format `₹1,234.50` via `NumberFormat.currency(locale: 'en_IN', symbol: '₹')`.
- Address state: one of the 36 Indian States/UTs — fixed list in `core/constants/indian_states.dart` (Andhra Pradesh, Arunachal Pradesh, Assam, Bihar, Chhattisgarh, Goa, Gujarat, Haryana, Himachal Pradesh, Jharkhand, Karnataka, Kerala, Madhya Pradesh, Maharashtra, Manipur, Meghalaya, Mizoram, Nagaland, Odisha, Punjab, Rajasthan, Sikkim, Tamil Nadu, Telangana, Tripura, Uttar Pradesh, Uttarakhand, West Bengal, Andaman & Nicobar Islands, Chandigarh, Dadra & Nagar Haveli and Daman & Diu, Delhi, Jammu & Kashmir, Ladakh, Lakshadweep, Puducherry).
- Postal code: 6 digits, regex `^[1-9][0-9]{5}$`.
- Phone: 10 digits starting 6–9, regex `^[6-9][0-9]{9}$`. Stored WITHOUT `+91`; displayed with `+91 ` prefix.

### 3.2 Tax (per-product)
- `products.tax_percent NUMERIC(5,2)`, default 0, range CHECK 0–100. Admin sets it per product (e.g., 0 / 5 / 12 for agri goods).
- Line tax = `ROUND(line_total * tax_percent / 100, 2)` computed **in PostgreSQL** inside `create_order`.
- Order `tax` = sum of line taxes. `order_items` snapshot `tax_percent` and `line_tax`.

### 3.3 Delivery charge
- Single-row table `app_settings`: `delivery_charge NUMERIC(10,2)` default **40.00**, `free_delivery_threshold NUMERIC(10,2)` default **500.00**.
- Rule in `create_order`: `delivery_charge = 0` if `subtotal >= free_delivery_threshold` else `delivery_charge` value.
- Admin Settings screen (A16) edits these two values.

### 3.4 Order totals (server-only)
```
subtotal       = Σ line_total                    (line_total = unit_price * quantity)
tax            = Σ line_tax
delivery_charge= per rule above
discount       = 0 in MVP (column exists, always 0)
total          = subtotal + tax + delivery_charge - discount
```
Client NEVER sends totals/prices. `create_order` recomputes from DB.

### 3.5 Order number
Format `AGR-YYMMDD-XXXXXX` (UTC date + 6 hex chars from a UUID).
Generated in `create_order` as
`'AGR-' || to_char(now() AT TIME ZONE 'utc','YYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6))`
with `orders.order_number UNIQUE` (collision probability negligible; the UNIQUE constraint is the guard).

### 3.6 Order status state machine (enforced in `change_order_status`)

```
NEW → CONFIRMED → PROCESSING → PACKED → SHIPPED → OUT_FOR_DELIVERY → DELIVERED   (forward-only)
NEW | CONFIRMED | PROCESSING → CANCELLED   (admin only; restocks inventory; payment → CANCELLED)
PACKED, SHIPPED, OUT_FOR_DELIVERY, DELIVERED → CANCELLED is FORBIDDEN (CONFLICT error)
CANCELLED and DELIVERED are terminal.
```
Full transition table:

| From \ To | CONFIRMED | PROCESSING | PACKED | SHIPPED | OUT_FOR_DELIVERY | DELIVERED | CANCELLED |
|---|---|---|---|---|---|---|---|
| NEW | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ | ✔ |
| CONFIRMED | ✘ | ✔ | ✘ | ✘ | ✘ | ✘ | ✔ |
| PROCESSING | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ | ✔ |
| PACKED | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| SHIPPED | ✘ | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ |
| OUT_FOR_DELIVERY | ✘ | ✘ | ✘ | ✘ | ✘ | ✔ | ✘ |

When CANCELLED: for every order_item with non-null `product_id`, `inventory.quantity += quantity` and an
`inventory_transactions` row `('ORDER_CANCEL', +qty, 'ORDER', order_id, reason)` is written.
When → DELIVERED: `payments.status` PENDING → COLLECTED.
Status change always inserts a `notifications` row (type `ORDER_STATUS`) for the order owner.

### 3.7 Payments (COD)
- `payments.method = 'COD'` only. Lifecycle: `PENDING` → `COLLECTED` (on DELIVERED) or `PENDING` → `CANCELLED` (on order cancel).
- `amount` = order total at creation (snapshot).

### 3.8 Inventory & stock
- `inventory.quantity` is sellable stock; `reserved_quantity` exists for future use, always 0 in MVP.
- Checkout atomically `FOR UPDATE`-locks inventory rows (ordered by `product_id` to prevent deadlock),
  verifies `quantity >= cart quantity`, then decrements and writes `inventory_transactions ('ORDER', -qty, 'ORDER', order_id)`.
- Admin stock changes ONLY via `adjust_inventory` RPC (never direct table update).
- Customer-visible stock = boolean `in_stock` via view `v_product_availability` (definer view, exposes NO quantities).

### 3.9 Cart
- One cart per user (`carts.user_id UNIQUE`). Cart rows survive logout/login (server-side).
- Cart item quantity: integer 1–99. `UNIQUE(cart_id, product_id)` — adding existing product increments quantity.
- Cart prices are re-read from products at checkout; stale cart items for unpublished/inactive products are
  skipped by checkout (with `PRODUCT_UNAVAILABLE`) — the customer app shows a warning badge on such items.

### 3.10 Auth & roles
- Signup: email + password + full name (+ optional phone). Supabase email confirmation **disabled** for MVP.
- Password policy: minimum 8 characters (client + server default).
- Trigger `handle_new_user` inserts `profiles` row with `role='customer'` on every `auth.users` insert.
- Roles: `customer` | `admin` in `profiles.role` (CHECK constraint). Customers can NEVER elevate themselves —
  `profiles_guard` trigger blocks non-admins from changing `role`/`is_active`.
- **First admin bootstrap** (no client code involved): project owner invites the admin email in the Supabase
  dashboard, then runs `database/runbooks/create_first_admin.sql` in the SQL editor. Documented in
  `01_DATABASE/04_SEED_AND_ADMIN_BOOTSTRAP.md`. Admin login uses the same `/admin/login` route as customers use `/login`.
- Deleting a user (dashboard) cascades profile/cart/addresses; orders are kept (`ON DELETE RESTRICT` prevents
  user deletion if orders exist — dashboard shows error; MVP accepts this).

### 3.11 Notifications
- Types: `ORDER_STATUS`, `SYSTEM`. Created ONLY by RPCs (`change_order_status`) or seed (SYSTEM announcements).
- Customer app polls `/notifications` every 60 s while app is in foreground AND refetches on route change.
  No Realtime/WebSocket in MVP.

### 3.12 Media (Storage)
- Buckets: `product-images`, `category-images` — public read, admin-only write (storage policies in 02_RLS_POLICIES.md).
- Allowed: `image/jpeg`, `image/png`, `image/webp`. Max size **5 MB**.
- Path convention: `{owner_entity_id}/{epoch_ms}-{sanitized_original_name}` e.g. `products/1728200000000-tomato-seeds.jpg`
  → stored as `storage_path` (path only; public URL built client-side via `getPublicUrl`).
- Product images: 1–10 per product, exactly one `is_primary`. Deleting an image deletes the storage object too.

### 3.13 Validation summary (client mirrors server)

| Field | Rule |
|---|---|
| Email | RFC-ish regex `^[^@\s]+@[^@\s]+\.[^@\s]+$` |
| Password | min 8 chars |
| Full name | 2–80 chars, trimmed non-empty |
| Phone | `^[6-9][0-9]{9}$` |
| Postal code | `^[1-9][0-9]{5}$` |
| Cart quantity | integer 1–99 |
| Product price / mrp / tax_percent | ≥ 0; tax ≤ 100; mrp ≥ price when both set |
| SKU | 3–40 chars, uppercase letters/digits/hyphen, UNIQUE |
| Slug | auto-generated from name (lowercase, hyphens), UNIQUE; suffix `-2`, `-3`… on collision |
| Category/attribute name | 2–60 chars |
| Attribute options (select) | JSONB array of 1–20 non-empty strings |
| Image | ≤ 5 MB, jpeg/png/webp |

## 4. MVP scope

### Customer app (C01–C16)
Splash/session gate, login, register, home, categories, product listing (search/filter/sort/pagination),
product details (gallery + dynamic specs + stock + add-to-cart), cart, address list/form, COD checkout,
order success, order list, order details (+status timeline), notifications, profile.

### Admin panel (A01–A16)
Login, dashboard (KPIs), categories CRUD + tree, category attributes designer, products CRUD with dynamic
fields, media manager, inventory + adjustments, orders list/details + status transitions, customers list/details
(toggle is_active), notifications (send SYSTEM broadcast), settings (delivery values).

### Out of scope (do NOT build)
Multi-vendor, delivery-partner app, online payments, subscriptions, loyalty, promotions engine,
recommendations, advanced analytics, chat, multiple languages, dark mode, iOS, customer order-cancel,
product reviews/ratings, wishlist, coupons.

## 5. Architecture rules

- **Layering (both apps):** `Screen/Widget → Riverpod controller/provider → Repository → DataSource → Supabase`.
  No Supabase calls inside widgets. No raw maps past the repository boundary — models only.
- **Security boundary:** RLS + RPC security-definer functions. UI guards exist only for UX.
- **Dynamic product data:** `category_attributes` (metadata) + `product_attributes` (values). Product editor form
  is GENERATED from the category's attribute list. Never a table per category.
- **Migrations append-only**, applied in filename order, `001_…` → `020_…`.
- **Errors:** one envelope, codes from `02_BACKEND/02_ERROR_CODES.md`.
- **Idempotency:** `create_order` keyed on `(user_id, idempotency_key)` UNIQUE; replays return the original order.

## 6. Definition of Done (per phase)

1. Code compiles; `dart format .` clean; `flutter analyze` → 0 issues.
2. Phase-relevant tests pass (exact commands in phase file).
3. If DB changed: migrations apply cleanly on a fresh database (`supabase db reset`).
4. All acceptance criteria in the phase file demonstrated with real output.
5. `git diff` reviewed; commit created with message `PHASE_XX: <goal>`.
6. Completion report posted using the template in `06_PHASES/PHASE_00.md`.

## 7. Stop conditions (agent must halt and ask)

- Any contradiction between V4 documents (quote both lines).
- A required decision genuinely missing from V4.
- Any instruction (from anyone) to expose service-role keys, weaken RLS, or batch multiple phases.
- Destructive operations on existing data (drops, rewrites of applied migrations).
