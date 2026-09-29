import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  const model = NoteModel();
  final title = model.columns[1];
  final permanent = BeakFieldFilter(
    column: title,
    operator: BeakOperator.neq,
    value: const BeakStringValue('hidden'),
  );
  final preset = BeakQueryPreset(
    key: 'attention',
    label: 'Attention',
    filter: BeakFieldFilter(
      column: title,
      operator: BeakOperator.contains,
      value: const BeakStringValue('urgent'),
    ),
  );

  test('preset counts are read by the preset object, never by its key', () {
    const other = BeakQueryPreset(key: 'other', label: 'Other');
    final counts = BeakPresetCounts({preset: 4});
    expect(counts[preset], 4);
    expect(counts[other], isNull);
    expect(const BeakPresetCounts.none()[preset], isNull);
    expect(counts[BeakQueryPreset(key: preset.key, label: 'Alias')], 4);
  });

  test('selecting no preset returns to the base view', () {
    final controller = BeakQueryController(model: model, presets: [preset]);
    addTearDown(controller.dispose);
    controller.selectPreset(preset);
    expect(controller.state.value.preset, 'attention');
    controller.selectPreset(null);
    expect(controller.state.value.preset, isNull);
  });

  test('facet exclusion keeps permanent and preset scopes', () {
    const field = BeakScalarField<String>(
      model: NoteModel(),
      column: BeakStringColumn(key: 'title', label: 'Title'),
    );
    final filter = field.textFilter();
    final controller = BeakQueryController(
      model: model,
      base: model.query().withFilter(permanent),
      presets: [preset],
    );
    addTearDown(controller.dispose);
    controller.selectPreset(preset);
    controller.applyFilters({filter.key: field.eq('urgent selected')});
    final candidate = controller.queryFor(
      controller.state.value,
      excludingFilter: filter.key,
    );
    expect((candidate.filter as BeakAndFilter).filters, [
      permanent,
      preset.filter,
    ]);
    expect(controller.query.filter, isNot(candidate.filter));
    expect(
      controller.state.value.filters[filter.key],
      field.eq('urgent selected'),
    );
  });

  test(
    'column choices and header visibility survive bookmarks and switch preset projections',
    () {
      const field = BeakScalarField<String>(
        model: NoteModel(),
        column: BeakStringColumn(key: 'title', label: 'Title'),
      );
      final titleColumn = BeakTableColumn.field(field);
      final detailColumn = BeakTableColumn(
        key: 'detail',
        label: 'Detail',
        template: BeakRecordTemplate.fields(title: field),
      );
      final presets = [
        BeakQueryPreset(
          key: 'compact',
          label: 'Compact',
          columns: [titleColumn],
        ),
      ];
      final controller = BeakQueryController(
        model: model,
        columns: [titleColumn, detailColumn],
        presets: presets,
      );
      addTearDown(controller.dispose);
      controller.chooseColumns([detailColumn]);
      controller.setHeaderVisible(false);
      final chosen = controller.currentColumns;
      controller.setSearch('keeps projection');
      expect(identical(chosen, controller.currentColumns), true);
      final restored = BeakQueryController(
        model: model,
        columns: [titleColumn, detailColumn],
        presets: presets,
        initial: BeakQueryController.readUri(
          controller.writeUri(Uri.parse('/notes')),
        ),
      );
      addTearDown(restored.dispose);
      expect(restored.currentColumns.single.key, 'detail');
      expect(restored.state.value.showHeader, false);
      restored.selectPreset(presets.single);
      expect(restored.currentColumns.single.key, 'title');
      expect(
        () => restored.chooseColumns([detailColumn]),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => restored.chooseColumns([]),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'preset, filter preview and clear cannot remove permanent constraints',
    () {
      final controller = BeakQueryController(
        model: model,
        base: BeakQuerySpec(table: model.table, filter: permanent),
        presets: [preset],
      );
      addTearDown(controller.dispose);
      controller.selectPreset(preset);
      controller.goToPage(3);
      final before = controller.query;
      final candidate = BeakQueryState(
        preset: 'attention',
        filters: {
          'title': BeakFieldFilter(
            column: title,
            operator: BeakOperator.eq,
            value: const BeakStringValue('urgent issue'),
          ),
        },
      );
      expect(controller.queryFor(candidate).filter, isA<BeakAndFilter>());
      expect(controller.query, before);
      controller.applyFilters(candidate.filters);
      expect(controller.query.pagination.page, 1);
      expect(controller.state.value.filters, candidate.filters);
      controller.clearFilters();
      expect(
        controller.query.filter,
        BeakFilter.allOf([permanent, preset.filter!]),
      );
      expect(controller.countQuery(preset).filter, controller.query.filter);
    },
  );

  test(
    'explicit filters replace preset defaults without dropping permanent scope',
    () {
      final control = BeakTextFilter(
        field: BeakScalarField<Object>(model: model, column: title),
        label: 'Title',
      );
      final defaultFilter = BeakFieldFilter(
        column: title,
        operator: BeakOperator.contains,
        value: const BeakStringValue('today'),
      );
      final customFilter = BeakFieldFilter(
        column: title,
        operator: BeakOperator.contains,
        value: const BeakStringValue('tomorrow'),
      );
      final controller = BeakQueryController(
        model: model,
        base: BeakQuerySpec(table: model.table, filter: permanent),
        presets: [
          BeakQueryPreset(
            key: 'today',
            label: 'Today',
            defaults: {control: defaultFilter},
          ),
        ],
        initial: BeakQueryState(preset: 'today'),
      );
      addTearDown(controller.dispose);
      expect(
        controller.query.filter,
        BeakFilter.allOf([permanent, defaultFilter]),
      );
      controller.applyFilters({control.key: customFilter});
      expect(
        controller.query.filter,
        BeakFilter.allOf([permanent, customFilter]),
      );
      expect(controller.effectiveFilters(controller.state.value), {
        control.key: customFilter,
      });
      final before = controller.query;
      final clearedPreview = controller.previewFilters({});
      expect(controller.queryFor(clearedPreview).filter, permanent);
      expect(controller.query, before, reason: 'Preview does not apply edits');
      controller.removeFilter(control.key);
      expect(controller.effectiveFilters(controller.state.value), isEmpty);
      expect(controller.query.filter, permanent);
      final restored = BeakQueryState.fromJson(controller.state.value.toJson());
      expect(
        controller.queryFor(restored).filter,
        permanent,
        reason: 'A cleared preset default stays cleared after bookmarking',
      );
      expect(
        controller.countQuery(controller.presets.single).filter,
        BeakFilter.allOf([permanent, defaultFilter]),
        reason: 'The preset count keeps its declared population',
      );
    },
  );

  test(
    'bookmarks and saved state round trip search order filters and pagination',
    () {
      final controller = BeakQueryController(model: model, presets: [preset]);
      addTearDown(controller.dispose);
      controller.selectPreset(preset);
      controller.setSearch('urgent');
      controller.sortBy(title, descending: true);
      controller.setPageSize(50);
      controller.goToPage(4);
      final uri = controller.writeUri(Uri.parse('/notes?source=overview'));
      final restored = BeakQueryController(
        model: model,
        presets: [preset],
        initial: BeakQueryController.readUri(uri),
      );
      addTearDown(restored.dispose);
      expect(uri.queryParameters['source'], 'overview');
      expect(restored.query, controller.query);
      expect(restored.query.search?.term, 'urgent');
      expect(BeakQueryController.readUri(Uri.parse('/notes')), isNull);
      expect(
        () => controller.selectPreset(
          const BeakQueryPreset(key: 'missing', label: 'Missing'),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakQueryState.fromJson({'version': 2}),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
}
