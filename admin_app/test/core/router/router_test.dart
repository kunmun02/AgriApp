import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/auth/data/models/profile.dart';
import 'package:admin_app/core/theme/app_theme.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Profile _adminProfile() => Profile(
      id: 'admin-1',
      fullName: 'Admin User',
      email: 'admin@example.com',
      role: ProfileRole.admin,
      isActive: true,
      createdAt: DateTime(2024),
    );

Profile _customerProfile() => Profile(
      id: 'cust-1',
      fullName: 'Customer',
      email: 'cust@example.com',
      role: ProfileRole.customer,
      isActive: true,
      createdAt: DateTime(2024),
    );

const _publicRoutes = {'/admin/login'};
bool _requiresAdmin(String loc) =>
    !_publicRoutes.contains(loc) && loc != '/admin';

GoRouter _buildRouter({required AsyncValue<Profile?> authState}) {
  return GoRouter(
    initialLocation: '/admin/login',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (authState.isLoading) return null;
      final isAuthed = authState.value != null;
      final isAdmin = authState.value?.role == ProfileRole.admin;
      final onLogin = loc == '/admin/login';
      if (!isAuthed && _requiresAdmin(loc)) return '/admin/login';
      if (isAuthed && isAdmin && onLogin) return '/admin/dashboard';
      if (isAuthed && !isAdmin && _requiresAdmin(loc)) return '/admin/login';
      return null;
    },
    errorBuilder: (_, __) => const Scaffold(body: Text('Not Found')),
    routes: [
      GoRoute(
          path: '/admin/login',
          builder: (_, __) => const Scaffold(body: Text('Login'))),
      GoRoute(
          path: '/admin/dashboard',
          builder: (_, __) => const Scaffold(body: Text('Dashboard'))),
      GoRoute(
          path: '/admin/orders',
          builder: (_, __) => const Scaffold(body: Text('Orders'))),
    ],
  );
}

Future<void> pumpApp(
  WidgetTester tester, {
  required AsyncValue<Profile?> authState,
  required String initialLocation,
}) async {
  final router = _buildRouter(authState: authState)..go(initialLocation);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthControllerProvider.overrideWith(
          (ref) => AdminAuthController(ref.read(adminAuthRepositoryProvider))
            ..state = authState,
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  testWidgets('signed-out /admin/dashboard redirects to /admin/login',
      (tester) async {
    await pumpApp(
      tester,
      authState: const AsyncData(null),
      initialLocation: '/admin/dashboard',
    );
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('admin /admin/login redirects to /admin/dashboard',
      (tester) async {
    await pumpApp(
      tester,
      authState: AsyncData(_adminProfile()),
      initialLocation: '/admin/login',
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
  });

  testWidgets('customer-role on /admin/dashboard redirects to /admin/login',
      (tester) async {
    await pumpApp(
      tester,
      authState: AsyncData(_customerProfile()),
      initialLocation: '/admin/dashboard',
    );
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('unknown route shows not-found screen', (tester) async {
    await pumpApp(
      tester,
      authState: AsyncData(_adminProfile()),
      initialLocation: '/admin/unknown-page',
    );
    expect(find.text('Not Found'), findsOneWidget);
  });
}
