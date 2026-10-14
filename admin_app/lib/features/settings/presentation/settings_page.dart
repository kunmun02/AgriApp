import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_settings_repository.dart';
import '../data/models/app_settings.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _settingsProvider = FutureProvider.autoDispose<AppSettings>((ref) async {
  return ref.watch(adminSettingsRepositoryProvider).fetch();
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// A16 — Settings `/admin/settings`.
///
/// Edits delivery charge + free-delivery threshold; read-only Store card.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _chargeCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();

  bool _populated = false; // true after controllers filled from loaded data
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _chargeCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  // ── Populate form from loaded settings ────────────────────────────────

  void _populate(AppSettings settings) {
    if (_populated) return;
    _chargeCtrl.text = settings.deliveryCharge.toStringAsFixed(2);
    _thresholdCtrl.text = settings.freeDeliveryThreshold.toStringAsFixed(2);
    _populated = true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Returns null if valid, error string if invalid.
  String? _validateAmount(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    final parsed = num.tryParse(value.trim());
    if (parsed == null) return '$label must be a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final charge = (num.tryParse(_chargeCtrl.text.trim()) ?? 0).toDouble();
    final threshold =
        (num.tryParse(_thresholdCtrl.text.trim()) ?? 0).toDouble();

    setState(() => _saving = true);
    try {
      await ref.read(adminSettingsRepositoryProvider).update(
            deliveryCharge: charge,
            freeDeliveryThreshold: threshold,
          );
      // Invalidate so re-entering the page fetches fresh data.
      ref.invalidate(_settingsProvider);
      _populated = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverError =
            e is AppFailure ? e.userMessage : 'Something went wrong.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_settingsProvider);

    return AdminShell(
      title: 'Settings',
      child: settingsAsync.when(
        loading: () => const Center(
          key: Key('settings_loading'),
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
          key: const Key('settings_error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e is AppFailure ? e.userMessage : 'Failed to load settings.',
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                key: const Key('retry_button'),
                onPressed: () => ref.invalidate(_settingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (settings) {
          _populate(settings);
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final thresholdStr = _thresholdCtrl.text.trim();
    final thresholdNum = num.tryParse(thresholdStr)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Card: Delivery ────────────────────────────────────
              _SectionCard(
                title: 'Delivery',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Delivery charge
                    TextFormField(
                      key: const Key('delivery_charge_field'),
                      controller: _chargeCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Delivery charge (₹)',
                        prefixText: '₹ ',
                      ),
                      validator: (v) => _validateAmount(v, 'Delivery charge'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Free delivery threshold
                    TextFormField(
                      key: const Key('free_threshold_field'),
                      controller: _thresholdCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Free delivery threshold (₹)',
                        prefixText: '₹ ',
                        helperText: _thresholdHelper(thresholdNum),
                        helperMaxLines: 2,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          _validateAmount(v, 'Free delivery threshold'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Card: Store (read-only) ────────────────────────────
              const _SectionCard(
                title: 'Store',
                child: Column(
                  children: [
                    _ReadOnlyRow(label: 'App name', value: 'AgriStore'),
                    Divider(height: AppSpacing.lg),
                    _ReadOnlyRow(label: 'Currency', value: 'INR (₹)'),
                    Divider(height: AppSpacing.lg),
                    _ReadOnlyRow(
                        label: 'Support contact',
                        value: 'support@agristore.in'),
                  ],
                ),
              ),

              // ── Server error ──────────────────────────────────────
              if (_serverError != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _serverError!,
                  key: const Key('server_error'),
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Footer: Save ──────────────────────────────────────
              ElevatedButton(
                key: const Key('save_button'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _thresholdHelper(double threshold) {
    if (threshold <= 0) return 'Free delivery is disabled';
    return 'Orders with subtotal ≥ ${Formatters.inr(threshold)} get free delivery';
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Read-only row ─────────────────────────────────────────────────────────────

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
