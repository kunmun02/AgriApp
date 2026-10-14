import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/features/auth/controllers/auth_controller.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/models/profile.dart';
import 'package:customer_app/features/auth/presentation/register_page.dart';
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

/// Pumps [RegisterPage] inside a GoRouter so context.go() works.
Future<void> pumpRegisterPage(
  WidgetTester tester,
  MockAuthRepository mockRepo,
) async {
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
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

  testWidgets('mismatched confirm password blocks submit', (tester) async {
    await pumpRegisterPage(tester, mockRepo);

    await tester.enterText(find.byKey(const Key('name_field')), 'Test User');
    await tester.enterText(
        find.byKey(const Key('email_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.enterText(
        find.byKey(const Key('confirm_field')), 'different999');

    await tester.tap(find.byKey(const Key('register_button')));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    verifyNever(() => mockRepo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fullName: any(named: 'fullName'),
        ));
  });

  testWidgets('duplicate email shows friendly message', (tester) async {
    // Throw an ApiFailure with CONFLICT code — this is what ErrorMapper
    // produces for a 23505 unique-violation, and what the screen checks for.
    when(() => mockRepo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fullName: any(named: 'fullName'),
        )).thenThrow(const ApiFailure('CONFLICT', 'already exists'));

    await pumpRegisterPage(tester, mockRepo);

    await tester.enterText(find.byKey(const Key('name_field')), 'Test User');
    await tester.enterText(
        find.byKey(const Key('email_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.enterText(
        find.byKey(const Key('confirm_field')), 'password123');

    await tester.tap(find.byKey(const Key('register_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('server_error')), findsOneWidget);
    expect(
      find.text('An account with this email already exists'),
      findsOneWidget,
    );
  });

  testWidgets('valid form calls signUp and navigates on success',
      (tester) async {
    when(() => mockRepo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fullName: any(named: 'fullName'),
        )).thenAnswer((_) async => _fakeProfile());

    await pumpRegisterPage(tester, mockRepo);

    await tester.enterText(find.byKey(const Key('name_field')), 'Test User');
    await tester.enterText(
        find.byKey(const Key('email_field')), 'new@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    await tester.enterText(
        find.byKey(const Key('confirm_field')), 'password123');
    await tester.tap(find.byKey(const Key('register_button')));
    await tester.pumpAndSettle();

    // After success, router navigated to /home.
    expect(find.text('Home'), findsOneWidget);
    expect(find.byKey(const Key('register_button')), findsNothing);
  });
}
