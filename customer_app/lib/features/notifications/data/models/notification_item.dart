/// A single notification row from the `notifications` table.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.orderId,
  });

  final String id;
  final String userId;

  /// `'ORDER_STATUS'` or `'SYSTEM'`.
  final String type;

  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  /// Extracted from `data->order_id` when `type == 'ORDER_STATUS'`.
  final String? orderId;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return NotificationItem(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'SYSTEM',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      orderId: data?['order_id'] as String?,
    );
  }

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        orderId: orderId,
      );
}
