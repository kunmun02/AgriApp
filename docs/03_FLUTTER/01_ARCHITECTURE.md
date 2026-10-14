# 01_ARCHITECTURE.md — Flutter structure, dependencies, bootstrap

Two INDEPENDENT Flutter projects in one repo. No shared package, no melos (MVP simplicity beats DRY).

## customer_app/

```
customer_app/
├── pubspec.yaml
├── .env.example              # SUPABASE_URL= , SUPABASE_ANON_KEY=   (real .env git-ignored)
├── android/                  # default template + applicationId com.agristore.customer
└── lib/
    ├── main.dart             # bootstrap (below)
    ├── core/
    │   ├── config/env.dart               # reads --dart-define-from-file or dotenv
    │   ├── router/app_router.dart        # go_router config (04_UI/04)
    │   ├── theme/app_theme.dart          # from 04_UI/01
    │   ├── constants/indian_states.dart  # 36 states/UTs list
    │   ├── constants/app_constants.dart  # pageSize=20, cartQtyMax=99, currency format
    │   ├── errors/app_failure.dart       # sealed failure classes (02_BACKEND/02)
    │   ├── errors/error_mapper.dart      # PostgresException -> AppFailure
    │   ├── network/supabase_client.dart  # singleton provider wrapping SupabaseClient
    │   └── widgets/                      # AppButton, AppTextField, EmptyState, ErrorState,
    │                                     # LoadingState, ConfirmDialog, ProductCard, StatusChip,
    │                                     # QuantityStepper, PriceText, CachedImage
    └── features/
        ├── auth/         (data/auth_repository.dart, controllers/auth_controller.dart, screens/login_screen.dart, register_screen.dart)
        ├── home/         screens/home_screen.dart, controllers/home_controller.dart
        ├── categories/   screens/categories_screen.dart, category_products_screen.dart
        ├── products/     data/product_repository.dart, screens/product_list_screen.dart, product_detail_screen.dart, widgets/
        ├── cart/         data/cart_repository.dart, controllers/cart_controller.dart, screens/cart_screen.dart
        ├── addresses/    data/address_repository.dart, screens/address_list_screen.dart, address_form_screen.dart
        ├── checkout/     controllers/checkout_controller.dart, screens/checkout_screen.dart, order_success_screen.dart
        ├── orders/       data/order_repository.dart, screens/order_list_screen.dart, order_detail_screen.dart
        ├── notifications/data/notification_repository.dart, screens/notifications_screen.dart
        └── profile/      screens/profile_screen.dart
```

## admin_app/

```
admin_app/
├── pubspec.yaml
├── .env.example
├── web/
└── lib/
    ├── main.dart
    ├── core/ (config/, router/, theme/, errors/, network/, widgets/ + shared table/form widgets)
    └── features/
        ├── auth/         login + admin auth controller (role check)
        ├── dashboard/    screens/dashboard_screen.dart (KPI queries)
        ├── categories/   screens/category_list_screen.dart, category_editor_screen.dart
        ├── attributes/   screens/attribute_list_screen.dart, attribute_editor_screen.dart
        ├── products/     data/, screens/product_list_screen.dart, product_editor_screen.dart
        ├── media/        screens/media_manager_screen.dart
        ├── inventory/    screens/inventory_screen.dart
        ├── orders/       screens/order_list_screen.dart, order_detail_screen.dart
        ├── customers/    screens/customer_list_screen.dart, customer_detail_screen.dart
        ├── notifications/ screens/notifications_screen.dart (SYSTEM broadcast + list)
        └── settings/     screens/settings_screen.dart (delivery values)
```

## pubspec.yaml — customer_app (exact dependencies)

```yaml
name: customer_app
environment:
  sdk: ">=3.4.0 <4.0.0"
dependencies:
  flutter: { sdk: flutter }
  supabase_flutter: ^2.5.0
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  intl: ^0.19.0
  cached_network_image: ^3.3.1
  image_picker: ^1.1.0        # profile photo is NOT in MVP; kept out — REMOVE this line (see below)
dev_dependencies:
  flutter_test: { sdk: flutter }
  flutter_lints: ^4.0.0
  mocktail: ^1.0.3
```
> Final dependency list (customer): `supabase_flutter`, `flutter_riverpod`, `go_router`, `intl`,
> `cached_network_image`. No image_picker in the customer app.
> admin_app adds: `file_picker: ^8.0.0` (image upload). Nothing else — every new dependency needs a
> written justification in the phase report.

## Bootstrap — `main.dart` (both apps; identical except package name)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: App()));
}
```
Run: `flutter run --dart-define-from-file=.env`  (`.env` = `{"SUPABASE_URL":"...","SUPABASE_ANON_KEY":"..."}`)

## Riverpod conventions

- Repositories: plain classes, exposed via `Provider<ModelRepository>((ref) => ModelRepository(ref.read(supabaseClientProvider)))`.
- Async reads: `FutureProvider` / `FutureProvider.family` (detail by id) with `.autoDispose`.
- Mutations + pagination state: `StateNotifier` (one per feature, e.g. `CartController`, `CheckoutController`).
- Session: `authStateChanges` → `AuthController` exposes `AsyncValue<Profile?>` (null = signed out).
  Admin app additionally validates `profile.role == 'admin'` before granting shell access.
- Never mutate state inside build; never store repositories in widgets.

## Analysis & format

`analysis_options.yaml`: `include: package:flutter_lints/flutter.yaml` — zero analyzer issues is the bar.
Formatter: `dart format .` (default 80 cols) — CI gate.

## Platform minimums

- customer_app: `minSdk 24`, target Android 14 (API 34), Kotlin default template. Permissions: INTERNET only.
- admin_app: web enabled (`flutter create --platforms=web`), no mobile targets.
