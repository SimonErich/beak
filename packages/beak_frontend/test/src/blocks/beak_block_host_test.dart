import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  Future<void> pumpBlock(WidgetTester tester, BeakBlock block) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(block: block),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('layout blocks', () {
    testWidgets('column stacks children onto OiColumn', (tester) async {
      await pumpBlock(
        tester,
        const BeakColumnBlock(
          children: [BeakTextBlock('first'), BeakTextBlock('second')],
        ),
      );

      expect(find.byType(OiColumn), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('row lays children onto OiRow', (tester) async {
      await pumpBlock(
        tester,
        const BeakRowBlock(
          children: [BeakTextBlock('left'), BeakTextBlock('right')],
        ),
      );

      expect(find.byType(OiRow), findsOneWidget);
      expect(find.text('left'), findsOneWidget);
    });

    testWidgets('grid honors per-child spans via OiSpan', (tester) async {
      await pumpBlock(
        tester,
        const BeakGridBlock(
          columns: 4,
          children: [
            BeakTextBlock('wide', span: BeakSpan(columns: 3)),
            BeakTextBlock('narrow'),
          ],
        ),
      );

      expect(find.byType(OiGrid), findsOneWidget);
      expect(find.byType(OiSpan), findsOneWidget);
      final span = tester.widget<OiSpan>(find.byType(OiSpan));
      expect(
        span.data.columnSpan?.resolve(
          OiBreakpoint.large,
          OiBreakpointScale.defaultScale,
        ),
        3,
      );
    });

    testWidgets('card renders header, body, and footer', (tester) async {
      await pumpBlock(
        tester,
        const BeakCardBlock(
          title: 'Revenue',
          subtitle: 'this month',
          footer: BeakTextBlock('footer note'),
          child: BeakTextBlock('42'),
        ),
      );

      expect(find.byType(OiCard), findsOneWidget);
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('this month'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('footer note'), findsOneWidget);
    });

    testWidgets('section shows heading and description', (tester) async {
      await pumpBlock(
        tester,
        const BeakSectionBlock(
          title: 'Settings',
          description: 'Tune the panel',
          child: BeakTextBlock('content'),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Tune the panel'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('masonry distributes children', (tester) async {
      await pumpBlock(
        tester,
        const BeakMasonryBlock(
          columns: 2,
          children: [BeakTextBlock('a'), BeakTextBlock('b')],
        ),
      );

      expect(find.byType(OiMasonry), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('three panes render onto OiThreeColumnLayout', (tester) async {
      await pumpBlock(
        tester,
        const BeakThreePaneBlock(
          label: 'Inbox',
          left: BeakTextBlock('folders'),
          middle: BeakTextBlock('messages'),
          right: BeakTextBlock('preview'),
        ),
      );

      expect(find.byType(OiThreeColumnLayout), findsOneWidget);
      expect(find.text('folders'), findsOneWidget);
      expect(find.text('messages'), findsOneWidget);
      expect(find.text('preview'), findsOneWidget);
    });
  });

  group('interactive blocks', () {
    testWidgets('tabs switch their content on selection', (tester) async {
      await pumpBlock(
        tester,
        const BeakTabsBlock(
          tabs: [
            BeakTabBlockItem(label: 'One', content: BeakTextBlock('first')),
            BeakTabBlockItem(label: 'Two', content: BeakTextBlock('second')),
          ],
        ),
      );

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('accordion renders its sections and toggles on tap', (
      tester,
    ) async {
      await pumpBlock(
        tester,
        const BeakAccordionBlock(
          items: [
            BeakAccordionBlockItem(
              title: 'Shipping',
              content: BeakTextBlock('3-5 days'),
              initiallyExpanded: true,
            ),
          ],
        ),
      );

      expect(find.byType(OiAccordion), findsOneWidget);
      expect(find.text('Shipping'), findsOneWidget);
      expect(find.text('3-5 days'), findsOneWidget);

      await tester.tap(find.text('Shipping'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('breadcrumb with a route navigates the router', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const BeakBlockHost(
              block: BeakBreadcrumbsBlock(
                items: [
                  BeakBreadcrumbBlockItem(label: 'Home', route: '/target'),
                  BeakBreadcrumbBlockItem(label: 'Here'),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/target',
            builder: (_, _) => const OiLabel.body('arrived'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        OiApp.router(routerConfig: router, theme: OiThemeData.light()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('arrived'), findsOneWidget);
    });
  });

  group('display leaves', () {
    testWidgets('every text variant renders its OiLabel', (tester) async {
      await pumpBlock(
        tester,
        BeakColumnBlock(
          children: [
            for (final variant in BeakTextVariant.values)
              BeakTextBlock('sample', variant: variant),
          ],
        ),
      );

      expect(find.text('sample'), findsNWidgets(BeakTextVariant.values.length));
    });

    testWidgets('image maps its url, alt, and size onto OiImage', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: const BeakBlockHost(
            block: BeakImageBlock(
              'https://example.com/pic.png',
              alt: 'A picture',
              widthInPixels: 100,
              heightInPixels: 80,
            ),
          ),
        ),
      );

      final image = tester.widget<OiImage>(find.byType(OiImage));
      expect(image.src, 'https://example.com/pic.png');
      expect(image.alt, 'A picture');
      expect(image.width, 100);
      expect(image.height, 80);

      // OiImage resolves a NetworkImage; the test binding answers the fake
      // request with a 400, so drain the expected load failure.
      await tester.pump();
      tester.takeException();
    });

    testWidgets('markdown, dividers, and spacers render', (tester) async {
      await pumpBlock(
        tester,
        const BeakColumnBlock(
          children: [
            BeakMarkdownBlock('# Heading\n\nBody copy.'),
            BeakDividerBlock(label: 'or'),
            BeakDividerBlock(),
            BeakSpacerBlock(heightInPixels: 32),
          ],
        ),
      );

      expect(find.byType(OiMarkdown), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
      expect(find.byType(OiDivider), findsNWidgets(2));
    });

    testWidgets('the widget escape hatch embeds a raw subtree', (tester) async {
      await pumpBlock(
        tester,
        BeakWidgetBlock((context) => const OiLabel.body('escaped')),
      );

      expect(find.text('escaped'), findsOneWidget);
    });
  });

  group('composition', () {
    testWidgets('a deep tree renders every level', (tester) async {
      await pumpBlock(
        tester,
        const BeakColumnBlock(
          children: [
            BeakTextBlock('Dashboard', variant: BeakTextVariant.h1),
            BeakGridBlock(
              columns: 2,
              children: [
                BeakCardBlock(
                  title: 'Left',
                  child: BeakColumnBlock(
                    children: [BeakTextBlock('nested'), BeakDividerBlock()],
                  ),
                ),
                BeakCardBlock(title: 'Right', child: BeakTextBlock('deep')),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('nested'), findsOneWidget);
      expect(find.text('deep'), findsOneWidget);
    });
  });
}
