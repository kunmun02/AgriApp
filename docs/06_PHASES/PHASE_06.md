# PHASE_06 — Products (admin A07/A08/A09)

## Goal
Product list with filters/pagination, the create/edit form with category-locked dynamic attribute
fields, draft vs publish, and the media manager.

## Prerequisites
- PHASE_04, PHASE_05. Read: `04_UI/03_ADMIN_SCREENS.md` A07/A08/A09, `03_FLUTTER/03`
  AdminProductRepository + AdminMediaRepository, `02_BACKEND/01_DATA_CONTRACTS.md` §product rows,
  `00_MASTER` §Pricing/tax.

## Deliverables — exact files
```
admin_app/lib/features/products/data/admin_product_repository.dart     (full: list, details, create, update, publish, deactivate, saveAttributes)
admin_app/lib/features/products/data/admin_media_repository.dart       (full)
admin_app/lib/features/products/data/product_draft.dart                (validation-bearing draft object)
admin_app/lib/features/products/presentation/products_list_page.dart   (A07)
admin_app/lib/features/products/presentation/product_editor_page.dart  (A08)
admin_app/lib/features/products/presentation/media_manager_page.dart   (A09)
admin_app/lib/features/products/widgets/dynamic_attribute_form.dart    (renders fields from CategoryAttribute list)
admin_app/lib/core/widgets/paginated_table_controls.dart
test/features/products/presentation/product_editor_page_test.dart
```

## Tasks
1. A07: debounced search + sku + category + status filter; publish/unpublish toggle; deactivate
   confirm; pager (20/page).
2. A08 sections per 04_UI/03 §A08 — category dropdown locked on edit; price/MRP/tax validation
   (`price > 0`, `mrp >= price`, `tax 0–100`); dynamic attribute form from ACTIVE attributes of the
   selected category sorted by displayOrder, per-type inputs; required attributes block PUBLISH but
   not draft; stock section only on create; footer Save draft / Publish.
3. `create` inserts product + inventory row (initial qty) + attribute values; `update` persists base
   then `saveAttributes` replace-set (delete removed, upsert provided — sequential per 03_FLUTTER/03).
4. A09: multi-upload with per-file errors, first image auto-primary, Set primary (two-op swap),
   Move left/right reorder, delete (storage remove → row delete), primary badge.
5. Tests per 05_TESTING/01 (product_editor cases).

## Database impact
None (writes via policies; storage only).

## Verification commands
```
cd admin_app && dart format . && flutter analyze && flutter test
# anon visibility check after publishing:
curl "$SUPABASE_URL/rest/v1/products?select=name,is_published&is_published=eq.true" -H "apikey: $ANON_KEY"
```

## Acceptance criteria
- [ ] A07–A09 acceptance criteria of 04_UI/03 all demonstrated (all four editor Gherkin blocks).
- [ ] Required-attribute missing → Publish blocked with summary bar; Save draft succeeds.
- [ ] MRP < price and tax 150 both blocked inline.
- [ ] Category disabled on edit with helper text; changing category on CREATE re-renders fields.
- [ ] saveAttributes replace-set verified: remove a filled optional field → save → the
      `product_attributes` row is gone (check DB).
- [ ] Published product appears in the anon REST read; unpublished does not.
- [ ] Media: order persists after reload; delete of primary promotes next; >5 MB per-file error.

## Report
Use the templates in PHASE_00 § Report templates.
