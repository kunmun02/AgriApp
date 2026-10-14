import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:customer_app/features/auth/controllers/auth_controller.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/models/profile.dart';
import 'package:customer_app/core/theme/app_theme.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Profile _fakeProfile() => Profile(
      id: 'uid-1',
      fullName: 'Test User',
      email: 'test@example.com',
      role: ProfileRole.customer,
      isActive: true,
      createdAt: DateTime(2024),
    );

const _unauthRoutes = {'/', '/login', '/register'};

/// Builds a minimal router that mirrors the real guard logic.
GoRouter _buildRouter({
  required AsyncValue<Profile?> authState,
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (authState.isLoading) return null;
      final isAuthed = authState.value != null;
      final requiresAuth = !_unauthRoutes.contains(loc);
      final onAuthRoute = loc == '/login' || loc == '/register';
      if (!isAuthed && requiresAuth) return '/login';
      if (isAuthed && onAuthRoute) return '/home';
      return null;
    },
    errorBuilder: (_, __) => const Scaffold(body: Text('Not Found')),
    routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Splash'))),
      GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login'))),
      GoRoute(
          path: '/register',
          builder: (_, __) => const Scaffold(body: Text('Register'))),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home'))),
      GoRoute(
        path: '/orders/:orderId',
        builder: (_, state) =>
            Scaffold(body: Text('Order ${state.pathParameters['orderId']}')),
      ),
    ],
  );
}

Future<void> pumpApp(
  WidgetTester tester, {
  required AsyncValue<Profile?> authState,
  required String initialLocation,
}) async {
  final router =
      _buildRouter(authState: authState, initialLocation: initialLocation);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => AuthController(ref.read(authRepositoryProvider))
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
  testWidgets('signed-out /home redirects to /login', (tester) async {
    await pumpApp(
      tester,
      authState: const AsyncData(null),
      initialLocation: '/home',
    );
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('signed-in /login redirects to /home', (tester) async {
    await pumpApp(
      tester,
      authState: AsyncData(_fakeProfile()),
      initialLocation: '/login',
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
  });

  testWidgets('unknown route shows not-found screen', (tester) async {
    await pumpApp(
      tester,
      authState: AsyncData(_fakeProfile()),
      initialLocation: '/this/does/not/exist',
    );
    expect(find.text('Not Found'), findsOneWidget);
  });

  testWidgets('signed-in deep link /orders/:id lands on that route',
      (tester) async {
    await pumpApp(
      tester,
      authState: AsyncData(_fakeProfile()),
      initialLocation: '/orders/abc-123',
    );
    expect(find.text('Order abc-123'), findsOneWidget);
  });
}
