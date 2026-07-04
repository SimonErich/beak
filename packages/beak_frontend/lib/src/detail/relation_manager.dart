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
    this.onCreateRequested,
    this.relatedPrimaryKeyKey = 'id',
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

  /// Invoked when the user asks to create a related record (typically
  /// navigates to the related resource's create form).
  final VoidCallback? onCreateRequested;

  /// Primary-key column key of the related table.
  final String relatedPrimaryKeyKey;

  @override
  Widget build(BuildContext context) {
    final repository = useMemoized(() => BeakResourceRepository(dataSource), [
      dataSource,
    ]);
    final related = useState<List<BeakRecord>>(const []);
    final reloadTick = useState(0);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final List<BeakRecord> loaded = await _load(repository);
        if (!cancelled) {
          related.value = loaded;
        }
      }

      load();
      return () => cancelled = true;
    }, [repository, parentId, reloadTick.value]);

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
            if (onCreateRequested != null)
              OiButton.secondary(label: 'Create', onTap: onCreateRequested),
          ],
        ),
        if (relationship case final BeakBelongsToMany manyToMany)
          _attachPicker(repository, manyToMany, reload),
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
          OiLabel.caption('No ${relationship.label.toLowerCase()} yet.'),
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

  Future<List<BeakRecord>> _load(BeakResourceRepository repository) async {
    switch (relationship) {
      case final BeakHasMany hasMany:
        final spec = BeakQuerySpec(table: hasMany.relatedTable).withFilter(
          BeakFieldFilter.forKey(
            hasMany.foreignKey,
            BeakOperator.eq,
            BeakValue.of(parentId),
          ),
        );
        final result = await repository.query(spec);
        return switch (result) {
          BeakOk(:final value) => value.items,
          BeakErr() => const [],
        };
      case final BeakBelongsToMany manyToMany:
        return beakLoadAttachedRecords(
          repository,
          parentModel: parentModel,
          parentId: parentId,
          relation: manyToMany,
        );
      case BeakBelongsTo() || BeakHasOne():
        return const [];
    }
  }

  void _withRecordId(BeakRecord record, void Function(Object relatedId) run) {
    final Object? relatedId = record[relatedPrimaryKeyKey]?.raw;
    if (relatedId != null) {
      run(relatedId);
    }
  }
}
