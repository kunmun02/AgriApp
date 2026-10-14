import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/auth/controllers/auth_controller.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/models/profile.dart';
import 'package:customer_app/features/notifications/controllers/unread_badge_controller.dart';
import 'package:customer_app/features/notifications/data/notification_repository.dart';
import 'package:customer_app/features/profile/presentation/profile_page.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Profile _fakeProfile({String? phone}) => Profile(
      id: 'uid-1',
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      phone: phone,
      role: ProfileRole.customer,
      isActive: true,
      createdAt: DateTime(2024),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Profile profile,
  MockAuthRepository? mockRepo,
}) async {
  final repo = mockRepo ?? MockAuthRepository();
  final notifRepo = MockNotificationRepository();
  when(() => notifRepo.unreadCount()).thenAnswer((_) async => 0);

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfilePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login')),
      ),
      GoRoute(
        path: '/orders',
        builder: (_, __) => const Scaffold(body: Text('Orders')),
      ),
      GoRoute(
        path: '/addresses',
        builder: (_, __) => const Scaffold(body: Text('Addresses')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const Scaffold(body: Text('Notifications')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(
          (ref) => AuthController(repo)..state = AsyncData(profile),
        ),
        notificationRepositoryProvider.overrideWithValue(notifRepo),
        unreadBadgeControllerProvider.overrideWith(
          (ref) => UnreadBadgeController(notifRepo),
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
  group('ProfilePage — display', () {
    testWidgets('shows avatar with initials', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      expect(find.byKey(const Key('profile_avatar')), findsOneWidget);
      // 'Jane Doe' → initials 'JD'
      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('shows full name and email', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      expect(find.text('Jane Doe'), findsAtLeast(1));
      expect(find.text('jane@example.com'), findsAtLeast(1));
    });

    testWidgets('shows phone when present', (tester) async {
      await _pump(tester, profile: _fakeProfile(phone: '9876543210'));

      expect(find.text('9876543210'), findsOneWidget);
    });

    testWidgets('shows "Add phone" when phone is absent', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      expect(find.text('Add phone'), findsOneWidget);
    });

    testWidgets('shows app version', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      expect(find.byKey(const Key('app_version_text')), findsOneWidget);
      expect(find.textContaining('1.0.0'), findsOneWidget);
    });

    testWidgets('shows navigation shortcuts', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      expect(find.byKey(const Key('my_orders_tile')), findsOneWidget);
      expect(find.byKey(const Key('my_addresses_tile')), findsOneWidget);
      expect(find.byKey(const Key('notifications_tile')), findsOneWidget);
    });

    testWidgets('shows logout tile', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      expect(find.byKey(const Key('logout_tile')), findsOneWidget);
    });
  });

  group('ProfilePage — edit form', () {
    testWidgets('Edit profile button shows inline form', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('full_name_field')), findsOneWidget);
      expect(find.byKey(const Key('phone_field')), findsOneWidget);
    });

    testWidgets('form is pre-filled with current name', (tester) async {
      await _pump(tester, profile: _fakeProfile(phone: '9876543210'));

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      final nameField = tester
          .widget<TextFormField>(find.byKey(const Key('full_name_field')));
      expect(nameField.controller?.text, 'Jane Doe');
    });

    testWidgets('empty full name shows validation error', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('full_name_field')), '');
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required.'), findsOneWidget);
    });

    testWidgets('invalid phone shows validation error', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('phone_field')), '12345');
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('valid 10-digit'), findsOneWidget);
    });

    testWidgets('Cancel button hides the edit form', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel_edit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('full_name_field')), findsNothing);
    });

    testWidgets('successful save calls authController.updateProfile',
        (tester) async {
      final mockRepo = MockAuthRepository();
      final updatedProfile = _fakeProfile(phone: '9123456789');
      when(() => mockRepo.updateProfile(
            userId: any(named: 'userId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => updatedProfile);

      await _pump(tester, profile: _fakeProfile(), mockRepo: mockRepo);

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('full_name_field')), 'Jane Doe');
      await tester.enterText(
          find.byKey(const Key('phone_field')), '9123456789');
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updateProfile(
            userId: 'uid-1',
            fullName: 'Jane Doe',
            phone: '9123456789',
          )).called(1);
    });

    testWidgets('successful save shows "Profile updated" snackbar',
        (tester) async {
      final mockRepo = MockAuthRepository();
      when(() => mockRepo.updateProfile(
            userId: any(named: 'userId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => _fakeProfile());

      await _pump(tester, profile: _fakeProfile(), mockRepo: mockRepo);

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('Profile updated'), findsOneWidget);
    });
  });

  group('ProfilePage — logout', () {
    testWidgets('logout tile shows confirm dialog', (tester) async {
      await _pump(tester, profile: _fakeProfile());

      await tester.ensureVisible(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.byKey(const Key('confirm_action')), findsOneWidget);
    });

    testWidgets('cancelling logout does not sign out', (tester) async {
      final mockRepo = MockAuthRepository();
      await _pump(tester, profile: _fakeProfile(), mockRepo: mockRepo);

      await tester.ensureVisible(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.signOut());
    });

    testWidgets('confirming logout calls signOut and navigates to /login',
        (tester) async {
      final mockRepo = MockAuthRepository();
      when(() => mockRepo.signOut()).thenAnswer((_) async {});

      await _pump(tester, profile: _fakeProfile(), mockRepo: mockRepo);

      await tester.ensureVisible(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_action')));
      await tester.pumpAndSettle();

      verify(() => mockRepo.signOut()).called(1);
      expect(find.text('Login'), findsOneWidget);
    });
  });
}
