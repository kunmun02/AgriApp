# PHASE_05 — Dynamic attributes (admin A05/A06)

## Goal
Attribute metadata management per category: typed fields (TEXT/NUMBER/BOOLEAN/SELECT), required
flag, ordering, activation — the foundation Phase 06 forms are generated from.

## Prerequisites
- PHASE_04. Read: `04_UI/03_ADMIN_SCREENS.md` A05/A06, `03_FLUTTER/03` AdminAttributeRepository,
  `00_MASTER` §dynamic attribute rule.

## Deliverables — exact files
```
admin_app/lib/features/attributes/data/admin_attribute_repository.dart
admin_app/lib/features/attributes/presentation/attributes_page.dart       (A05)
admin_app/lib/features/attributes/presentation/attribute_editor_page.dart (A06)
admin_app/lib/features/attributes/widgets/attribute_options_editor.dart   (tag input for SELECT)
admin_app/lib/core/utils/attribute_key_generator.dart     (name → snake_case, pattern ^[a-z][a-z0-9_]{1,39}$)
test/core/utils/attribute_key_generator_test.dart
test/features/attributes/presentation/attribute_editor_page_test.dart
```

## Tasks
1. Repository per 03_FLUTTER/03 (fetchForCategory includes inactive, ordered by display_order).
2. A06: key auto-suggested from name on create, editable pre-save only; key + data_type disabled on
   edit with helper text; SELECT requires ≥ 1 non-empty unique option; required + order + active.
3. A05 table with type chips, Required icon, deactivate confirm with the exact copy about kept
   product values.
4. Seed coverage check: the 9 seeded category_attributes (020) render correctly for categories
   11111111-… through 44444444-….

## Database impact
None.

## Verification commands
```
cd admin_app && dart format . && flutter analyze && flutter test
```
Manual: add NUMBER "Nitrogen %" (key `nitrogen_percent`, required) to the Urea-like seeded
category → appears in A05 in order; edit it → key/type locked; deactivate it → confirm.

## Acceptance criteria
- [ ] A05 + A06 acceptance criteria of 04_UI/03 all demonstrated.
- [ ] `attribute_key_generator` tests pass ("Soil Type" → `soil_type`; strips invalid chars).
- [ ] SELECT with zero options blocks save with the exact inline error.
- [ ] Deactivated attribute disappears from A05 default view (fetch includes inactive — show
      "Inactive" chip row instead).

## Report
Use the templates in PHASE_00 § Report templates.
