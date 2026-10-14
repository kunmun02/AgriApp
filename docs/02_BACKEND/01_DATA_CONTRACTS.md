# 01_DATA_CONTRACTS.md — JSON shapes, pagination, storage, polling

Field names below are EXACTLY what Supabase returns (PostgREST uses table/column names).
Dart models in `03_FLUTTER/02_MODELS.md` map these keys 1:1 via `fromJson`/`toJson`.

## 1. Pagination envelope

All list endpoints use offset paging with exact counts:

- Request params: `from = (page - 1) * pageSize`, `limit = pageSize` — `pageSize` fixed **20**.
- Query: `.range(from, from + pageSize - 1).count('exact')`
- Repository returns `Paginated<T>`:

```json
{ "items": [ ... ], "total": 137, "page": 3, "pageSize": 20, "hasMore": true }
```

`hasMore = (page * pageSize) < total`.

## 2. Row shapes (selected columns per endpoint)

### categories (list/tree)
```json
{ "id": "uuid", "parent_id": null, "name": "Seeds", "slug": "seeds",
  "description": "...", "image_path": null, "display_order": 1, "is_active": true }
```
Tree built client-side from flat list (all active rows, no paging; ≤ 200 rows expected).

### category_attributes (per category, admin editor + product form generator)
```json
{ "id": "uuid", "category_id": "uuid", "name": "Seed Variant", "attribute_key": "seed_variant",
  "data_type": "select", "options": ["Hybrid","Desi"], "is_required": true,
  "display_order": 1, "is_active": true }
```

### products — LIST card projection (customer + admin)
```json
{ "id": "uuid", "name": "Tomato Hybrid Seeds", "slug": "tomato-hybrid-seeds", "sku": "SEED-TOM-001",
  "brand": "AgriPlus", "price": "149.00", "mrp": "199.00", "tax_percent": "5.00",
  "is_active": true, "is_published": true,
  "primary_image_path": "aaaa.../1728200000000-tomato.jpg",   // from join, nullable
  "in_stock": true }                                           // from v_product_availability
```
PostgREST returns NUMERIC as JSON **strings** — models must parse with `num.tryParse`.
Customer list query (embed images + availability):
```
products.select('id,name,slug,sku,brand,price,mrp,tax_percent,product_images(storage_path,is_primary,display_order),v_product_availability(in_stock)')
  .eq('is_active', true).eq('is_published', true) ...
```
`primary_image_path` = the embedded image with smallest `display_order` (client picks).

### products — DETAIL (customer)
```
products.select('*,category:categories(id,name,slug),product_attributes(category_attribute_id,value_text,value_number,value_boolean,value_json,attribute:category_attributes(name,attribute_key,data_type,options,display_order)),product_images(id,storage_path,is_primary,display_order),v_product_availability(in_stock)')
  .eq('id', productId).eq('is_active', true).eq('is_published', true).single()
```
Attributes sorted client-side by `attribute.display_order`.

### inventory (admin)
```json
{ "product_id": "uuid", "quantity": 42, "reserved_quantity": 0,
  "min_stock_level": 5, "updated_at": "2026-10-06T10:00:00+00:00" }
```

### cart (customer) — items embed product card fields
```
cart_items.select('id,quantity,product:products(id,name,slug,sku,price,mrp,brand,is_active,is_published,product_images(storage_path,is_primary,display_order),v_product_availability(in_stock))')
  .eq('cart_id', cartId).order('created_at')
```
An item whose product is `!is_active || !is_published` renders with the unavailable badge and is
excluded from the "proceed to checkout" button state (but remains visible; user removes it).

### orders — LIST
```json
{ "id": "uuid", "order_number": "AGR-261006-A1B2C3", "status": "CONFIRMED",
  "total": "538.00", "created_at": "2026-10-06T10:00:00+00:00",
  "item_count": 3, "first_image_path": "..." }   // item_count/first_image: client-side from detail fetch OR embed
```
List embed: `orders.select('id,order_number,status,total,created_at,order_items(line_total),...')` —
MVP keeps list simple: `id, order_number, status, total, created_at` only.

