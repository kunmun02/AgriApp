# PHASE_04 — Categories (admin A03/A04)

## Goal
Category CRUD with tree display, slug collision handling, image upload, soft deactivation.

## Prerequisites
- PHASE_01–03. Read: `04_UI/03_ADMIN_SCREENS.md` A03/A04, `03_FLUTTER/03` AdminCategoryRepository,
  `02_BACKEND/01_DATA_CONTRACTS.md` §storage.

## Deliverables — exact files
```
admin_app/lib/features/categories/data/admin_category_repository.dart   (full: fetchAll, create, update, deactivate, uploadImage)
admin_app/lib/features/categories/presentation/categories_page.dart     (A03)
admin_app/lib/features/categories/presentation/category_editor_page.dart (A04)
admin_app/lib/features/categories/widgets/category_tree_table.dart
admin_app/lib/core/widgets/confirm_dialog.dart
admin_app/lib/core/utils/slugifier.dart                    (name → kebab; used by A04 and A08)
test/features/categories/presentation/categories_page_test.dart
```

## Tasks
1. Repository exactly per 03_FLUTTER/03 — `create` generates slug via Slugifier, retries with
   `-2`, `-3`… on 23505 (documented loop, max 5 suffixes).
2. A03 tree table with indentation, Active switch (toggle = update), Deactivate confirm.
3. A04 sectioned form: name, parent dropdown (self+descendant options disabled), description,
   display order, active, image section (file_picker, 5 MB / jpg-png-webp pre-check, upload to
   `category-images/{categoryId}/{epoch_ms}-{sanitized}`).
4. Create-then-image flow (create returns Category; image section appears after save).
5. Tests per 05_TESTING/01.

## Database impact
None (DML only).

## Verification commands
```
cd admin_app && dart format . && flutter analyze && flutter test
```
Manual: create "Fertilizers" then "Fertilizers" again → slugs `fertilizers`, `fertilizers-2`;
upload 6 MB file → inline rejection; deactivate → confirm → greys out; anon REST read no longer
returns it; upload a valid image → object exists at expected path (Supabase dashboard).

## Acceptance criteria
- [ ] A03 + A04 acceptance criteria of 04_UI/03 all demonstrated.
- [ ] Slug collision loop proven (two same-name creates).
- [ ] Parent self/descendant selection blocked in dropdown.
- [ ] Storage path convention followed (visible in dashboard bucket).
- [ ] Analyzer 0; tests green.

## Report
Use the templates in PHASE_00 § Report templates.
