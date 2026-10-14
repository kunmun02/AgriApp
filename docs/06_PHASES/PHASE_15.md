# PHASE_15 — QA & security verification

## Goal
Everything green: full automated suites, all database security/business scenarios re-run on the
final build, the security failure catalog signed off, zero loose ends.

## Prerequisites
- PHASE_00–14 complete. Read: `05_TESTING/01_TEST_PLAN.md`, `05_TESTING/02_E2E_AND_SECURITY.md`
  (all sections), `AGENTS.md` reporting rules.

## Deliverables — exact files
```
database/tests/00_helpers.sql … 04_money_math.sql   (finalized, all PASS)
qa/phase15_report.md                 (the completion report + attached outputs)
qa/security_signoff.md               (F1–F12 table from 05_TESTING/02 §F with evidence each)
```

## Tasks
1. Static: `dart format --set-exit-if-changed .` and `flutter analyze` in BOTH apps → clean.
2. Unit + widget: `flutter test` both apps → paste the exact summary lines into the report.
3. Integration: run `integration_test/e2e_01…05` on an emulator/Chrome with `.env.test`.
4. Database scripts on a FRESH project restored from migrations + seed (never the dev database):
   `01_rls_cases` (C01–C12), `02_rpc_cases` (R1–R11 incl. concurrent R1), `03_state_machine`
   (SM-1–8), `04_money_math` (MONEY-1–3) → 0 FAIL everywhere.
5. E2E-6…10 executed per 05_TESTING/02 §C (manual walkthroughs + SQL asserts).
6. Security sweep: F1–F12 each verified with the detection method listed; `grep` checks for
   service-role strings, PII logging, TODO/FIXME.
7. Sanity performance: cold start < 3 s on emulator; catalog scroll 60 fps-ish (subjective ok);
   list screens paginate rather than load-all.
8. Write `qa/phase15_report.md` and `qa/security_signoff.md` with real outputs only.

## Database impact
None (read-only verification; fresh throwaway project for scripts).

## Verification commands
```
cd customer_app && dart format --set-exit-if-changed . && flutter analyze && flutter test
cd admin_app    && dart format --set-exit-if-changed . && flutter analyze && flutter test
cd customer_app && flutter test integration_test --dart-define-from-file=.env.test
psql "$FRESH_DB_URL" -f database/tests/01_rls_cases.sql    # etc. 01→04
```

## Acceptance criteria
- [ ] Both apps: analyzer 0 issues; format clean; ALL unit/widget tests pass (outputs pasted).
- [ ] All 5 integration journeys pass on-device.
- [ ] RLS-C01…C12, RPC-R1…R11, SM-1…8, MONEY-1…3 → 0 FAIL on a fresh database.
- [ ] E2E-1…E2E-10 each marked pass with evidence notes.
- [ ] F1–F12 signed off in `qa/security_signoff.md` (each row: method + result).
- [ ] No TODO/FIXME in either app; no `service_role` string anywhere in the repo.
- [ ] Release notes draft (user-visible changes list) exists for Phase 16.

## Report
Use the templates in PHASE_00 § Report templates. This phase's completion report IS the QA gate —
any unchecked box blocks Phase 16.
