import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late List<BeakFilter?> emitted;

  final defs = [
    BeakSelectFilter(field: _article(ArticleColumns.status), label: 'Status'),
    BeakBoolFilter(
      field: _article(ArticleColumns.active),
      label: 'Active only',
    ),
    BeakTextFilter(field: _article(ArticleColumns.title), label: 'Title'),
    BeakDateRangeFilter(
      field: _article(ArticleColumns.publishedAt),
      label: 'Published',
    ),
  ];

  setUp(() => emitted = []);

  testWidgets('filter bars default to compact chips with on-demand editors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(filters: defs, onChanged: emitted.add),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OiFilterChip), findsNWidgets(defs.length));
    final selectFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString().startsWith('OiSelect<'),
      skipOffstage: false,
    );
    expect(selectFinder, findsNothing);
    expect(find.byType(OiDateRangePickerField), findsNothing);

    await tester.tap(find.byType(OiFilterChip).first);
    await tester.pumpAndSettle();
    expect(selectFinder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active chips remove their predicate and clear all together', (
    tester,
  ) async {
    const filter = BeakFieldFilter.forKey(
      'active',
      BeakOperator.eq,
      BeakBoolValue(true),
    );
    const titleFilter = BeakFieldFilter.forKey(
      'title',
      BeakOperator.contains,
      BeakStringValue('Lunch'),
    );
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(
          filters: [
            BeakBoolFilter(
              field: _article(ArticleColumns.active),
              label: 'Active',
            ),
            BeakTextFilter(
              field: _article(ArticleColumns.title),
              label: 'Title',
            ),
          ],
          initialValues: {'active': filter, 'title': titleFilter},
          onChanged: emitted.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear all'), findsOneWidget);
    final activeChip = tester.widget<OiFilterChip>(
      find.byType(OiFilterChip).first,
    );
    expect(activeChip.selected, isTrue);
    activeChip.onRemove!.call();
    await tester.pumpAndSettle();
    expect(emitted.last, isNotNull);
    expect(find.text('Clear all'), findsOneWidget);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(emitted.last, isNull);
    expect(find.text('Clear all'), findsNothing);
  });

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(
          filters: defs,
          onChanged: emitted.add,
          presentation: BeakFilterBarPresentation.controls,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BeakFieldFilter fieldOf(BeakFilter? filter) => switch (filter) {
    final BeakFieldFilter field => field,
    final Object? other => fail('Expected a field filter, got $other.'),
  };

  testWidgets('facet counts batch named predicates inside the scoped query', (
    tester,
  ) async {
    const field = BeakScalarField<String>(
      model: NoteModel(),
      column: BeakStringColumn(key: 'title', label: 'Title', sortable: true),
    );
    final source = _FacetSource();
    final scope = field.contains('Tenant');
    final options = [
      for (var i = 0; i < 10; i++)
        BeakFilterChoice(
          key: 'choice $i',
          label: 'Choice $i',
          filter: field.eq('$i'),
        ),
    ];
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(
          dataSource: source,
          countQuery: const NoteModel().query().withFilter(scope),
          filters: [
            BeakChoiceFilter(
              field: field,
              label: 'Choices',
              options: options,
              showCounts: true,
            ),
          ],
          onChanged: (_) {},
          presentation: BeakFilterBarPresentation.controls,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.summaries.map((spec) => spec.measures.length), [8, 2]);
    expect(source.summaries.every((spec) => spec.filter == scope), isTrue);
    expect(
      source.summaries
          .expand((spec) => spec.measures)
          .map((measure) => measure.filter),
      options.map((option) => option.filter),
    );
    expect(find.text('11'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final presentation in [
    BeakChoiceFilterPresentation.chips,
    BeakChoiceFilterPresentation.radio,
    BeakChoiceFilterPresentation.select,
  ]) {
    testWidgets('facet counts show in the ${presentation.name} presentation', (
      tester,
    ) async {
      const field = BeakScalarField<String>(
        model: NoteModel(),
        column: BeakStringColumn(key: 'title', label: 'Title', sortable: true),
      );
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFilterBar(
            dataSource: _FacetSource(),
            filters: [
              BeakChoiceFilter(
                field: field,
                label: 'Choices',
                presentation: presentation,
                showCounts: true,
                options: [
                  BeakFilterChoice(
                    key: 'a',
                    label: 'Alpha',
                    filter: field.eq('a'),
                  ),
                  BeakFilterChoice(
                    key: 'b',
                    label: 'Beta',
                    filter: field.eq('b'),
                  ),
                ],
              ),
            ],
            onChanged: (_) {},
            presentation: BeakFilterBarPresentation.controls,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A select keeps its options in a closed menu; open it first.
      if (presentation == BeakChoiceFilterPresentation.select) {
        await tester.tap(find.byType(OiSelect<String>));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Alpha (11)'), findsWidgets);
      expect(find.textContaining('Beta (12)'), findsWidgets);
    });
  }

  testWidgets(
    'one-sided currency range edits major units and submits exact cents',
    (tester) async {
      const field = BeakScalarField<int>(
        model: NoteModel(),
        column: BeakIntColumn(key: 'amount', label: 'Amount'),
      );
      final def = field
          .currency(minorUnits: true)
          .numberRangeFilter(
            showMaximum: false,
            minimumLabel: 'Minimum order',
            placeholder: 'e.g. 40.00',
          );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFormattingScope(
            formatting: const BeakFormatting(currency: 'EUR'),
            child: BeakFilterBar(
              filters: [def],
              onChanged: emitted.add,
              presentation: BeakFilterBarPresentation.controls,
            ),
          ),
        ),
      );
      expect(find.byType(OiNumberInput), findsOneWidget);
      expect(find.text('+'), findsNothing);
      expect(find.text('€'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '40.25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      final predicate = fieldOf(emitted.last);
      expect(predicate.operator, BeakOperator.gte);
      expect(predicate.value.raw, 4025);
    },
  );

  testWidgets('named dropdown filters restore and clear compound predicates', (
    tester,
  ) async {
    const field = BeakScalarField<String>(
      model: NoteModel(),
      column: BeakStringColumn(key: 'title', label: 'Title'),
    );
    final choice = BeakOrFilter([field.eq('One'), field.eq('Two')]);
    final def = BeakChoiceFilter(
      field: field,
      label: 'Author',
      allLabel: 'Anyone',
      presentation: BeakChoiceFilterPresentation.select,
      options: [BeakFilterChoice(key: 'staff', label: 'Staff', filter: choice)],
    );
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(
          filters: [def],
          initialValues: {
            def.key: BeakOrFilter([choice]),
          },
          onChanged: emitted.add,
          presentation: BeakFilterBarPresentation.controls,
        ),
      ),
    );
    final select = tester.widget<OiSelect<String>>(
      find.byType(OiSelect<String>),
    );
    expect(select.value, 'staff');
    select.onChanged!('');
    await tester.pump();
    expect(emitted.last, isNull);
  });

  testWidgets('restored compound choices preserve OR and typed range bounds', (
    tester,
  ) async {
    const status = BeakScalarField<ArticleStatus>(
      model: ArticleModel(),
      column: ArticleColumns.status,
    );
    final attention = BeakFilter.allOf([
      status.eq(ArticleStatus.draft),
      const BeakFieldFilter(
        column: ArticleColumns.active,
        operator: BeakOperator.eq,
        value: BeakBoolValue(true),
      ),
    ])!;
    final published = status.eq(ArticleStatus.published);
    final choice = BeakChoiceFilter(
      field: status,
      label: 'Workflow',
      options: [
        BeakFilterChoice(
          key: 'published',
          label: 'Published',
          filter: published,
        ),
        BeakFilterChoice(
          key: 'attention',
          label: 'Needs attention',
          filter: attention,
        ),
      ],
    );
    const amount = BeakIntColumn(key: 'amount', label: 'Amount');
    final range = BeakNumberRangeFilter(
      field: _article(amount),
      label: 'Amount',
    );
    const bounds = BeakAndFilter([
      BeakFieldFilter(
        column: amount,
        operator: BeakOperator.gte,
        value: BeakIntValue(2),
      ),
      BeakFieldFilter(
        column: amount,
        operator: BeakOperator.lte,
        value: BeakIntValue(10),
      ),
    ]);
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(
          filters: [choice, range],
          initialValues: {
            choice.key: BeakOrFilter([attention]),
            range.key: bounds,
          },
          onChanged: emitted.add,
          presentation: BeakFilterBarPresentation.controls,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<OiNumberInput>(find.byType(OiNumberInput))
          .map((input) => input.value),
      [2, 10],
    );
    expect(
      tester
          .widgetList<OiCheckbox>(find.byType(OiCheckbox))
          .map((input) => input.value),
      [false, true],
    );
    tester.widget<OiCheckbox>(find.byType(OiCheckbox).first).onChanged!(true);
    await tester.pumpAndSettle();
    final combined = emitted.last! as BeakAndFilter;
    expect(combined.filters, contains(BeakOrFilter([published, attention])));
    expect(combined.filters, contains(bounds));
  });

  testWidgets(
    'choice presentations preserve typed predicates and radio clearing',
    (tester) async {
      const field = BeakScalarField<ArticleStatus>(
        model: ArticleModel(),
        column: ArticleColumns.status,
      );
      final choices = [
        BeakFilterChoice(
          key: 'draft',
          label: 'Draft',
          filter: field.eq(ArticleStatus.draft),
        ),
        BeakFilterChoice(
          key: 'published',
          label: 'Published',
          filter: field.eq(ArticleStatus.published),
        ),
      ];
      for (final presentation in BeakChoiceFilterPresentation.values) {
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            home: SizedBox(
              width: 420,
              child: BeakFilterBar(
                key: ValueKey(presentation),
                stacked: true,
                filters: [
                  BeakChoiceFilter(
                    field: field,
                    label: 'Workflow',
                    options: choices,
                    presentation: presentation,
                    columns: 2,
                  ),
                ],
                onChanged: emitted.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        switch (presentation) {
          case BeakChoiceFilterPresentation.checkboxes:
            tester.widget<OiCheckbox>(find.byType(OiCheckbox).first).onChanged!(
              true,
            );
          case BeakChoiceFilterPresentation.chips:
            tester
                .widget<OiFilterChip>(find.byType(OiFilterChip).first)
                .onTap!();
          case BeakChoiceFilterPresentation.combobox:
            tester
                .widget<OiComboBox<BeakFilterChoice>>(
                  find.byType(OiComboBox<BeakFilterChoice>),
                )
                .onMultiSelect!([choices.first]);
          case BeakChoiceFilterPresentation.select:
            tester
                .widget<OiSelect<String>>(find.byType(OiSelect<String>))
                .onChanged!('draft');
          case BeakChoiceFilterPresentation.radio:
            tester
                .widget<OiRadio<String>>(find.byType(OiRadio<String>))
                .onChanged!('draft');
        }
        await tester.pumpAndSettle();
        expect(emitted.last, BeakOrFilter([choices.first.filter]));
        if (presentation == BeakChoiceFilterPresentation.radio) {
          final radio = tester.widget<OiRadio<String>>(
            find.byType(OiRadio<String>),
          );
          radio.onChanged!('published');
          await tester.pumpAndSettle();
          expect(emitted.last, BeakOrFilter([choices.last.filter]));
          tester
              .widget<OiRadio<String>>(find.byType(OiRadio<String>))
              .onChanged!('');
          await tester.pumpAndSettle();
          expect(emitted.last, isNull);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('advanced filters retain drafts when their section collapses', (
    tester,
  ) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(
          stacked: true,
          filters: [
            BeakTextFilter(
              field: _article(ArticleColumns.title),
              label: 'Title',
              advanced: true,
            ),
          ],
          onChanged: emitted.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    await tester.tap(find.text('More filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'launch');
    await tester.pumpAndSettle();
    final predicate = emitted.last;
    await tester.tap(find.text('More filters'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    expect(emitted.last, predicate);
    await tester.tap(find.text('More filters'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'launch',
    );
  });

  testWidgets('renders the matching obers_ui control per filter type', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.byType(OiSelect<Enum>), findsOneWidget);
    expect(find.byType(OiSelect<bool>), findsOneWidget);
    expect(find.byType(OiTextInput), findsOneWidget);
    expect(find.byType(OiDateRangePickerField), findsOneWidget);
  });

  testWidgets('each control contributes its typed predicate', (tester) async {
    await pumpBar(tester);

    final OiSelect<Enum> select = tester.widget(find.byType(OiSelect<Enum>));
    select.onChanged!(ArticleStatus.published);
    await tester.pumpAndSettle();
    final BeakFieldFilter statusFilter = fieldOf(emitted.last);
    expect(statusFilter.columnKey, 'status');
    expect(statusFilter.operator, BeakOperator.eq);
    expect(statusFilter.value, const BeakStringValue('published'));

    final OiDateRangePickerField range = tester.widget(
      find.byType(OiDateRangePickerField),
    );
    range.onChanged!(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
    await tester.pumpAndSettle();
    expect(emitted.last, isA<BeakAndFilter>());

    await tester.enterText(find.byType(EditableText), 'launch');
    await tester.pumpAndSettle();
    final BeakAndFilter combined = switch (emitted.last) {
      final BeakAndFilter and => and,
      final Object? other => fail('Expected an AND filter, got $other.'),
    };
    expect(combined.filters, hasLength(3));
  });

  testWidgets('booleans filter true, false and clear back to all records', (
    tester,
  ) async {
    await pumpBar(tester);

    final OiSelect<bool> toggle = tester.widget(find.byType(OiSelect<bool>));
    toggle.onChanged!(true);
    await tester.pumpAndSettle();

    final BeakFieldFilter filter = fieldOf(emitted.last);
    expect(filter.columnKey, 'active');
    expect(filter.value, const BeakBoolValue(true));
    toggle.onChanged!(false);
    await tester.pumpAndSettle();
    expect(fieldOf(emitted.last).value, const BeakBoolValue(false));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(emitted.last, isNull);
  });

  testWidgets('clearing every control emits null again', (tester) async {
    await pumpBar(tester);

    final OiSelect<Enum> select = tester.widget(find.byType(OiSelect<Enum>));
    select.onChanged!(ArticleStatus.draft);
    await tester.pumpAndSettle();
    expect(emitted.last, isNotNull);

    select.onChanged!(null);
    await tester.pumpAndSettle();
    expect(emitted.last, isNull);

    await tester.enterText(find.byType(EditableText), '   ');
    await tester.pumpAndSettle();
    expect(emitted.last, isNull);
  });

  testWidgets('a select filter over a non-enum column renders a notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(
          filters: [
            BeakSelectFilter(
              field: _article(ArticleColumns.title),
              label: 'Broken',
            ),
          ],
          onChanged: emitted.add,
          presentation: BeakFilterBarPresentation.controls,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets(
    'numeric range accepts typed decimals and full calendar ranges retain the end day',
    (tester) async {
      const price = BeakScalarField<double>(
        model: ArticleModel(),
        column: BeakDecimalColumn(key: 'price', label: 'Price'),
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFilterBar(
            filters: [price.numberRangeFilter(), defs.last],
            onChanged: emitted.add,
            presentation: BeakFilterBarPresentation.controls,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final numberFields = find.descendant(
        of: find.byType(OiNumberInput),
        matching: find.byType(EditableText),
      );
      expect(numberFields, findsNWidgets(2));
      await tester.enterText(numberFields.first, '12.50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fieldOf(emitted.last).value, const BeakDoubleValue(12.5));
      expect(fieldOf(emitted.last).operator, BeakOperator.gte);
      final range = tester.widget<OiDateRangePickerField>(
        find.byType(OiDateRangePickerField),
      );
      range.onChanged!(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      await tester.pumpAndSettle();
      final combined = switch (emitted.last) {
        BeakAndFilter(:final filters) => filters,
        _ => <BeakFilter>[],
      };
      final dates = combined.whereType<BeakAndFilter>().single.filters;
      expect(
        dates.last,
        isA<BeakFieldFilter>()
            .having((filter) => filter.operator, 'operator', BeakOperator.lt)
            .having((filter) => filter.value.raw, 'end', DateTime(2026, 2, 1)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'typed related fields keep qualified paths and relation selections scope identity',
    (tester) async {
      const name = BeakScalarField<String>(
        model: ArticleModel(),
        column: BeakStringColumn(key: 'name', label: 'Category'),
        path: [ArticleRelations.category],
      );
      const category = BeakToOneField(
        model: ArticleModel(),
        relation: ArticleRelations.category,
        target: _FilterCategory(),
      );
      final record = BeakRecord.fromRow({'id': 'c1', 'name': 'Coffee'});
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFilterBar(
            filters: [name.textFilter(), category.relationFilter()],
            dataSource: FakeDataSource(),
            onChanged: emitted.add,
            presentation: BeakFilterBarPresentation.controls,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<OiTextInput>(find.byType(OiTextInput));
      text.onChanged!('Coffee');
      await tester.pumpAndSettle();
      expect(fieldOf(emitted.last).columnKey, 'category.name');
      final picker = tester.widget<OiComboBox<BeakRecord>>(
        find.byType(OiComboBox<BeakRecord>),
      );
      picker.onSelect!(record);
      await tester.pumpAndSettle();
      final combined = switch (emitted.last) {
        BeakAndFilter(:final filters) => filters,
        _ => <BeakFilter>[],
      };
      expect(
        combined.last,
        BeakRelationFilter(
          'category',
          BeakFieldFilter(
            column: const _FilterCategory().primaryKey,
            operator: BeakOperator.eq,
            value: const BeakStringValue('c1'),
          ),
        ),
      );
    },
  );

  testWidgets(
    'an already-selected relationship filter refreshes its label after remote edits',
    (tester) async {
      const category = BeakToOneField(
        model: ArticleModel(),
        relation: ArticleRelations.category,
        target: _FilterCategory(),
      );
      final record = BeakRecord.fromRow({'id': 'c1', 'name': 'Old label'});
      final storage = FakeDataSource(
        models: const [ArticleModel(), _FilterCategory()],
        records: {
          'categories': {'c1': record},
        },
      );
      final source = ModelBeakDataSource(
        registry: BeakModelRegistry()
          ..register(const ArticleModel())
          ..register(const _FilterCategory()),
        fallback: storage,
      );
      addTearDown(source.dispose);
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFilterBar(
            filters: [category.relationFilter()],
            dataSource: source,
            onChanged: emitted.add,
            presentation: BeakFilterBarPresentation.controls,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<OiComboBox<BeakRecord>>(find.byType(OiComboBox<BeakRecord>))
          .onSelect!(record);
      await tester.pumpAndSettle();
      final predicate = emitted.single;
      await source.update(
        'categories',
        'c1',
        BeakRecord.fromRow({'name': 'Fresh label'}),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OiComboBox<BeakRecord>>(find.byType(OiComboBox<BeakRecord>))
            .value?['name']
            ?.raw,
        'Fresh label',
      );
      expect(emitted, [
        predicate,
      ], reason: 'Refreshing a label preserves the selected filter identity.');
      await tester.pumpWidget(const SizedBox());
    },
  );

  group('derived defaults', () {
    test('one control per filterable column, matched to its type', () {
      final filters = beakDefaultFiltersOf(const _FilterableModel());

      expect(filters.map((filter) => (filter.runtimeType, filter.column.key)), [
        (BeakTextFilter, 'name'),
        (BeakBoolFilter, 'active'),
        (BeakSelectFilter, 'status'),
        (BeakDateRangeFilter, 'published_at'),
        (BeakNumberRangeFilter, 'stock'),
      ]);
    });

    test('every derived control addresses a typed field of the model', () {
      const model = _FilterableModel();
      final filters = beakDefaultFiltersOf(model);

      for (final filter in filters) {
        expect(filter.field, isA<BeakScalarField<Object>>());
        expect(filter.field.model, same(model));
        expect(filter.key, filter.column.key);
      }
    });

    test('numeric columns automatically receive a range control', () {
      expect(
        beakDefaultFiltersOf(const _FilterableModel()).map((f) => f.column.key),
        contains('stock'),
      );
    });

    test('declared filters win over the derived ones', () {
      final declared = BeakTextFilter(
        field: _article(ArticleColumns.title),
        label: 'Headline',
      );
      final resource = BeakResource(
        model: const _FilterableModel(),
        icon: const BeakIconToken(OiIcons.table),
        filters: [declared],
      );

      expect(resource.effectiveFilters, [declared]);
      expect(
        resource.copyWith(filters: const []).effectiveFilters,
        hasLength(5),
      );
    });
  });
}

/// The typed field of an [ArticleModel] column.
BeakScalarField<Object> _article(BeakColumn column) =>
    BeakScalarField<Object>(model: const ArticleModel(), column: column);

/// A model marking each common scalar shape as filterable.
final class _FilterableModel extends BeakModel {
  const _FilterableModel();

  @override
  String get table => 'posts';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name', filterable: true),
    BeakBoolColumn(key: 'active', label: 'Active', filterable: true),
    BeakEnumColumn<ArticleStatus>(
      key: 'status',
      label: 'Status',
      values: ArticleStatus.values,
      filterable: true,
    ),
    BeakDateTimeColumn(
      key: 'published_at',
      label: 'Published at',
      filterable: true,
    ),
    BeakIntColumn(key: 'stock', label: 'Stock', filterable: true),
    BeakStringColumn(key: 'slug', label: 'Slug'),
  ];
}

final class _FilterCategory extends BeakModel {
  const _FilterCategory();
  @override
  String get table => 'categories';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

final class _FacetSource extends FakeDataSource
    implements BeakSummaryDataSource {
  final summaries = <BeakSummarySpec>[];
  @override
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) async {
    summaries.add(spec);
    return BeakSummaryResult(
      rows: [
        BeakSummaryRow(
          group: const BeakNullValue(),
          values: {
            for (final measure in spec.measures)
              measure.key:
                  int.parse(measure.key.replaceFirst('facet_', '')) + 11,
          },
        ),
      ],
      truncated: false,
    );
  }
}
