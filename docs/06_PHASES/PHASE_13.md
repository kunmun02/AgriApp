# PHASE_13 — Customers & notifications (A13/A14/A15 + C15)

## Goal
Admin customer list/details with activation toggle, admin notifications list + broadcast composer,
and the customer notifications screen with unread handling.

## Prerequisites
- PHASE_12. Read: `04_UI/03_ADMIN_SCREENS.md` A13/A14/A15, `04_UI/02_CUSTOMER_SCREENS.md` C15,
  `03_FLUTTER/03` AdminCustomerRepository, AdminNotificationRepository, NotificationRepository,
  `02_BACKEND/01` §notifications rows.

## Deliverables — exact files
```
admin_app/lib/features/customers/data/admin_customer_repository.dart    (complete: list, details, ordersOf, setActive)
admin_app/lib/features/customers/presentation/customers_page.dart       (A13)
admin_app/lib/features/customers/presentation/customer_details_page.dart (A14)
admin_app/lib/features/notifications/data/admin_notification_repository.dart (list + broadcast)
admin_app/lib/features/notifications/presentation/admin_notifications_page.dart (A15)
admin_app/lib/features/notifications/widgets/broadcast_dialog.dart
customer_app/lib/features/notifications/data/notification_repository.dart
customer_app/lib/features/notifications/data/models/notification_item.dart
customer_app/lib/features/notifications/presentation/notifications_page.dart  (C15)
customer_app/lib/features/notifications/controllers/unread_badge_controller.dart  (60 s poll per 00_MASTER)
test/features/notifications/presentation/broadcast_dialog_test.dart
test/features/notifications/presentation/notifications_page_test.dart (customer)
```

## Tasks
1. A13: debounced search, table (name, email, phone, joined), Active switch with confirm, row →
   A14. Admins never listed.
2. A14: profile card + activate/deactivate + paginated orders table → A12.
3. A15: broadcast dialog (title/body validation, "Will be sent to N active customers" live count,
   locked button while sending, partial-failure report "Sent to X of N"); notifications table
   newest first with type chips.
4. C15: paginated tiles (type icon: truck=ORDER_STATUS, megaphone=SYSTEM), tap → mark read via
   `mark_notification_read` rpc, "Mark all read" loops rpcs, unread badge on shell syncs via 60 s
   poll + refetch on screen open.
5. Tests per 05_TESTING/01 (broadcast dialog, customer notifications).

## Database impact
None.

## Verification commands
```
cd admin_app && dart format . && flutter analyze && flutter test
cd customer_app && dart format . && flutter analyze && flutter test
```
Manual: broadcast to 4 active customers → `select count(*) from notifications where type='SYSTEM' and title='…'`
= 4; deactivate a customer → broadcast count excludes them; customer app shows unread → tap clears.

## Acceptance criteria
- [ ] A13–A15 + C15 acceptance criteria of their screen specs all demonstrated.
- [ ] Broadcast recipient count excludes inactive profiles (DB proof).
- [ ] Double-submit of broadcast impossible (button lock test green).
- [ ] Customer mark-read only affects own rows (rpc owner check — R-case from Phase 01 still holds).
- [ ] Unread badge decrements after read; poll interval exactly 60 s (const + test).

## Report
Use the templates in PHASE_00 § Report templates.
