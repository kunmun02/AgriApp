# PHASE_02 — Authentication (customer app)

## Goal
C01 Splash/Session gate, C02 Login, C03 Register, session restore, guarded customer router, Profile
model + AuthRepository + AuthController.

## Prerequisites
- PHASE_00, PHASE_01. Read: `04_UI/02_CUSTOMER_SCREENS.md` C01–C03, `04_UI/04_NAVIGATION_AND_ROUTES.md`,
  `03_FLUTTER/02_MODELS.md` (Profile), `03_FLUTTER/03_REPOSITORIES.md` (AuthRepository).

## Deliverables — exact files
```
customer_app/lib/features/auth/data/auth_repository.dart
customer_app/lib/features/auth/data/models/profile.dart
customer_app/lib/features/auth/controllers/auth_controller.dart   (StateNotifier<AsyncValue<Profile?>>)
customer_app/lib/features/auth/presentation/splash_page.dart       (C01)
customer_app/lib/features/auth/presentation/login_page.dart        (C02)
customer_app/lib/features/auth/presentation/register_page.dart     (C03)
customer_app/lib/core/router/app_router.dart                       (full customer route table, placeholders for C04+)
test/core/utils/formatters_test.dart            (already exists)
test/features/auth/presentation/login_page_test.dart
test/features/auth/presentation/register_page_test.dart
test/core/router/router_test.dart
```

## Tasks
1. `Profile` model exactly per 03_FLUTTER/02 (role enum customer/admin; unknown → customer).
2. `AuthRepository` per 03_FLUTTER/03 (signUp passes `data: {'full_name': …}` so the trigger fills
   the profile; signIn fetches the profile row after password auth).
3. `AuthController`: restore on start; wraps signUp/signIn/signOut; exposes `AsyncValue<Profile?>`.
4. C01: restore with 3 s timeout → `/home` or `/login` (04_UI/02 C01 layout).
5. C02/C03 with all validation copy, inline errors, loading buttons, server message mapping
   (23505 duplicate email → friendly text).
6. Router: full guard `redirect` from 04_UI/04; authenticated routes list all 17 customer routes
   (screens as placeholder pages except C01–C03).
7. Tests per 05_TESTING/01 rows for login/register/router.

## Database impact
None (writes via Auth + trigger only).

## Verification commands
```
cd customer_app && dart format . && flutter analyze && flutter test
```
Manual: register `demo1@example.com` → lands `/home`; check DB has `profiles` row with full_name;
kill + relaunch app → still signed in; sign out → `/login`; deep-link `/home` signed-out → `/login`.

## Acceptance criteria
- [ ] C01–C03 acceptance criteria of 04_UI/02 all demonstrated.
- [ ] `flutter test` green including router redirect cases (signed-in↔out, unknown route).
- [ ] New signup's profile row has correct full_name (trigger works, no manual insert).
- [ ] Wrong password shows "Invalid email or password"; never leaks which part was wrong.
- [ ] No Supabase call outside repository files (`grep -rn "from('" lib/ | grep -v data/` → 0).

## Report
Use the templates in PHASE_00 § Report templates.
