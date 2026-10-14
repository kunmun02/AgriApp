-- 020_seed_data.sql
-- DEV ONLY. Never seed credentials. Never run on production without review.
-- Uses fixed UUIDs so tests can reference rows by known IDs.

-- ============ Categories ============
insert into public.categories (id, name, slug, description, display_order, is_active) values
  ('11111111-1111-1111-1111-111111111111', 'Seeds',       'seeds',       'Vegetable and field crop seeds', 1, true),
  ('22222222-2222-2222-2222-222222222222', 'Fertilizers', 'fertilizers', 'Soil nutrition and boosters',    2, true),
  ('33333333-3333-3333-3333-333333333333', 'Farm Tools',  'farm-tools',  'Hand tools and equipment',       3, true),
  ('44444444-4444-4444-4444-444444444444', 'Pesticides',  'pesticides',  'Crop protection',                4, true);

-- ============ Category attributes ============
insert into public.category_attributes
  (id, category_id, name, attribute_key, data_type, options, is_required, display_order) values
  -- Seeds
  ('a1000001-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'Seed Variant', 'seed_variant', 'select',
   '["Hybrid","Desi","Open-Pollinated"]'::jsonb, true, 1),
  ('a1000001-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   'Weight (kg)', 'weight_kg', 'number',
   '[]'::jsonb, true, 2),
  ('a1000001-0000-0000-0000-000000000003',
   '11111111-1111-1111-1111-111111111111',
   'Organic', 'organic', 'boolean',
   '[]'::jsonb, false, 3),
  -- Fertilizers
  ('a2000002-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222',
   'Type', 'type', 'select',
   '["Urea","NPK","Compost","Potash"]'::jsonb, true, 1),
  ('a2000002-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222',
   'Net Weight (kg)', 'net_weight_kg', 'number',
   '[]'::jsonb, true, 2),
  -- Farm Tools
  ('a3000003-0000-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333',
   'Material', 'material', 'text',
   '[]'::jsonb, false, 1),
  ('a3000003-0000-0000-0000-000000000002',
   '33333333-3333-3333-3333-333333333333',
   'Warranty', 'warranty', 'boolean',
   '[]'::jsonb, false, 2),
  -- Pesticides
  ('a4000004-0000-0000-0000-000000000001',
   '44444444-4444-4444-4444-444444444444',
   'Active Ingredient', 'active_ingredient', 'text',
   '[]'::jsonb, false, 1),
  ('a4000004-0000-0000-0000-000000000002',
   '44444444-4444-4444-4444-444444444444',
   'Volume (ml)', 'volume_ml', 'number',
   '[]'::jsonb, true, 2);

-- ============ Products (6, published) ============
insert into public.products
  (id, category_id, name, slug, sku, description, brand,
   price, mrp, tax_percent, is_active, is_published) values
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'Tomato Hybrid Seeds', 'tomato-hybrid-seeds', 'SEED-TOM-001',
   'High yield tomato seeds', 'AgriPlus',
   149.00, 199.00, 5, true, true),

  ('aaaaaaaa-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   'Okra Desi Seeds', 'okra-desi-seeds', 'SEED-OKR-001',
   'Traditional okra seeds', 'AgriPlus',
   89.00, 120.00, 5, true, true),

  ('aaaaaaaa-0000-0000-0000-000000000003',
   '22222222-2222-2222-2222-222222222222',
   'NPK 19:19:19 (1kg)', 'npk-19-19-19-1kg', 'FERT-NPK-001',
   'Water soluble fertilizer', 'GrowMax',
   450.00, 520.00, 12, true, true),

  ('aaaaaaaa-0000-0000-0000-000000000004',
   '22222222-2222-2222-2222-222222222222',
   'Vermicompost (5kg)', 'vermicompost-5kg', 'FERT-VER-001',
   'Organic compost', 'GreenSoil',
   220.00, 260.00, 5, true, true),

  ('aaaaaaaa-0000-0000-0000-000000000005',
   '33333333-3333-3333-3333-333333333333',
   'Pruning Shears', 'pruning-shears', 'TOOL-PRU-001',
   'Stainless steel shears', 'KisanTools',
   349.00, 499.00, 18, true, true),

  ('aaaaaaaa-0000-0000-0000-000000000006',
   '44444444-4444-4444-4444-444444444444',
   'Neem Oil Pesticide (500ml)', 'neem-oil-500ml', 'PEST-NEM-001',
   'Cold pressed neem oil', 'NeoProtect',
   299.00, 350.00, 12, true, true);

-- ============ Product attributes ============
-- exactly one value column set per row; select options stored in value_text
insert into public.product_attributes
  (product_id, category_attribute_id, value_text, value_number, value_boolean, value_json) values
  -- Tomato Hybrid Seeds
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000001', 'Hybrid',  null,  null, null),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000002', null,      0.1,   null, null),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000003', null,      null,  false, null),
  -- Okra Desi Seeds
  ('aaaaaaaa-0000-0000-0000-000000000002', 'a1000001-0000-0000-0000-000000000001', 'Desi',    null,  null, null),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'a1000001-0000-0000-0000-000000000002', null,      0.25,  null, null),
  -- NPK 19:19:19
  ('aaaaaaaa-0000-0000-0000-000000000003', 'a2000002-0000-0000-0000-000000000001', 'NPK',     null,  null, null),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'a2000002-0000-0000-0000-000000000002', null,      1,     null, null),
  -- Vermicompost
  ('aaaaaaaa-0000-0000-0000-000000000004', 'a2000002-0000-0000-0000-000000000001', 'Compost', null,  null, null),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'a2000002-0000-0000-0000-000000000002', null,      5,     null, null),
  -- Pruning Shears
  ('aaaaaaaa-0000-0000-0000-000000000005', 'a3000003-0000-0000-0000-000000000001', 'Stainless Steel', null, null, null),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'a3000003-0000-0000-0000-000000000002', null,      null,  true, null),
  -- Neem Oil
  ('aaaaaaaa-0000-0000-0000-000000000006', 'a4000004-0000-0000-0000-000000000001', 'Cold Pressed Neem Oil', null, null, null),
  ('aaaaaaaa-0000-0000-0000-000000000006', 'a4000004-0000-0000-0000-000000000002', null,      500,   null, null);

-- ============ Inventory ============
insert into public.inventory (product_id, quantity, min_stock_level) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 100, 10),
  ('aaaaaaaa-0000-0000-0000-000000000002', 100, 10),
  ('aaaaaaaa-0000-0000-0000-000000000003',  50,  5),
  ('aaaaaaaa-0000-0000-0000-000000000004',  50,  5),
  ('aaaaaaaa-0000-0000-0000-000000000005',  30,  5),
  ('aaaaaaaa-0000-0000-0000-000000000006',  40,  5);

-- ============ Opening stock transaction log ============
insert into public.inventory_transactions
  (product_id, transaction_type, quantity_delta, reason)
  select product_id, 'INITIAL', quantity, 'dev seed'
  from public.inventory;
