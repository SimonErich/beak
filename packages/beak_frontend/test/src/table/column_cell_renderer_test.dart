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
    expect(find.textContaining('ghost'), findsOneWidget);
  });

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
}
