# 03_ADMIN_SCREENS.md — A01–A16 full specification

Format per screen: route, purpose, data, layout (top→bottom), actions, states, acceptance criteria.
Every screen obeys the states contract (04_UI/01 §States), the admin shell (04_UI/04 §admin_app:
sidebar ≥1100px, icon rail below, drawer <800px, topbar with title + admin email + logout), and
paginates tables at 20 rows with the standard `Paginated` controls (Prev / "Page X of Y" / Next,
hidden when total ≤ 20). Screens NEVER call Supabase directly — only the repositories in
03_FLUTTER/03 §admin_app. Guards are UX only; RLS/RPC is the security boundary.

---

## A01 Admin Login — `/admin/login`

Data: `AdminAuthRepository.signIn` then `requireAdminProfile()`.

Layout: centered card (max width 400): "AgriStore Admin" title, email field, password field
(obscured), primary button "Sign in".

Validation: email format, password ≥ 8 (inline errors, values preserved).

Actions: submit. Success → `requireAdminProfile()`: role == admin → `/admin/dashboard`;
role != admin → **sign out immediately** + error "This account is not an admin". Failure → inline
server message ("Invalid email or password").

States: loading on button; error card never leaks whether the email exists.

**AC:**
```gherkin
Given an admin account, signing in lands on /admin/dashboard.
When a customer-role account signs in, they are signed out with "This account is not an admin"
  and land back on /admin/login (never the dashboard).
When offline, a NetworkFailure message shows and field values are preserved.
```

## A02 Dashboard — `/admin/dashboard`

Data (all read-only, no new backend): `AdminOrderRepository.list(page:1)` → first 10 rows for
"Recent orders"; four count queries built on repositories: orders today (`countOrdersCreatedToday()` —
head-count `from('orders').select('id', head:true, count:exact).gte('created_at', startOfTodayUtc)`),
new orders (`countNewOrders()` — same with `.eq('status','NEW')`), customers (`countCustomers()` —
head-count `.eq('role','customer')`), products (`countProducts()` — head-count `.eq('is_active', true)`).
Low stock: `AdminInventoryRepository.list(page:1, lowStockOnly:true)` → take up to 10.

Layout:
1. KPI row (4 StatCards): "Orders today", "New orders" (accent color when > 0), "Customers",
   "Products"
2. Row: "Low stock" card (up to 10 rows: product name, sku, qty/min) each tap → `/admin/products/:productId/edit`;
   "Recent orders" card (10 rows: order_number, created_at short, total ₹, status badge) tap → `/admin/orders/:orderId`

Actions: KPI cards tap → their list screens; pull-to-refresh not applicable (web) — refresh icon in
section headers refetches.

States: skeleton shimmer cards on load; section empty states ("No low stock items 🎉" → use text
"No low stock items", no emoji).

**AC:**
```gherkin
Given 3 orders exist created today, "Orders today" shows 3 after load and after refresh.
When an order is created by a customer in another tab, pressing refresh on dashboard updates counts.
Tapping a low-stock row navigates to that product's editor.
```

## A03 Categories — `/admin/categories`

Data: `AdminCategoryRepository.fetchAll()` (flat, includes inactive).

Layout:
1. Header row: "Categories" title + button "New category" → `/admin/categories/new`
2. Tree table: Name (indent children by level icon), Slug, Display order, Active switch, Products
   count (optional column), Actions: Edit (→ A04 edit), Attributes (→ A05), Deactivate
   (ConfirmDialog "Deactivate category 'X'? Products remain but are hidden from customers.")
3. Inactive rows render greyed with an "Inactive" chip.

Actions: see above. Activate again = toggle the Active switch (update).

States: table skeleton; empty → "No categories yet" + "New category" action; error → retry.

**AC:**
```gherkin
Given a parent with 2 children, the tree shows indentation and each row has Edit/Attributes actions.
When a category is deactivated, it greys out and disappears from the customer app on next fetch.
Deactivation always asks for confirmation first.
```

## A04 Category Editor — `/admin/categories/new` and `/admin/categories/:categoryId/edit`

Data: create → `AdminCategoryRepository.create`; edit → fetch by id from `fetchAll()` result or
`fetchSingle` via repository; image → `uploadImage`.

Layout (sectioned form, "Save Draft and Publish are separate when applicable" — for categories a
single "Save" plus Active toggle):
1. Section "Details": Name (2–80, required), Parent category dropdown (roots + "None"; a category
   cannot select itself or its own descendant as parent — client-checked, backend also guarded by
   self-FK sanity in repository loop prevention), Description (textarea, ≤ 500)
