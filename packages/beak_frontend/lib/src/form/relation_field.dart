import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_resource_repository.dart';
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

/// The form picker for a [BeakBelongsTo] relationship: an async-searching
/// combobox over the related table (searching the relation's search
/// columns, showing its display column) whose selection stores the related
/// record's id in the foreign-key field.
class BeakBelongsToField extends HookWidget {
  /// Creates the picker for [relation] bound to [controller].
  const BeakBelongsToField({
    required this.controller,
    required this.relation,
    required this.dataSource,
    this.relatedPrimaryKeyKey = 'id',
    super.key,
  });

  /// The form controller holding the foreign-key field.
  final BeakFormController controller;

  /// The relationship this picker selects for.
  final BeakBelongsTo relation;

  /// The source related records are searched through.
  final BeakDataSource dataSource;

  /// Primary-key column key of the related table.
  final String relatedPrimaryKeyKey;

  @override
  Widget build(BuildContext context) {
    final BeakFormSlot slot = controller.slotOfForeignKey(relation);
    final repository = useMemoized(() => BeakResourceRepository(dataSource), [
      dataSource,
    ]);
    useListenable(controller);
    final selected = useState<BeakRecord?>(null);

    // Resolve the prefilled foreign key into a labelled record once.
    useEffect(() {
      final Object? initialId = controller.get<Object>(slot);
      if (initialId == null) {
        return null;
      }
      var cancelled = false;
      Future<void> resolve() async {
        final result = await repository.getOne(
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
    }, [repository, slot]);

    final List<String> searchKeys = relation.searchColumnKeys.isEmpty
        ? [relation.displayColumnKey]
        : relation.searchColumnKeys;

    return OiComboBox<BeakRecord>(
      label: relation.label,
      labelOf: (record) =>
          record[relation.displayColumnKey]?.raw?.toString() ?? '',
      value: selected.value,
      error: controller.getError(slot),
      search: (query) => beakSearchRelated(
        repository,
        table: relation.relatedTable,
        columnKeys: searchKeys,
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

    Object? idOf(BeakRecord record) => record[relatedPrimaryKeyKey]?.raw;

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final spec = BeakQuerySpec(table: model.table)
            .withFilter(
              BeakFieldFilter.forKey(
                model.primaryKey.key,
                BeakOperator.eq,
                BeakValue.of(parentId),
              ),
            )
            .withRelation(relation);
        final result = await repository.query(spec);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value) when value.items.isNotEmpty) {
          attached.value =
              value.items.first.relations[relation.key] ?? const [];
        }
      }

      load();
      return () => cancelled = true;
    }, [repository, parentId]);

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
      attached.value = next;
      if (added.isNotEmpty) {
        await repository.attach(model.table, parentId, relation.key, added);
      }
      if (removed.isNotEmpty) {
        await repository.detach(model.table, parentId, relation.key, removed);
      }
    }

    final List<String> searchKeys = relation.searchColumnKeys.isEmpty
        ? [relation.displayColumnKey]
        : relation.searchColumnKeys;

    return OiComboBox<BeakRecord>(
      label: relation.label,
      labelOf: (record) =>
          record[relation.displayColumnKey]?.raw?.toString() ?? '',
      multiSelect: true,
      selectedValues: attached.value,
      search: (query) => beakSearchRelated(
        repository,
        table: relation.relatedTable,
        columnKeys: searchKeys,
        term: query,
      ),
      onMultiSelect: sync,
    );
  }
}
