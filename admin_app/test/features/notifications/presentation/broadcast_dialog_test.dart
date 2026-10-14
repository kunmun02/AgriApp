import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/notifications/data/admin_notification_repository.dart';
import 'package:admin_app/features/notifications/widgets/broadcast_dialog.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminNotificationRepository extends Mock
    implements AdminNotificationRepository {}

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pumpDialog(
  WidgetTester tester,
  MockAdminNotificationRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminNotificationRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              key: const Key('open_broadcast'),
              onPressed: () => showDialog<bool>(
                context: ctx,
                builder: (_) => const BroadcastDialog(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open_broadcast')));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAdminNotificationRepository repo;

  setUp(() {
    repo = MockAdminNotificationRepository();
    // Default: 4 active customers.
    when(() => repo.activeCustomerCount()).thenAnswer((_) async => 4);
  });

  group('BroadcastDialog — validation', () {
    testWidgets('empty title shows inline error', (tester) async {
      await _pumpDialog(tester, repo);

      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('empty body shows inline error', (tester) async {
      await _pumpDialog(tester, repo);

      await tester.enterText(find.byKey(const Key('broadcast_title')), 'Hello');
      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Body is required'), findsOneWidget);
    });

    testWidgets('title shorter than 3 chars shows error', (tester) async {
      await _pumpDialog(tester, repo);

      await tester.enterText(find.byKey(const Key('broadcast_title')), 'Hi');
      await tester.enterText(
          find.byKey(const Key('broadcast_body')), 'Some message');
      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Title must be at least 3 characters'), findsOneWidget);
    });

    testWidgets('body shorter than 3 chars shows error', (tester) async {
      await _pumpDialog(tester, repo);

      await tester.enterText(
          find.byKey(const Key('broadcast_title')), 'Valid title');
      await tester.enterText(find.byKey(const Key('broadcast_body')), 'Hi');
      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Body must be at least 3 characters'), findsOneWidget);
    });
  });

  group('BroadcastDialog — recipient count', () {
    testWidgets('shows live count from repository', (tester) async {
      await _pumpDialog(tester, repo);

      expect(
        find.byKey(const Key('recipient_count_text')),
        findsOneWidget,
      );
      expect(
        find.textContaining('4 active customers'),
        findsOneWidget,
      );
    });
  });

  group('BroadcastDialog — double-submit prevention', () {
    testWidgets('button is disabled while sending', (tester) async {
      // Use a completer so broadcast never completes during the test.
      final completer = Completer<BroadcastResult>();
      when(() => repo.broadcast(
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).thenAnswer((_) => completer.future);

      await _pumpDialog(tester, repo);

      await tester.enterText(
          find.byKey(const Key('broadcast_title')), 'Price drop');
      await tester.enterText(
          find.byKey(const Key('broadcast_body')), 'Big sale today');

      // First tap — starts the broadcast.
      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pump(); // start async, don't settle

      // Button should now be disabled (onPressed == null).
      final btn = tester
          .widget<ElevatedButton>(find.byKey(const Key('broadcast_submit')));
      expect(btn.onPressed, isNull);

      // Verify broadcast called exactly once.
      verify(() => repo.broadcast(
            title: 'Price drop',
            body: 'Big sale today',
          )).called(1);

      completer.complete(const BroadcastResult(sent: 4, total: 4));
    });

    testWidgets('second tap after send does not call broadcast again',
        (tester) async {
      when(() => repo.broadcast(
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => const BroadcastResult(sent: 4, total: 4));

      await _pumpDialog(tester, repo);

      await tester.enterText(find.byKey(const Key('broadcast_title')), 'Offer');
      await tester.enterText(
          find.byKey(const Key('broadcast_body')), 'Limited time');

      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pump();
      // Try a second tap — button is disabled during sending.
      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pumpAndSettle();

      // broadcast called only once despite two taps.
      verify(() => repo.broadcast(
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).called(1);
    });
  });

  group('BroadcastDialog — success', () {
    testWidgets('valid broadcast calls repo.broadcast and pops dialog',
        (tester) async {
      when(() => repo.broadcast(
            title: 'Price drop',
            body: 'Sale on fertilizers',
          )).thenAnswer((_) async => const BroadcastResult(sent: 4, total: 4));

      await _pumpDialog(tester, repo);

      await tester.enterText(
          find.byKey(const Key('broadcast_title')), 'Price drop');
      await tester.enterText(
          find.byKey(const Key('broadcast_body')), 'Sale on fertilizers');
      await tester.tap(find.byKey(const Key('broadcast_submit')));
      await tester.pumpAndSettle();

      verify(() => repo.broadcast(
            title: 'Price drop',
            body: 'Sale on fertilizers',
          )).called(1);

      // Dialog dismissed — title no longer on screen.
      expect(find.text('New broadcast'), findsNothing);
    });
  });
}