2. Section "Visibility": Display order (int ≥ 0), Active switch
3. Section "Image" (edit mode or after create): current image preview + "Upload image"
   (file_picker, 5 MB, jpg/png/webp) + "Remove image" (storage delete + null path, confirm)
4. Footer: Cancel (back), Save button

Behavior: slug auto-generated from name (`lowercase-kebab`), editable, client pattern
`^[a-z0-9]+(-[a-z0-9]+)*$`; on 23505 the repository appends `-2`, `-3`… and retries (documented
loop), final result shown in the field after save.

Actions: Save → success snackbar "Category saved" → back to A03. Create flow saves first, then image
section becomes available (create returns the new Category).

Validation: name required; parent cannot be self/descendant; image size/type checked before upload
with inline error.

**AC:**
```gherkin
Given name "Fertilizers", saving creates slug "fertilizers"; saving a second one creates
  "fertilizers-2" without error.
When a parent tries to select its own child as parent, the dropdown disables that option.
Uploading a 6 MB file shows an inline error and does not call storage.
```

## A05 Attributes — `/admin/categories/:categoryId/attributes`

Data: `AdminAttributeRepository.fetchForCategory(categoryId)`; category name from A03 repo.

Layout:
1. Header: "Attributes — {category name}" + breadcrumb link back to Categories + button
   "New attribute" → `.../attributes/new`
2. Table: Name, Key (code style), Type (TEXT/NUMBER/BOOLEAN/SELECT), Required (check icon),
   Order, Active switch, Actions: Edit (→ A06), Deactivate (confirm; note shown:
   "Existing product values are kept; the field stops appearing on product forms.")

States/AC:
```gherkin
Given a category with 3 attributes, all render in display_order with type chips.
When an attribute is deactivated, it disappears from A08's dynamic form for new edits.
Header shows the parent category name; breadcrumb returns to A03.
```

## A06 Attribute Editor — `/admin/categories/:categoryId/attributes/new` and `.../:attributeId/edit`

Data: create/update via `AdminAttributeRepository`.

