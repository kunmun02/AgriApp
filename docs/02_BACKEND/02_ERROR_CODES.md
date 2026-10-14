# 02_ERROR_CODES.md — The single error envelope + handling rules

## Envelope

Business failures from RPCs arrive as `PostgresException` with `code = '23514'`? No — RPCs raise
SQLSTATE `P0001`, so `PostgresException.code == 'P0001'` and `message` is a JSON string:

```json
{ "code": "OUT_OF_STOCK", "message": "insufficient stock for Tomato Seeds",
  "details": { "product_id": "...", "available": 0 } }
```

Client rule: on `PostgresException` where `code == 'P0001'`, attempt `jsonDecode(message)`;
if it parses and has a `code` key → typed `AppException(code, message, details)`.
Anything else → `AppException(code: 'INTERNAL_ERROR', ...)` (never show raw exception text in UI).

RLS denials surface as PostgresException with codes like `42501` (permission denied) or empty result
sets — map to `FORBIDDEN` / `NOT_FOUND` per case below.

## Code table

| Code | Meaning | Raised by | Client UI behavior |
|---|---|---|---|
| AUTH_REQUIRED | No valid session | create_order, mark_notification_read, any 401 from PostgREST | redirect to login, preserve intended route |
| FORBIDDEN | Role/ownership check failed | change_order_status, adjust_inventory, RLS 42501, profiles_guard | snackbar "You are not allowed to do this"; log out only if session invalid |
| VALIDATION_ERROR | Input failed server checks | all RPCs, table CHECK constraints (23514) | show server message under the relevant field / dialog |
| NOT_FOUND | Entity missing or not owned | create_order(address), change_order_status, mark_notification_read, `.single()` 0-rows (PGRST116) | empty state or snackbar; navigate back on detail pages |
| OUT_OF_STOCK | Checkout stock race lost | create_order | dialog naming product + available qty; refresh cart |
| PRODUCT_UNAVAILABLE | Product inactive/unpublished at checkout | create_order (empty purchasable set) | dialog "Some items are no longer available"; refresh cart |
| DUPLICATE_REQUEST | Reserved (replays return success instead) | — | treat replay result as success |
| CONFLICT | Illegal order status transition | change_order_status | snackbar with server message; refresh order |
| INTERNAL_ERROR | Anything unmapped | catch-all | snackbar "Something went wrong. Try again." |

PostgREST infra codes to map: `PGRST301` (JWT expired) → AUTH_REQUIRED; network `SocketException` →
`NETWORK_ERROR` (retry affordance, never fake success).

## Client architecture (`core/errors/`)

```dart
sealed class AppFailure {
  final String code; final String message; final Map<String, dynamic>? details;
  const AppFailure(this.code, this.message, [this.details]);
}
class ApiFailure extends AppFailure { ... }       // server envelope / mapped PostgREST codes
class NetworkFailure extends AppFailure { ... }   // no connectivity / timeout
class ValidationFailure extends AppFailure { ... }// client-side form validation only
```

`AppFailure.userMessage` returns the copy shown in UI (server `message` for ApiFailure when present).
Controllers expose `AsyncValue<T>`; screens render per `04_UI` state contract. Never `print` tokens or
full exceptions — log `code` + sanitized message via the app logger only (debug mode console).

## Idempotency note

`create_order` replay (same idempotency_key) returns `{"duplicate":true,"order_id":...}` — the client
MUST treat it as success: navigate to order success screen with that order_id. This is what makes
double-tap / flaky-network retries safe.
