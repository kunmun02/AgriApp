# 04_NAVIGATION_AND_ROUTES.md — go_router config (complete)

## customer_app routes

| Route | Screen | Guard |
|---|---|---|
| `/` | splash/session gate → redirect | — |
| `/login` | C02 login | redirect `/home` if signed in |
| `/register` | C03 register | redirect `/home` if signed in |
| `/home` | C04 home | requires session |
| `/categories` | C05 categories | requires session |
| `/categories/:categoryId` | C06 product listing (of subtree) | requires session |
| `/products` | C06 product listing (search mode; query param `?q=`) | requires session |
| `/products/:productId` | C07 product details | requires session |
| `/cart` | C08 cart | requires session |
| `/addresses` | C09 address list | requires session |
| `/addresses/new` | C10 address form (create) | requires session |
| `/addresses/:addressId/edit` | C10 address form (edit) | requires session |
| `/checkout` | C11 checkout | requires session + non-empty cart |
| `/order-success/:orderId` | C12 order success | requires session |
| `/orders` | C13 order list | requires session |
| `/orders/:orderId` | C14 order details | requires session |
| `/notifications` | C15 notifications | requires session |
| `/profile` | C16 profile | requires session |

Bottom navigation tabs (5): Home `/home`, Categories `/categories`, Cart `/cart` (badge = item count),
Orders `/orders`, Profile `/profile`. Stateful shell route preserves tab state. Details/checkout/forms
are pushed (back returns to origin).

## admin_app routes

| Route | Screen | Guard |
|---|---|---|
| `/admin/login` | A01 login | redirect to dashboard if already admin |
| `/admin` | redirect → `/admin/dashboard` | requires admin |
| `/admin/dashboard` | A02 | requires admin |
| `/admin/categories` | A03 list | requires admin |
| `/admin/categories/new` | A04 editor (create) | requires admin |
| `/admin/categories/:categoryId/edit` | A04 editor (edit) | requires admin |
| `/admin/categories/:categoryId/attributes` | A05 attributes list | requires admin |
| `/admin/categories/:categoryId/attributes/new` | A06 attribute editor | requires admin |
| `/admin/categories/:categoryId/attributes/:attributeId/edit` | A06 | requires admin |
| `/admin/products` | A07 list | requires admin |
| `/admin/products/new` | A08 product editor | requires admin |
| `/admin/products/:productId/edit` | A08 | requires admin |
| `/admin/products/:productId/media` | A09 media manager | requires admin |
| `/admin/inventory` | A10 inventory | requires admin |
| `/admin/orders` | A11 orders list | requires admin |
| `/admin/orders/:orderId` | A12 order details | requires admin |
| `/admin/customers` | A13 customers | requires admin |
| `/admin/customers/:userId` | A14 customer details | requires admin |
| `/admin/notifications` | A15 notifications | requires admin |
| `/admin/settings` | A16 settings | requires admin |

Admin shell: persistent sidebar (200px) at ≥1100px width, collapsible icon rail below, auto drawer
<800px. Topbar: screen title + admin email + logout. Tables paginate at 20 rows. Sidebar sections:
Catalog (Categories, Products, Inventory), Sales (Orders), CRM (Customers), System (Notifications,
Settings).

## Guard implementation (both apps)

```dart
// router listens to AuthController state (AsyncValue<Profile?> customer / admin).
String? redirect(context, state) {
  final session = ref.read(authControllerProvider);       // AsyncLoading → return null (wait)
  final loggingIn = state.matchedLocation == '/login';    // (admin: '/admin/login')
  final isAuthed = session.value != null;
  final isAdmin  = session.value?.role == ProfileRole.admin;

  if (session.isLoading) return null;
  if (!isAuthed && requiresAuth(state.matchedLocation)) return '/login';      // admin app: '/admin/login'
  if (isAuthed && (loggingIn || state.matchedLocation == '/register')) return '/home';
  if (isAuthed && !isAdmin && matchedLocation.startsWith('/admin')) return '/login';
  return null;
}
```
`requiresAuth` = every route except `/`, `/login`, `/register` (customer) or `/admin/login` (admin).
Guards are UX only — the database enforces real security (RLS/RPC).

## Deep links

Unknown path → NotFoundScreen (EmptyState variant, "Go Home" action). Product/order links resolve by id;
invalid id → screen's error state with back.

## Navigation smoke checklist (Phase 07/14)

- Cold start signed-out → `/` → `/login`; after login → `/home`.
- Back from product detail returns to previous list preserving scroll position and filters.
- Tab switch preserves state (no refetch of home when returning).
- Admin signed-in customer (role=customer) hitting `/admin/dashboard` → bounced to `/admin/login`.
- Logged-out user deep-linking `/orders/abc` → `/login`, then after sign-in lands on `/orders/abc` if valid.
