import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/paginated_table_controls.dart';
import '../../../features/orders/data/admin_order_repository.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_notification_repository.dart';
import '../widgets/broadcast_dialog.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _notificationsPageStateProvider = StateProvider<int>((ref) => 1);

final _notificationsListProvider = FutureProvider.autoDispose
    .family<Paginated<NotificationItem>, int>((ref, page) {
  return ref.watch(adminNotificationRepositoryProvider).list(page: page);
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// A15 — Notifications `/admin/notifications`.
class AdminNotificationsPage extends ConsumerWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(_notificationsPageStateProvider);
    final listAsync = ref.watch(_notificationsListProvider(page));

    void goPage(int p) {
      ref.read(_notificationsPageStateProvider.notifier).state = p;
    }

    return AdminShell(
      title: 'Notifications',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text('Notifications',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    key: const Key('new_broadcast_button'),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('New broadcast'),
                    onPressed: () async {
                      final sent = await showDialog<bool>(
                        context: context,
                        builder: (_) => const BroadcastDialog(),
                      );
                      if (sent == true) {
                        ref.invalidate(_notificationsListProvider);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Table
            Expanded(
              child: listAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    e is AppFailure ? e.userMessage : e.toString(),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (paginated) {
                  if (paginated.items.isEmpty) {
                    return const Center(child: Text('No notifications yet.'));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Title')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Recipient')),
                        DataColumn(label: Text('Created')),
                        DataColumn(label: Text('Read'), numeric: true),
                      ],
                      rows: paginated.items.map((n) {
                        return DataRow(
                          key: ValueKey('notif_row_${n.id}'),
                          cells: [
                            DataCell(Text(n.title)),
                            DataCell(_TypeChip(type: n.type)),
                            DataCell(Text(
                              n.recipientEmail ?? 'broadcast',
                            )),
                            DataCell(
                                Text(Formatters.dateTimeShort(n.createdAt))),
                            DataCell(
                              n.isRead
                                  ? const Icon(Icons.check_circle_outline,
                                      color: Colors.green, size: 18)
                                  : const Icon(Icons.radio_button_unchecked,
                                      color: Colors.grey, size: 18),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            listAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (paginated) => PaginatedTableControls(
                page: page,
                total: paginated.total,
                pageSize: paginated.pageSize,
                onPrev: page > 1 ? () => goPage(page - 1) : null,
                onNext: paginated.hasMore ? () => goPage(page + 1) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type chip ─────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final isOrder = type == 'ORDER_STATUS';
    return Chip(
      label: Text(isOrder ? 'ORDER' : 'SYSTEM'),
      backgroundColor: isOrder ? Colors.blue.shade100 : Colors.orange.shade100,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isOrder ? Colors.blue.shade800 : Colors.orange.shade800,
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
