import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_resource_repository.dart';
import '../form/relation_field.dart';

/// The embedded manager of a to-many relationship on one parent record:
/// lists the related records by their display column and offers the
/// matching mutations — attach/detach through the pivot for
/// [BeakBelongsToMany], delete for [BeakHasMany], plus an optional
/// create hook.
///
/// A [BeakBelongsTo] or [BeakHasOne] [relationship] renders an informational
/// caption instead of a manager (only to-many relations are managed here).
/// [BeakDataForm] embeds one per has-many relation in edit mode.
///
/// ```dart
/// BeakRelationManager(
///   parentModel: const OrderModel(),
///   parentId: orderId,
///   relationship: OrderRelations.lineItems, // a BeakHasMany
///   dataSource: dataSource,
///   onCreateRequested: () => context.go('/line-items/new?order=$orderId'),
/// )
/// ```
class BeakRelationManager extends HookWidget {
  /// Creates the manager of [relationship] on the [parentId] record of
  /// [parentModel].
  const BeakRelationManager({
    required this.parentModel,
    required this.parentId,
    required this.relationship,
    required this.dataSource,
    this.initialRecords,
    this.onCreateRequested,
    this.relatedPrimaryKeyKey = 'id',
    this.pageSize = 25,
    this.maxHeightInPixels = 360,
    super.key,
  });

  /// The model owning the relationship.
  final BeakModel parentModel;

  /// Primary key of the parent record.
  final Object parentId;

  /// The to-many relationship managed here.
  final BeakRelationship relationship;

  /// The source related records load from and mutations run against.
  final BeakDataSource dataSource;

  /// The related records the parent already loaded, if any.
  ///
  /// A detail page eager-loads every relation with the record it shows, so
  /// passing them here means N managers cost zero extra queries on first
  /// paint. Any mutation still refetches.
  final List<BeakRecord>? initialRecords;

  /// Invoked when the user asks to create a related record (typically
  /// navigates to the related resource's create form).
  final VoidCallback? onCreateRequested;

  /// Primary-key column key of the related table.
  final String relatedPrimaryKeyKey;

  /// How many related rows to read at a time.
  ///
  /// A to-many can be unbounded, so the manager reads a page and offers to
  /// read the next one rather than pretending the first page is all of it.
  final int pageSize;

  /// The maximum height of the scrollable related-rows list, in pixels.
  final double maxHeightInPixels;

