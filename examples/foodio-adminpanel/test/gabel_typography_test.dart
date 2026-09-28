import 'dart:ui' as ui;

import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Align, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/resources/orders/list/order_list_screen.dart';
import 'package:foodio_adminpanel/theme/gabel_theme.dart';

void main() {
  test(
    'native hundred weights rasterize exactly as their variable font axes',
    () async {
      await (FontLoader(
        'Mona Sans',
      )..addFont(rootBundle.load('assets/fonts/MonaSans.ttf'))).load();
      final body = gabelTheme().textTheme.body;
      Future<List<int>> raster(TextStyle style) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final painter = TextPainter(
          text: TextSpan(
            text: 'Beetroot risotto · Tobias Wagner',
            style: style,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, const Offset(0, 0));
        painter.dispose();
        final picture = recorder.endRecording();
        final image = await picture.toImage(350, 40);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final result = bytes.toList();
        image.dispose();
        picture.dispose();
        return result;
      }

      List<int>? previous;
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ]) {
        final native = await raster(body.copyWith(fontWeight: weight));
        final axis = await raster(
          body.copyWith(
            fontWeight: weight,
            fontVariations: [
              FontVariation('wght', weight.value.toDouble()),
              const FontVariation('wdth', 100),
            ],
          ),
        );
        expect(
          native,
          orderedEquals(axis),
          reason:
              'Native${weight.value} must use identical glyph pixels to explicit wght${weight.value}.',
        );
        if (previous != null) {
          expect(
            native,
            isNot(orderedEquals(previous)),
            reason: 'The next weight must not fall back to the previous face.',
          );
        }
        previous = native;
      }
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Items heading fits and retains sorting in its narrow column', (
    tester,
  ) async {
    await (FontLoader(
      'Mona Sans',
    )..addFont(rootBundle.load('assets/fonts/MonaSans.ttf'))).load();
    final column = orderList().definition!.columns.singleWhere(
      (column) => column.key == 'items',
    );
    expect(column.sortBy!.column.sortable, isTrue);
    final controller = OiTableController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      OiApp(
        theme: gabelTheme(),
        home: OiTable<int>(
          label: 'Order items',
          controller: controller,
          rows: const [12],
          columns: [
            OiTableColumn(
              id: column.key,
              header: column.label,
              width: column.width,
              minWidth: column.minWidth,
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
    await (FontLoader(
      'Mona Sans',
    )..addFont(rootBundle.load('assets/fonts/MonaSans.ttf'))).load();
    final template = orderList().definition!.columns
        .singleWhere((column) => column.key == 'items')
        .template!;
    await tester.pumpWidget(
      OiApp(
        theme: gabelTheme(),
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
          style: gabelTheme().textTheme.body.copyWith(
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

  test('semantic emphasis changes the rendered variable font weight', () async {
    await (FontLoader(
      'Mona Sans',
    )..addFont(rootBundle.load('assets/fonts/MonaSans.ttf'))).load();
    final body = gabelTheme().textTheme.body;
    double width(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Orders that need attention', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    expect(
      width(body.copyWith(fontWeight: FontWeight.w700)),
      greaterThan(width(body)),
      reason: 'A stale wght axis must not defeat component emphasis.',
    );
    expect(
      gabelTheme().textTheme.h1.fontVariations,
      contains(const FontVariation('wght', 560)),
      reason:
          'Fractional display weights still need an explicit variable axis.',
    );
  });
  test('midweight labels use the same glyphs as the variable 500 axis', () async {
    await (FontLoader(
      'Mona Sans',
    )..addFont(rootBundle.load('assets/fonts/MonaSans.ttf'))).load();
    final body = gabelTheme().textTheme.body;
    double width(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Tobias Wagner', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final regular = width(body.copyWith(fontWeight: FontWeight.w400));
    final medium = width(body.copyWith(fontWeight: FontWeight.w500));
    final explicit = width(
      body.copyWith(
        fontWeight: FontWeight.w500,
        fontVariations: const [
          FontVariation('wght', 500),
          FontVariation('wdth', 100),
        ],
      ),
    );
    expect(
      medium,
      closeTo(explicit, .01),
      reason:
          'Native medium weight must interpolate the 500 variable font axis (regular=$regular, medium=$medium, explicit=$explicit).',
    );
    expect(medium, greaterThan(regular));
  });
}
