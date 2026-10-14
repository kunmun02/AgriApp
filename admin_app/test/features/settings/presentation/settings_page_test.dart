import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/settings/data/admin_settings_repository.dart';
import 'package:admin_app/features/settings/data/models/app_settings.dart';
import 'package:admin_app/features/settings/presentation/settings_page.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminSettingsRepository extends Mock
    implements AdminSettingsRepository {}

class MockAdminAuthRepository extends Mock implements AdminAuthRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _defaultSettings = AppSettings(
  deliveryCharge: 40.00,
  freeDeliveryThreshold: 500.00,
);

Future<void> _pump(
  WidgetTester tester,
  MockAdminSettingsRepository repo,
) async {
  final mockAuthRepo = MockAdminAuthRepository();

  final router = GoRouter(
    initialLocation: '/admin/settings',
    routes: [
      GoRoute(
        path: '/admin/settings',
        builder: (_, __) => const SettingsPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminSettingsRepositoryProvider.overrideWithValue(repo),
        adminAuthRepositoryProvider.overrideWithValue(mockAuthRepo),
        adminAuthControllerProvider.overrideWith(
          (ref) =>
              AdminAuthController(mockAuthRepo)..state = const AsyncData(null),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAdminSettingsRepository repo;

  setUp(() {
    repo = MockAdminSettingsRepository();
  });

  group('SettingsPage — loading state', () {
    testWidgets('shows spinner while fetch is pending', (tester) async {
      final completer = Completer<AppSettings>();
      when(() => repo.fetch()).thenAnswer((_) => completer.future);

      await _pump(tester, repo);
      await tester.pump();

      expect(find.byKey(const Key('settings_loading')), findsOneWidget);
    });
  });

  group('SettingsPage — error state', () {
    testWidgets('shows error message + retry button on fetch failure',
        (tester) async {
      when(() => repo.fetch()).thenThrow(Exception('Network error'));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_error')), findsOneWidget);
      expect(find.byKey(const Key('retry_button')), findsOneWidget);
    });

    testWidgets('retry button triggers a new fetch', (tester) async {
      var callCount = 0;
      when(() => repo.fetch()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('fail');
        return _defaultSettings;
      });

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delivery_charge_field')), findsOneWidget);
      expect(callCount, 2);
    });
  });

  group('SettingsPage — data state', () {
    setUp(() {
      when(() => repo.fetch()).thenAnswer((_) async => _defaultSettings);
    });

    testWidgets('pre-fills delivery charge and threshold from loaded data',
        (tester) async {
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delivery_charge_field')), findsOneWidget);
      expect(find.byKey(const Key('free_threshold_field')), findsOneWidget);

      final chargeField = tester.widget<TextFormField>(
          find.byKey(const Key('delivery_charge_field')));
      expect(chargeField.controller?.text, '40.00');

      final thresholdField = tester
          .widget<TextFormField>(find.byKey(const Key('free_threshold_field')));
      expect(thresholdField.controller?.text, '500.00');
    });

    testWidgets(
        'threshold helper shows "Free delivery is disabled" when threshold is 0',
        (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => const AppSettings(
            deliveryCharge: 40.00,
            freeDeliveryThreshold: 0.00,
          ));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Free delivery is disabled'), findsOneWidget);
    });

    testWidgets('threshold helper mentions "free delivery" when > 0',
        (tester) async {
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.textContaining('get free delivery'), findsOneWidget);
    });

    testWidgets('helper updates live when threshold field changes',
        (tester) async {
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('free_threshold_field')), '0');
      await tester.pump();

      expect(find.text('Free delivery is disabled'), findsOneWidget);
    });
  });

  group('SettingsPage — validation', () {
    setUp(() {
      when(() => repo.fetch()).thenAnswer((_) async => _defaultSettings);
    });

    testWidgets('negative delivery charge shows "Must be ≥ 0"', (tester) async {
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('delivery_charge_field')), '-5');
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Must be ≥ 0'), findsOneWidget);
    });

    testWidgets('negative threshold shows "Must be ≥ 0"', (tester) async {
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('free_threshold_field')), '-1');
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Must be ≥ 0'), findsOneWidget);
    });

    testWidgets('non-numeric charge shows number error', (tester) async {
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('delivery_charge_field')), 'abc');
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('must be a number'), findsOneWidget);
    });

    testWidgets('save is blocked when form has errors', (tester) async {
      when(() => repo.update(
            deliveryCharge: any(named: 'deliveryCharge'),
            freeDeliveryThreshold: any(named: 'freeDeliveryThreshold'),
          )).thenAnswer((_) async => _defaultSettings);

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('delivery_charge_field')), '-1');
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      verifyNever(() => repo.update(
            deliveryCharge: any(named: 'deliveryCharge'),
            freeDeliveryThreshold: any(named: 'freeDeliveryThreshold'),
          ));
    });
  });

  group('SettingsPage — save', () {
    setUp(() {
      when(() => repo.fetch()).thenAnswer((_) async => _defaultSettings);
    });

    testWidgets('valid save calls repo.update with parsed values',
        (tester) async {
      when(() => repo.update(
            deliveryCharge: any(named: 'deliveryCharge'),
            freeDeliveryThreshold: any(named: 'freeDeliveryThreshold'),
          )).thenAnswer((_) async => const AppSettings(
            deliveryCharge: 50,
            freeDeliveryThreshold: 200,
          ));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('delivery_charge_field')), '50');
      await tester.enterText(
          find.byKey(const Key('free_threshold_field')), '200');
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      verify(() => repo.update(
            deliveryCharge: 50,
            freeDeliveryThreshold: 200,
          )).called(1);
    });

    testWidgets('successful save shows "Settings saved" snackbar',
        (tester) async {
      when(() => repo.update(
            deliveryCharge: any(named: 'deliveryCharge'),
            freeDeliveryThreshold: any(named: 'freeDeliveryThreshold'),
          )).thenAnswer((_) async => _defaultSettings);

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Settings saved'), findsOneWidget);
    });

    testWidgets('save button is disabled while saving', (tester) async {
      final completer = Completer<AppSettings>();
      when(() => repo.update(
            deliveryCharge: any(named: 'deliveryCharge'),
            freeDeliveryThreshold: any(named: 'freeDeliveryThreshold'),
          )).thenAnswer((_) => completer.future);

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pump();

      final btn =
          tester.widget<ElevatedButton>(find.byKey(const Key('save_button')));
      expect(btn.onPressed, isNull);

      completer.complete(_defaultSettings);
    });
  });

  group('SettingsPage — store card', () {
    testWidgets('shows read-only store info', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => _defaultSettings);

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('AgriStore'), findsOneWidget);
      expect(find.text('INR (₹)'), findsOneWidget);
    });
  });
}
