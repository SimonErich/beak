import 'dart:ui' as ui;

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _capture = ValueKey('page-paint');

Future<Color> _paintedAt(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final local = boundary.globalToLocal(point);
  final index = (local.dy.floor() * image!.width + local.dx.floor()) * 4;
  final color = Color.fromARGB(
    bytes!.getUint8(index + 3),
    bytes.getUint8(index),
    bytes.getUint8(index + 1),
    bytes.getUint8(index + 2),
  );
  image.dispose();
  return color;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String route,
    List<BeakScreen> pages = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = FakeDataSource(
      models: const [NoteModel()],
      records: {
        'notes': {
          'n1': BeakRecord(
            values: const {
              'id': BeakStringValue('n1'),
              'title': BeakStringValue('First note'),
            },
            relations: {
              'labels': [
                BeakRecord.fromRow(const {'id': 'k1', 'name': 'Nice one'}),
              ],
            },
          ),
        },
      },
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: _capture,
        child: BeakPanel(
          dataSource: source,
          config: BeakPanelConfig(
            title: 'Surfaces',
            resources: const [
              BeakResource(model: NoteModel()),
              BeakResource(model: LabelModel()),
            ],
            pages: pages,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go(route);
    await tester.pumpAndSettle();
  }

  Future<void> expectSeparateSurfaces(WidgetTester tester) async {
    final cards = find.byType(OiCard).evaluate().toList();
    // Measure declared leaf cards even if a regression adds an outer one.
    final first = tester.getRect(find.byWidget(cards[cards.length - 2].widget));
    final second = tester.getRect(find.byWidget(cards.last.widget));
    final gap = Offset(
      first.left + first.width / 2,
      (first.bottom + second.top) / 2,
    );
    final background = tester
        .element(find.byType(OiAppShell))
        .colors
        .background;
    expect(
      await _paintedAt(tester, gap),
      background,
      reason: 'The page canvas must remain visible between declared cards.',
    );
    expect(
      await _paintedAt(tester, Offset(first.left + 8, first.top + 8)),
      isNot(background),
      reason: 'Declared cards must still paint their own distinct surface.',
    );
  }

  testWidgets('framed dashboards paint no extra surface behind their cards', (
    tester,
  ) async {
    await pump(
      tester,
      route: '/overview',
      pages: const [
        BeakScreen(
          path: '/overview',
          title: 'Overview',
          icon: BeakIconToken(OiIcons.layoutDashboard),
          body: BeakColumnBlock(
            gapInPixels: 32,
            children: [
              BeakCardBlock(child: BeakTextBlock('Revenue')),
              BeakCardBlock(child: BeakTextBlock('Orders')),
            ],
          ),
        ),
      ],
    );
    await expectSeparateSurfaces(tester);
  });

  testWidgets('generated detail cards share the page canvas with forms', (
    tester,
  ) async {
    await pump(tester, route: '/notes/n1');
    await expectSeparateSurfaces(tester);
  });
}
