# 02_CUSTOMER_SCREENS.md — C01–C16 full specification

Format per screen: route, purpose, data, layout (top→bottom), actions, states, acceptance criteria.
Every screen obeys the states contract (04_UI/01 §States) and validation copy rules.

---

## C01 Splash / Session Gate — `/`
Full-screen background `#F6F7F6`, centered logo text "AgriStore" (headlineSmall, primary color) +
LinearProgressIndicator. Logic: restore session (≤3 s timeout) → `session != null ? /home : /login`.
**AC:** cold start signed-out lands `/login`; signed-in lands `/home`; no flash of login for signed-in users.

## C02 Login — `/login`
Data: `AuthRepository.signIn`. Layout: logo, title "Welcome back", email field, password field
(obscured, visibility toggle), primary button "Login", text button "New user? Register".
Validation: email format; password ≥ 8. Submit: button → loading; success → snackbar + `/home`;
failure → inline/server message (wrong credentials → "Invalid email or password").
**AC:**
```gherkin
Given a registered customer, when they submit valid credentials, they land on /home.
When credentials are wrong, an inline error shows and no navigation happens.
When offline, a NetworkFailure snackbar shows and the form values are preserved.
```

## C03 Register — `/register`
Fields: full name (2–80), email, phone (optional, `^[6-9]\d{9}$`), password, confirm password
(must match). Submit → `signUp` (auto sign-in since confirmation disabled) → `/home` with welcome
snackbar. Server 23505 (email exists) → "An account with this email already exists".
**AC:** valid signup lands home; mismatched confirm shows inline error; duplicate email shows friendly error; all inputs preserved on failure.

## C04 Home — `/home`
Layout top→bottom:
1. Search bar (readonly field, tap → `/categories` with search focus)
2. Horizontal banner area — static "Fresh farm supplies" card (asset image, no CMS)
3. "Categories" title + horizontal scroll of category circles (CachedImage or leaf icon placeholder), tap → `/categories/:id`
4. "Popular Products" title + vertical grid (2 cols) of ProductCards — `popularProducts()`
Actions: pull-to-refresh. States: skeleton on load; empty categories → EmptyState "No categories yet".
**AC:** signed-in cold load shows categories + 8 products; tap product → details; tap category → listing; pull-to-refresh refetches both.

## C05 Categories — `/categories`
`fetchActiveCategories()` → tree. Layout: search bar (real input, submit → `/categories/:id` is NOT used;
search submits to Product Listing with `q`, pushed as `/products?q=` variant of C06), then expandable
category tree (ExpansionTile per root; children indented, tap child → listing).
**AC:** tree renders parents with children; tapping any node opens listing for that node; searching "seed" opens listing with q=seed.

## C06 Product Listing — `/categories/:categoryId` (also `/products?q=…`)
Query params: `q`, optional. Data: `listProducts(query, categoryId, sort, page)`.
Layout: AppBar title = category name or "Search: q"; sort dropdown (Newest, Price ↑, Price ↓);
price min/max inputs (collapsible "Filters" row); grid 2 cols ProductCard + PaginatedListView.
Filter `inStockOnly` toggle filters current page client-side.
Empty → "No products found" + "Clear filters" action. Error → retry.
**AC:**
```gherkin
Given 25 published products in a category, scrolling loads page 2 (total 25 shown).
When sort Price ↑ is chosen, the first card is the cheapest.
When q has no matches, empty state with Clear filters appears.
Unpublished or inactive products never appear (verify via API as anon).
```

## C07 Product Details — `/products/:productId`
Data: `productDetails(id)`. Layout:
1. Image carousel (PageView, 4:3, page indicator, CachedImage; no images → placeholder)
2. Name (titleMedium), brand (bodySmall secondary), price row: price + MRP strikethrough if mrp>price + tax note "Incl. {tax_percent}% tax"
3. Stock: in_stock → green "In stock" else red "Out of stock"
4. QuantityStepper (1–99, cap: none — stock boolean only in MVP)
5. AppButton "Add to Cart" (disabled when out of stock) — adds, shows snackbar "Added to cart", cart badge increments
6. "Specifications" section — generated from attributes sorted by displayOrder: row = name : displayValue
7. "Description" section (body text)
**AC:**
```gherkin
Given a published product with attributes, specs render in displayOrder.
When out of stock, Add to Cart is disabled with grey style.
When product id is invalid or unpublished, error state with back appears.
Add to cart twice creates ONE cart item with quantity 2 (not two rows).
```

## C08 Cart — `/cart`
Data: `CartController` (items, totals preview). Layout:
1. Items list: CachedImage thumb, name, unit price, QuantityStepper, remove (trash icon → ConfirmDialog), line total; unavailable items show grey overlay + "Unavailable" chip and are excluded from totals
2. Price summary card: Subtotal, note "Delivery calculated at checkout"
3. AppButton "Proceed to Checkout" — disabled when no available items; → C11
Empty → EmptyState "Your cart is empty" + action "Browse products" → `/categories`.
Mutation failures (update qty) → snackbar + revert value.
**AC:**
```gherkin
Quantity + / − updates server value and line total; badge count updates.
Removing the only item shows the empty state.
Unavailable product stays visible but excluded from subtotal and checkout.
Quantity capped at 99 (stepper disables +).
```

