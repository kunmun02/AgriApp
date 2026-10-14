# 03_REPOSITORIES.md — Exact method signatures (both apps)

Every method below: input → output, the Supabase call pattern, and failure mapping. Screens NEVER
call Supabase directly. Constructors take `SupabaseClient` (via ref). All list methods return
`Paginated<T>` (pageSize 20) unless stated "no paging".

## customer_app

```dart
class AuthRepository {
  Future<Session?> currentUserSession();          // restore
  Future<Profile> signUp({required String email, required String password, required String fullName});
  // auth.signUp(email, password, emailRedirectTo: null, data: {'full_name': fullName}) → profile via trigger
  Future<Profile> signIn({required String email, required String password}); // auth.signInWithPassword + fetch profile
  Future<void> signOut();
  Stream<AuthState> onAuthStateChange();
  Future<Profile> fetchProfile(String userId);    // profiles select single
  Future<Profile> updateProfile({required String userId, String? fullName, String? phone}); // profiles update (own row)
}

class ProductRepository {
  Future<Paginated<ProductCard>> listProducts({String? query, String? categoryId, // categoryId = subtree root; repo resolves children ids first
    double? minPrice, double? maxPrice, ProductSort sort = ProductSort.newest,
    required int page});
  Future<List<ProductCard>> popularProducts({int limit = 8}); // first 8 published ordered by created_at desc
  Future<ProductDetail> productDetails(String productId);     // .single(); not found → NOT_FOUND; !published → NOT_FOUND
  Future<List<Category>> fetchActiveCategories();             // flat, ordered by display_order (no paging)
}

class CartRepository {
  Future<String> ensureCart();                      // select carts by user; insert if none; return cart id
  Future<List<CartItem>> fetchItems(String cartId); // embed per 02_BACKEND/01 §2
  Future<void> addItem({required String cartId, required String productId, required int quantity});
  // select existing row first: insert or update quantity = min(existing + qty, 99)
  Future<void> updateQuantity({required String itemId, required int quantity}); // 1..99 client-checked
  Future<void> removeItem(String itemId);
  Future<int> itemCount();                          // count query for badge
}

class AddressRepository {
  Future<List<Address>> fetchAddresses();           // order by is_default desc, created_at desc
  Future<Address> createAddress(Address draft);     // if isDefault → clear others' is_default first (two ops)
  Future<Address> updateAddress(Address draft);     // same default handling
  Future<void> deleteAddress(String id);
  Future<void> setDefault(String id);               // transaction-ish: clear all, then set (two ops)
}

class CheckoutRepository {
  Future<AppSettings> fetchSettings();              // app_settings single row (authenticated read)
  Future<Map<String, dynamic>> createOrder({required String addressId, required String idempotencyKey});
  // rpc create_order → parsed jsonb; errors via ErrorMapper
}

class OrderRepository {
  Future<Paginated<OrderSummary>> myOrders({OrderStatus? status, required int page}); // own, newest first
  Future<OrderDetail> orderDetails(String orderId); // embed items + payment; 0 rows → NOT_FOUND
}

class NotificationRepository {
  Future<Paginated<NotificationItem>> fetch({required int page});
  Future<int> unreadCount();                        // head:true count
  Future<void> markRead(String notificationId);     // rpc mark_notification_read
}
```

## admin_app

