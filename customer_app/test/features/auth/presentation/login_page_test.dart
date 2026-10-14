import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:customer_app/features/auth/controllers/auth_controller.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/models/profile.dart';
import 'package:customer_app/features/auth/presentation/login_page.dart';
import 'package:customer_app/core/theme/app_theme.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Profile _fakeProfile() => Profile(
      id: 'uid-1',
      fullName: 'Test User',
      email: 'test@example.com',
      role: ProfileRole.customer,
      isActive: true,
      createdAt: DateTime(2024),
    );

/// Pumps the [LoginPage] with a minimal go_router that has /login and /home.
Future<void> pumpLoginPage(
  WidgetTester tester,
  MockAuthRepository mockRepo,
) async {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
        authControllerProvider.overrideWith(
          (ref) => AuthController(mockRepo)..state = const AsyncData(null),
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
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  testWidgets('renders email and password fields', (tester) async {
    await pumpLoginPage(tester, mockRepo);
    expect(find.byKey(const Key('email_field')), findsOneWidget);
    expect(find.byKey(const Key('password_field')), findsOneWidget);
  });

  testWidgets('invalid email shows inline error, no repo call', (tester) async {
    await pumpLoginPage(tester, mockRepo);

    await tester.enterText(
        find.byKey(const Key('email_field')), 'not-an-email');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    verifyNever(() => mockRepo.signIn(
        email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('wrong credentials shows server message', (tester) async {
    when(() => mockRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(Exception('Invalid login credentials'));

    await pumpLoginPage(tester, mockRepo);

    await tester.enterText(
        find.byKey(const Key('email_field')), 'user@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'wrongpass');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('server_error')), findsOneWidget);
    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('button disabled while submitting', (tester) async {
    // Use a Completer so no pending timer is left when the test ends.
    final completer = Completer<Profile>();
    when(() => mockRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) => completer.future);

    await pumpLoginPage(tester, mockRepo);

    await tester.enterText(
        find.byKey(const Key('email_field')), 'user@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump(); // let setState(_isLoading = true) fire

    final button =
        tester.widget<ElevatedButton>(find.byKey(const Key('login_button')));
    expect(button.onPressed, isNull);

    // Resolve the completer so the widget disposes cleanly.
    completer.completeError(Exception('cancelled'));
    await tester.pumpAndSettle();
  });

  testWidgets('success navigates to /home', (tester) async {
    when(() => mockRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => _fakeProfile());

    await pumpLoginPage(tester, mockRepo);

    await tester.enterText(
        find.byKey(const Key('email_field')), 'user@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byKey(const Key('login_button')), findsNothing);
  });
}