Layout (single sectioned form):
1. Name (required, 2–60)
2. Attribute key: auto-suggested from name (snake_case) on CREATE, editable only on create,
   pattern `^[a-z][a-z0-9_]{1,39}$`, unique per category (23505 → inline "Key already exists for
   this category"). On EDIT the key field is disabled with helper text "Key is locked once created".
3. Data type dropdown: TEXT, NUMBER, BOOLEAN, SELECT (display labels; stored/JSON values are the
   lowercase DB strings 'text'/'number'/'boolean'/'select') — locked on edit (values already stored
   against it; helper text explains)
4. Options editor (visible only when type = SELECT): tag-style input, ≥ 1 option, each trimmed,
   duplicates rejected inline
5. Required switch, Display order (int ≥ 0), Active switch
6. Footer: Cancel, Save

Actions: Save → back to A05 with snackbar.

**AC:**
```gherkin
Given name "Soil Type", the key field pre-fills "soil_type" and is editable before first save.
When editing, key and data type fields are disabled and a helper text explains why.
SELECT with zero options blocks save with "Add at least one option".
```

## A07 Products — `/admin/products`

Data: `AdminProductRepository.list({query, sku, categoryId, filter, page})`.

Layout:
1. Header: "Products" + button "New product" → `/admin/products/new`
2. Filter row: search field (name, debounced 400 ms), SKU field, category dropdown (from
   `fetchAll`), status dropdown (All / Published / Draft / Inactive), Apply + Clear
3. Table (paginated): Thumb (primary image or placeholder), Name, SKU, Category, Price ₹,
   Stock (from availability — quantity if shown by list embed, else dash), Status chips
   (Published / Draft / Inactive), Actions: Edit, Media, Publish/Unpublish toggle,
   Deactivate (confirm)

Actions: publish toggle calls `publish(id, bool)` — publishing is allowed even with 0 images
(customer UI shows placeholder). Deactivate → confirm dialog.

States: skeleton rows; empty → "No products match the filters" + Clear; error → retry.

**AC:**
```gherkin
Given 25 products, page 2 loads rows 21–25 and the pager shows "Page 2 of 2".
Filtering status=Draft lists only unpublished, active products.
Toggling Publish immediately changes the chip and is reflected in the customer listing on next fetch.
Search by exact SKU returns exactly that product row.
```

## A08 Product Editor — `/admin/products/new` and `/admin/products/:productId/edit`

Data: `AdminProductRepository.details(id)` (edit), `AdminCategoryRepository.fetchAll()`,
`AdminAttributeRepository.fetchForCategory(selectedCategoryId)` (drives the DYNAMIC form),
`create` / `update` / `saveAttributes`.

Layout (sectioned form, desktop two-column where noted):
1. Section "Basics": Category dropdown (roots+children flattened, shows full path "Fertilizers ›
   Urea"). **Create mode: selectable. Edit mode: disabled** with helper "Category is locked after
   creation because attribute values are bound to it." Name (3–120, required), Slug (auto from
   name, pattern as A04, 23505 → suffix loop), SKU (required, `^[A-Z0-9-]{3,40}$`, uppercase
   enforced on input, unique → 23505 inline "SKU already exists"), Brand (optional, ≤ 60),
   Description (textarea ≤ 5000)
2. Section "Pricing" (two-column): Price ₹ (required, > 0, ≤ 2 decimals), MRP ₹ (≥ price; when
   equal, no strike-through shows to customers), Tax % (0–100, default 0, hint "Applied per product
   at checkout")
3. Section "Attributes — {category name}": **generated form** from the category's ACTIVE
   attributes sorted by displayOrder. Per type: TEXT → TextField (≤ 200); NUMBER → numeric field
   (decimal allowed); BOOLEAN → switch; SELECT → dropdown of options. Required attributes show `*`
   and block save when empty. Attributes left empty (non-required) are simply not saved. Note under
   section: "Fields come from the category definition — manage them under Categories › Attributes."
4. Section "Stock" (create mode only): Initial quantity (int ≥ 0, default 0). Edit mode: not shown —
   stock changes go through A10 only (hint link → `/admin/inventory`).
5. Section "Media" (edit mode): primary image preview + "Manage media" button → A09.
   Create mode: hint "Save the product first to upload images."
6. Footer (sticky): "Save draft" (primary-outline; sets is_published=false, stays on page) and
   "Publish" (primary; sets is_published=true after validation passes) — per spec A08 the two are
   separate. Cancel → back.

Save semantics: `create` inserts product + inventory row (quantity from section 4) + provided
attribute values; `update` persists base fields then `saveAttributes` with replace-set semantics
(removed fields deleted, provided values upserted). After any save, if required attributes were
filled at create but category has none, form shows "This category has no attributes" muted text.

Validation: every rule inline; publish blocked with a summary bar listing failing fields; draft save
allows empty required attributes.

**AC:**
```gherkin
Given category "Urea" has NUMBER attribute "Nitrogen %" required, publishing without it shows
  an inline error and a summary bar; Save draft succeeds with the field empty.
When price 100 and MRP 80 are entered, MRP field shows "MRP must be ≥ price" and blocks save.
Switching to a different category at CREATE re-renders the attribute section for that category.
In EDIT mode the category dropdown is disabled with the explanatory helper text.
Publishing a product makes it visible to an anonymous API read of products.
An out-of-range tax 150 is rejected inline ("0–100").
```

## A09 Media Manager — `/admin/products/:productId/media`

Data: `AdminMediaRepository` (fetchImages, upload, setPrimary, reorder, delete).

Layout:
1. Header: "Media — {product name}" + back to product editor + "Upload images" (file_picker,
   multi-select, jpg/png/webp, 5 MB each)
2. Grid (responsive, ~160 px tiles): image (1:1), overlay badge "Primary" on the primary,
   hover/press actions per tile: "Set primary", "◀ Move left", "Move right ▶", Delete (trash →
   ConfirmDialog "Delete this image? This cannot be undone.")
3. Order note: "The first image is the primary image shown to customers."

Behavior: first upload auto-becomes primary. Reorder uses Move left/right buttons (deterministic —
no drag-drop in MVP) calling `reorder`. Upload loop shows per-file progress text ("Uploading 2 of
3…"); a failed file shows which one failed and continues others. Delete calls storage remove first,
then row delete; if storage object is already gone, row delete still proceeds.

**AC:**
```gherkin
Given 3 images, moving the third left swaps it to position 2 and order persists after reload.
Setting image 2 as primary moves the badge; customer detail page carousel order matches A09 order.
Deleting the primary image promotes the next image to primary (first remaining).
A 6 MB upload is rejected with a per-file error message; other selected files still upload.
```

## A10 Inventory — `/admin/inventory`

Data: `AdminInventoryRepository.list`, `adjust` (rpc `adjust_inventory`), `transactions`.

Layout:
1. Header: "Inventory" + filter: search (name/sku) + "Low stock only" checkbox
2. Table (paginated): Product (name + sku), Quantity (bold; red when ≤ min), Reserved, Min level,
   Last updated, Actions: "Adjust" button, "History" icon
3. Adjust dialog: product name header, Type dropdown (RESTOCK / CORRECTION), Delta (int ≠ 0,
   signed input with +/- prefix), Reason (required, 3–200), live preview "New quantity: X → Y"
   (X + delta; negative preview blocks submit), Submit → loading → success snackbar "Stock updated:
   30 → 45" → row refreshes
4. History dialog: last 50 transactions for the product — type, delta (+green/−red), reason,
   created_at, created_by email if available

Behavior: OUT_OF_RANGE server results (delta would go negative) → inline dialog error
"Resulting stock cannot be negative".

**AC:**
```gherkin
Given quantity 5 and min 10, the row renders red and appears under "Low stock only".
Adjust RESTOCK +40 reason "PO #12" updates quantity to 45 and writes a transaction visible in History.
Adjust with delta −50 (would be −5) is blocked with the negative-stock message, both client preview
  and server check.
Two admins adjusting simultaneously both produce separate transaction rows and a correct final total.
```

## A11 Orders — `/admin/orders`

Data: `AdminOrderRepository.list({status, query, page})`.

Layout:
1. Header: "Orders"
2. Filter row: status chip bar (All, NEW, CONFIRMED, PROCESSING, PACKED, SHIPPED, OUT_FOR_DELIVERY,
   DELIVERED, CANCELLED) + search field (order_number exact, debounced)
3. Table (paginated): Order number (code style), Date (dd MMM yyyy, HH:mm), Customer name,
   Items count, Total ₹, Status badge (color per 04_UI/01), → row tap opens A12

States: NEW count shown as an accent dot on the chip; empty → "No orders match".

**AC:**
```gherkin
Filtering NEW shows only status NEW; the chip shows an accent dot when count > 0.
Searching an exact order number navigates the table to that single row.
Row click opens A12 for that order; back returns to A11 preserving page and active filter.
```

## A12 Order Details — `/admin/orders/:orderId`

Data: `AdminOrderRepository.details` (order + items + payment + customer profile embed) and
`changeStatus` (rpc `change_order_status`).

Layout:
1. Header: order_number + Status badge + "Customer" block (name, email, phone — from profile,
   NOT from snapshot alone)
2. Action bar (top-right) — **only the allowed next transitions render as buttons**, per the
   transition matrix in 00_MASTER §Order state machine:
   NEW → Confirm / Cancel · CONFIRMED → Start processing / Cancel · PROCESSING → Mark packed /
   Cancel · PACKED → Mark shipped · SHIPPED → Mark out for delivery · OUT_FOR_DELIVERY → Mark
   delivered · DELIVERED / CANCELLED → none. Cancel always opens a reason dialog (required, 3–200).
   Positive transitions confirm inline ("Mark shipped?") via ConfirmDialog.
3. Section "Items" table: Product (name snapshot; "(deleted product)" style when product_id null),
   SKU snapshot, Unit price ₹, Qty, Line total ₹
4. Section "Totals" card: Subtotal, Delivery ₹, Tax ₹, Discount ₹ (0 in MVP — row hidden),
   Total ₹ (bold)
5. Section "Shipping address" — snapshot card (recipient, phone, full address lines) with note
   "Snapshot at order time"
6. Section "Payment": method COD, status chip (PENDING / COLLECTED / CANCELLED), amount
7. Section "Timeline": created_at, payment status changes (payment.updated_at + status), last
   order update (orders.updated_at + current status) — chronological list; cancel reason shown
   in red when CANCELLED (reason stored on order per schema)

Behavior: status button → loading state on that button only → success snackbar "Order marked
{STATUS}" → badge and action bar re-render. Cancellation via RPC restocks inventory and flips
payment to CANCELLED server-side; the UI simply refetches details after success and shows a muted
banner "This order was cancelled. Reason: {reason}". OUT_OF_STOCK on confirm (rare) → error
snackbar with the server message; details refetch to show current truth.

**AC:**
```gherkin
Given a NEW order, exactly "Confirm" and "Cancel" buttons render — no PACKED/SHIPPED shortcuts.
Confirming a NEW order moves it to CONFIRMED and the customer's order list reflects it on refetch.
Cancel requires a reason; the dialog blocks empty submit; after cancel the banner with the reason
  shows, payment becomes CANCELLED and inventory rows are restocked (verify in A10 History).
A DELIVERED order renders no action buttons.
Marking delivered flips payment to COLLECTED (visible in the Payment section).
Two admins clicking Confirm simultaneously: one succeeds, the other gets a CONFLICT error snackbar
  and the page refetches to CONFIRMED.
```

## A13 Customers — `/admin/customers`

Data: `AdminCustomerRepository.list({query, page})`.

Layout:
1. Header: "Customers"
2. Search row: name/email contains, debounced 400 ms
3. Table (paginated): Name, Email, Phone (or —), Orders count (optional column; dash in MVP if
   not fetched), Joined (created_at date), Active switch (→ `setActive` with confirm:
   "Deactivate this customer? They will not be able to sign in."), row tap → A14

States: empty "No customers found"; the signed-in admin's own account never appears (role filter).

**AC:**
```gherkin
Searching by email substring returns matching rows within one request after debounce.
Toggling Active off asks for confirmation; afterwards that customer's sign-in fails with
  invalid-credentials-style error (backend behavior) and the switch can be re-enabled.
Customers list never shows admin-role accounts.
```

## A14 Customer Details — `/admin/customers/:userId`

Data: `AdminCustomerRepository.details` + `ordersOf(userId, page)`.

Layout:
1. Profile card: avatar initial, name, email, phone, joined date, active chip + same
   Activate/Deactivate action as A13
2. Section "Orders" (paginated table): same columns as A11, row tap → `/admin/orders/:orderId`

States: customer not found → NOT_FOUND error state with back.

**AC:**
```gherkin
Opening a customer shows their profile and their orders newest-first, paginated at 20.
Tapping an order navigates to A12 and back returns to A14.
An invalid user id renders the NOT_FOUND error state, never a blank page.
```

## A15 Notifications — `/admin/notifications`

Data: `AdminNotificationRepository.list`, `broadcast`.

Layout:
1. Header: "Notifications" + button "New broadcast"
2. Broadcast dialog: Title (required, 3–80), Body (required, 3–500), live preview line "Will be sent
   to N active customers" (N = head-count of active customer profiles), Submit → loading
   (button text "Sending…") → success snackbar "Broadcast sent to N customers"
3. Table (paginated, newest first): Title, Type chip (ORDER/SYSTEM), Recipient (user email or
   "broadcast" group), Created, Read count if derivable (dash in MVP)

Behavior: broadcast loops `insert` of one SYSTEM row per active customer profile (repository
documented as sequential inserts; partial failure reports "Sent to X of N"). Marking read is a
customer action; admins cannot mark read.

**AC:**
```gherkin
Broadcasting "Price drop" to 4 active customers creates 4 SYSTEM rows and shows "Sent to 4 customers".
Deactivated customers are excluded from the recipient count and do not receive the row.
The dialog validates empty title/body inline and disables double-submit while sending.
```

## A16 Settings — `/admin/settings`

Data: `AdminSettingsRepository.fetch` / `update` (app_settings single row).

Layout:
1. Header: "Settings"
2. Card "Delivery" (two-column): Delivery charge ₹ (≥ 0, 2 decimals), Free delivery threshold ₹
   (≥ 0), live helper under threshold: "Orders with subtotal ≥ ₹X get free delivery". When
   threshold = 0, helper shows "Free delivery is disabled".
3. Card "Store" (read-only in MVP): App name "AgriStore", Currency "INR (₹)", Support contact
   placeholder — display only, no editor
4. Footer: Save → success snackbar "Settings saved"

Behavior: values arrive as JSON strings (NUMERIC) → parse with `num.tryParse`; save sends doubles.
Customer checkout (C11) reflects new values on next fetch — no cache-busting needed beyond
provider refresh on screen entry.

**AC:**
```gherkin
Changing delivery charge to 50 and saving persists; reopening A16 shows 50; a new checkout summary
  in the customer app shows ₹50 delivery.
Entering a negative charge shows "Must be ≥ 0" and blocks save.
Setting threshold 200 with charge 50 makes a ₹250-subtotal cart show "FREE" delivery at checkout.
```

---

## Cross-screen rules (admin)

1. **Optimistic UI is forbidden everywhere.** Every mutation waits for the server response, then
   refreshes the affected row/section from the response or refetch. Failures revert nothing because
   nothing changed client-side.
2. **ConfirmDialog required for:** deactivate category, deactivate attribute, delete image,
   deactivate product, customer deactivate, cancel order, every positive order transition.
   Confirmation text states the consequence ("This cannot be undone." where true).
3. **Error copy:** use ErrorMapper codes — never show raw PostgresException to the user; log the
   raw error without PII (03_BACKEND/02 §logging).
4. **Buttons:** every submit button shows a spinner and is disabled while loading (no double
   submits); table row actions disable for that row only.
5. **Money/number display:** `Formatters.inr` everywhere (₹, en_IN grouping); dates `dd MMM yyyy`,
   datetimes add `HH:mm` — one shared formatter set only.
