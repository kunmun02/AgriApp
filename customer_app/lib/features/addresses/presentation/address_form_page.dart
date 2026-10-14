import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/indian_states.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../data/address_repository.dart';
import '../data/models/address.dart';

const _kLabels = ['Home', 'Work', 'Farm', 'Other'];

/// C10 — Address Form screen.
///
/// Used for both create (`/addresses/new`) and edit (`/addresses/:id/edit`).
/// When [existing] is provided the form pre-fills all fields.
class AddressFormPage extends ConsumerStatefulWidget {
  const AddressFormPage({super.key, this.existing});

  /// Non-null when editing an existing address.
  final Address? existing;

  @override
  ConsumerState<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  late String _label;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _line2Ctrl;
  late final TextEditingController _cityCtrl;
  late String? _state;
  late final TextEditingController _pinCtrl;
  late bool _isDefault;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _label = a?.label ?? 'Home';
    _nameCtrl = TextEditingController(text: a?.recipientName ?? '');
    _phoneCtrl = TextEditingController(text: a?.phone ?? '');
    _line1Ctrl = TextEditingController(text: a?.line1 ?? '');
    _line2Ctrl = TextEditingController(text: a?.line2 ?? '');
    _cityCtrl = TextEditingController(text: a?.city ?? '');
    _state = a?.state;
    _pinCtrl = TextEditingController(text: a?.postalCode ?? '');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_state == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state.')),
      );
      return;
    }
    setState(() => _submitting = true);

    final repo = ref.read(addressRepositoryProvider);

    // Build draft; id is set only on edit.
    Address draft;
    if (_isEdit) {
      draft = widget.existing!.copyWith(
        label: _label,
        recipientName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        line1: _line1Ctrl.text.trim(),
        line2: _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _state,
        postalCode: _pinCtrl.text.trim(),
        isDefault: _isDefault,
      );
    } else {
      draft = Address(
        id: '',
        userId: '',
        label: _label,
        recipientName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        line1: _line1Ctrl.text.trim(),
        line2: _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _state!,
        postalCode: _pinCtrl.text.trim(),
        country: 'India',
        isDefault: _isDefault,
      );
    }

    try {
      if (_isEdit) {
        await repo.updateAddress(draft);
      } else {
        await repo.createAddress(draft);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Address ${_isEdit ? 'updated' : 'saved'} successfully.')),
        );
        context.pop();
      }
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      // Catches unexpected errors (e.g. parsing failures) so the UI never
      // silently hangs with the save button disabled.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Address' : 'New Address'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Label
              DropdownButtonFormField<String>(
                initialValue: _label,
                decoration: const InputDecoration(labelText: 'Label'),
                items: _kLabels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _label = v ?? 'Home'),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Recipient name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Recipient name'),
                textCapitalization: TextCapitalization.words,
                validator: Validators.fullName,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Phone
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Line 1
              TextFormField(
                controller: _line1Ctrl,
                decoration: const InputDecoration(labelText: 'Address Line 1'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Address line 1 is required.';
                  }
                  if (v.trim().length < 3) {
                    return 'Address line 1 must be at least 3 characters.';
                  }
                  if (v.trim().length > 160) {
                    return 'Address line 1 must be 160 characters or fewer.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Line 2 (optional)
              TextFormField(
                controller: _line2Ctrl,
                decoration: const InputDecoration(
                    labelText: 'Address Line 2 (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),

              // City
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'City'),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'City is required.';
                  }
                  if (v.trim().length < 2) {
                    return 'City must be at least 2 characters.';
                  }
                  if (v.trim().length > 60) {
                    return 'City must be 60 characters or fewer.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // State dropdown
              DropdownButtonFormField<String>(
                initialValue: _state,
                decoration: const InputDecoration(labelText: 'State'),
                items: IndianStates.all
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _state = v),
                validator: (v) => v == null ? 'Please select a state.' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Pincode
              TextFormField(
                controller: _pinCtrl,
                decoration: const InputDecoration(labelText: 'PIN Code'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: Validators.postalCode,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Set as default
              SwitchListTile.adaptive(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Set as default address'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Save button
              AppButton(
                label: _isEdit ? 'Update Address' : 'Save Address',
                onPressed: _submit,
                loading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
