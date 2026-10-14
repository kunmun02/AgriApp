import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/notifications/controllers/unread_badge_controller.dart';
import 'package:customer_app/features/notifications/data/notification_repository.dart';
import 'package:customer_app/features/notifications/presentation/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

NotificationItem _item({
  String id = 'n1',
  String type = 'SYSTEM',
  String title = 'Hello',
  String body = 'This is a test notification',
  bool isRead = false,
  String? orderId,
}) =>
    NotificationItem(
      id: id,
      userId: 'user-1',
      type: type,
      title: title,
      body: body,
      isRead: isRead,
      createdAt: DateTime(2026, 10, 6),
      orderId: orderId,
    );

NotificationPaginated<NotificationItem> _page(
  List<NotificationItem> items, {
  int total = -1,
}) =>
    NotificationPaginated(
      items: items,
      total: total < 0 ? items.length : total,
      page: 1,
      pageSize: 20,
    );

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pumpPage(
  WidgetTester tester,
  MockNotificationRepository repo,
) async {
  // Stub unreadCount so the badge controller doesn't throw.
  when(() => repo.unreadCount()).thenAnswer((_) async => 0);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        unreadBadgeControllerProvider
            .overrideWith((ref) => UnreadBadgeController(repo)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const NotificationsPage(),
      ),
    ),
  );
  // Allow initState + async fetch to resolve.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockNotificationRepository repo;

  setUp(() {
    repo = MockNotificationRepository();
    when(() => repo.unreadCount()).thenAnswer((_) async => 0);
  });

  group('NotificationsPage — empty state', () {
    testWidgets('shows "No notifications." when list is empty', (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([]));

      await _pumpPage(tester, repo);

      expect(find.text('No notifications.'), findsOneWidget);
    });
  });

  group('NotificationsPage — renders notifications', () {
    testWidgets('displays notification title and body', (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([
                _item(title: 'Price drop', body: 'Check our new offers'),
              ]));

      await _pumpPage(tester, repo);

      expect(find.text('Price drop'), findsOneWidget);
      expect(find.text('Check our new offers'), findsOneWidget);
    });

    testWidgets('unread item shows unread dot', (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_item(id: 'n1', isRead: false)]));

      await _pumpPage(tester, repo);

      expect(find.byKey(const Key('unread_dot_n1')), findsOneWidget);
    });

    testWidgets('read item does not show unread dot', (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_item(id: 'n1', isRead: true)]));

      await _pumpPage(tester, repo);

      expect(find.byKey(const Key('unread_dot_n1')), findsNothing);
    });
  });

  group('NotificationsPage — mark read on tap', () {
    testWidgets('tapping an unread notification calls markRead and clears dot',
        (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_item(id: 'n1', isRead: false)]));
      when(() => repo.markRead('n1')).thenAnswer((_) async {});

      await _pumpPage(tester, repo);

      // Unread dot present before tap.
      expect(find.byKey(const Key('unread_dot_n1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('notif_list_tile_n1')));
      await tester.pumpAndSettle();

      // markRead called.
      verify(() => repo.markRead('n1')).called(1);

      // Unread dot gone after tap.
      expect(find.byKey(const Key('unread_dot_n1')), findsNothing);
    });

    testWidgets('tapping a read item does NOT call markRead', (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_item(id: 'n1', isRead: true)]));

      await _pumpPage(tester, repo);

      await tester.tap(find.byKey(const Key('notif_list_tile_n1')));
      await tester.pumpAndSettle();

      verifyNever(() => repo.markRead(any()));
    });
  });

  group('NotificationsPage — mark all read', () {
    testWidgets('"Mark all read" action appears when there are unread items',
        (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_item(id: 'n1', isRead: false)]));

      await _pumpPage(tester, repo);

      expect(find.byKey(const Key('mark_all_read')), findsOneWidget);
    });

    testWidgets('"Mark all read" not shown when all are read', (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_item(id: 'n1', isRead: true)]));

      await _pumpPage(tester, repo);

      expect(find.byKey(const Key('mark_all_read')), findsNothing);
    });

    testWidgets('tapping "Mark all read" calls markRead for each unread item',
        (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([
                _item(id: 'n1', isRead: false),
                _item(id: 'n2', isRead: false),
                _item(id: 'n3', isRead: true),
              ]));
      when(() => repo.markRead(any())).thenAnswer((_) async {});

      await _pumpPage(tester, repo);

      await tester.tap(find.byKey(const Key('mark_all_read')));
      await tester.pumpAndSettle();

      // markRead called for n1 and n2, not for n3 (already read).
      verify(() => repo.markRead('n1')).called(1);
      verify(() => repo.markRead('n2')).called(1);
      verifyNever(() => repo.markRead('n3'));

      // All unread dots gone.
      expect(find.byKey(const Key('unread_dot_n1')), findsNothing);
      expect(find.byKey(const Key('unread_dot_n2')), findsNothing);
    });
  });

  group('NotificationsPage — icon by type', () {
    testWidgets('ORDER_STATUS type renders truck icon', (tester) async {
      when(() => repo.fetch(page: any(named: 'page'))).thenAnswer(
          (_) async => _page([_item(id: 'n1', type: 'ORDER_STATUS')]));

      await _pumpPage(tester, repo);

      expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
    });

    testWidgets('SYSTEM type renders megaphone icon', (tester) async {
      when(() => repo.fetch(page: any(named: 'page')))
          .thenAnswer((_) async => _page([_item(id: 'n1', type: 'SYSTEM')]));

      await _pumpPage(tester, repo);

      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
    });
  });
}
