# AgriStore — V4 AI Build Specification

Complete, deterministic build pack for a two-app agricultural e-commerce system.

## What this is

V4 replaces V3. V3 was an outline (~6,000 words); V4 contains every decision and every line of
security-critical SQL so that ANY competent AI model produces the SAME application.

## How to use with any AI model

1. Give the model the whole `AgriStore_AI_Build_Specification_V4` folder plus an empty repo.
2. Prompt: "Read AGENTS.md, then 00_MASTER, then implement only PHASE_00. Start with the phase
   start report and stop for approval."
3. Approve each phase report, then run the next phase. Never allow batch execution of phases.

## Document map

| Folder | File | Contents |
|---|---|---|
| 00_MASTER | 00_MASTER_SPECIFICATION.md | Mission, stack, ALL business rules, MVP scope |
| 01_DATABASE | 01_SCHEMA_DDL.md | Migrations 001–017: complete SQL for every table, constraint, index |
| 01_DATABASE | 02_RLS_POLICIES.md | Migration 018: complete RLS policy SQL for every table + storage |
| 01_DATABASE | 03_RPC_FUNCTIONS.md | Migration 019: complete PL/pgSQL bodies incl. atomic checkout |
| 01_DATABASE | 04_SEED_AND_ADMIN_BOOTSTRAP.md | Migration 020 seed data + first-admin runbook |
| 02_BACKEND | 01_DATA_CONTRACTS.md | JSON shapes, pagination envelope, storage paths, realtime/polling |
| 02_BACKEND | 02_ERROR_CODES.md | Error envelope, code table, client handling |
| 03_FLUTTER | 01_ARCHITECTURE.md | Folder trees, pubspec dependencies, bootstrap, env config |
| 03_FLUTTER | 02_MODELS.md | Every Dart model: fields, JSON keys, rules |
| 03_FLUTTER | 03_REPOSITORIES.md | Every repository: exact method signatures + Supabase calls |
| 04_UI | 01_DESIGN_SYSTEM.md | Colors, typography, spacing, shared components |
| 04_UI | 02_CUSTOMER_SCREENS.md | C01–C16: layout, fields, validation, states, acceptance criteria |
| 04_UI | 03_ADMIN_SCREENS.md | A01–A16: same depth for admin |
| 04_UI | 04_NAVIGATION_AND_ROUTES.md | Complete go_router config: routes, guards, redirects |
| 05_TESTING | 01_TEST_PLAN.md | Unit/widget/integration/DB test files and case names |
| 05_TESTING | 02_E2E_AND_SECURITY.md | 10 E2E journeys numbered step-by-step + security checks |
| 06_PHASES | PHASE_00.md … PHASE_16.md | 17 phases with exact files, tasks, acceptance criteria |

## Locked business decisions (do not re-litigate)

- Currency INR (₹), region India, `en_IN` number formatting
- Tax: per-product `tax_percent` (0–100), snapshot into order_items
- Delivery: flat ₹40, free when subtotal ≥ ₹500, both configurable in `app_settings`
- Payment: Cash on Delivery only
- Order statuses: NEW → CONFIRMED → PROCESSING → PACKED → SHIPPED → OUT_FOR_DELIVERY → DELIVERED;
  CANCELLED allowed from NEW/CONFIRMED/PROCESSING (restocks inventory)
- First admin: created via `database/runbooks/create_first_admin.sql` (never via client code)
