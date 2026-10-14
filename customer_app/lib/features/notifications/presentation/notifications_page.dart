import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/unread_badge_controller.dart';
import '../data/notification_repository.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

/// C15 — Notifications screen `/notifications`.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _page = 1;
  List<NotificationItem> _items = [];
  int _total = 0;
  bool _isLoading = true;
  String? _error;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    // Refetch on screen open (per spec).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPage(1, reset: true);
      ref.read(unreadBadgeControllerProvider.notifier).refresh();
    });
  }

  Future<void> _loadPage(int page, {bool reset = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(notificationRepositoryProvider).fetch(page: page);
      if (!mounted) return;
      setState(() {
        _page = page;
        _total = result.total;
        _items = reset ? result.items : [..._items, ...result.items];
        _isLoading = false;
      });
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.map((n) {
          return n.id == item.id ? n.copyWith(isRead: true) : n;
        }).toList();
      });
      ref.read(unreadBadgeControllerProvider.notifier).decrement();
    } catch (_) {
      // Best-effort; do not show error for mark-read failures.
    }
  }

  Future<void> _markAllRead() async {
    final unread = _items.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    setState(() => _markingAll = true);
    final repo = ref.read(notificationRepositoryProvider);
    for (final n in unread) {
      try {
        await repo.markRead(n.id);
      } catch (_) {
        // Continue even if some fail.
      }
    }
    if (!mounted) return;
    setState(() {
      _items = _items.map((n) => n.copyWith(isRead: true)).toList();
      _markingAll = false;
    });
    ref.read(unreadBadgeControllerProvider.notifier).reset();
  }

  bool get _hasMore => (_page * 20) < _total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_items.any((n) => !n.isRead))
            _markingAll
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    key: const Key('mark_all_read'),
                    onPressed: _markAllRead,
                    child: const Text('Mark all read'),
                  ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _loadPage(1, reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No notifications.'));
    }

    return ListView.builder(
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton(
                    onPressed: () => _loadPage(_page + 1),
                    child: const Text('Load more'),
                  ),
          );
        }
        final item = _items[index];
        return _NotificationTile(
          key: ValueKey('notif_tile_${item.id}'),
          item: item,
          onTap: () => _onTap(item),
        );
      },
    );
  }

  Future<void> _onTap(NotificationItem item) async {
    await _markRead(item);
    if (!mounted) return;
    if (item.orderId != null) {
      context.push('/orders/${item.orderId}');
    }
    // else: tile expands in place — handled inside _NotificationTile
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isOrder = item.type == 'ORDER_STATUS';

    return Column(
      children: [
        ListTile(
          key: Key('notif_list_tile_${item.id}'),
          leading: Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(
                isOrder
                    ? Icons.local_shipping_outlined
                    : Icons.campaign_outlined,
                color: isOrder ? AppColors.primary : Colors.orange.shade700,
              ),
              if (!item.isRead)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    key: Key('unread_dot_${item.id}'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.body,
                maxLines: _expanded ? null : 2,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _timeAgo(item.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          onTap: () {
            // If it has an order id navigate; else expand in place.
            if (item.orderId != null) {
              widget.onTap();
            } else {
              setState(() => _expanded = !_expanded);
              widget.onTap(); // still marks as read
            }
          },
          isThreeLine: true,
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return DateFormat('d MMM yyyy').format(dt);
  }
}
