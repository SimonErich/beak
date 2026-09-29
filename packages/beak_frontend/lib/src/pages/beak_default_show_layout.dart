import 'package:beak_core/beak_core.dart';

import '../form/beak_form_layout.dart';

/// The most columns of a related record a default show tab lists in a row.
const int _relatedRowColumnLimit = 5;

/// The read-only layout a resource shows for a record when it declares no read
/// screen: a card with an input for each column visible on
/// `BeakContext.detail`, followed by a card with one tab per to-many
/// relationship listing its related records.
///
/// A column marked `visibleOn: {BeakContext.detail}` therefore appears here
/// and not in the create and edit forms, and a form-only column such as a
/// password does not appear here. A resource that declares its own read screen
/// (a `BeakFormScreen` for the read role) shares one layout between reading
/// and editing, so that layout decides what is shown.
///
/// Related rows come from the same query as the record, so the page costs one
/// round trip. A to-many relationship whose target model is not in [registry]
/// (declared through `BeakModel.relatedModels` on generated models) has no
/// columns to list and is left out.
BeakFormLayout beakDefaultShowLayout(
  BeakModel model, {
  BeakModelRegistry? registry,
}) {
  final base = BeakFormLayout.fromModel(
    model,
    registry: registry,
    surface: BeakContext.detail,
  );
  final tabs = <BeakTab>[
    for (final relation in model.relationships)
      if (relation.cardinality == BeakRelationCardinality.many)
        if (registry?.byTable(relation.relatedTable)
            case final BeakModel target)
          BeakTab(
            title: relation.label,
            children: [
              BeakRelationTable(
                field: BeakToManyField(
                  model: model,
                  relation: relation,
                  target: target,
                ),
                showHeading: false,
                showColumnHeadings: true,
                readOnly: true,
                allowAdding: false,
                allowEdit: false,
                allowRemove: false,
                presentation: BeakRelationTablePresentation.rows,
                children: _rowInputs(target, relation),
              ),
            ],
          ),
  ];
  return BeakFormLayout(
    children: [
      if (base.children.isNotEmpty) BeakCard(children: base.children),
      if (tabs.isNotEmpty) BeakCard(children: [BeakTabs(tabs: tabs)]),
    ],
  );
}

/// The first columns of [target] worth listing beside each row's identity,
/// without the display column the row already shows or the keys that only
/// point back at the record on display.
List<BeakFormNode> _rowInputs(BeakModel target, BeakRelationship relation) {
  final Set<String> hidden = {
    target.primaryKey.key,
    relation.displayColumnKey,
    if (relation case BeakHasMany(:final foreignKey)) foreignKey,
    if (relation case BeakHasOne(:final foreignKey)) foreignKey,
    for (final own in target.relationships)
      if (own is BeakBelongsTo) own.foreignKey,
  };
  return [
    for (final column
        in target
            .columnsFor(BeakContext.detail)
            .where((column) => !hidden.contains(column.key))
            .take(_relatedRowColumnLimit))
      BeakInput<Object>(
        field: BeakScalarField<Object>(model: target, column: column),
      ),
  ];
}
