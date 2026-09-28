import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_relation_loads.dart';
import '../data/beak_data_changes.dart';
import '../data/beak_resource_repository.dart';
import '../data/reference_cache.dart';
import 'beak_form_controller_builder.dart';

/// Searches [table] for records matching [term] across [columnKeys],
/// returning an empty list on failure — the shared option source behind
/// every relation picker.
Future<List<BeakRecord>> beakSearchRelated(
  BeakResourceRepository repository, {
  required String table,
  required List<String> columnKeys,
  required String term,
}) async {
  final String trimmed = term.trim();
  final spec = BeakQuerySpec(
    table: table,
    search: trimmed.isEmpty ? null : BeakSearch(trimmed, columnKeys),
  );
  final result = await repository.query(spec);
  return switch (result) {
    BeakOk(:final value) => value.items,
    BeakErr() => const <BeakRecord>[],
  };
}

/// Loads the records currently attached through [relation] on the
/// [parentId] record of [parentModel] (one relation-loaded parent query);
/// empty on failure or when the parent is missing.
Future<List<BeakRecord>> beakLoadAttachedRecords(
  BeakResourceRepository repository, {
  required BeakModel parentModel,
  required Object parentId,
  required BeakBelongsToMany relation,
}) async {
  final result = await beakLoadRecordWithRelations(
    repository,
    model: parentModel,
    id: parentId,
    relations: [relation],
  );
  return switch (result) {
    BeakOk(:final value) => value.relations[relation.key] ?? const [],
    BeakErr() => const [],
  };
}

/// The form picker for a [BeakBelongsTo] relationship: an async-searching
/// combobox over the related table (searching the relation's search
/// columns, showing its display column) whose selection stores the related
/// record's id in the foreign-key field.
///
/// A lower-level selector for custom controller integrations;
/// build it directly only in a hand-composed form. In edit mode it resolves
/// the prefilled foreign key into a labelled record so the picker opens on
/// the current selection.
///
/// ```dart
/// BeakBelongsToField(
///   controller: controller,
///   relation: ProductRelations.category, // a BeakBelongsTo
///   dataSource: dataSource,
/// )
/// ```
class BeakBelongsToField extends HookWidget {
  /// Creates the picker for [relation] bound to [controller].
  const BeakBelongsToField({
    required this.controller,
    required this.relation,
    required this.dataSource,
    this.referenceCache,
    this.relatedPrimaryKeyKey = 'id',
    super.key,
  });

  /// The form controller holding the foreign-key field.
  final BeakFormController controller;

  /// The relationship this picker selects for.
  final BeakBelongsTo relation;

  /// The source related records are searched through.
  final BeakDataSource dataSource;

  /// Resolves the prefilled key into its record. Passing the panel's cache
  /// collapses every picker on a form into one `batchGet`; without it each
  /// picker fetches its own.
  final ReferenceCache? referenceCache;

  /// Primary-key column key of the related table.
  final String relatedPrimaryKeyKey;

  @override
  Widget build(BuildContext context) {
    final Enum slot = controller.slotOfForeignKey(relation);
    final repository = useMemoized(
      () => BeakResourceRepository(dataSource, referenceCache: referenceCache),
      [dataSource, referenceCache],
    );
    useListenable(controller);
    final selected = useState<BeakRecord?>(null);
    final dataRevision = useBeakDataRevision(
      dataSource,
      table: relation.relatedTable,
    );
    final choiceItems = useMemoized(() => <BeakRecord>[], [dataRevision]);

    // Resolve the prefilled foreign key into a labelled record once.
    useEffect(() {
      final Object? initialId = controller.get<Object>(slot);
      if (initialId == null) {
        return null;
      }
      var cancelled = false;
      Future<void> resolve() async {
        final result = await repository.resolveReference(
          relation.relatedTable,
          initialId,
        );
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          selected.value = value;
        }
      }

      resolve();
      return () => cancelled = true;
    }, [repository, slot, dataRevision]);

