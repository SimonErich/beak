import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'Alpha'}),
        },
      },
    )..aggregateHandler = (_) => 200;
    // --8<-- [start:standaloneBlock]
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
          BeakResource(
            model: ArticleModel(),
            icon: BeakIconToken(OiIcons.newspaper),
          ),
        ],
      ),
      dataSource: dataSource,
    );
    // --8<-- [end:standaloneBlock]
  });

  Future<void> pump(WidgetTester tester, BeakBlock block) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // --8<-- [start:standaloneBlockHost]
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(block: block),
      ),
    );
    // --8<-- [end:standaloneBlockHost]
    await tester.pumpAndSettle();
  }

  Finder icon(IconData data) => find.byWidgetPredicate(
    (widget) => widget is OiIcon && widget.icon == data,
  );

  const notes = BeakAggregateSpec.count(table: 'notes');

  testWidgets('shows the label, icon and number-formatted aggregate', (
    tester,
  ) async {
    dataSource.aggregateHandler = (_) => 12000;
    await pump(
      tester,
      const BeakMetricBlock(
        label: 'Notes',
        aggregate: notes,
        icon: OiIcons.file,
      ),
    );

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('12,000'), findsOneWidget);
    expect(icon(OiIcons.file), findsOneWidget);
    expect(dataSource.aggregateCalls, [notes]);
  });

  testWidgets('shows a loading state until the aggregate arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: const BeakBlockHost(
          block: BeakMetricBlock(label: 'Notes', aggregate: notes),
        ),
      ),
    );

    expect(find.text('Loading…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Loading…'), findsNothing);
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('formats currency through the panel display policy', (
    tester,
  ) async {
    dataSource.aggregateHandler = (_) => 1250.5;
    await pump(
      tester,
      const BeakMetricBlock(
        label: 'Revenue',
        aggregate: notes,
        format: BeakValueFormat.currency,
      ),
    );

    expect(find.text(r'$1,250.50'), findsOneWidget);
  });

  testWidgets('uses the surrounding formatting scope', (tester) async {
    const german = BeakFormatting(locale: 'de_DE', currency: 'EUR');
    dataSource.aggregateHandler = (_) => 1250.5;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: const BeakFormattingScope(
          formatting: german,
          child: BeakBlockHost(
            block: BeakMetricBlock(
              label: 'Revenue',
              aggregate: notes,
              format: BeakValueFormat.currency,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(german.currency(1250.5), startsWith('1.250,50'));
    expect(find.text(german.currency(1250.5)), findsOneWidget);
  });

  testWidgets('shows integral minor units as exact money', (tester) async {
    dataSource.aggregateHandler = (_) => 125050;
    await pump(
      tester,
      const BeakMetricBlock(
        label: 'Revenue',
        aggregate: notes,
        format: BeakValueFormat.currency,
        minorUnits: true,
      ),
    );

    expect(find.text(r'$1,250.50'), findsOneWidget);
  });

  testWidgets('scales fractional minor units such as an average', (
    tester,
  ) async {
    dataSource.aggregateHandler = (_) => 1234.5;
    await pump(
      tester,
      const BeakMetricBlock(
        label: 'Average order',
        aggregate: notes,
        format: BeakValueFormat.currency,
        minorUnits: true,
        scale: 1,
      ),
    );

    expect(find.text(r'$123.45'), findsOneWidget);
  });

  testWidgets('formats a fractional rate as a percentage', (tester) async {
    dataSource.aggregateHandler = (_) => 0.25;
    await pump(
      tester,
      const BeakMetricBlock(
        label: 'Conversion',
        aggregate: notes,
        format: BeakValueFormat.percent,
      ),
    );

    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('scales an integral minor-unit rate before the percentage', (
    tester,
  ) async {
    dataSource.aggregateHandler = (_) => 2500;
    await pump(
      tester,
      const BeakMetricBlock(
        label: 'Conversion',
        aggregate: notes,
        format: BeakValueFormat.percent,
        minorUnits: true,
        scale: 4,
        target: 10000,
      ),
    );

    expect(find.text('25%'), findsOneWidget);
    expect(find.text('25% / 100%'), findsOneWidget);
  });

  testWidgets('appends the unit to the value and the target', (tester) async {
    dataSource.aggregateHandler = (_) => 12000;
    await pump(
      tester,
      const BeakMetricBlock(
        label: 'Stock',
        aggregate: notes,
        unit: 'kg',
        target: 20000,
      ),
    );

    expect(find.text('12,000 kg'), findsOneWidget);
    expect(find.text('12,000 kg / 20,000 kg'), findsOneWidget);
  });

  test('accepts only number, currency and percent formats', () {
    for (final format in [
      BeakValueFormat.text,
      BeakValueFormat.date,
      BeakValueFormat.dateTime,
      BeakValueFormat.time,
    ]) {
      expect(
        () => BeakMetricBlock(label: 'Notes', aggregate: notes, format: format),
        throwsAssertionError,
        reason: '$format',
      );
    }
  });

  group('previous period', () {
    const prior = BeakAggregateSpec.count(table: 'notes', withTrashed: true);

    testWidgets('an increase shows a positive delta', (tester) async {
      dataSource.aggregateHandler = (spec) => spec == prior ? 160 : 200;
      await pump(
        tester,
        const BeakMetricBlock(
          label: 'Notes',
          aggregate: notes,
          previous: prior,
        ),
      );

      expect(dataSource.aggregateCalls, [notes, prior]);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('+25%'), findsOneWidget);
      expect(icon(OiIcons.trendingUp), findsOneWidget);
    });

    testWidgets('a decrease shows a negative delta', (tester) async {
      dataSource.aggregateHandler = (spec) => spec == prior ? 200 : 150;
      await pump(
        tester,
        const BeakMetricBlock(
          label: 'Notes',
          aggregate: notes,
          previous: prior,
        ),
      );

      expect(find.text('-25%'), findsOneWidget);
      expect(icon(OiIcons.trendingDown), findsOneWidget);
    });

    testWidgets('an unchanged value shows a neutral delta', (tester) async {
      await pump(
        tester,
        const BeakMetricBlock(
          label: 'Notes',
          aggregate: notes,
          previous: prior,
        ),
      );

      expect(find.text('0%'), findsOneWidget);
      expect(icon(OiIcons.trendingUp), findsNothing);
      expect(icon(OiIcons.trendingDown), findsNothing);
    });

    testWidgets('a zero prior period has no defined delta', (tester) async {
      dataSource.aggregateHandler = (spec) => spec == prior ? 0 : 200;
      await pump(
        tester,
        const BeakMetricBlock(
          label: 'Notes',
          aggregate: notes,
          previous: prior,
        ),
      );

      expect(find.text('200'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('without a prior period no delta is fetched or shown', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakMetricBlock(label: 'Notes', aggregate: notes),
      );

      expect(dataSource.aggregateCalls, [notes]);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('target', () {
    testWidgets('draws progress towards the target', (tester) async {
      dataSource.aggregateHandler = (_) => 150;
      await pump(
        tester,
        const BeakMetricBlock(label: 'Notes', aggregate: notes, target: 200),
      );

      final progress = tester.widget<OiProgress>(find.byType(OiProgress));
      expect(progress.value, 0.75);
      expect(progress.indeterminate, isFalse);
      expect(find.text('150 / 200'), findsOneWidget);
    });

    testWidgets('a reached target caps the progress at complete', (
      tester,
    ) async {
      dataSource.aggregateHandler = (_) => 5000;
      await pump(
        tester,
        const BeakMetricBlock(
          label: 'Revenue',
          aggregate: notes,
          format: BeakValueFormat.currency,
          minorUnits: true,
          target: 4000,
        ),
      );

      expect(tester.widget<OiProgress>(find.byType(OiProgress)).value, 1);
      expect(find.text(r'$50.00 / $40.00'), findsOneWidget);
    });

    testWidgets('a non-positive target draws no progress', (tester) async {
      await pump(
        tester,
        const BeakMetricBlock(label: 'Notes', aggregate: notes, target: 0),
      );

      expect(find.byType(OiProgress), findsNothing);
    });
  });

  testWidgets('a failed load offers a retry', (tester) async {
    dataSource.aggregateHandler = (_) =>
        throw const BeakAuthorizationException('Offline');
    await pump(tester, const BeakMetricBlock(label: 'Notes', aggregate: notes));

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    dataSource.aggregateHandler = (_) => 3;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a failed prior period fails the whole metric', (tester) async {
    const prior = BeakAggregateSpec.count(table: 'articles');
    dataSource.aggregateHandler = (spec) =>
        spec == prior ? throw const BeakAuthorizationException('Offline') : 200;
    await pump(
      tester,
      const BeakMetricBlock(label: 'Notes', aggregate: notes, previous: prior),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('200'), findsNothing);
  });

  testWidgets('a write to the aggregated table refreshes the value', (
    tester,
  ) async {
    await pump(tester, const BeakMetricBlock(label: 'Notes', aggregate: notes));
    expect(find.text('200'), findsOneWidget);

    dataSource.aggregateHandler = (_) => 201;
    await beakLocator<BeakDataSource>().create(
      'notes',
      BeakRecord.fromRow(const {'id': 'n2', 'title': 'Beta'}),
    );
    await tester.pumpAndSettle();

    expect(find.text('201'), findsOneWidget);
  });

  testWidgets('a write to the prior period table refreshes the delta', (
    tester,
  ) async {
    const prior = BeakAggregateSpec.count(table: 'articles');
    dataSource.aggregateHandler = (spec) => spec == prior ? 100 : 200;
    await pump(
      tester,
      const BeakMetricBlock(label: 'Notes', aggregate: notes, previous: prior),
    );
    expect(find.text('+100%'), findsOneWidget);

    dataSource.aggregateHandler = (spec) => spec == prior ? 400 : 200;
    await beakLocator<BeakDataSource>().create(
      'articles',
      BeakRecord.fromRow(const {'id': 'a9', 'title': 'Later'}),
    );
    await tester.pumpAndSettle();

    expect(find.text('-50%'), findsOneWidget);
  });

  testWidgets('an equal block rebuilt by its parent does not refetch', (
    tester,
  ) async {
    await pump(tester, const BeakMetricBlock(label: 'Notes', aggregate: notes));
    await pump(
      tester,
      BeakMetricBlock(label: 'Notes', aggregate: const NoteModel().count()),
    );

    expect(dataSource.aggregateCalls, [notes]);
  });
}
