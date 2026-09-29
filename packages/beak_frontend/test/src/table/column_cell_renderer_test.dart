import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

enum _Status { draft, published }

void main() {
  final fixedNow = DateTime.utc(2026, 7, 3, 12);

  Future<void> pumpCell(
    WidgetTester tester, {
    required BeakColumn column,
    required BeakRecord record,
    BeakRenderIntent? intentOverride,
    VoidCallback? onOpenRelation,
  }) => tester.pumpWidget(
    OiApp(
      theme: OiThemeData.light(),
      home: Builder(
        builder: (context) => renderBeakCell(
          context,
          column: column,
          record: record,
          intentOverride: intentOverride,
          onOpenRelation: onOpenRelation,
          now: () => fixedNow,
        ),
      ),
    ),
  );

  tearDown(BeakCustomRenderers.reset);

  testWidgets(
    'plain field labels share currency formatting and password masking',
    (tester) async {
      final price = const BeakScalarField<int>(
        model: _LabelModel(),
        column: _LabelModel.price,
      ).currency(minorUnits: true);
      const password = BeakScalarField<String>(
        model: _LabelModel(),
        column: _LabelModel.password,
      );
      final record = BeakRecord.fromRow({
        'price': 12345,
        'password': 'never-visible',
      });
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFormattingScope(
            formatting: const BeakFormatting(currency: 'EUR', locale: 'en_US'),
            child: Builder(
              builder: (context) => Column(
                children: [
                  Text(formatBeakField(context, field: price, record: record)),
                  Text(
                    formatBeakField(context, field: password, record: record),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('€123.45'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);
      expect(find.text('never-visible'), findsNothing);
    },
  );

  group('a display format on a money-semantic decimal', () {
    // The wire carries 123456 minor units of a scale-2 money column: 1234.56.
    final record = BeakRecord.fromRow({'amount': 123456});
    const money = BeakScalarField<BeakDecimal>(
      model: _LabelModel(),
      column: _LabelModel.amount,
    );
    const formatting = BeakFormatting(currency: 'EUR', locale: 'en_US');

    Future<void> pumpUnder(
      WidgetTester tester,
      Widget Function(BuildContext) build,
    ) => tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFormattingScope(
          formatting: formatting,
          child: Builder(builder: build),
        ),
      ),
    );

    testWidgets('formatBeakField decodes the units before formatting', (
      tester,
    ) async {
      late String text;
      await pumpUnder(tester, (context) {
        text = formatBeakField(
          context,
          field: money.formatted(BeakValueFormat.currency),
          record: record,
        );
        return const SizedBox.shrink();
      });

      expect(text, '£1,234.56');
    });

    testWidgets('renderBeakField decodes the units before formatting', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        (context) => renderBeakField(
          context,
          field: money.formatted(BeakValueFormat.currency, label: 'Due'),
          record: record,
        ),
      );

      expect(find.text('£1,234.56'), findsOneWidget);
      expect(find.textContaining('123,456'), findsNothing);
    });

    testWidgets('it agrees with the unformatted field', (tester) async {
      late String plain;
      late String formatted;
      await pumpUnder(tester, (context) {
        plain = formatBeakField(context, field: money, record: record);
        formatted = formatBeakField(
          context,
          field: money.formatted(BeakValueFormat.currency),
          record: record,
        );
        return const SizedBox.shrink();
      });

      expect(formatted, plain);
    });

    testWidgets('a number format shows the decimal, not the units', (
      tester,
    ) async {
      late String text;
      await pumpUnder(tester, (context) {
        text = formatBeakField(
          context,
          field: money.formatted(BeakValueFormat.number),
          record: record,
        );
        return const SizedBox.shrink();
      });

      expect(text, '1,234.56');
    });

    testWidgets('an empty amount shows the empty placeholder', (tester) async {
      late String text;
      await pumpUnder(tester, (context) {
        text = formatBeakField(
          context,
          field: money.formatted(BeakValueFormat.currency),
          record: BeakRecord.fromRow({'amount': null}),
        );
        return const SizedBox.shrink();
      });

      expect(text, '—');
    });
  });

  testWidgets('text and number intents render labels', (tester) async {
    await pumpCell(
      tester,
      column: const BeakStringColumn(key: 'name', label: 'Name'),
      record: BeakRecord.fromRow(const {'name': 'Laser'}),
    );
    expect(find.text('Laser'), findsOneWidget);

    await pumpCell(
      tester,
      column: const BeakIntColumn(key: 'stock', label: 'Stock'),
      record: BeakRecord.fromRow(const {'stock': 42}),
    );
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('currency formatting honors precision, prefix and suffix', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakDecimalColumn(
        key: 'price',
        label: 'Price',
        prefix: '€',
      ),
      record: BeakRecord.fromRow(const {'price': 12.5}),
    );
    expect(find.text('€12.50'), findsOneWidget);
  });

  testWidgets('prefix-less decimals honor precision in the number intent', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakDecimalColumn(
        key: 'rating',
        label: 'Rating',
        precision: 1,
      ),
      record: BeakRecord.fromRow(const {'rating': 4.666}),
    );
    expect(
      find.text('4.7'),
      findsOneWidget,
      reason: 'a unitless decimal formats at its precision, as CSV export does',
    );
  });

  testWidgets('enum badges use the configured BeakColor and label', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakEnumColumn<_Status>(
        key: 'status',
        label: 'Status',
        values: _Status.values,
        badgeColors: {_Status.published: BeakColor.success},
      ),
      record: BeakRecord.fromRow(const {'status': 'published'}),
    );
    expect(find.byType(OiBadge), findsOneWidget);
    expect(find.text('published'), findsOneWidget);
  });

  test('every BeakColor maps onto an obers badge color', () {
    expect(oiBadgeColorFor(BeakColor.primary), OiBadgeColor.primary);
    expect(oiBadgeColorFor(BeakColor.secondary), OiBadgeColor.accent);
    expect(oiBadgeColorFor(BeakColor.success), OiBadgeColor.success);
    expect(oiBadgeColorFor(BeakColor.warning), OiBadgeColor.warning);
    expect(oiBadgeColorFor(BeakColor.error), OiBadgeColor.error);
    expect(oiBadgeColorFor(BeakColor.info), OiBadgeColor.info);
    expect(oiBadgeColorFor(BeakColor.muted), OiBadgeColor.neutral);
  });

  testWidgets('booleans render the configured state labels', (tester) async {
    const column = BeakBoolColumn(
      key: 'active',
      label: 'Active',
      trueLabel: 'On sale',
    );
    await pumpCell(
      tester,
      column: column,
      record: BeakRecord.fromRow(const {'active': true}),
    );
    expect(find.text('On sale'), findsOneWidget);

    await pumpCell(
      tester,
      column: column,
      record: BeakRecord.fromRow(const {'active': false}),
    );
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('dates format per the column format', (tester) async {
    final instant = DateTime.utc(2026, 7, 1, 8, 5);
    await pumpCell(
      tester,
      column: const BeakDateTimeColumn(key: 'created_at', label: 'Created'),
      record: BeakRecord.fromRow({'created_at': instant}),
    );
    expect(find.text('2026-07-01 08:05'), findsOneWidget);
  });

  testWidgets('relative dates humanize against the injected clock', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakDateTimeColumn(
        key: 'created_at',
        label: 'Created',
      ).withFormat(BeakDateFormat.relative),
      record: BeakRecord.fromRow({
        'created_at': fixedNow.subtract(const Duration(hours: 3)),
      }),
    );
    expect(find.text('3h ago'), findsOneWidget);
  });

  testWidgets('thumbnails render an OiImage from the stored URL', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakImageColumn(
        key: 'avatar',
        label: 'Avatar',
        storagePath: 'avatars',
      ),
      record: BeakRecord.fromRow(const {'avatar': 'assets/missing.png'}),
    );
    expect(find.byType(OiImage), findsOneWidget);
  });

  testWidgets('relation links are tappable', (tester) async {
    var opened = 0;
    await pumpCell(
      tester,
      column: const BeakStringColumn(key: 'category', label: 'Category'),
      record: BeakRecord.fromRow(const {'category': 'Toys'}),
      intentOverride: BeakRenderIntent.relationLink,
      onOpenRelation: () => opened += 1,
    );

    await tester.tap(find.text('Toys'));
    expect(opened, 1);
  });

  testWidgets('relation badges render one badge per related label', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakStringColumn(key: 'tags', label: 'Tags'),
      record: BeakRecord.fromRow(const {
        'tags': ['hot', 'new'],
      }),
      intentOverride: BeakRenderIntent.relationBadges,
    );
    expect(find.byType(OiBadge), findsNWidgets(2));
    expect(find.text('hot'), findsOneWidget);
    expect(find.text('new'), findsOneWidget);
  });

  testWidgets('color columns render a swatch plus the hex code', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakColorColumn(key: 'tint', label: 'Tint'),
      record: BeakRecord.fromRow(const {'tint': '#663399'}),
    );
    expect(find.text('#663399'), findsOneWidget);
  });

  // --8<-- [start:customCellTests]
  testWidgets('custom cells delegate to the registered builder', (
    tester,
  ) async {
    const tag = BeakColumnTag('sparkline');
    BeakCustomRenderers.register(
      tag,
      (context, column, record) => const OiLabel.body('custom!'),
    );
    await pumpCell(
      tester,
      column: const BeakCustomColumn(key: 'trend', label: 'Trend', tag: tag),
      record: BeakRecord.fromRow(const {'trend': 7}),
    );
    expect(find.text('custom!'), findsOneWidget);
  });

  testWidgets('an unregistered custom tag renders a visible placeholder', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakCustomColumn(
        key: 'trend',
        label: 'Trend',
        tag: BeakColumnTag('ghost'),
      ),
      record: BeakRecord.fromRow(const {'trend': 7}),
    );
    expect(find.text('Unavailable'), findsOneWidget);
  });
  // --8<-- [end:customCellTests]

  testWidgets(
    'custom cells can render eager relations without a scalar value',
    (tester) async {
      const tag = BeakColumnTag('related-labels');
      BeakCustomRenderers.register(
        tag,
        (context, column, record) => OiLabel.body(
          record.relations[column.key]!.single['name']!.raw.toString(),
        ),
      );
      await pumpCell(
        tester,
        column: const BeakCustomColumn(key: 'roles', label: 'Roles', tag: tag),
        record: BeakRecord(
          values: const {},
          relations: {
            'roles': [
              BeakRecord.fromRow(const {'name': 'Administrator'}),
            ],
          },
        ),
      );
      expect(find.text('Administrator'), findsOneWidget);
    },
  );

  testWidgets('null values render an em dash', (tester) async {
    await pumpCell(
      tester,
      column: const BeakStringColumn(key: 'name', label: 'Name'),
      record: BeakRecord.fromRow(const {'name': null}),
    );
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('no Material widgets appear in any rendered cell', (
    tester,
  ) async {
    await pumpCell(
      tester,
      column: const BeakStringColumn(key: 'name', label: 'Name'),
      record: BeakRecord.fromRow(const {'name': 'Laser'}),
    );
    final offenders = tester.allWidgets.where(
      (widget) => const {
        'Material',
        'Scaffold',
        'Chip',
        'Card',
      }.contains(widget.runtimeType.toString()),
    );
    expect(offenders, isEmpty);
  });

  group('beakCellText', () {
    test('formats Postgres string numerics with currency precision', () {
      const column = BeakDecimalColumn(
        key: 'total',
        label: 'Total',
        prefix: r'$',
      );
      // Postgres numerics arrive over the wire as JSON strings.
      expect(beakCellText(column, '233.0'), r'$233.00');
      expect(beakCellText(column, '16.7'), r'$16.70');
      expect(beakCellText(column, 233.0), r'$233.00');
      expect(beakCellText(column, null), '—');
    });

    test('formats DateTime and ISO-string dates without toString noise', () {
      const column = BeakDateTimeColumn(key: 'due', label: 'Due');
      expect(
        beakCellText(column, DateTime(2026, 6, 9, 21)),
        '2026-06-09 21:00',
      );
      expect(
        beakCellText(column, '2026-06-09T21:00:00.000Z'),
        '2026-06-09 21:00',
      );
    });
  });
}

final class _LabelModel extends BeakModel {
  const _LabelModel();
  static const price = BeakIntColumn(key: 'price', label: 'Price');
  static const amount = BeakIntColumn(
    key: 'amount',
    label: 'Amount',
    semantic: BeakSemantic.money(currency: 'GBP'),
  );
  static const password = BeakStringColumn(
    key: 'password',
    label: 'Password',
    semantic: BeakSemantic.password(),
  );
  @override
  String get table => 'labels';
  @override
  String get displayColumnKey => 'price';
  @override
  List<BeakColumn> get columns => const [price, amount, password];
}
