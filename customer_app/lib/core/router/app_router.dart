import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/data/models/profile.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/products/presentation/product_details_page.dart';
import '../../features/products/presentation/product_listing_page.dart';
import '../../features/addresses/data/models/address.dart';
import '../../features/addresses/presentation/address_form_page.dart';
import '../../features/addresses/presentation/address_list_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/checkout/presentation/checkout_page.dart';
import '../../features/checkout/presentation/order_success_page.dart';
import '../../features/notifications/controllers/unread_badge_controller.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/orders/presentation/order_details_page.dart';
import '../../features/orders/presentation/order_list_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../providers/cart_provider.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

/// Exposes the GoRouter instance and refreshes it whenever [authControllerProvider]
/// changes so that guards re-run automatically on sign-in / sign-out.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) => notifier.redirect(state),
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      // ── Unauthenticated ────────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // ── Main shell with bottom navigation ─────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Home
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
          ]),
          // Tab 1: Categories
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesPage(),
              routes: [
                GoRoute(
                  path: ':categoryId',
                  builder: (context, state) {
                    final categoryId = state.pathParameters['categoryId']!;
                    final extra = state.extra as Map<String, String?>?;
                    return ProductListingPage(
                      categoryId: categoryId,
                      categoryName: extra?['categoryName'],
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/products',
              builder: (context, state) => ProductListingPage(
                initialQuery: state.uri.queryParameters['q'],
              ),
            ),
            GoRoute(
              path: '/products/:productId',
              builder: (context, state) => ProductDetailsPage(
                productId: state.pathParameters['productId']!,
              ),
            ),
          ]),
          // Tab 2: Cart
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              builder: (context, state) => const CartPage(),
            ),
            GoRoute(
              path: '/addresses',
              builder: (context, state) {
                final selectMode =
                    state.uri.queryParameters['selectMode'] == 'true';
                return AddressListPage(selectMode: selectMode);
              },
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const AddressFormPage(),
                ),
                GoRoute(
                  path: ':addressId/edit',
                  builder: (context, state) {
                    final existing = state.extra as Address?;
                    return AddressFormPage(existing: existing);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/checkout',
              builder: (context, state) => const CheckoutPage(),
            ),
            GoRoute(
              path: '/order-success/:orderId',
              builder: (context, state) {
                final orderId = state.pathParameters['orderId']!;
                final extra = state.extra as Map<String, dynamic>?;
                return OrderSuccessPage(
                  orderId: orderId,
                  orderNumber: extra?['orderNumber'] as String?,
                  total: extra?['total'] as double?,
                );
              },
            ),
          ]),
          // Tab 3: Orders
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/orders',
              builder: (context, state) => const OrderListPage(),
              routes: [
                GoRoute(
                  path: ':orderId',
                  builder: (context, state) => OrderDetailsPage(
                    orderId: state.pathParameters['orderId']!,
                  ),
                ),
              ],
            ),
          ]),
          // Tab 4: Profile
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsPage(),
            ),
          ]),
        ],
      ),
    ],
  );
});

// ── Guard notifier ────────────────────────────────────────────────────────────

const _unauthRoutes = {'/', '/login', '/register'};

bool _requiresAuth(String location) => !_unauthRoutes.contains(location);

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<Profile?>>(authControllerProvider, (_, __) {
      notifyListeners();
    });
    _ref = ref;
  }

  late final Ref _ref;

  String? redirect(GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final location = state.matchedLocation;

    // While loading (splash still initialising) → don't redirect.
    if (authState.isLoading) return null;

    final isAuthed = authState.value != null;
    final onAuthRoute = location == '/login' || location == '/register';

    // Signed-out user hitting a protected route → login.
    if (!isAuthed && _requiresAuth(location)) return '/login';

    // Signed-in user hitting login or register → home.
    if (isAuthed && onAuthRoute) return '/home';

    return null;
  }
}

// ── Shell (bottom nav) ────────────────────────────────────────────────────────

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    final unreadCount = ref.watch(unreadBadgeControllerProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.person_outline),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.person),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ── 404 ───────────────────────────────────────────────────────────────────────

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