    return OiComboBox<BeakRecord>(
      items: choiceItems,
      label: relation.label,
      labelOf: relation.displayLabelOf,
      value: selected.value,
      error: controller.getError(slot),
      search: (query) => beakSearchRelated(
        repository,
        table: relation.relatedTable,
        columnKeys: relation.effectiveSearchColumnKeys,
        term: query,
      ),
      onSelect: (record) {
        selected.value = record;
        controller.set(slot, record?[relatedPrimaryKeyKey]?.raw);
      },
    );
  }
}

/// The edit-mode picker for a [BeakBelongsToMany] relationship: a
/// multi-select combobox seeded with the currently attached records that
/// attaches newly selected ids and detaches removed ones as the selection
/// changes.
///
/// Requires a saved [parentId] (a many-to-many pivot needs both keys), so
/// This standalone control performs immediate writes. Each selection change diffs
/// against the attached set and issues just the `attach`/`detach` calls
/// needed; a rejected mutation reverts the optimistic selection.
///
/// ```dart
/// BeakBelongsToManyField(
///   model: const ProductModel(),
///   parentId: productId,
///   relation: ProductRelations.tags, // a BeakBelongsToMany
///   dataSource: dataSource,
/// )
/// ```
class BeakBelongsToManyField extends HookWidget {
  /// Creates the picker for [relation] on the [parentId] record of [model].
  const BeakBelongsToManyField({
    required this.model,
    required this.parentId,
    required this.relation,
    required this.dataSource,
    this.relatedPrimaryKeyKey = 'id',
    super.key,
  });

  /// The parent model owning the relationship.
  final BeakModel model;

  /// Primary key of the record under edit.
  final Object parentId;

  /// The many-to-many relationship managed here.
  final BeakBelongsToMany relation;

  /// The source attached records load from and mutations run against.
  final BeakDataSource dataSource;

  /// Primary-key column key of the related table.
  final String relatedPrimaryKeyKey;

  @override
  Widget build(BuildContext context) {
    final repository = useMemoized(() => BeakResourceRepository(dataSource), [
      dataSource,
    ]);
    final attached = useState<List<BeakRecord>>(const []);
    final dataRevision = useBeakDataRevision(dataSource);
    final choiceItems = useMemoized(() => <BeakRecord>[], [dataRevision]);

    Object? idOf(BeakRecord record) => record[relatedPrimaryKeyKey]?.raw;

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final records = await beakLoadAttachedRecords(
          repository,
          parentModel: model,
          parentId: parentId,
          relation: relation,
        );
        if (!cancelled) {
          attached.value = records;
        }
      }

      load();
      return () => cancelled = true;
    }, [repository, parentId, dataRevision]);

    Future<void> sync(List<BeakRecord> next) async {
      final Set<Object> currentIds = {
        for (final record in attached.value)
          if (idOf(record) case final Object id) id,
      };
      final Set<Object> nextIds = {
        for (final record in next)
          if (idOf(record) case final Object id) id,
      };
      final List<Object> added = [
        for (final id in nextIds)
          if (!currentIds.contains(id)) id,
      ];
      final List<Object> removed = [
        for (final id in currentIds)
          if (!nextIds.contains(id)) id,
      ];
      final List<BeakRecord> previous = attached.value;
      attached.value = next;
      final results = <BeakResult<void>>[
        if (added.isNotEmpty)
          await repository.attach(model.table, parentId, relation.key, added),
        if (removed.isNotEmpty)
          await repository.detach(model.table, parentId, relation.key, removed),
      ];
      final bool failed = results.any(
        (result) => switch (result) {
          BeakErr() => true,
          BeakOk() => false,
        },
      );
      if (failed && context.mounted) {
        // A rejected mutation must not leave the optimistic selection in
        // place — revert so the UI keeps matching the server's pivot rows.
        attached.value = previous;
      }
    }

    return OiComboBox<BeakRecord>(
      label: relation.label,
      labelOf: relation.displayLabelOf,
      multiSelect: true,
      items: choiceItems,
      selectedValues: attached.value,
      search: (query) => beakSearchRelated(
        repository,
        table: relation.relatedTable,
        columnKeys: relation.effectiveSearchColumnKeys,
        term: query,
      ),
      onMultiSelect: sync,
    );
  }
}
