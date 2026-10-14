import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/product_detail.dart';

/// Renders a product's specification attributes as a two-column table.
///
/// Each row displays `name : displayValue`. Attributes must already be
/// sorted by [ProductAttributeValue.displayOrder] by the caller (the
/// [ProductDetail.attributes] list is pre-sorted by the repository).
class SpecificationTable extends StatelessWidget {
  const SpecificationTable({super.key, required this.attributes});

  final List<ProductAttributeValue> attributes;

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: attributes.asMap().entries.map((entry) {
        final isLast = entry.key == attributes.length - 1;
        final attr = entry.value;

        final decoration = isLast
            ? null
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.outline, width: 1),
                ),
              );

        return TableRow(
          decoration: decoration,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.xs,
              ),
              child: Text(
                attr.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.xs,
              ),
              child: Text(
                attr.displayValue,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
