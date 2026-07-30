import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late List<BeakFilter?> emitted;

  const defs = [
    BeakSelectFilter(column: ArticleColumns.status, label: 'Status'),
    BeakBoolFilter(column: ArticleColumns.active, label: 'Active only'),
    BeakTextFilter(column: ArticleColumns.title, label: 'Title'),
    BeakDateRangeFilter(column: ArticleColumns.publishedAt, label: 'Published'),
  ];

  setUp(() => emitted = []);

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFilterBar(filters: defs, onChanged: emitted.add),
      ),
    );
    await tester.pumpAndSettle();
  }

  BeakFieldFilter fieldOf(BeakFilter? filter) => switch (filter) {
    final BeakFieldFilter field => field,
    final Object? other => fail('Expected a field filter, got $other.'),
  };

  testWidgets('renders the matching obers_ui control per filter type', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.byType(OiSelect<Enum>), findsOneWidget);
    expect(find.byType(OiSwitch), findsOneWidget);
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

  testWidgets('the switch toggles an equals-true predicate', (tester) async {
    await pumpBar(tester);

    final OiSwitch toggle = tester.widget(find.byType(OiSwitch));
    toggle.onChanged!(true);
    await tester.pumpAndSettle();

    final BeakFieldFilter filter = fieldOf(emitted.last);
    expect(filter.columnKey, 'active');
    expect(filter.value, const BeakBoolValue(true));
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
          filters: const [
            BeakSelectFilter(column: ArticleColumns.title, label: 'Broken'),
          ],
          onChanged: emitted.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('need an enum column'), findsOneWidget);
  });

  group('derived defaults', () {
    test('one control per filterable column, matched to its type', () {
      final filters = beakDefaultFiltersOf(const _FilterableModel());

      expect(filters.map((filter) => (filter.runtimeType, filter.column.key)), [
        (BeakTextFilter, 'name'),
        (BeakBoolFilter, 'active'),
        (BeakSelectFilter, 'status'),
        (BeakDateRangeFilter, 'published_at'),
      ]);
    });

    test('a filterable column with no fitting control is skipped', () {
      // A number has no range control yet; guessing one would be worse than
      // leaving it to the resource.
      expect(
        beakDefaultFiltersOf(const _FilterableModel()).map((f) => f.column.key),
        isNot(contains('stock')),
      );
    });

    test('declared filters win over the derived ones', () {
      const declared = BeakTextFilter(
        column: ArticleColumns.title,
        label: 'Headline',
      );
      const resource = BeakResource(
        model: _FilterableModel(),
        icon: BeakIconToken(OiIcons.table),
        filters: [declared],
      );

      expect(resource.effectiveFilters, [declared]);
      expect(
        resource.copyWith(filters: const []).effectiveFilters,
        hasLength(4),
      );
    });
  });
}

/// A model marking one column of each filterable shape, plus an int (which
/// has no control) to prove the skip.
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
