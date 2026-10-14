import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../attributes/data/models/category_attribute.dart';
import '../data/admin_product_repository.dart';
import '../data/product_draft.dart';

/// Renders a dynamic form driven by a list of [CategoryAttribute]s.
///
/// Only ACTIVE attributes are shown, sorted ascending by [displayOrder].
/// The [values] map keys are [CategoryAttribute.id]; values are the raw
/// Dart types: String / double / bool / null.
///
/// [onChanged] is called whenever any field changes; the full map is emitted.
class DynamicAttributeForm extends StatefulWidget {
  const DynamicAttributeForm({
    super.key,
    required this.attributes,
    required this.values,
    required this.onChanged,
    this.validateRequiredOnPublish = false,
  });

  /// All attributes for the selected category, pre-sorted by displayOrder.
  final List<CategoryAttribute> attributes;

  /// Current values keyed by [CategoryAttribute.id].
  final Map<String, dynamic> values;

  /// Called with the updated map on any field change.
  final ValueChanged<Map<String, dynamic>> onChanged;

  /// When true, required fields that are empty show an error decoration.
  final bool validateRequiredOnPublish;

  @override
  State<DynamicAttributeForm> createState() => _DynamicAttributeFormState();
}

class _DynamicAttributeFormState extends State<DynamicAttributeForm> {
  /// Controller pool keyed by attribute id (text / number fields only).
  final Map<String, TextEditingController> _controllers = {};

  List<CategoryAttribute> get _active =>
      widget.attributes.where((a) => a.isActive).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  void didUpdateWidget(DynamicAttributeForm old) {
    super.didUpdateWidget(old);
    // If the attribute list changed (category switched), dispose stale controllers.
    final oldIds = old.attributes.map((a) => a.id).toSet();
    final newIds = widget.attributes.map((a) => a.id).toSet();
    final removed = oldIds.difference(newIds);
    for (final id in removed) {
      _controllers.remove(id)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(CategoryAttribute attr) {
    return _controllers.putIfAbsent(attr.id, () {
      final existing = widget.values[attr.id];
      final initial = existing != null ? existing.toString() : '';
      return TextEditingController(text: initial);
    });
  }

  void _emit(String attrId, dynamic value) {
    final updated = Map<String, dynamic>.from(widget.values);
    if (value == null) {
      updated.remove(attrId);
    } else {
      updated[attrId] = value;
    }
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (active.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          'This category has no attributes.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final attr in active) ...[
          _buildField(attr),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Fields come from the category definition — manage them under'
          ' Categories › Attributes.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildField(CategoryAttribute attr) {
    final currentValue = widget.values[attr.id];
    final label = attr.isRequired ? '${attr.name} *' : attr.name;
    final isEmpty =
        currentValue == null || currentValue.toString().trim().isEmpty;
    final showError =
        widget.validateRequiredOnPublish && attr.isRequired && isEmpty;

    switch (attr.dataType) {
      case AttributeType.text:
        final ctrl = _controllerFor(attr);
        return TextFormField(
          key: Key('attr_${attr.id}'),
          controller: ctrl,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: label,
            errorText: showError ? '${attr.name} is required.' : null,
          ),
          onChanged: (v) => _emit(attr.id, v.trim().isEmpty ? null : v.trim()),
        );

      case AttributeType.number:
        final ctrl = _controllerFor(attr);
        return TextFormField(
          key: Key('attr_${attr.id}'),
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            errorText: showError ? '${attr.name} is required.' : null,
          ),
          onChanged: (v) {
            final d = double.tryParse(v);
            _emit(attr.id, d);
          },
        );

      case AttributeType.boolean:
        final boolVal = currentValue is bool ? currentValue : false;
        return Row(
          children: [
            Expanded(child: Text(label)),
            Switch(
              key: Key('attr_${attr.id}'),
              value: boolVal,
              onChanged: (v) => _emit(attr.id, v),
            ),
          ],
        );

      case AttributeType.select:
        final strVal =
            currentValue is String && attr.options.contains(currentValue)
                ? currentValue
                : null;
        return DropdownButtonFormField<String?>(
          key: Key('attr_${attr.id}'),
          decoration: InputDecoration(
            labelText: label,
            errorText: showError ? '${attr.name} is required.' : null,
          ),
          initialValue: strVal,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('—')),
            ...attr.options.map(
              (o) => DropdownMenuItem(value: o, child: Text(o)),
            ),
          ],
          onChanged: (v) => _emit(attr.id, v),
        );
    }
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

/// Converts the dynamic value map from [DynamicAttributeForm.values] into
/// a list of [ProductAttributeInput] suitable for [AdminProductRepository.saveAttributes].
List<ProductAttributeInput> attributeInputsFromMap(
  Map<String, dynamic> values,
  List<CategoryAttribute> attributes,
) {
  final result = <ProductAttributeInput>[];
  for (final attr in attributes) {
    final val = values[attr.id];
    if (val == null) continue;
    switch (attr.dataType) {
      case AttributeType.text:
      case AttributeType.select:
        if (val is String && val.isNotEmpty) {
          result.add(ProductAttributeInput(
              categoryAttributeId: attr.id, valueText: val));
        }
        break;
      case AttributeType.number:
        if (val is double) {
          result.add(ProductAttributeInput(
              categoryAttributeId: attr.id, valueNumber: val));
        }
        break;
      case AttributeType.boolean:
        if (val is bool) {
          result.add(ProductAttributeInput(
              categoryAttributeId: attr.id, valueBoolean: val));
        }
        break;
    }
  }
  return result;
}

/// Converts a list of saved [ProductAttributeValue]s back into a map for
/// [DynamicAttributeForm.values], keyed by [CategoryAttribute.id].
Map<String, dynamic> attributeMapFromValues(
  List<ProductAttributeValue> saved,
  List<CategoryAttribute> attributes,
) {
  // Build lookup: attributeKey → attribute id.
  final keyToId = {for (final a in attributes) a.attributeKey: a.id};

  final result = <String, dynamic>{};
  for (final v in saved) {
    final attrId = keyToId[v.attributeKey];
    if (attrId == null) continue;
    if (v.valueText != null) {
      result[attrId] = v.valueText;
    } else if (v.valueNumber != null) {
      result[attrId] = v.valueNumber;
    } else if (v.valueBoolean != null) {
      result[attrId] = v.valueBoolean;
    }
  }
  return result;
}
