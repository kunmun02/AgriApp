# PHASE_01 — Database (schema, RLS, RPC, seed)

## Goal
A fresh Supabase project carries the full schema (001–020), verified RLS, verified RPCs, seed data,
and the first admin account.

## Prerequisites
- PHASE_00 complete. Read: `01_DATABASE/01_SCHEMA_DDL.md`, `02_RLS_POLICIES.md`,
  `03_RPC_FUNCTIONS.md`, `04_SEED_AND_ADMIN_BOOTSTRAP.md`, `05_TESTING/02_E2E_AND_SECURITY.md` §A §B.

## Deliverables — exact files
```
database/migrations/001_profiles.sql          (01_DATABASE/01 §001, verbatim)
… 002_categories … 017_indexes                (01_DATABASE/01, one file per section)
database/migrations/018_rls.sql               (01_DATABASE/02 entire SQL)
database/migrations/019_rpc_functions.sql     (01_DATABASE/03 entire SQL)
database/migrations/020_seed_data.sql         (01_DATABASE/04 §seed)
database/runbooks/create_first_admin.sql      (01_DATABASE/04 §runbook)
database/tests/00_helpers.sql                 (act_as / expect_rows / expect_error + fixture users)
database/tests/01_rls_cases.sql  02_rpc_cases.sql  03_state_machine.sql  04_money_math.sql
```

## Tasks
1. Create the Supabase project (user-owned; record URL + anon key in `.env` — never service key).
2. Apply migrations 001→020 strictly in order (SQL editor or `supabase db push`). Append-only:
   an error means FIX IN A NEW MIGRATION or fix the not-yet-applied file — never edit applied ones.
3. Verify schema: run 01_DATABASE/01 §Post-migration check; spot-check `\d orders`, `\d products`.
4. Create the first admin via `database/runbooks/create_first_admin.sql` (dashboard-add the user,
   then run the UPDATE from the SQL editor — the guard allows `postgres`/`supabase_admin`).
5. Load fixture users via `database/tests/00_helpers.sql`; promote `:admin`.
6. Run RLS-C01…C12 (`01_rls_cases.sql`) — every case PASS.
7. Run RPC-R1…R11 (`02_rpc_cases.sql`) — including genuinely-concurrent R1 (two psql sessions).
8. Run SM-1…8 (`03_state_machine.sql`) and MONEY-1…3 (`04_money_math.sql`).

## Database impact
This phase IS the database. Nothing app-side yet.

## Verification commands
```sql
-- no table without RLS:
select relname from pg_class join pg_namespace n on n.oid=relnamespace
 where n.nspname='public' and relkind='table' and relname not in ('schema_migrations')
   and not exists (select 1 from pg_tables t where t.tablename=relname and t.rowsecurity);
-- expected: 0 rows
```
```
psql "$DB_URL" -f database/tests/01_rls_cases.sql     # 0 FAIL lines
psql "$DB_URL" -f database/tests/02_rpc_cases.sql     # 0 FAIL lines
```

## Acceptance criteria
- [ ] 20 migrations applied in order; re-running any already-applied one is never needed.
- [ ] All 16 public tables have RLS enabled with the exact policies of 01_DATABASE/02.
- [ ] `handle_new_user` created profile rows for both fixture users with role `customer`.
- [ ] First admin exists: `profiles.role='admin'` for the bootstrap email.
- [ ] RLS-C01…C12 all PASS (paste counts). Anon `curl "$URL/rest/v1/products?select=name"` with
      anon key returns only published products.
- [ ] RPC-R1…R11 all PASS; R1 shows exactly one succeeded order and non-negative inventory.
- [ ] Seed data visible: 4 categories, 6 products (fixed UUIDs) as anon.
- [ ] No service-role key ever pasted into any repo file (grep `service_role` → 0 hits in repo).

## Report
Use the templates in PHASE_00 § Report templates.
