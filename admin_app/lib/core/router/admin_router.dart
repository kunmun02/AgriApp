import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/controllers/admin_auth_controller.dart';
import '../../features/auth/data/models/profile.dart';
import '../../features/auth/presentation/admin_login_page.dart';
import '../../features/attributes/presentation/attribute_editor_page.dart';
import '../../features/attributes/presentation/attributes_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/categories/presentation/category_editor_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/products/presentation/media_manager_page.dart';
import '../../features/products/presentation/product_editor_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/customers/presentation/customer_details_page.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/notifications/presentation/admin_notifications_page.dart';
import '../../features/orders/presentation/order_details_page.dart';
import '../../features/orders/presentation/orders_list_page.dart';
import '../../features/products/presentation/products_list_page.dart';
import '../../features/settings/presentation/settings_page.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final adminRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AdminRouterNotifier(ref);
  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/admin/login',
    debugLogDiagnostics: false,
    redirect: (context, state) => notifier.redirect(state),
    errorBuilder: (context, state) => const _AdminNotFoundScreen(),
    routes: [
      // ── Public ───────────────────────────────────────────────────────
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginPage(),
      ),

      // ── Root redirect ────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        redirect: (_, __) => '/admin/dashboard',
      ),

      // ── Authenticated ────────────────────────────────────────────────
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),

      // Categories
      GoRoute(
        path: '/admin/categories',
        builder: (context, state) => const CategoriesPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const CategoryEditorPage(),
          ),
          GoRoute(
            path: ':categoryId/edit',
            builder: (context, state) => CategoryEditorPage(
              categoryId: state.pathParameters['categoryId'],
            ),
          ),
          GoRoute(
            path: ':categoryId/attributes',
            builder: (context, state) => AttributesPage(
              categoryId: state.pathParameters['categoryId']!,
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => AttributeEditorPage(
                  categoryId: state.pathParameters['categoryId']!,
                ),
              ),
              GoRoute(
                path: ':attributeId/edit',
                builder: (context, state) => AttributeEditorPage(
                  categoryId: state.pathParameters['categoryId']!,
                  attributeId: state.pathParameters['attributeId'],
                ),
              ),
            ],
          ),
        ],
      ),

      // Products
      GoRoute(
        path: '/admin/products',
        builder: (context, state) => const ProductsListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ProductEditorPage(),
          ),
          GoRoute(
            path: ':productId/edit',
            builder: (context, state) => ProductEditorPage(
              productId: state.pathParameters['productId'],
            ),
          ),
          GoRoute(
            path: ':productId/media',
            builder: (context, state) => MediaManagerPage(
              productId: state.pathParameters['productId']!,
            ),
          ),
        ],
      ),

      // Inventory
      GoRoute(
        path: '/admin/inventory',
        builder: (context, state) => const InventoryPage(),
      ),

      // Orders
      GoRoute(
        path: '/admin/orders',
        builder: (context, state) => const OrdersListPage(),
        routes: [
          GoRoute(
            path: ':orderId',
            builder: (context, state) => OrderDetailsPage(
              orderId: state.pathParameters['orderId']!,
            ),
          ),
        ],
      ),

      // Customers
      GoRoute(
        path: '/admin/customers',
        builder: (context, state) => const CustomersPage(),
        routes: [
          GoRoute(
            path: ':userId',
            builder: (context, state) => CustomerDetailsPage(
              userId: state.pathParameters['userId']!,
            ),
          ),
        ],
      ),

      // Notifications
      GoRoute(
        path: '/admin/notifications',
        builder: (context, state) => const AdminNotificationsPage(),
      ),

      // Settings
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

// ── Guard notifier ────────────────────────────────────────────────────────────

const _publicRoutes = {'/admin/login'};

bool _requiresAdmin(String location) =>
    !_publicRoutes.contains(location) && location != '/admin';

class _AdminRouterNotifier extends ChangeNotifier {
  _AdminRouterNotifier(Ref ref) {
    ref.listen<AsyncValue<Profile?>>(
        adminAuthControllerProvider, (_, __) => notifyListeners());
    _ref = ref;
  }

  late final Ref _ref;

  String? redirect(GoRouterState state) {
    final authState = _ref.read(adminAuthControllerProvider);
    final location = state.matchedLocation;

    if (authState.isLoading) return null;

    final isAuthed = authState.value != null;
    final isAdmin = authState.value?.role == ProfileRole.admin;
    final onLogin = location == '/admin/login';

    // Signed-out hitting protected route → login.
    if (!isAuthed && _requiresAdmin(location)) return '/admin/login';

    // Signed-in as admin on login page → dashboard.
    if (isAuthed && isAdmin && onLogin) return '/admin/dashboard';

    // Signed-in but NOT admin (should not reach here; repository signs out,
    // but guard as extra safety) → login.
    if (isAuthed && !isAdmin && _requiresAdmin(location)) {
      return '/admin/login';
    }

    return null;
  }
}

// ── 404 ───────────────────────────────────────────────────────────────────────

class _AdminNotFoundScreen extends StatelessWidget {
  const _AdminNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 64),
            const SizedBox(height: 16),
            Text('Page not found',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/admin/login'),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