  @override
  Widget build(BuildContext context) {
    final repository = useMemoized(() => BeakResourceRepository(dataSource), [
      dataSource,
    ]);
    final related = useState<List<BeakRecord>>(initialRecords ?? const []);
    final total = useState(initialRecords?.length ?? 0);
    final perPage = useState(pageSize);
    final reloadTick = useState(0);

    useEffect(() {
      // Seeded by the parent: the first paint is already correct, so only a
      // mutation (which bumps the tick) or a "load more" sends us back.
      if (initialRecords != null &&
          reloadTick.value == 0 &&
          perPage.value == pageSize) {
        return null;
      }
      var cancelled = false;
      Future<void> load() async {
        final (rows, count) = await _load(repository, perPage.value);
        if (!cancelled) {
          related.value = rows;
          total.value = count;
        }
      }

      load();
      return () => cancelled = true;
    }, [repository, parentId, reloadTick.value, perPage.value]);

    if (relationship.cardinality != BeakRelationCardinality.many) {
      return OiLabel.caption(
        '${relationship.label} is not a to-many relationship.',
      );
    }

    void reload() => reloadTick.value += 1;

    Future<void> mutate(Future<BeakResult<void>> Function() run) async {
      await run();
      reload();
    }

    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiRow(
          breakpoint: context.breakpoint,
          children: [
            Expanded(child: OiLabel.smallStrong(relationship.label)),
            if (total.value > 0) OiBadge.soft(label: '${total.value}'),
            if (onCreateRequested != null)
              OiButton.secondary(label: 'Create', onTap: onCreateRequested),
          ],
        ),
        if (relationship case final BeakBelongsToMany manyToMany)
          _attachPicker(repository, manyToMany, reload),
        // The related rows scroll within a bounded box, so a record with many
        // relations never overflows the surrounding form or detail layout.
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeightInPixels),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final record in related.value)
                  OiRow(
                    breakpoint: context.breakpoint,
                    children: [
                      Expanded(
                        child: OiLabel.body(
                          relationship.displayLabelOf(record),
                          maxLines: 1,
                        ),
                      ),
                      switch (relationship) {
                        final BeakBelongsToMany manyToMany => OiButton.icon(
                          icon: OiIcons.unlink,
                          label: 'Detach',
                          onTap: () => _withRecordId(record, (relatedId) {
                            mutate(
                              () => repository.detach(
                                parentModel.table,
                                parentId,
                                manyToMany.key,
                                [relatedId],
                              ),
                            );
                          }),
                        ),
                        _ => OiButton.icon(
                          icon: OiIcons.trash2,
                          label: 'Delete',
                          onTap: () => _withRecordId(record, (relatedId) {
                            mutate(
                              () => repository.delete(
                                relationship.relatedTable,
                                relatedId,
                              ),
                            );
                          }),
                        ),
                      },
                    ],
                  ),
                if (related.value.isEmpty)
                  OiLabel.caption(
                    'No ${relationship.label.toLowerCase()} yet.',
                  ),
                // Only when there is more: a button that loads nothing is
                // worse than no button.
                if (related.value.length < total.value)
                  OiButton.ghost(
                    label: 'Load more (${total.value - related.value.length})',
                    onTap: () => perPage.value += pageSize,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The attach picker of a belongs-to-many manager: search the related
  /// table, selecting attaches through the pivot.
  Widget _attachPicker(
    BeakResourceRepository repository,
    BeakBelongsToMany manyToMany,
    VoidCallback reload,
  ) {
    return OiComboBox<BeakRecord>(
      label: 'Attach ${manyToMany.label.toLowerCase()}',
      labelOf: manyToMany.displayLabelOf,
      search: (query) => beakSearchRelated(
        repository,
        table: manyToMany.relatedTable,
        columnKeys: manyToMany.effectiveSearchColumnKeys,
        term: query,
      ),
      onSelect: (record) {
        if (record == null) {
          return;
        }
        _withRecordId(record, (relatedId) async {
          await repository.attach(parentModel.table, parentId, manyToMany.key, [
            relatedId,
          ]);
          reload();
        });
      },
    );
  }

  /// The related records, and how many there are in total.
  ///
  /// The count matters: a has-many reads a page, so a parent with 400
  /// children used to show a badge reading 25 — the page size, presented as
  /// the truth.
  Future<(List<BeakRecord>, int)> _load(
    BeakResourceRepository repository,
    int perPage,
  ) async {
    switch (relationship) {
      case final BeakHasMany hasMany:
        final spec = BeakQuerySpec(table: hasMany.relatedTable)
            .withFilter(
              BeakFieldFilter.forKey(
                hasMany.foreignKey,
                BeakOperator.eq,
                BeakValue.of(parentId),
              ),
            )
            .paginate(perPage: perPage);
        final result = await repository.query(spec);
        return switch (result) {
          BeakOk(:final value) => (value.items, value.total),
          BeakErr() => (const <BeakRecord>[], 0),
        };
      case final BeakBelongsToMany manyToMany:
        // A pivot load comes back whole with the parent, so what arrived is
        // all there is.
        final attached = await beakLoadAttachedRecords(
          repository,
          parentModel: parentModel,
          parentId: parentId,
          relation: manyToMany,
        );
        return (attached, attached.length);
      case BeakBelongsTo() || BeakHasOne():
        return (const <BeakRecord>[], 0);
    }
  }

  void _withRecordId(BeakRecord record, void Function(Object relatedId) run) {
    final Object? relatedId = record[relatedPrimaryKeyKey]?.raw;
    if (relatedId != null) {
      run(relatedId);
    }
  }
}
