import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the singleton [SupabaseClient].
///
/// Repositories read this provider; widgets must NEVER call
/// `Supabase.instance.client` directly — they go through repositories.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