```dart
class AdminAuthRepository { // same signIn/signOut/onAuthStateChange as customer +:
  Future<Profile> requireAdminProfile();    // fetch profile; if role != 'admin' → FORBIDDEN (router signs out)
}

class AdminCategoryRepository {
  Future<List<Category>> fetchAll({bool includeInactive = true});       // flat, no paging
  Future<Category> create({required String name, String? parentId, String? description,
    int displayOrder, required String slug});                            // slug client-generated + suffix loop on 23505
  Future<Category> update(Category c);
  Future<void> deactivate(String id);                                    // is_active=false (soft)
  Future<String> uploadImage({required String categoryId, required Uint8List bytes, required String fileName});
}

class AdminAttributeRepository {
  Future<List<CategoryAttribute>> fetchForCategory(String categoryId);   // active + inactive, display_order
  Future<CategoryAttribute> create({required String categoryId, required String name,
    required String attributeKey, required AttributeType dataType, required List<String> options,
    required bool isRequired, required int displayOrder});
  Future<CategoryAttribute> update(CategoryAttribute a);                 // e.g. options/order/required
  Future<void> deactivate(String id);
}

class AdminProductRepository {
  Future<Paginated<ProductCard>> list({String? query, String? sku, String? categoryId,
    ProductAdminFilter filter = ProductAdminFilter.all, required int page}); // filter: all/published/draft/inactive
  Future<int> countProducts();                    // head:true count, is_active = true (A02 StatCard)
  Future<ProductDetail> details(String id);                              // same embed as customer + inactive ok
  Future<Product> create(ProductDraft d);                                 // insert + inventory row (quantity 0) + optional attributes
  Future<Product> update(ProductDraft d);
  Future<void> publish(String id, bool published);
  Future<void> deactivate(String id);
  // Dynamic attributes: replace-set semantics — delete removed rows, upsert provided rows in one
  // sequential batch (MVP: no all-or-nothing guarantee; checkout reads only published products)
  Future<void> saveAttributes(String productId, List<ProductAttributeInput> values);
}

class AdminMediaRepository {
  Future<List<ProductImage>> fetchImages(String productId);
  Future<ProductImage> upload({required String productId, required Uint8List bytes,
    required String fileName, bool makePrimary = false});
  Future<void> setPrimary({required String productId, required String imageId}); // clear old primary, set new (two ops)
  Future<void> reorder(String productId, List<String> imageIdsInOrder);
  Future<void> delete(ProductImage img);   // storage remove(path) then row delete
}

class AdminInventoryRepository {
  Future<Paginated<InventoryRow>> list({String? query, bool lowStockOnly = false, required int page});
  // lowStockOnly: quantity <= min_stock_level (client-side filter of current page)
  Future<Map<String, dynamic>> adjust({required String productId, required int delta,
    required String transactionType, required String reason}); // rpc adjust_inventory
  Future<List<InventoryTransaction>> transactions(String productId, {int limit = 50});
}

class AdminOrderRepository {
  Future<Paginated<OrderSummary>> list({OrderStatus? status, String? query, required int page});
  Future<int> countOrdersCreatedToday();   // head:true, created_at >= date_trunc('day', now()) UTC (A02 StatCard)
  Future<int> countNewOrders();            // head:true, status = 'NEW' (A02 StatCard)
  Future<OrderDetail> details(String orderId);            // + customer profile embed
  Future<Map<String, dynamic>> changeStatus({required String orderId, required OrderStatus target,
    String? reason});                                      // rpc change_order_status
}

class AdminCustomerRepository {
  Future<Paginated<Profile>> list({String? query, required int page});    // profiles role='customer'
  Future<int> countCustomers();                                           // head:true count, role='customer' (A02 StatCard)
  Future<Profile> details(String userId);
  Future<Paginated<OrderSummary>> ordersOf(String userId, {required int page});
  Future<void> setActive(String userId, bool active);                     // admin guard allows
}

class AdminNotificationRepository {
  Future<Paginated<NotificationItem>> list({required int page});          // all users' (admin select policy)
  Future<void> broadcast({required String title, required String body});  // insert rows type SYSTEM per customer profile
}

class AdminSettingsRepository {
  Future<AppSettings> fetch();
  Future<void> update({required double deliveryCharge, required double freeDeliveryThreshold});
}
```

## Supabase call patterns (canonical)

```dart
// paginated list
final from = (page - 1) * 20;
final res = await sb.from('products')
  .select(<projection>)
  .range(from, from + 19)
  .count(CountOption.exact);
return Paginated(items: res.data.map(ProductCard.fromJson).toList(),
  total: res.count ?? 0, page: page, pageSize: 20,
  hasMore: (page * 20) < (res.count ?? 0));

// rpc + error mapping
try {
  return await sb.rpc('create_order', params: {...});
} on PostgresException catch (e) { throw ErrorMapper.from(e); }

// storage upload (admin)
final path = '$productId/${DateTime.now().millisecondsSinceEpoch}-${sanitize(fileName)}';
await sb.storage.from('product-images').uploadBinary(path, bytes,
  fileOptions: const FileOptions(contentType: contentType));
```

## ErrorMapper rules

1. `PostgresException.code == 'P0001'` → try `jsonDecode(message)` → `ApiFailure(code, message, details)`.
2. `42501` → `ApiFailure('FORBIDDEN', ...)`. `PGRST301`/401 → `AUTH_REQUIRED`. `23505` unique violation →
   `ApiFailure('CONFLICT', 'already exists')` (callers turn into friendly field errors).
3. `SocketException`/timeout → `NetworkFailure`.
4. `.single()` `PGRST116` (0 rows) → `ApiFailure('NOT_FOUND', ...)`.
5. Anything else → `ApiFailure('INTERNAL_ERROR', ...)` with log (no PII).
