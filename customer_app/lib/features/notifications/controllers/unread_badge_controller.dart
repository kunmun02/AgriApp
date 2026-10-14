import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';

/// Poll interval exactly 60 seconds (const — tested).
const kUnreadBadgePollInterval = Duration(seconds: 60);

final unreadBadgeControllerProvider =
    StateNotifierProvider<UnreadBadgeController, int>(
  (ref) => UnreadBadgeController(ref.read(notificationRepositoryProvider)),
);

/// Holds the count of unread notifications for the bottom-nav badge.
///
/// Polling strategy (per 02_BACKEND/01 §5):
///  - [Timer.periodic] every [kUnreadBadgePollInterval] while app is resumed.
///  - [refresh] is called explicitly on every screen open (C15 router entry)
///    and after marking notifications as read.
///
/// AppLifecycleObserver pauses polling when app is backgrounded.
class UnreadBadgeController extends StateNotifier<int>
    with WidgetsBindingObserver {
  UnreadBadgeController(this._repo) : super(0) {
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    refresh();
  }

  final NotificationRepository _repo;
  Timer? _timer;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      refresh();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(kUnreadBadgePollInterval, (_) => refresh());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Re-fetches the authoritative unread count from the server.
  Future<void> refresh() async {
    try {
      final count = await _repo.unreadCount();
      if (mounted) state = count;
    } catch (_) {
      // Badge is best-effort — silently ignore errors.
    }
  }

  /// Decrement the local badge by 1 after a single mark-read action.
  void decrement() {
    if (state > 0) state = state - 1;
  }

  /// Reset badge to zero (after mark-all-read).
  void reset() => state = 0;

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
