-- 018_rls.sql
-- Security boundary. Enables RLS on all 16 tables and defines all policies.
-- Applied immediately after 001–017 as one push.

-- ---------- enable RLS everywhere ----------
alter table public.profiles                enable row level security;
alter table public.categories              enable row level security;
alter table public.category_attributes     enable row level security;
alter table public.products                enable row level security;
alter table public.product_attributes      enable row level security;
alter table public.product_images          enable row level security;
alter table public.inventory               enable row level security;
alter table public.inventory_transactions  enable row level security;
alter table public.addresses               enable row level security;
alter table public.carts                   enable row level security;
alter table public.cart_items              enable row level security;
alter table public.orders                  enable row level security;
alter table public.order_items             enable row level security;
alter table public.payments                enable row level security;
alter table public.notifications           enable row level security;
alter table public.app_settings            enable row level security;

-- ---------- profiles ----------
-- insert: only via handle_new_user trigger (security definer). No client insert policy.
create policy profiles_select_own_or_admin on public.profiles
  for select using (id = auth.uid() or public.is_admin());
create policy profiles_update_own_or_admin on public.profiles
  for update using (id = auth.uid() or public.is_admin());
-- column changes still guarded by profiles_guard trigger (001). No delete policy.

-- ---------- categories ----------
create policy categories_read on public.categories
  for select using (is_active or public.is_admin());
create policy categories_insert_admin on public.categories
  for insert with check (public.is_admin());
create policy categories_update_admin on public.categories
  for update using (public.is_admin());
create policy categories_delete_admin on public.categories
  for delete using (public.is_admin());

-- ---------- category_attributes ----------
create policy category_attributes_read on public.category_attributes
  for select using (is_active or public.is_admin());
create policy category_attributes_insert_admin on public.category_attributes
  for insert with check (public.is_admin());
create policy category_attributes_update_admin on public.category_attributes
  for update using (public.is_admin());
create policy category_attributes_delete_admin on public.category_attributes
  for delete using (public.is_admin());

-- ---------- products ----------
create policy products_read on public.products
  for select using ((is_active and is_published) or public.is_admin());
create policy products_insert_admin on public.products
  for insert with check (public.is_admin());
create policy products_update_admin on public.products
  for update using (public.is_admin());
create policy products_delete_admin on public.products
  for delete using (public.is_admin());

-- ---------- product_attributes ----------
create policy product_attributes_read on public.product_attributes
  for select using (
    public.is_admin()
    or exists (select 1 from public.products p
               where p.id = product_id and p.is_active and p.is_published)
  );
create policy product_attributes_insert_admin on public.product_attributes
  for insert with check (public.is_admin());
create policy product_attributes_update_admin on public.product_attributes
  for update using (public.is_admin());
create policy product_attributes_delete_admin on public.product_attributes
  for delete using (public.is_admin());

-- ---------- product_images ----------
create policy product_images_read on public.product_images
  for select using (
    public.is_admin()
    or exists (select 1 from public.products p
               where p.id = product_id and p.is_active and p.is_published)
  );
create policy product_images_insert_admin on public.product_images
  for insert with check (public.is_admin());
create policy product_images_update_admin on public.product_images
  for update using (public.is_admin());
create policy product_images_delete_admin on public.product_images
  for delete using (public.is_admin());

-- ---------- inventory (quantities are admin-only; customers use the view) ----------
create policy inventory_admin_all on public.inventory
  for all using (public.is_admin()) with check (public.is_admin());

create or replace view public.v_product_availability as
  select product_id, (quantity - reserved_quantity) > 0 as in_stock
  from public.inventory;

-- PG15: views execute with owner rights (postgres) => bypasses RLS intentionally.
-- It exposes ONLY a boolean; never add quantity columns to it.
grant select on public.v_product_availability to anon, authenticated;

-- ---------- inventory_transactions ----------
create policy inv_tx_admin_select on public.inventory_transactions
  for select using (public.is_admin());
-- inserts happen only inside security-definer RPCs (019); no client insert policy.

-- ---------- addresses ----------
create policy addresses_all_own on public.addresses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- carts ----------
create policy carts_all_own on public.carts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- cart_items ----------
create policy cart_items_all_own on public.cart_items
  for all using (
    exists (select 1 from public.carts c where c.id = cart_id and c.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.carts c where c.id = cart_id and c.user_id = auth.uid())
  );

-- ---------- orders (customer: read own; admin: read all; writes ONLY via RPC) ----------
create policy orders_select_own_or_admin on public.orders
  for select using (user_id = auth.uid() or public.is_admin());
-- no insert/update/delete policies on purpose

-- ---------- order_items ----------
create policy order_items_select_own_or_admin on public.order_items
  for select using (
    public.is_admin()
    or exists (select 1 from public.orders o
               where o.id = order_id and o.user_id = auth.uid())
  );

-- ---------- payments ----------
create policy payments_select_own_or_admin on public.payments
  for select using (
    public.is_admin()
    or exists (select 1 from public.orders o
               where o.id = order_id and o.user_id = auth.uid())
  );

-- ---------- notifications ----------
create policy notifications_select_own_or_admin on public.notifications
  for select using (user_id = auth.uid() or public.is_admin());
create policy notifications_update_own on public.notifications
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());
-- inserts happen only inside RPCs (019); no client insert policy.

-- ---------- app_settings ----------
create policy app_settings_read_authenticated on public.app_settings
  for select using (auth.uid() is not null);
create policy app_settings_update_admin on public.app_settings
  for update using (public.is_admin());

-- ============ storage ============
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true),
       ('category-images', 'category-images', true)
on conflict (id) do nothing;

create policy product_images_bucket_read on storage.objects
  for select using (bucket_id = 'product-images');
create policy product_images_bucket_insert on storage.objects
  for insert with check (bucket_id = 'product-images' and public.is_admin());
create policy product_images_bucket_update on storage.objects
  for update using (bucket_id = 'product-images' and public.is_admin());
create policy product_images_bucket_delete on storage.objects
  for delete using (bucket_id = 'product-images' and public.is_admin());

create policy category_images_bucket_read on storage.objects
  for select using (bucket_id = 'category-images');
create policy category_images_bucket_insert on storage.objects
  for insert with check (bucket_id = 'category-images' and public.is_admin());
create policy category_images_bucket_update on storage.objects
  for update using (bucket_id = 'category-images' and public.is_admin());
create policy category_images_bucket_delete on storage.objects
  for delete using (bucket_id = 'category-images' and public.is_admin());
