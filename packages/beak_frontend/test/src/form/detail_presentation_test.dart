import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: ArticleModel(),
  column: ArticleColumns.title,
);
const _status = BeakScalarField<ArticleStatus>(
  model: ArticleModel(),
  column: ArticleColumns.status,
);
const _time = BeakScalarField<DateTime>(
  model: ArticleModel(),
  column: ArticleColumns.publishedAt,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(OiApp(theme: OiThemeData.light(), home: child));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'planned progress does not imply completion and loads contextual identity',
    (tester) async {
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: FakeDataSource(),
          initialValues: BeakRecord.fromRow({
            'status': 'published',
            'title': 'Approver',
          }),
          layout: BeakFormLayout(
            children: [
              BeakFormProgress(
                field: _status,
                planned: true,
                steps: [
                  BeakProgressStep(
                    label: 'Approval',
                    state: ArticleStatus.draft,
                    context: BeakRecordTemplate(
                      title: BeakValueBinding.field(_title),
                    ),
                  ),
                  const BeakProgressStep(
                    label: 'Delivery',
                    state: ArticleStatus.published,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final stepper = tester.widget<OiStepper>(find.byType(OiStepper));
      expect(stepper.currentStep, -1);
      expect(stepper.completedSteps, isEmpty);
      expect(find.text('Approver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapsed typed card retains supporting metadata and has a leading disclosure',
    (tester) async {
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: FakeDataSource(),
          initialValues: BeakRecord.fromRow({'title': 'Source details'}),
          layout: BeakFormLayout(
            children: [
              BeakCard(
                title: 'Support',
                collapseLeading: true,
                collapsible: true,
                initiallyExpanded: false,
                headerSubtitle: BeakValueBinding.field(_title),
                children: [BeakCalculated(value: (_) => 'Hidden body')],
              ),
            ],
          ),
        ),
      );
      final card = tester.widget<OiCard>(find.byType(OiCard));
      expect(card.collapseLeading, isTrue);
      expect(find.text('Source details'), findsOneWidget);
      expect(find.text('Hidden body').hitTestable(), findsNothing);
      final toggle = find.byWidgetPredicate(
        (widget) =>
            widget is OiTappable && widget.semanticLabel == 'Expand Support',
      );
      expect(
        tester.getTopLeft(toggle).dx,
        lessThan(tester.getTopLeft(find.text('Support')).dx),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Hidden body'), findsOneWidget);
    },
  );

  testWidgets(
    'placement counter and placeholder do not change model validation',
    (tester) async {
      late BeakFormSession session;
      await _pump(
        tester,
        BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: FakeDataSource(),
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _title.inputText(
                maxLines: 2,
                showCounter: false,
                placeholder: 'Write a note',
              ),
            ],
          ),
        ),
      );
      final input = tester.widget<OiTextInput>(find.byType(OiTextInput));
      expect(input.showCounter, isFalse);
      expect(input.placeholder, 'Write a note');
      expect(input.maxLength, 20);
      session.root.set(_title, 'A deliberately overlong title');
      expect(await session.validate(), isFalse);
      expect(session.validationIssueCount, greaterThan(0));
    },
  );

  testWidgets(
    'compact code tokens keep square geometry and accessible explanations',
    (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: BeakRecordTemplateView(
            record: BeakRecord.fromRow({'title': 'A'}),
            template: BeakRecordTemplate(
              title: BeakValueBinding.field(
                _title,
                badge: true,
                badgeToken: true,
                itemTone: (_, _) => BeakColor.warning,
                itemTooltip: (_, _) => 'Contains gluten',
              ),
            ),
          ),
        ),
      );
      final badge = tester.widget<OiBadge>(find.byType(OiBadge));
      expect(badge.compactToken, isTrue);
      expect(badge.color, OiBadgeColor.warning);
      expect(tester.getSize(find.byType(OiBadge)), const Size(20, 20));
      expect(
        tester.widget<OiTooltip>(find.byType(OiTooltip)).message,
        'Contains gluten',
      );
    },
  );

  testWidgets(
    'time-first activities fill columns vertically while retaining chronological order',
    (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 640,
            child: BeakRecordTimeline(
              entries: [
                for (var index = 0; index < 6; index++)
                  BeakRecord.fromRow({
                    'title': 'Event $index',
                    'published_at': DateTime.utc(2026, 9, 28, 8, index),
                  }),
              ],
              title: _title,
              time: _time,
              compact: true,
              inlineTime: true,
              columns: 2,
            ),
          ),
        ),
      );
      final newest = tester.getTopLeft(
        find.text('Event 5', findRichText: true),
      );
      final third = tester.getTopLeft(find.text('Event 3', findRichText: true));
      final fourth = tester.getTopLeft(
        find.text('Event 2', findRichText: true),
      );
      expect(third.dx, newest.dx);
      expect(third.dy, greaterThan(newest.dy));
      expect(fourth.dx, greaterThan(newest.dx));
      expect(fourth.dy, newest.dy);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('proportional asides allocate the post-padding post-gap width', (
    tester,
  ) async {
    const mainKey = Key('main');
    const asideKey = Key('aside');
    await _pump(
      tester,
      const OiPageLayout(
        padding: EdgeInsets.all(24),
        gap: 24,
        asideFraction: 1 / 3,
        aside: SizedBox(key: asideKey),
        child: SizedBox(key: mainKey),
      ),
    );
    expect(tester.getSize(find.byKey(asideKey)).width, 376);
    expect(tester.getSize(find.byKey(mainKey)).width, 752);
  });

  test('contextual date patterns preserve locale and timezone policy', () {
    const formatting = BeakFormatPolicy(
      locale: 'en_GB',
      timeZoneOffsetMinutes: 120,
    );
    expect(
      formatting.date(DateTime.utc(2026, 9, 30, 23), pattern: 'MMM yyyy'),
      'Oct 2026',
    );
    expect(
      formatting.calendarDate(
        const BeakDate(2026, 9, 30),
        pattern: 'EEE d MMM yyyy',
      ),
      'Wed 30 Sept 2026',
    );
  });
}
