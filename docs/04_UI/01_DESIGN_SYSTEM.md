# 01_DESIGN_SYSTEM.md — tokens, theme, shared components

Light theme only (MVP). Material 3. Both apps use the SAME `core/theme/app_theme.dart` values.

## Color tokens

| Token | Hex | Use |
|---|---|---|
| primary | `#2E7D32` | app bars, primary buttons, links |
| onPrimary | `#FFFFFF` | text on primary |
| primaryContainer | `#A5D6A7` | chips, selected states |
| onPrimaryContainer | `#0B3D0E` | text on primaryContainer |
| secondary | `#F9A825` | badges, highlights, MRP strike-through context |
| error | `#C62828` | error text, destructive buttons |
| surface | `#FFFFFF` | cards, sheets |
| background (scaffold) | `#F6F7F6` | screens |
| outline | `#DADCE0` | borders, dividers |
| textPrimary | `#1B1B1B` | body text |
| textSecondary | `#5F6368` | captions, labels |
| success | `#2E7D32` | success snackbars, delivered status |
| warning | `#F9A825` | low-stock, pending states |

`ColorScheme.fromSeed(seedColor: Color(0xFF2E7D32))` then override `surface`, `background`, `error`.

## Typography (Material 3, default Roboto)

| Style | Size/Weight | Use |
|---|---|---|
| headlineSmall | 24/600 | screen titles |
| titleMedium | 16/600 | card titles, section headers |
| bodyMedium | 14/400 | body |
| bodySmall | 12/400 | captions, timestamps |
| labelLarge | 14/500 | buttons, chips |

Price display: `titleMedium` + primary color. MRP: `bodySmall` + lineThrough + textSecondary.
All prices via `Formatters.inr`.

## Spacing & shape

- 4-grid: 4/8/12/16/24/32. Screen padding: customer 16, admin 24 (desktop) / 16 (compact).
- Card radius 12; buttons 8; sheets 16 (top corners). Border width 1.
- Touch targets ≥ 44 dp. Product card image 1:1; detail image 4:3.

## Shared components (customer `core/widgets/`, admin mirrors in its core/widgets/)

| Widget | API | Behavior |
|---|---|---|
| AppButton | label, onPressed, type{primary,secondary,danger,text}, loading, enabled | loading shows spinner + disables; min height 44 |
| AppTextField | controller, label, hint, keyboardType, validator, enabled, suffixIcon | inline error below field; preserves input on failed submit |
| AppDropdown<T> | items, value, onChanged, validator | for category pickers, sort, states |
| ProductCard | ProductCard model, onTap, onAdd | 1:1 image (CachedNetworkImage + placeholder), name 2 lines ellipsis, price + MRP, add button disabled when !inStock; unavailable overlay |
| StatusChip | OrderStatus | color map: NEW grey, CONFIRMED blue, PROCESSING amber, PACKED indigo, SHIPPED violet, OUT_FOR_DELIVERY orange, DELIVERED green, CANCELLED red; label = humanized (Out For Delivery) |
| QuantityStepper | value, min 1, max, onChanged | − / value / + ; disables at bounds |
| PriceText | double, style variant | inr format |
| CachedImage | path?, bucket, ratio | placeholder shimmer box; error icon box |
| EmptyState | icon, title, message, actionLabel?, onAction | centered, used everywhere empty |
| ErrorState | message, onRetry | centered + retry button |
| LoadingState | — | centered `CircularProgressIndicator` |
| ListSkeleton | — | shimmer placeholder cards for lists |
| ConfirmDialog | title, message, confirmLabel{danger?} | returns bool; used for all destructive actions |
| PaginatedListView | loadMore callback, hasMore, footer states | infinite scroll with 400px trigger; shows spinner/error on loadMore |
| AppSnackBar | show(context, text, type{info,success,error}) | float, 4s, one at a time |

## States contract (EVERY network screen)

| State | Render |
|---|---|
| loading | first load: ListSkeleton / LoadingState; pagination: footer spinner |
| empty | EmptyState with screen-specific copy + action |
| error | ErrorState + Retry (reload same query); network message if offline |
| success | content |
| mutating | submit button loading; other conflicting actions disabled |
| mutation success | snackbar + navigation/state update |
| mutation failure | snackbar with failure message; form values preserved |

Accessibility: every icon button gets `semanticLabel`; text scales per system (no fixed-height text
containers); contrast ≥ 4.5:1 for body text (tokens above comply); admin fully keyboard-navigable.
