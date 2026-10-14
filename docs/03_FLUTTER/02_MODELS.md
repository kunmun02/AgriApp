# 02_MODELS.md — Every Dart model (fields, JSON keys, rules)

All models: immutable, `const` constructors where possible, `fromJson(Map<String,dynamic>)`,
`toJson()` where needed for forms, `copyWith`. NUMERIC columns arrive as JSON **strings** — parse with
`num.tryParse`. Timestamps arrive ISO-8601 — parse `DateTime.tryParse`. Place in
`core/models/` (shared concepts) or `features/<f>/data/models/` (feature-local); MVP: one file per
model under `core/models/` in both apps (admin imports only what it needs).

| Model | Fields (type) | JSON key | Notes |
|---|---|---|---|
| Profile | id String, fullName String, email String, phone String?, role ProfileRole enum, isActive bool, createdAt DateTime | id, full_name, email, phone, role, is_active, created_at | role: `customer`/`admin` |
| Category | id, parentId?, name, slug, description?, imagePath?, displayOrder int, isActive bool | id, parent_id, name, slug, description, image_path, display_order, is_active | tree built via helper `CategoryTree.build(List<Category>)` |
| CategoryAttribute | id, categoryId, name, attributeKey, dataType AttributeType enum, options List<String>, isRequired bool, displayOrder int, isActive bool | id, category_id, name, attribute_key, data_type, options, is_required, display_order, is_active | dataType: `text`/`number`/`boolean`/`select` (lowercase DB strings); options parsed from JSONB array |
| ProductCard | id, name, slug, sku, brand?, price double, mrp double?, taxPercent double, primaryImagePath?, inStock bool | id, name, slug, sku, brand, price, mrp, tax_percent, primary_image_path*, in_stock* | *computed from embedded join client-side |
| ProductDetail | all ProductCard fields + description?, categoryId, categoryName, isActive, isPublished, images List<ProductImage>, attributes List<ProductAttributeValue> | — | detail fetch only |
| ProductImage | id, storagePath, isPrimary bool, displayOrder int | id, storage_path, is_primary, display_order | public URL via `SupabaseHelper.publicUrl(bucket, path)` |
| ProductAttributeValue | categoryAttributeId, name, attributeKey, dataType, options, valueText?, valueNumber?, valueBoolean?, valueJson? | category_attribute_id, name, attribute_key, data_type, options, value_text, value_number, value_boolean, value_json | `displayValue` getter renders per dataType |
| InventoryRow (admin) | productId, quantity int, reservedQuantity int, minStockLevel int, updatedAt | product_id, quantity, reserved_quantity, min_stock_level, updated_at | |
| InventoryTransaction (admin) | id, productId, transactionType, quantityDelta int, referenceType?, referenceId?, reason?, createdBy?, createdAt | id, product_id, transaction_type, quantity_delta, reference_type, reference_id, reason, created_by, created_at | |
| CartItem | id, productId, quantity int, product ProductCard? | id, quantity, product | product null-able when embed fails; unavailable flag = product null or !isActive/!isPublished |
| Address | id, label, recipientName, phone, line1, line2?, city, state, postalCode, country, isDefault bool | id, label, recipient_name, phone, line1, line2, city, state, postal_code, country, is_default | |
| ShippingSnapshot | same fields as Address minus id/label/isDefault | recipient_name, phone, line1, line2, city, state, postal_code, country | parsed from `shipping_snapshot` jsonb |
| OrderSummary | id, orderNumber, status OrderStatus enum, total double, createdAt | id, order_number, status, total, created_at | status JSON values are UPPERCASE DB strings: 'NEW','CONFIRMED','PROCESSING','PACKED','SHIPPED','OUT_FOR_DELIVERY','DELIVERED','CANCELLED' (Dart names lowercase — §Enum mapping) |
| OrderDetail | OrderSummary fields + subtotal, deliveryCharge, tax, discount, cancelReason?, shippingSnapshot, items List<OrderItem>, payment PaymentInfo, customer? (admin) | subtotal, delivery_charge, tax, discount, cancel_reason, shipping_snapshot, items, payment | |
| OrderItem | id, productId?, productName, sku, unitPrice, taxPercent, quantity int, lineTotal, lineTax | id, product_id, product_name_snapshot, sku_snapshot, unit_price, tax_percent, quantity, line_total, line_tax | JSON keys are the *_snapshot columns |
| PaymentInfo | method, status PaymentStatus enum, amount | method, status, amount | status JSON: 'PENDING'/'COLLECTED'/'CANCELLED' (uppercase DB strings); method 'COD' |
| NotificationItem | id, type NotificationType enum, title, body, data Map, isRead bool, createdAt | id, type, title, body, data, is_read, created_at | type JSON: 'ORDER_STATUS'/'SYSTEM' (uppercase DB strings) |
| AppSettings | deliveryCharge double, freeDeliveryThreshold double | delivery_charge, free_delivery_threshold | |
| Paginated<T> | items List<T>, total int, page int, pageSize int, hasMore bool | — | from count header + slice |

## Enum ↔ JSON mapping (exact strings)

```dart
enum OrderStatus { new_, confirmed, processing, packed, shipped, outForDelivery, delivered, cancelled }
// json: 'NEW','CONFIRMED','PROCESSING','PACKED','SHIPPED','OUT_FOR_DELIVERY','DELIVERED','CANCELLED'

enum OrderTransition { // allowed forward steps (mirror of Master §3.6, client-side guard for UX)
  NEW -> [CONFIRMED, CANCELLED], CONFIRMED -> [PROCESSING, CANCELLED],
  PROCESSING -> [PACKED, CANCELLED], PACKED -> [SHIPPED],
  SHIPPED -> [OUT_FOR_DELIVERY], OUT_FOR_DELIVERY -> [DELIVERED],
  DELIVERED -> [], CANCELLED -> [] }
```
Client-side transition list is UX-only; the RPC re-validates.

## Shared helpers

- `SupabaseHelper.publicUrl(String bucket, String path)` → `Supabase.instance.client.storage.from(bucket).getPublicUrl(path)`
- `Formatters.inr(double)` → `₹1,234.50` via `NumberFormat.currency(locale:'en_IN', symbol:'₹')`
- `Formatters.dateTime(DateTime)` → `dd MMM yyyy, hh:mm a` (en_IN)
- `Validators`: email, password (≥8), fullName (2–80), phone (`^[6-9]\d{9}$`), postalCode, required, maxLength, sku, price ≥ 0, quantity 1–99
- `CategoryTree`: `List<CategoryTreeNode> build(List<Category>)`, node holds `children`, sorted by displayOrder
