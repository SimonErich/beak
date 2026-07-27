import 'package:beak_core/beak_core.dart';

import '../blocks/beak_block.dart';

/// The show-page layout [model] implies.
///
/// The shape every hand-written layout in this repository converged on: the
/// display column and the first few fields as a headline card, the rest in a
/// wide card beside a narrow one, and one tab per to-many relationship. A
/// resource that declares no `detail` gets this instead of a flat definition
/// grid, and a resource that wants something else still says so.
///
/// Derived rather than generated on purpose: it follows the model, so adding
/// a column changes the page with no file to regenerate, and a hand-written
/// panel gets it too.
BeakBlock beakDefaultDetailLayout(BeakModel model) {
  final List<BeakColumn> detail = model.columnsFor(BeakContext.detail);
  final Set<String> foreignKeys = {
    for (final relation in model.relationships)
      if (relation is BeakBelongsTo) relation.foreignKey,
  };
  // The relationship renders the record; the key that stores it is noise.
  final List<BeakColumn> shown = [
    for (final column in detail)
      if (!foreignKeys.contains(column.key) &&
          column.key != model.primaryKey.key)
        column,
  ];
  final List<BeakColumn> headline = shown.take(4).toList();
  final List<BeakColumn> rest = shown.skip(4).toList();
  final List<BeakRelationship> toMany = [
    for (final relation in model.relationships)
      if (relation.cardinality == BeakRelationCardinality.many) relation,
  ];

  return BeakColumnBlock(
    gapInPixels: 20,
    children: [
      if (headline.isNotEmpty)
        BeakCardBlock(
          child: BeakFieldGroupBlock(headline, columnCount: headline.length),
        ),
      if (rest.isNotEmpty)
        BeakGridBlock(
          columns: 12,
          children: [
            BeakCardBlock(
              span: const BeakSpan(columns: 8),
              title: 'Details',
              child: BeakFieldGroupBlock(rest.take(8).toList(), columnCount: 2),
            ),
            if (rest.length > 8)
              BeakCardBlock(
                span: const BeakSpan(columns: 4),
                title: 'More',
                child: BeakFieldGroupBlock(rest.skip(8).toList()),
              ),
          ],
        ),
      if (toMany.isNotEmpty)
        BeakCardBlock(
          title: 'Related',
          child: BeakTabsBlock(
            tabs: [
              for (final relation in toMany)
                BeakTabBlockItem(
                  label: relation.label,
                  content: BeakRelationBlock(relation),
                ),
            ],
          ),
        ),
    ],
  );
}
