import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../di/beak_locator.dart';
import '../localization/beak_localizations.dart';
import '../panel/beak_routes.dart';
import '../presentation/beak_record_template.dart';
import '../table/beak_data_table.dart';
import 'beak_form_layout.dart';

/// A read-only table of the records that point at the open form's record.
///
/// The rows are scoped by [scope] on [model] against [parent]'s value in the
/// same draft, so a product form lists that product's variants and an invoice
/// lists its lines. A row opens the record itself, or the record [openVia]
/// points at when the child is a join row.
///
/// ```dart
/// BeakRelatedList(
///   const ProductVariantModel(),
///   scope: ProductVariantModel.productId,
///   parent: ProductModel.id,
///   fields: [ProductVariantModel.sku],
/// )
/// ```
final class BeakRelatedList extends BeakFormWidget {
  /// Creates a draft-scoped related list.
  BeakRelatedList(
    BeakModel model, {
    required BeakScalarField<Object> scope,
    required BeakScalarField<Object> parent,
    required List<BeakScalarField<Object>> fields,
    BeakToOneField? openVia,
    String? emptyTitle,
    super.visibleIf,
  }) : super(
         builder: (context, draft) => _RelatedListBody(
           model: model,
           scope: scope,
           parent: parent,
           fields: fields,
           openVia: openVia,
           parentValue: draft.read(parent),
           emptyTitle: emptyTitle,
         ),
       );
}

class _RelatedListBody extends StatelessWidget {
  const _RelatedListBody({
    required this.model,
    required this.scope,
    required this.parent,
    required this.fields,
    required this.openVia,
    required this.parentValue,
    required this.emptyTitle,
  });

  final BeakModel model;
  final BeakScalarField<Object> scope;
  final BeakScalarField<Object> parent;
  final List<BeakScalarField<Object>> fields;
  final BeakToOneField? openVia;
  final Object? parentValue;
  final String? emptyTitle;

  @override
  Widget build(BuildContext context) {
    final value = parentValue;
    if (value == null) {
      return OiEmptyState(
        title: emptyTitle ?? BeakLocalizations.of(context).noRecords,
        icon: OiIcons.inbox,
      );
    }
    final source = beakDependencies(context)<BeakDataSource>();
    final via = openVia;
    return BeakDataTable(
      model: model,
      dataSource: source,
      fields: fields,
      initialSpec: model.query(filter: scope.eq(value)),
      enableDelete: false,
      showStatusBar: false,
      showBulkActionBar: false,
      onRowTap: (record) {
        final Object? id = via == null
            ? model.primaryKeyOf(record)
            : switch (via.relation) {
                BeakBelongsTo(:final foreignKey) => record[foreignKey]?.raw,
                _ => null,
              };
        if (id == null) return;
        context.go(BeakRoutes.show((via?.target ?? model).table, id));
      },
    );
  }
}

/// Convenience nodes for the relationship shapes an admin repeats.
extension BeakRelationRowDefaults on BeakToManyField {
  /// The related records as compact read-only rows.
  BeakRelationTable readOnlyRows({
    required List<BeakFormNode> children,
    String? label,
    List<BeakFormNode> identityChildren = const [],
    bool showHeading = true,
    int identityFlex = 3,
    List<double?> columnWidths = const [],
    List<AlignmentGeometry> columnAlignments = const [],
    BeakFormLayout? advancedForm,
  }) => tableForm(
    label: label,
    children: children,
    identityChildren: identityChildren,
    showHeading: showHeading,
    showColumnHeadings: true,
    showAddAction: false,
    presentation: BeakRelationTablePresentation.rows,
    readOnly: true,
    allowAdding: false,
    allowEdit: false,
    allowRemove: false,
    identityFlex: identityFlex,
    columnWidths: columnWidths,
    columnAlignments: columnAlignments,
    rowPadding: const EdgeInsets.symmetric(vertical: 8),
    rowMinHeightInPixels: 44,
    rowGapInPixels: 8,
    minRowWidthInPixels: 640,
    advancedForm: advancedForm,
  );

  /// The owned translation rows of this collection, with one input per
  /// translatable column.
  ///
  /// Reads the target's [BeakAdmission.translation] to find the owner foreign
  /// key and the locale column, so a translation table needs no hand-written
  /// form. Throws a [BeakConfigurationException] when the target is not a
  /// translation table.
  BeakRelationTable translationsForm({String? label}) {
    final spec = target.admission?.translation;
    if (spec == null) {
      throw BeakConfigurationException(
        'The related table "${target.table}" is not a translation table.',
      );
    }
    final hidden = {
      target.primaryKey.key,
      spec.owner.key,
      spec.locale.key,
      target.createdAtColumnKey,
      target.updatedAtColumnKey,
      target.deletedAtColumnKey,
      ?target.isDeletedColumnKey,
    };
    return tableForm(
      label: label,
      showColumnHeadings: false,
      presentation: BeakRelationTablePresentation.cards,
      children: [
        BeakInput<Object>(
          field: BeakScalarField<Object>(model: target, column: spec.locale),
        ),
        for (final column in target.columnsFor(BeakContext.form))
          if (!hidden.contains(column.key) && column is! BeakCustomColumn)
            BeakInput<Object>(
              field: BeakScalarField<Object>(model: target, column: column),
            ),
      ],
    );
  }
}

/// The relation's own display value as a link to the related record.
extension BeakToOneLink on BeakToOneField {
  /// A form node that renders the related record's display column as a link to
  /// its detail page.
  BeakFormWidget link({String? label, BeakValueBinding<String>? title}) {
    final target = this.target;
    final relation = this.relation;
    final display = target.columnByKey(target.displayColumnKey);
    final foreign = switch (relation) {
      BeakBelongsTo(:final foreignKey) => model.columnByKey(foreignKey),
      _ => null,
    };
    if (display == null || foreign == null) {
      throw BeakConfigurationException(
        'The relation "$key" has no display column to link.',
      );
    }
    final value = BeakScalarField<Object>(
      model: model,
      column: display,
      path: [...path, relation],
    );
    final id = BeakScalarField<Object>(model: model, column: foreign);
    return BeakFormWidget(
      builder: (context, draft) {
        final recordId = draft.read(id);
        final raw = draft.read<Object>(value);
        final text = title?.read(draft) ?? (raw == null ? '—' : '$raw');
        if (recordId == null) return OiLabel.body(label ?? text);
        return OiTappable(
          semanticLabel: text,
          onTap: () => context.go(BeakRoutes.show(target.table, recordId)),
          child: OiLabel.body(
            text,
            color: context.colors.primary.base,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      },
    );
  }
}
