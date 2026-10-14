# PHASE_14 — Settings & UX polish (A16 + C16 + polish sweep)

## Goal
Admin settings editor (delivery money knobs), customer profile screen, and a full polish audit:
every screen's five states, navigation smoke checks, deep links, 404.

## Prerequisites
- PHASE_13. Read: `04_UI/03_ADMIN_SCREENS.md` A16 + cross-screen rules, `04_UI/02` C16,
  `04_UI/04` §Navigation smoke checklist, `00_MASTER` §settings.

## Deliverables — exact files
```
admin_app/lib/features/settings/data/admin_settings_repository.dart
admin_app/lib/features/settings/data/models/app_settings.dart   (mirror of customer model)
admin_app/lib/features/settings/presentation/settings_page.dart  (A16)
customer_app/lib/features/profile/presentation/profile_page.dart (C16)
customer_app/lib/features/profile/controllers/profile_controller.dart (update full_name/phone)
polish audit additions (as needed): missing EmptyState/ErrorRetry on any network screen,
  loading skeletons, ConfirmDialogs, Formatters adoption
test/features/settings/presentation/settings_page_test.dart
test/features/profile/presentation/profile_page_test.dart
```

## Tasks
1. A16 per 04_UI/03: delivery charge + threshold editing (string→num parse, ≥ 0, 2 decimals),
   live helper texts (threshold 0 → "Free delivery is disabled"), read-only Store card, Save.
2. C16 per 04_UI/02: avatar initial, name/email/phone (edit full_name + phone inline), app version
   from pubspec, "My Orders" and "My Addresses" shortcuts, Notifications shortcut with unread
   count, Logout (confirm).
3. Polish sweep — walk EVERY screen against 04_UI/01 §States contract:
   loading (skeleton/spinner), empty (message + next action), error (safe message + retry),
   validation (inline, values preserved), success (snackbar + next action), forbidden-safe.
4. Navigation smoke checklist from 04_UI/04 executed line by line (both apps).
5. Deep links: product/order ids → valid screens or graceful error; unknown path → NotFound.

## Database impact
None.

## Verification commands
```
cd admin_app && dart format . && flutter analyze && flutter test
cd customer_app && dart format . && flutter analyze && flutter test
```
Manual: set charge 50 / threshold 200 → customer checkout with ₹250 subtotal shows FREE; reopen
A16 shows saved values; profile edits persist (DB check); run the smoke checklist fully.

## Acceptance criteria
- [ ] A16 + C16 acceptance criteria demonstrated (incl. FREE-at-threshold end-to-end).
- [ ] States-contract audit table filled for all C01–C16 and A01–A16 (each state ✅ with evidence).
- [ ] Navigation smoke checklist 04_UI/04 — all 5 lines pass.
- [ ] `grep -rn "Color(0x" lib/ | grep -v theme` → 0 (tokens only).
- [ ] `grep -rn "TODO\|FIXME" lib/` → 0.
- [ ] Both apps analyzer 0, tests green.

## Report
Use the templates in PHASE_00 § Report templates.
