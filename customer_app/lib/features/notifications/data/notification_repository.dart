import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/notification_item.dart';

export 'models/notification_item.dart';

// ── Paginated wrapper (mirrors the one in order_repository.dart) ──────────────

class NotificationPaginated<T> {
  const NotificationPaginated({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  bool get hasMore => (page * pageSize) < total;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(supabaseClientProvider));
});

// ── Repository ────────────────────────────────────────────────────────────────

class NotificationRepository {
  NotificationRepository(this._sb);
  final SupabaseClient _sb;

  String? get _userId => _sb.auth.currentUser?.id;

  void _requireAuth() {
    if (_userId == null) {
      throw const ApiFailure('AUTH_REQUIRED', 'Not signed in.');
    }
  }

  /// Fetches the current user's notifications, newest first, page size 20.
  Future<NotificationPaginated<NotificationItem>> fetch({
    required int page,
  }) async {
    _requireAuth();
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;

      final res = await _sb
          .from('notifications')
          .select('id, user_id, type, title, body, data, is_read, created_at')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      return NotificationPaginated(
        items: (res.data as List)
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: res.count,
        page: page,
        pageSize: pageSize,
      );
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Returns the count of unread notifications for the current user.
  Future<int> unreadCount() async {
    _requireAuth();
    try {
      final res = await _sb
          .from('notifications')
          .select('id')
          .eq('user_id', _userId!)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Marks a single notification as read via the `mark_notification_read` rpc.
  ///
  /// The RPC enforces ownership — it only marks rows belonging to the caller.
  Future<void> markRead(String notificationId) async {
    _requireAuth();
    try {
      await _sb.rpc('mark_notification_read', params: {
        'p_notification_id': notificationId,
      });
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
