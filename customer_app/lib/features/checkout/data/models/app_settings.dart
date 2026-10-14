/// App-wide settings fetched from the single-row `app_settings` table.
///
/// PostgREST returns NUMERIC columns as JSON strings; values are parsed
/// with [num.tryParse] per 02_BACKEND/01 convention.
class AppSettings {
  const AppSettings({
    required this.deliveryCharge,
    required this.freeDeliveryThreshold,
  });

  /// Fixed delivery fee applied when subtotal < [freeDeliveryThreshold].
  final double deliveryCharge;

  /// Subtotal at or above which delivery is free.
  final double freeDeliveryThreshold;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      deliveryCharge:
          (num.tryParse(json['delivery_charge']?.toString() ?? '') ?? 40)
              .toDouble(),
      freeDeliveryThreshold: (num.tryParse(
                json['free_delivery_threshold']?.toString() ?? '',
              ) ??
              500)
          .toDouble(),
    );
  }
}
