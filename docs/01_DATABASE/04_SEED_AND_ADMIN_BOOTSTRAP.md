# 04_SEED_AND_ADMIN_BOOTSTRAP.md — Migration 020 + first-admin runbook

## 020_seed_data.sql (development seed only)

Never seed credentials. Never seed production data. Categories use no images (app shows placeholder).

```sql
-- ============ 020_seed_data.sql (DEV ONLY) ============

-- Categories
insert into public.categories (id, name, slug, description, display_order, is_active) values
  ('11111111-1111-1111-1111-111111111111', 'Seeds',       'seeds',       'Vegetable and field crop seeds', 1, true),
  ('22222222-2222-2222-2222-222222222222', 'Fertilizers', 'fertilizers', 'Soil nutrition and boosters',    2, true),
  ('33333333-3333-3333-3333-333333333333', 'Farm Tools',  'farm-tools',  'Hand tools and equipment',       3, true),
  ('44444444-4444-4444-4444-444444444444', 'Pesticides',  'pesticides',  'Crop protection',                4, true);

-- Category attributes
insert into public.category_attributes
  (category_id, name, attribute_key, data_type, options, is_required, display_order) values
  ('11111111-...', 'Seed Variant',   'seed_variant', 'select',     '["Hybrid","Desi","Open-Pollinated"]'::jsonb, true,  1),
  ('11111111-...', 'Weight (kg)',    'weight_kg',    'number',     '[]'::jsonb, true,  2),
  ('11111111-...', 'Organic',        'organic',      'boolean',    '[]'::jsonb, false, 3),
  ('22222222-...', 'Type',           'type',         'select',     '["Urea","NPK","Compost","Potash"]'::jsonb, true,  1),
  ('22222222-...', 'Net Weight (kg)','net_weight_kg','number',    '[]'::jsonb, true,  2),
  ('33333333-...', 'Material',       'material',     'text',       '[]'::jsonb, false, 1),
  ('33333333-...', 'Warranty',       'warranty',     'boolean',    '[]'::jsonb, false, 2),
  ('44444444-...', 'Active Ingredient','active_ingredient','text','[]'::jsonb, false, 1),
  ('44444444-...', 'Volume (ml)',    'volume_ml',    'number',     '[]'::jsonb, true,  2);
-- (write full UUIDs, not '...' — shown shortened here only for readability)

-- Products (6, published, price/mrp/tax set)
insert into public.products (id, category_id, name, slug, sku, description, brand, price, mrp, tax_percent, is_active, is_published) values
  ('aaaaaaaa-0000-0000-0000-000000000001','11111111-...','Tomato Hybrid Seeds','tomato-hybrid-seeds','SEED-TOM-001','High yield tomato seeds','AgriPlus',149.00,199.00,5,true,true),
  ('aaaaaaaa-0000-0000-0000-000000000002','11111111-...','Okra Desi Seeds','okra-desi-seeds','SEED-OKR-001','Traditional okra seeds','AgriPlus',89.00,120.00,5,true,true),
  ('aaaaaaaa-0000-0000-0000-000000000003','22222222-...','NPK 19:19:19 (1kg)','npk-19-19-19-1kg','FERT-NPK-001','Water soluble fertilizer','GrowMax',450.00,520.00,12,true,true),
  ('aaaaaaaa-0000-0000-0000-000000000004','22222222-...','Vermicompost (5kg)','vermicompost-5kg','FERT-VER-001','Organic compost','GreenSoil',220.00,260.00,5,true,true),
  ('aaaaaaaa-0000-0000-0000-000000000005','33333333-...','Pruning Shears','pruning-shears','TOOL-PRU-001','Stainless steel shears','KisanTools',349.00,499.00,18,true,true),
  ('aaaaaaaa-0000-0000-0000-000000000006','44444444-...','Neem Oil Pesticide (500ml)','neem-oil-500ml','PEST-NEM-001','Cold pressed neem oil','NeoProtect',299.00,350.00,12,true,true);

-- Product attributes (values matching each attribute's data_type; exactly one value column)
insert into public.product_attributes (product_id, category_attribute_id, value_text, value_number, value_boolean) values
  ('...0001','(seeds.seed_variant id)', 'Hybrid',       null, null),
  ('...0001','(seeds.weight_kg id)',    null, 0.1,       null),
  ('...0001','(seeds.organic id)',      null, null,      false),
  ('...0002','(seeds.seed_variant id)', 'Desi',         null, null),
  ('...0002','(seeds.weight_kg id)',    null, 0.25,      null),
  ('...0003','(fertilizers.type id)',   null, null, null) /* use value_json? NO:
     select attribute -> store option string in value_text, e.g. 'NPK' */,
  ('...0003','(fertilizers.net_weight_kg id)', null, 1, null),
  ('...0005','(tools.material id)',     'Stainless Steel', null, null),
  ('...0005','(tools.warranty id)',     null, null, true),
  ('...0006','(pesticides.active_ingredient id)','Cold Pressed Neem Oil', null, null),
  ('...0006','(pesticides.volume_ml id)', null, 500, null);
-- resolve every "(... id)" to the actual uuid via subselect:
--   (select id from public.category_attributes where attribute_key='seed_variant' and category_id='11111111-...')
-- (spec requires the file to contain literal subselects, not placeholders)

-- Inventory
insert into public.inventory (product_id, quantity, min_stock_level) values
  ('...0001', 100, 10), ('...0002', 100, 10), ('...0003', 50, 5),
  ('...0004', 50, 5),   ('...0005', 30, 5),  ('...0006', 40, 5);

-- Opening stock tx log
insert into public.inventory_transactions (product_id, transaction_type, quantity_delta, reason)
  select product_id, 'INITIAL', quantity, 'dev seed' from public.inventory;
```

**Rule:** the shipped `020_seed_data.sql` must contain full literal UUIDs or subselects — no `...` placeholders.
The snippet above shortens IDs for readability only.

## First admin bootstrap — `database/runbooks/create_first_admin.sql`

Run ONCE by the project owner in Supabase Dashboard → SQL Editor. Never in client code.

```sql
-- create_first_admin.sql
-- Step 1 (Dashboard): Authentication -> Users -> "Add user" -> enter admin email + password
--                     (or invite; email confirmation is disabled in MVP)
-- Step 2: run this with the SAME email you used in step 1:
update public.profiles
   set role = 'admin'
 where email = 'admin@yourstore.example';      -- <-- replace

-- Step 3: verify exactly one admin exists
select id, email, role, is_active from public.profiles where role = 'admin';
```

Why the guard trigger does not block this: `profiles_guard` (001) allows `current_user = 'postgres'`,
and the SQL Editor runs as `postgres`. Client connections run as `authenticated`/`anon` and are always blocked.

## Full-reset procedure (fresh environment)

```bash
supabase link --project-ref <ref>
supabase db push        # applies 001..020 in order
# then run create_first_admin.sql once
```

## Applying to a hosted project without CLI

Supabase Dashboard → SQL Editor → paste each migration file in order 001 → 020 and run.
Record applied files in `database/migrations/APPLIED.md` (date + file list) — the AI agent must check this
before writing any new migration.
