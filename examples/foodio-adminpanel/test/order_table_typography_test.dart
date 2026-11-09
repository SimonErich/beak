import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:beak_theme_gabel/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show Align, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/resources/orders/list/order_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Items heading fits and retains sorting in its narrow column', (
    tester,
  ) async {
    await loadGabelFonts();
    final column = orderList().definition!.columns.singleWhere(
      (column) => column.key == 'items',
    );
    expect(column.sortBy!.column.sortable, isTrue);
    final controller = OiTableController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      OiApp(
        theme: GabelTheme().light,
        home: OiTable<int>(
          label: 'Order items',
          controller: controller,
          rows: const [12],
          columns: [
            OiTableColumn(
              id: column.key,
              header: column.label,
              width: column.widthInPixels,
              minWidth: column.minWidthInPixels,
              textAlign: column.textAlign,
              cellPadding: column.cellPadding,
              valueGetter: (value) => '$value',
            ),
          ],
        ),
      ),
    );
    final heading = find.text('Items');
    expect(
      tester.renderObject<RenderParagraph>(heading).didExceedMaxLines,
      isFalse,
      reason: 'The narrow column must show the full heading before sorting.',
    );
    controller.sortBy('items');
    await tester.pump();
    expect(controller.sortColumnId, 'items');
    expect(controller.sortAscending, isTrue);
    expect(tester.widget<Text>(heading).data, 'Items');
    expect(tester.widget<Text>(heading).overflow, TextOverflow.ellipsis);
    final sortedBounds = tester.getRect(heading);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(heading));
    await tester.pump();
    expect(tester.getRect(heading), sortedBounds);
    await tester.tap(heading);
    await tester.pump();
    expect(controller.sortAscending, isFalse);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Items count uses the reference tabular numeric advance', (
    tester,
  ) async {
    await loadGabelFonts();
    final template = orderList().definition!.columns
        .singleWhere((column) => column.key == 'items')
        .template!;
    await tester.pumpWidget(
      OiApp(
        theme: GabelTheme().light,
        home: Align(
          child: BeakRecordTemplateView(
            template: template,
            record: BeakRecord.fromRow({'item_count': 12}),
          ),
        ),
      ),
    );
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: GabelTheme().light.textTheme.body.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final value = painter.width;
      painter.dispose();
      return value;
    }

    final count = tester.renderObject<RenderParagraph>(find.text('12'));
    expect(count.size.width, closeTo(width('12'), .001));
    expect(count.size.width, closeTo(width('88'), .001));
    expect(tester.takeException(), isNull);
  });
}
