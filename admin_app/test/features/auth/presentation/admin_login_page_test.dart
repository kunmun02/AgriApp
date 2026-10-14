import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/errors/app_failure.dart';
import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/auth/data/models/profile.dart';
import 'package:admin_app/features/auth/presentation/admin_login_page.dart';
import 'package:admin_app/core/theme/app_theme.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminAuthRepository extends Mock implements AdminAuthRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Profile _adminProfile() => Profile(
      id: 'admin-1',
      fullName: 'Admin User',
      email: 'admin@example.com',
      role: ProfileRole.admin,
      isActive: true,
      createdAt: DateTime(2024),
    );

Future<void> pumpLoginPage(
  WidgetTester tester,
  MockAdminAuthRepository mockRepo,
) async {
  final router = GoRouter(
    initialLocation: '/admin/login',
    routes: [
      GoRoute(path: '/admin/login', builder: (_, __) => const AdminLoginPage()),
      GoRoute(
          path: '/admin/dashboard',
          builder: (_, __) => const Scaffold(body: Text('Dashboard'))),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(mockRepo),
        adminAuthControllerProvider.overrideWith(
          (ref) => AdminAuthController(mockRepo)..state = const AsyncData(null),
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
  late MockAdminAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAdminAuthRepository();
  });

  testWidgets('renders email and password fields with Sign in button',
      (tester) async {
    await pumpLoginPage(tester, mockRepo);
    expect(find.byKey(const Key('email_field')), findsOneWidget);
    expect(find.byKey(const Key('password_field')), findsOneWidget);
    expect(find.byKey(const Key('signin_button')), findsOneWidget);
  });

  testWidgets('invalid email shows inline error, no repo call', (tester) async {
    await pumpLoginPage(tester, mockRepo);
    await tester.enterText(find.byKey(const Key('email_field')), 'bad-email');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('signin_button')));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    verifyNever(() => mockRepo.signIn(
        email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('wrong credentials shows invalid message', (tester) async {
    when(() => mockRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(const ApiFailure('AUTH_ERROR', 'wrong credentials'));

    await pumpLoginPage(tester, mockRepo);
    await tester.enterText(
        find.byKey(const Key('email_field')), 'admin@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'wrongpass');
    await tester.tap(find.byKey(const Key('signin_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('server_error')), findsOneWidget);
    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('non-admin account shows "not an admin" message', (tester) async {
    when(() => mockRepo.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ))
        .thenThrow(
            const ApiFailure('FORBIDDEN', 'This account is not an admin'));

    await pumpLoginPage(tester, mockRepo);
    await tester.enterText(
        find.byKey(const Key('email_field')), 'cust@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('signin_button')));
    await tester.pumpAndSettle();

    expect(find.text('This account is not an admin'), findsOneWidget);
  });

  testWidgets('button disabled while submitting', (tester) async {
    final completer = Completer<Profile>();
    when(() => mockRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) => completer.future);

    await pumpLoginPage(tester, mockRepo);
    await tester.enterText(
        find.byKey(const Key('email_field')), 'admin@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('signin_button')));
    await tester.pump();

    final btn =
        tester.widget<ElevatedButton>(find.byKey(const Key('signin_button')));
    expect(btn.onPressed, isNull);

    completer.completeError(Exception('cancelled'));
    await tester.pumpAndSettle();
  });

  testWidgets('admin sign-in navigates to /admin/dashboard', (tester) async {
    when(() => mockRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => _adminProfile());

    await pumpLoginPage(tester, mockRepo);
    await tester.enterText(
        find.byKey(const Key('email_field')), 'admin@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('signin_button')));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
