# PHASE_16 — Production release

## Goal
Signed customer AAB ready for Play Store, deployed admin web app, a fresh production database, and
a smoke-tested live stack. (Absorbs V3's 08_RELEASE content — V4 has no separate release folder.)

## Prerequisites
- PHASE_15 fully green. Read: `00_MASTER`, `01_DATABASE/04_SEED_AND_ADMIN_BOOTSTRAP.md`,
  `03_FLUTTER/01_ARCHITECTURE.md` §env/dart-define.

## Deliverables — exact files / artifacts
```
customer_app/android/key.properties           (git-ignored; keystore path + passwords, user-owned)
customer_app/android/app/build.gradle         (release signing reads key.properties + env)
customer_app/build/app/outputs/bundle/release/app-release.aab
admin_app/build/web/                          (flutter build web --release)
ops/prod_setup_checklist.md                   (executed, dated, initialed)
ops/release_notes_v1.md                       (from Phase 15 draft)
```

## Tasks
1. Production Supabase project: apply migrations 001→020 in order (fresh, no dev seed beyond 020
   if real categories differ — decide: keep 020's 4 starter categories or delete them post-setup;
   both allowed, record the choice).
2. Create the real first admin via the runbook; enable Supabase Auth email confirmation OFF
   (MVP auto-signin) or ON with redirects — record the choice; configure Site URL.
3. Storage buckets exist via 018; verify policies on prod project (re-run C05/C06/C12 quickly).
4. Android signing: user generates keystore (`keytool -genkeypair -v -keystore
   ~/agristore-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`); wire
   `key.properties`; NEVER commit it; build AAB:
   `flutter build appbundle --dart-define-from-file=.env.prod`.
5. Admin web: `flutter build web --release --dart-define-from-file=.env.prod`; deploy to the
   user's host (Firebase Hosting / any static host); HTTPS required.
6. `ops/prod_setup_checklist.md` executed: env values correct (anon key only), app version +
   build number bumped, Play listing assets (icon 512, feature graphic, ≥ 2 phone screenshots),
   privacy policy URL (collects email/phone/address — say so), content rating, data safety form.
7. Live smoke (E2E-1 short form on the PROD stack): register → browse → order → admin confirms →
   delivered; then delete the smoke order data if desired (never delete migration history).
8. Rollback plan noted: keep the previous AAB; database changes are append-only — a rollback is a
   new migration or a project restore from backup (document backup schedule: daily automatic).

## Database impact
Fresh production project ONLY (dev project untouched).

## Verification commands
```
flutter build appbundle --dart-define-from-file=.env.prod      # succeeds
flutter build web --release --dart-define-from-file=.env.prod  # succeeds
# prod REST sanity with anon key:
curl "$PROD_URL/rest/v1/categories?select=name&is_active=eq.true" -H "apikey: $ANON_KEY"
# prod RLS sanity: anon write attempts → 401/403 (re-run C03/C05/C12 mini-suite)
```

## Acceptance criteria
- [ ] AAB builds signed (verified via `jarsigner -verify` or bundletool) and uploads to Play
      Console internal testing.
- [ ] Admin web live over HTTPS; admin login + dashboard + one status change work on prod.
- [ ] Prod database: 20 migrations applied, first admin exists, RLS spot-cases pass.
- [ ] Live smoke journey completes end-to-end with a real COD order.
- [ ] No secrets in the repo (`git status` clean of key.properties/`.env.prod`; history grep 0).
- [ ] `ops/prod_setup_checklist.md` + `ops/release_notes_v1.md` committed.
- [ ] Internal testers can install from the Play internal track.

## Report
Use the templates in PHASE_00 § Report templates — then the project is DONE for MVP; future work
lives outside V4 scope (payments gateway, customer cancel, etc. — all listed in 00_MASTER §Out of
scope on purpose).