### orders — DETAIL
```
orders.select('*,items:order_items(*),payment:payments(method,status,amount),profile:profiles(full_name,phone)')
```
Admin detail additionally selects `user:profiles(id,email,full_name,phone)`.

### shipping_snapshot (inside order rows)
```json
{ "recipient_name": "Ramesh Kumar", "phone": "9876543210",
  "line1": "12/4 Main Road", "line2": "Near Bus Stand", "city": "Nashik",
  "state": "Maharashtra", "postal_code": "422001", "country": "India" }
```

### notifications
```json
{ "id": "uuid", "type": "ORDER_STATUS", "title": "Order AGR-... updated",
  "body": "Your order status is now Out For Delivery.",
  "data": { "order_id": "uuid", "status": "OUT_FOR_DELIVERY" },
  "is_read": false, "created_at": "..." }
```

### app_settings
```json
{ "delivery_charge": "40.00", "free_delivery_threshold": "500.00" }
```

## 3. RPC call contracts

| RPC | Client call | Success result (jsonb) | Failure |
|---|---|---|---|
| create_order | `rpc('create_order', params:{p_address_id, p_idempotency_key})` | `{duplicate,order_id,order_number,total}` | error envelope (02) |
| change_order_status | `rpc('change_order_status', params:{p_order_id,p_target_status,p_reason})` | `{order_id,status}` | error envelope |
| adjust_inventory | `rpc('adjust_inventory', params:{p_product_id,p_delta,p_transaction_type,p_reason})` | `{product_id,new_quantity}` | error envelope |
| mark_notification_read | `rpc('mark_notification_read', params:{p_notification_id})` | `null` | error envelope |

`p_idempotency_key`: UUID v4 generated ONCE per checkout submission attempt and held in controller
state; reused on retry of the same submission, regenerated when the user changes the cart/address.

## 4. Storage conventions

- `product-images/{product_id}/{epoch_ms}-{original_name_sanitized}`
- `category-images/{category_id}/{epoch_ms}-{original_name_sanitized}`
- Sanitize: lowercase, spaces→`-`, keep `[a-z0-9._-]`, strip everything else, max 60 chars.
- Upload: `storage.from(bucket).uploadBinary(path, bytes, contentType)` or `upload` with `File`;
  then `getPublicUrl(path)` for display. DB stores the PATH, never the URL.
- Public URL format: `{SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}`.
- Delete: remove storage object first, then DB row (and vice-versa failures retried once; orphans are acceptable in MVP and noted).

## 5. Sessions, polling, realtime

- Session: `supabase_flutter` persists the session automatically (no custom storage).
- Notifications polling: `Timer.periodic(60 s)` while app lifecycle is `resumed` + refetch on every
  go_router navigation. Unread count badge = `count` query with `.eq('is_read', false)`.
- No `.stream()`/Realtime anywhere in MVP.

## 6. Search & filter contract (customer product listing)

| Param | Client source | Query |
|---|---|---|
| `q` | search box | `.ilike('name', '%$q%')` |
| `categoryId` | tapped category | `.eq('category_id', id)` (includes descendants — client resolves subtree first) |
| `sort` | dropdown | `price_asc` → `.order('price')`; `price_desc` → `.order('price', ascending:false)`; `newest` → `.order('created_at', ascending:false)` (default) |
| `inStockOnly` | toggle | filter on embedded `v_product_availability.in_stock` client-side |
| `minPrice`/`maxPrice` | range inputs | `.gte('price', min)` `.lte('price', max)` |
| page | pagination | §1 envelope |

Admin product list adds filters: `status` (all/published/draft/inactive), `sku` exact, `category`.
Admin orders list filters: `status` dropdown, `order_number` ilike, date range (`created_at`).
Admin customers list: search on email/full_name ilike, page 20.
