import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  testWidgets('radio cards preserve typed selection and disabled choices', (
    tester,
  ) async {
    const status = BeakScalarField<ArticleStatus>(
      model: ArticleModel(),
      column: ArticleColumns.status,
    );
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        home: BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: FakeDataSource(),
          initialValues: BeakRecord.fromRow({'status': 'draft'}),
          layout: BeakFormLayout(
            children: [
              status.inputRadio(
                cards: true,
                options: (_) => const [
                  BeakInputOption(
                    ArticleStatus.draft,
                    'Keep draft',
                    enabled: false,
                  ),
                  BeakInputOption(
                    ArticleStatus.published,
                    'Publish online',
                    description: 'Available to readers',
                    icon: OiIcons.globe,
                  ),
                ],
              ),
            ],
          ),
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available to readers'), findsOneWidget);
    await tester.tap(find.text('Publish online'));
    await tester.pumpAndSettle();
    expect(session.root.read(status), ArticleStatus.published);
    await tester.tap(find.text('Keep draft'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(session.root.read(status), ArticleStatus.published);
    expect(tester.takeException(), isNull);
  });
  for (final width in [800.0, 360.0]) {
    testWidgets('metric strips use weighted responsive rows at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          home: BeakConfiguredForm(
            model: const ArticleModel(),
            dataSource: FakeDataSource(),
            layout: BeakFormLayout(
              children: [
                BeakFormMetrics(
                  minColumnWidth: 120,
                  metrics: [
                    for (var i = 0; i < 5; i++)
                      BeakFormMetric(
                        label: 'Metric $i',
                        value: (_) => i,
                        flex: i == 3 ? 2 : 1,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Metric 0'));
      final last = tester.getTopLeft(find.text('Metric 4'));
      if (width == 800) {
        expect(last.dy, first.dy);
        final x1 = tester.getTopLeft(find.text('Metric 1')).dx;
        final x2 = tester.getTopLeft(find.text('Metric 2')).dx;
        final x3 = tester.getTopLeft(find.text('Metric 3')).dx;
        expect(last.dx - x3, closeTo(2 * (x2 - x1), 1));
      } else {
        expect(last.dy, greaterThan(first.dy));
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final stored in [null, 'published', 'unrecognized']) {
    testWidgets('initial milestone preserves the stored state $stored', (
      tester,
    ) async {
      const status = BeakScalarField<ArticleStatus>(
        model: ArticleModel(),
        column: ArticleColumns.status,
      );
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          home: BeakConfiguredForm(
            model: const ArticleModel(),
            dataSource: FakeDataSource(
              models: const [ArticleModel()],
              records: {
                'articles': {
                  'a': BeakRecord.fromRow({'id': 'a', 'status': stored}),
                },
              },
            ),
            recordId: 'a',
            mode: BeakFormMode.read,
            layout: const BeakFormLayout(
              children: [
                BeakFormProgress(
                  field: status,
                  initialState: ArticleStatus.draft,
                  steps: [
                    BeakProgressStep(
                      state: ArticleStatus.draft,
                      label: 'Awaiting placement',
                    ),
                  ],
                ),
              ],
            ),
            onSession: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(session.root.snapshot['status']?.raw, stored);
      if (stored == null) {
        expect(find.text('Awaiting placement'), findsOneWidget);
        expect(tester.widget<OiStepper>(find.byType(OiStepper)).currentStep, 0);
      } else {
        expect(find.byType(OiStepper), findsNothing);
        expect(find.text('Awaiting placement'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'checkbox presentation keeps validation and typed boolean binding',
    (tester) async {
      const active = BeakScalarField<bool>(
        model: ArticleModel(),
        column: ArticleColumns.active,
      );
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          home: BeakConfiguredForm(
            model: const ArticleModel(),
            dataSource: FakeDataSource(),
            initialValues: BeakRecord.fromRow({
              'title': 'Consent',
              'active': false,
            }),
            layout: BeakFormLayout(
              children: [
                active.inputCheckbox(
                  label: 'Send confirmation',
                  description: 'The customer receives an email.',
                  validate: const [
                    BeakInList<bool>([true]),
                  ],
                ),
              ],
            ),
            onSession: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(await session.root.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Must be one of: true.'), findsOneWidget);
      expect(find.text('The customer receives an email.'), findsOneWidget);
      await tester.tap(find.byType(OiCheckbox));
      await tester.pumpAndSettle();
      expect(session.root.read(active), isTrue);
      expect(await session.root.validate(), isTrue);
    },
  );
  testWidgets(
    'milestones preserve typed state, formatted details and preceding events',
    (tester) async {
      const status = BeakScalarField<ArticleStatus>(
        model: ArticleModel(),
        column: ArticleColumns.status,
      );
      const published = BeakScalarField<DateTime>(
        model: ArticleModel(),
        column: ArticleColumns.publishedAt,
      );
      final progress = BeakFormProgress(
        field: status,
        timeline: true,
        contextSpacing: 8,
        steps: [
          const BeakProgressStep<ArticleStatus>(label: 'Created'),
          const BeakProgressStep(state: ArticleStatus.draft, label: 'Draft'),
          BeakProgressStep(
            state: ArticleStatus.published,
            label: 'Published',
            context: BeakRecordTemplate(
              title: BeakValueBinding<String>.computed(
                dependencies: const [],
                compute: (_) => 'Actor',
              ),
            ),
            details: BeakRecordTemplate(
              title: BeakValueBinding.field(
                published.formatted(BeakValueFormat.time),
              ),
            ),
          ),
        ],
      );
      final source = FakeDataSource(
        models: const [ArticleModel()],
        records: {
          'articles': {
            'a': BeakRecord.fromRow({
              'id': 'a',
              'status': 'published',
              'published_at': DateTime.utc(2026, 9, 28, 6, 12),
            }),
          },
        },
      );
      await tester.pumpWidget(
        OiApp(
          home: BeakFormattingScope(
            formatting: const BeakFormatting(timeZoneOffsetMinutes: 120),
            child: BeakConfiguredForm(
              model: const ArticleModel(),
              dataSource: source,
              recordId: 'a',
              mode: BeakFormMode.read,
              layout: BeakFormLayout(children: [progress]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('08:12'), findsOneWidget);
      final stepper = tester.widget<OiStepper>(find.byType(OiStepper));
      expect(stepper.currentStep, 2);
      expect(stepper.timeline, isTrue);
      expect(stepper.completedSteps, {0, 1});
      expect(
        tester.getTopLeft(find.text('Actor')).dy -
            tester.getBottomLeft(find.text('08:12')).dy,
        closeTo(8, .01),
      );
      expect(
        progress.dependencies.map((field) => field.qualifiedKey),
        contains(published.qualifiedKey),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
