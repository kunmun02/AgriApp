import 'package:uuid/uuid.dart';

/// Generates a UUID v4 string to use as an idempotency key.
///
/// One key is generated when the user ARRIVES at C11; it is reused on
/// network-failure retries and consumed (discarded) on success or a
/// DUPLICATE_REQUEST replay.
String generateIdempotencyKey() => const Uuid().v4();