## C09 Address List — `/addresses`
Data: addresses newest/default first. Layout: list of cards (label chip, recipient, phone +91-formatted, one-line address, Default chip), tap → select-and-return mode when pushed from checkout (returns Address); trailing edit → C10, delete → ConfirmDialog → delete.
"Add Address" AppButton → C10. Empty → EmptyState "No addresses yet" + "Add Address".
**AC:** default sorts first; delete asks confirmation; long address elides; select mode returns the tapped address.

## C10 Address Form — `/addresses/new`, `/addresses/:id/edit`
Fields: Label (dropdown: Home/Work/Farm/Other, default Home), Recipient name, Phone (10-digit,
numeric keyboard), Line1, Line2 (optional), City, State (dropdown of 36), Pincode, "Set as default"
switch. Validation per Master §3.13. Save → create/update → back + snackbar. Edit mode pre-fills.
Default handling: setting default clears previous default (repository two-step).
**AC:** invalid pincode/phone shows inline errors; save disabled while submitting; edit round-trips all fields; new default replaces old default.

## C11 Checkout — `/checkout`
Guard: cart has ≥1 available item (else redirect `/cart`).
Data: addresses, app_settings, cart items (for summary only).
Layout:
1. Delivery address selector: radio list of addresses + "Add new" → C09 select-mode → returns
2. Price summary: Subtotal, Delivery (shows "FREE" when subtotal ≥ threshold, else ₹40), Tax (Σ line tax preview), Total (large)
3. Payment: static radio "Cash on Delivery" (checked, disabled)
4. AppButton "Place Order" — generates idempotency key on entry; loading state during rpc; success →
   clear cart state → `/order-success/:orderId` (pushReplacement, clears stack to `/orders` root? No:
   pushReplacement to success; back from success → `/orders`)
Failure handling: OUT_OF_STOCK/PRODUCT_UNAVAILABLE → dialog naming product + "Review cart" → `/cart`;
DUPLICATE/other → snackbar + stay.
**AC:**
```gherkin
Given subtotal 600, delivery shows FREE and total = subtotal + tax.
Given subtotal 300, delivery ₹40 added.
Double-tap Place Order creates exactly ONE order (button disables while loading).
Killing the app mid-submit and retrying with same key returns the SAME order (idempotency).
Losing a stock race shows the dialog with the product name.
```

## C12 Order Success — `/order-success/:orderId`
Data: `orderDetails(orderId)`. Layout: centered success icon (check circle, success color),
"Order placed!", order number (copyable), total, "Expected: admin confirmation" note,
buttons: "View Order" → C14, "Continue Shopping" → `/home` (clear stack).
**AC:** shows correct number/total from server response; Continue Shopping clears navigation stack to home.

## C13 Order List — `/orders`
Data: `myOrders(page)` newest first. Layout: PaginatedListView of cards: order number (titleMedium),
StatusChip, total, created date, thumbnail strip (item images if embedded — MVP: omit), tap → C14.
Status filter dropdown (All + 8 statuses). Empty → "No orders yet" + "Start shopping".
**AC:** pagination loads page 2; filter CONFIRMED shows only confirmed; tap navigates with detail.

## C14 Order Details — `/orders/:orderId`
Data: `orderDetails`. Layout:
1. Header card: order number, StatusChip, placed date
2. Status timeline (vertical steps): NEW → CONFIRMED → PROCESSING → PACKED → SHIPPED → OUT_FOR_DELIVERY → DELIVERED; completed steps filled, current pulsing dot, future grey; CANCELLED replaces timeline with red banner + cancel_reason
3. Items list (name, sku, qty × unit price, line total, line tax)
4. Payment row: "Cash on Delivery — {payment.status}"
5. Shipping snapshot card (all 8 fields)
6. Bill card: Subtotal, Delivery, Tax, Total (bold)
**AC:**
```gherkin
Timeline reflects status; delivered order shows all steps filled.
Cancelled order hides timeline and shows reason banner.
Cross-user id (B's order id opened by A) → NOT_FOUND error state, never B's data.
```

## C15 Notifications — `/notifications`
Data: `fetch(page)` + unread badge reset on open (mark each visible unread as read via rpc on tap;
"Mark all read" AppBar action loops rpcs). Layout: PaginatedListView of tiles: icon (truck for
ORDER_STATUS, megaphone for SYSTEM), title, body 2 lines, time ago, unread dot. Tap → if
data.order_id → C14 else expands tile in place.
Empty → "No notifications".
**AC:** unread dot clears after tap; order notification navigates to that order; badge on tab clears.

## C16 Profile — `/profile`
Layout: avatar circle (initials), name, email, phone (or "Add phone" → inline edit), "Edit profile"
(full name + phone form), list tiles: My Addresses → C09, My Orders → C13, Notifications → C15,
Logout (danger) → ConfirmDialog → signOut → `/login` (clear stack).
**AC:** edits persist and reflect on re-login; logout returns to login and guards block back-navigation to tabs.
