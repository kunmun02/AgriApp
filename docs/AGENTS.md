# AgriStore AI Build Contract (V4)

Read this before coding. This V4 pack is the single source of truth. It supersedes V3.
Every file is Markdown so any AI agent (Claude, GPT, Grok, GLM, Qwen, Cursor, etc.) can parse it reliably.

## Source of truth (read in this order)

1. `AGENTS.md` (this file)
2. `00_MASTER/00_MASTER_SPECIFICATION.md`
3. Your assigned phase: `06_PHASES/PHASE_XX.md`
4. Linked documents referenced by that phase
5. The existing repository code

## Repository layout you will build

```
agristore/                        # project root
├── customer_app/                 # Flutter Android customer app (independent project)
├── admin_app/                    # Flutter Web admin panel (independent project)
├── database/
│   ├── migrations/               # 001_profiles.sql ... 020_seed_data.sql (append-only)
│   └── runbooks/                 # admin bootstrap SQL (run once by project owner)
├── docs/                         # copy of this spec pack
└── .env.example                  # template only — never commit real keys
```

## Hard rules

- One phase at a time. Never implement a future phase.
- Never invent product, security, schema, navigation or business decisions. V4 already decides everything; follow it.
- Never expose service-role credentials to client code. Only the anon key goes in client `.env`.
- Never bypass or weaken RLS. RLS is the security boundary; UI guards are UX only.
- Never trust client-sent totals, prices, stock or order status. Server recalculates everything.
- Never create one table per product category. Dynamic data lives in `category_attributes` + `product_attributes`.
- Never rewrite an applied migration. Add a new one (append-only).
- Preserve historical order meaning: order_items keep name/sku/price/tax snapshots; never mutate paid history.
- Every network screen implements loading, empty, error, validation and success states.
- Run `dart format .`, `flutter analyze`, and the phase's tests before claiming completion.
- Review `git diff` before reporting. Report actual command output; never claim unverified behavior.
- Stop and ask when something in V4 is genuinely contradictory or blocking — quote the exact line.

## Phase workflow (mandatory loop)

READ → INSPECT → PLAN → IMPLEMENT → FORMAT → ANALYZE → TEST → REVIEW DIFF → VERIFY → REPORT → STOP

Each phase file lists: goal, prerequisites, exact files to create/modify, tasks, database impact,
verification commands and acceptance criteria. You may not report the phase complete until every
acceptance criterion is checked with real output.

## Reporting format

Use `07 templates` embedded in `06_PHASES/PHASE_00.md` § "Report templates" (start report + completion report).
