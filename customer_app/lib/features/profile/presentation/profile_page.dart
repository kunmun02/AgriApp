import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/data/models/profile.dart';
import '../../notifications/controllers/unread_badge_controller.dart';
import '../controllers/profile_controller.dart';

// ── App version ───────────────────────────────────────────────────────────────

/// Version string sourced from pubspec.yaml via compile-time constant.
/// Matches `version: 1.0.0+1` in pubspec.
const _kAppVersion = '1.0.0+1';

// ── Page ──────────────────────────────────────────────────────────────────────

/// C16 — Profile `/profile`.
///
/// Displays avatar (initials), name, email, phone, edit form, nav shortcuts,
/// and logout with ConfirmDialog.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _editing = false;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Start editing ─────────────────────────────────────────────────────

  void _startEdit(Profile profile) {
    _nameCtrl.text = profile.fullName;
    _phoneCtrl.text = profile.phone ?? '';
    setState(() {
      _editing = true;
      _saveError = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _saveError = null;
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _saveProfile(Profile profile) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final error = await ref.read(profileControllerProvider).save(
          userId: profile.id,
          fullName: name,
          phone: phone.isEmpty ? null : phone,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saveError = error;
        _saving = false;
      });
    } else {
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will be returned to the login screen.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(authControllerProvider);
    final profile = profileAsync.value;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Avatar + name/email ───────────────────────────────────
            _AvatarSection(profile: profile),
            const SizedBox(height: AppSpacing.xl),

            // ── Edit profile form / display ───────────────────────────
            if (_editing)
              _EditForm(
                formKey: _formKey,
                nameCtrl: _nameCtrl,
                phoneCtrl: _phoneCtrl,
                saving: _saving,
                saveError: _saveError,
                onSave: () => _saveProfile(profile),
                onCancel: _cancelEdit,
              )
            else
              _ProfileInfo(
                profile: profile,
                onEditTap: () => _startEdit(profile),
              ),

            const SizedBox(height: AppSpacing.xl),
            const Divider(),

            // ── Navigation shortcuts ──────────────────────────────────
            _NavTile(
              key: const Key('my_orders_tile'),
              icon: Icons.receipt_long_outlined,
              label: 'My Orders',
              onTap: () => context.push('/orders'),
            ),
            _NavTile(
              key: const Key('my_addresses_tile'),
              icon: Icons.location_on_outlined,
              label: 'My Addresses',
              onTap: () => context.push('/addresses'),
            ),
            _NotificationsTile(),

            const Divider(),
            const SizedBox(height: AppSpacing.sm),

            // ── Logout ────────────────────────────────────────────────
            ListTile(
              key: const Key('logout_tile'),
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: _logout,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── App version ───────────────────────────────────────────
            Center(
              child: Text(
                'Version $_kAppVersion',
                key: const Key('app_version_text'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Avatar section ────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.profile});

  final Profile profile;

  String get _initials {
    final parts = profile.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            key: const Key('profile_avatar'),
            radius: 40,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              _initials,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.fullName,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.email,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Profile info (read-only) ──────────────────────────────────────────────────

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.profile, required this.onEditTap});

  final Profile profile;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoRow(label: 'Full name', value: profile.fullName),
            const Divider(height: AppSpacing.xl),
            _InfoRow(label: 'Email', value: profile.email),
            const Divider(height: AppSpacing.xl),
            _InfoRow(
              label: 'Phone',
              value: profile.phone?.isNotEmpty == true
                  ? profile.phone!
                  : 'Add phone',
              valueColor: profile.phone?.isNotEmpty == true
                  ? null
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: const Key('edit_profile_button'),
              label: 'Edit profile',
              onPressed: onEditTap,
              type: AppButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }
}

// ── Edit form ─────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.saving,
    required this.saveError,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool saving;
  final String? saveError;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit profile',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('full_name_field'),
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name *'),
                validator: Validators.fullName,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('phone_field'),
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: '10-digit mobile number',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  return Validators.phone(v);
                },
              ),
              if (saveError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  saveError!,
                  key: const Key('save_error'),
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      key: const Key('cancel_edit_button'),
                      label: 'Cancel',
                      onPressed: saving ? null : onCancel,
                      type: AppButtonType.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      key: const Key('save_profile_button'),
                      label: 'Save',
                      onPressed: saving ? null : onSave,
                      loading: saving,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ── Notifications tile (with unread badge) ────────────────────────────────────

class _NotificationsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadBadgeControllerProvider);
    return ListTile(
      key: const Key('notifications_tile'),
      leading: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child:
            const Icon(Icons.notifications_outlined, color: AppColors.primary),
      ),
      title: const Text('Notifications'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/notifications'),
    );
  }
}
