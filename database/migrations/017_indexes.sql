-- 017_indexes.sql

create extension if not exists pg_trgm;

create index categories_parent_idx        on public.categories(parent_id);
create index categories_active_idx        on public.categories(is_active, display_order);
create index category_attributes_cat_idx  on public.category_attributes(category_id);
create index products_category_idx        on public.products(category_id);
create index products_published_idx       on public.products(is_active, is_published);
create index products_name_trgm_idx       on public.products using gin (name gin_trgm_ops);
create index product_attributes_prod_idx  on public.product_attributes(product_id);
create index product_attributes_attr_idx  on public.product_attributes(category_attribute_id);
create index product_images_prod_idx      on public.product_images(product_id, display_order);
create index inv_tx_prod_idx              on public.inventory_transactions(product_id, created_at desc);
create index addresses_user_idx           on public.addresses(user_id);
create index cart_items_product_idx       on public.cart_items(product_id);
create index orders_user_idx              on public.orders(user_id, created_at desc);
create index orders_status_idx            on public.orders(status, created_at desc);
create index order_items_order_idx        on public.order_items(order_id);
create index notifications_user_idx       on public.notifications(user_id, created_at desc);
create index notifications_unread_idx     on public.notifications(user_id) where not is_read;
