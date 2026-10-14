import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../orders/data/admin_order_repository.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.recipientEmail,
    this.orderId,
  });

  final String id;
  final String userId;
  final String type; // 'ORDER_STATUS' | 'SYSTEM'
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  /// Email of the recipient profile (admin list view).
  final String? recipientEmail;

  /// Extracted from data->order_id if present.
  final String? orderId;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final profile = json['profiles'] as Map<String, dynamic>?;
    return NotificationItem(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'SYSTEM',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      recipientEmail: profile?['email'] as String?,
      orderId: data?['order_id'] as String?,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final adminNotificationRepositoryProvider =
    Provider<AdminNotificationRepository>((ref) {
  return AdminNotificationRepository(ref.read(supabaseClientProvider));
});

// ── Repository ────────────────────────────────────────────────────────────────

class AdminNotificationRepository {
  AdminNotificationRepository(this._client);
  final SupabaseClient _client;

  // ── List ──────────────────────────────────────────────────────────────

  Future<Paginated<NotificationItem>> list({required int page}) async {
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      // Step 1: fetch the notifications page.
      // We intentionally do NOT embed profiles(email) here because
      // notifications.user_id references auth.users(id), not public.profiles(id),
      // so PostgREST cannot infer that relationship and returns PGRST200.
      final res = await _client
          .from('notifications')
          .select('id, user_id, type, title, body, data, is_read, created_at')
          .order('created_at', ascending: false)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      final rows = res.data as List;

      // Step 2: collect the distinct user_ids from this page and fetch
      // their emails from public.profiles in a single query.
      Map<String, String> emailByUserId = {};
      final userIds =
          rows.map((e) => (e as Map<String, dynamic>)['user_id'] as String).toSet().toList();

      if (userIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, email')
            .inFilter('id', userIds);

        emailByUserId = {
          for (final p in profiles as List)
            (p as Map<String, dynamic>)['id'] as String:
                (p)['email'] as String? ?? '',
        };
      }

      return Paginated(
        items: rows.map((e) {
          final row = e as Map<String, dynamic>;
          // Inject the resolved email so fromJson can pick it up via the
          // synthetic 'profiles' key it already expects.
          row['profiles'] = {'email': emailByUserId[row['user_id'] as String]};
          return NotificationItem.fromJson(row);
        }).toList(),
        total: res.count,
        page: page,
        pageSize: pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Active customer count (for broadcast live count) ──────────────────

  Future<int> activeCustomerCount() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'customer')
          .eq('is_active', true)
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Broadcast ─────────────────────────────────────────────────────────

  /// Sends one SYSTEM notification to every active customer via the
  /// `broadcast_notification` security-definer RPC (migration 020).
  ///
  /// Using an RPC bypasses the RLS INSERT restriction on `notifications`
  /// (there is intentionally no client-side INSERT policy for admins —
  /// see 018_rls.sql). The RPC performs the bulk insert in a single
  /// atomic SQL statement and returns {"sent": N}.
  ///
  /// Returns a [BroadcastResult] with [sent] count.
  Future<BroadcastResult> broadcast({
    required String title,
    required String body,
  }) async {
    try {
      final result = await _client.rpc(
        'broadcast_notification',
        params: {'p_title': title, 'p_body': body},
      ) as Map<String, dynamic>;

      final sent = result['sent'] as int? ?? 0;
      return BroadcastResult(sent: sent, total: sent);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}

// ── Result type ───────────────────────────────────────────────────────────────

class BroadcastResult {
  const BroadcastResult({required this.sent, required this.total});
  final int sent;
  final int total;
  bool get isPartialFailure => sent < total;
}
