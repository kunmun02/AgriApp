# PHASE_00 — Foundation (empty runnable scaffold)

## Goal
Both Flutter apps build and run against nothing yet: repo layout, exact dependencies, theme tokens,
error types, config loading, minimal routers. No Supabase calls beyond client init.

## Prerequisites
- None. Read first: `AGENTS.md`, `00_MASTER/00_MASTER_SPECIFICATION.md`, `03_FLUTTER/01_ARCHITECTURE.md`, `04_UI/01_DESIGN_SYSTEM.md`.

## Deliverables — exact files
```
.gitignore                        (Flutter default + .env, *.g.dart, build/)
.env.example                      (customer + admin: SUPABASE_URL=, SUPABASE_ANON_KEY=)
customer_app/                     flutter create --org com.agristore --platforms android
admin_app/                        flutter create --platforms web
customer_app/lib/core/config/app_config.dart
customer_app/lib/core/theme/app_theme.dart          (04_UI/01 tokens verbatim)
customer_app/lib/core/errors/app_failure.dart       (sealed class, 02_BACKEND/02)
customer_app/lib/core/errors/error_mapper.dart      (skeleton: 5 rules)
customer_app/lib/core/utils/formatters.dart         (Formatters.inr, dateShort)
customer_app/lib/core/utils/validators.dart         (all rules from 00_MASTER §Validation)
customer_app/lib/core/widgets/                      (empty — filled later)
customer_app/lib/core/router/app_router.dart        (routes: /, /login placeholder)
customer_app/lib/main.dart                          (bootstrap per 03_FLUTTER/01 §main.dart)
admin_app/lib/…                                     (mirror core/, router: /admin/login placeholder)
database/migrations/  database/runbooks/  database/tests/   (empty dirs, .gitkeep)
```

## Tasks
1. `flutter create` both apps per commands above; apply minSdk 24 (customer) per 03_FLUTTER/01.
2. Add exact pubspec dependencies (03_FLUTTER/01 §pubspec) — no extras, no different versions.
3. Create `.env.example` files; add `.env` to `.gitignore`; NEVER commit real keys.
4. Implement `app_config.dart` reading `String.fromEnvironment('SUPABASE_URL')` etc.
5. Implement `app_theme.dart` with the full token table from 04_UI/01 (colors, text themes, radii,
   button/input themes with loading/disabled support).
6. Implement `AppFailure` + `ErrorMapper` exactly per 02_BACKEND/02 (including P0001 json envelope).
7. Implement `Formatters` (₹ en_IN) and `Validators` (email, password ≥8, phone `^[6-9]\d{9}$`,
   postal `^[1-9]\d{5}$`, sku `^[A-Z0-9-]{3,40}$`, qty 1–99, price non-negative).
8. Bootstrap Supabase in both `main.dart`s; placeholder login/home screens; routers with guard
   stubs from 04_UI/04 §Guard implementation.

## Database impact
None.

## Verification commands
```
cd customer_app && dart format . && flutter analyze && flutter test
cd admin_app    && dart format . && flutter analyze && flutter test
cd customer_app && flutter run            # placeholder screen renders
cd admin_app    && flutter run -d chrome  # placeholder renders
```

## Acceptance criteria
- [ ] Both apps `flutter analyze` → 0 issues.
- [ ] `grep -r "Supabase.instance" lib/` appears ONLY in main.dart and repositories (none yet).
- [ ] `Formatters.inr(1234567.5)` test returns `₹12,34,567.50` (write the test now).
- [ ] Every Validator rule has a passing unit test (write now, list in 05_TESTING/01).
- [ ] `.env` is git-ignored; `.env.example` exists in both apps.
- [ ] Placeholder screens use AppTheme (no hardcoded colors outside theme file).

## Report templates (used by EVERY phase — copy verbatim)

### Start report (post before implementing)
```
PHASE <id> START
Read: <list of docs actually opened>
Inspected: <git branch, existing files touched by this phase, surprises found>
Plan: <ordered summary of tasks, 5-15 lines>
Blocks/questions: <none, or exact quote of the contradicting spec line>
```

### Completion report (post before stopping)
```
PHASE <id> RESULT
Commands run + actual output lines:
  dart format .        → <e.g. "Formatted 42 files (0 changed)">
  flutter analyze      → <paste summary line>
  flutter test         → <paste summary line, e.g. "All tests passed!">
  <phase DB scripts>   → <PASS/FAIL counts>
Diff summary: <files created/changed, one line each>
Acceptance criteria: <each checkbox with ✅/❌ + one-line evidence>
Not done / deferred: <anything unchecked, honestly>
Next phase: PHASE <id+1> — ready / blocked because <reason>
```
