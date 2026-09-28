import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  testWidgets(
    'mixed typed display callbacks remain typed inside their bindings',
    (tester) async {
      await tester.pumpWidget(
        OiApp(
          home: BeakRecordTemplateView(
            record: BeakRecord.fromRow({}),
            template: BeakRecordTemplate(
              title: BeakValueBinding<String>.computed(
                dependencies: const [],
                compute: (_) => 'Customer',
                display: (value, _) => value!.toUpperCase(),
              ),
              titleMetadata: [
                BeakValueBinding<DateTime>.computed(
                  dependencies: const [],
                  compute: (_) => DateTime.utc(2026, 9, 29),
                  display: (value, format) =>
                      format.date(value!, pattern: 'EEE d MMM'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('CUSTOMER'), findsOneWidget);
      expect(find.text('Tue 29 Sep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final subtitleVariant in [null, OiLabelVariant.body]) {
    testWidgets(
      'identity metadata uses contextual $subtitleVariant typography',
      (tester) async {
        final theme = OiThemeData.light();
        await tester.pumpWidget(
          OiApp(
            theme: theme,
            home: BeakRecordTemplateView(
              record: BeakRecord.fromRow({}),
              subtitleVariant: subtitleVariant,
              template: BeakRecordTemplate(
                title: const BeakValueBinding<String>.computed(
                  dependencies: [],
                  compute: _identity,
                ),
                inlineSubtitle: true,
                subtitle: [
                  BeakValueBinding<String>.computed(
                    dependencies: const [],
                    compute: (_) => 'First metadata',
                  ),
                  BeakValueBinding<String>.computed(
                    dependencies: const [],
                    compute: (_) => 'Second metadata',
                  ),
                ],
              ),
            ),
          ),
        );
        final expected = subtitleVariant == null
            ? theme.textTheme.caption.fontSize
            : theme.textTheme.body.fontSize;
        for (final text in ['First metadata', 'Second metadata', '·']) {
          expect(
            tester.widget<Text>(find.text(text)).style!.fontSize,
            expected,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('status markers and icons stay inside labelled badges', (
    tester,
  ) async {
    final template = BeakRecordTemplate(
      title: const BeakValueBinding<String>.computed(
        dependencies: [],
        compute: _identity,
      ),
      badges: [
        BeakValueBinding<String>.computed(
          dependencies: const [],
          compute: (_) => 'In kitchen',
          badge: true,
          badgeDot: true,
          color: BeakColor.info,
        ),
        BeakValueBinding<String>.computed(
          dependencies: const [],
          compute: (_) => 'Payment failed',
          badge: true,
          icon: OiIcons.circleAlert,
          color: BeakColor.error,
        ),
      ],
    );
    await tester.pumpWidget(
      OiApp(
        home: Center(
          child: BeakRecordTemplateView(
            template: template,
            record: BeakRecord.fromRow({}),
          ),
        ),
      ),
    );
    final badges = tester.widgetList<OiBadge>(find.byType(OiBadge)).toList();
    expect(badges.first.showDot, isTrue);
    expect(badges.first.color, OiBadgeColor.info);
    expect(badges.last.icon, OiIcons.circleAlert);
    expect(badges.last.color, OiBadgeColor.error);
    expect(find.byIcon(OiIcons.circleAlert), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byIcon(OiIcons.circleAlert),
        matching: find.byType(OiBadge),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('In kitchen'), findsOneWidget);
    expect(find.bySemanticsLabel('Payment failed'), findsOneWidget);
  });

  testWidgets('inline metadata omits empty values and badge separators', (
    tester,
  ) async {
    final template = BeakRecordTemplate(
      title: const BeakValueBinding<String>.computed(
        dependencies: [],
        compute: _identity,
      ),
      inlineSubtitle: true,
      subtitle: [
        BeakValueBinding<List<String>>.computed(
          dependencies: const [],
          compute: (_) => [],
          badge: true,
        ),
        BeakValueBinding<String>.computed(
          dependencies: const [],
          compute: (_) => 'Soup',
        ),
        BeakValueBinding<String>.computed(
          dependencies: const [],
          compute: (_) => '',
        ),
        BeakValueBinding<List<String>>.computed(
          dependencies: const [],
          compute: (_) => ['G', 'L'],
          badge: true,
        ),
      ],
    );
    await tester.pumpWidget(
      OiApp(
        home: Center(
          child: BeakRecordTemplateView(
            template: template,
            record: BeakRecord.fromRow({}),
          ),
        ),
      ),
    );
    expect(find.text('Soup'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Soup')).style?.fontSize,
      OiThemeData.light().textTheme.caption.fontSize,
    );
    expect(find.text('·'), findsNothing);
    expect(find.byType(OiBadge), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'list badges and template regions render without duplicate identity',
    (tester) async {
      final template = BeakRecordTemplate(
        title: const BeakValueBinding<String>.computed(
          dependencies: [],
          compute: _identity,
        ),
        badges: [
          BeakValueBinding<List<String>>.computed(
            dependencies: const [],
            compute: (_) => ['G', 'L'],
            badge: true,
          ),
        ],
        details: [
          BeakValueBinding<String>.computed(
            dependencies: const [],
            compute: (_) => 'Reception, 3rd floor',
          ),
        ],
      );
      await tester.pumpWidget(
        OiApp(
          home: Center(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeakRecordTemplateView(
                    template: template,
                    record: BeakRecord.fromRow({}),
                    part: BeakRecordTemplatePart.identity,
                  ),
                  BeakRecordTemplateView(
                    template: template,
                    record: BeakRecord.fromRow({}),
                    part: BeakRecordTemplatePart.details,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Reception, 3rd floor'), findsOneWidget);
      expect(
        tester
            .widgetList<OiBadge>(find.byType(OiBadge))
            .map((badge) => badge.label),
        ['G', 'L'],
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('identity icons follow the declared record dependency', (
    tester,
  ) async {
    const category = BeakScalarField<String>(
      model: NoteModel(),
      column: BeakStringColumn(key: 'category', label: 'Category'),
    );
    final template = BeakRecordTemplate(
      title: BeakValueBinding.field(category),
      avatar: true,
      icon: BeakValueBinding<IconData>.computed(
        dependencies: [category],
        compute: (row) =>
            row.read(category) == 'Soup' ? OiIcons.soup : OiIcons.salad,
      ),
    );
    Future<void> show(String value) => tester.pumpWidget(
      OiApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: BeakRecordTemplateView(
              template: template,
              record: BeakRecord.fromRow({'category': value}),
            ),
          ),
        ),
      ),
    );
    await show('Soup');
    expect(find.byType(OiAvatar), findsNothing);
    expect(tester.widget<OiIcon>(find.byType(OiIcon)).icon, OiIcons.soup);
    await show('Salad');
    expect(tester.widget<OiIcon>(find.byType(OiIcon)).icon, OiIcons.salad);
    expect(template.fields, contains(category));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'composite identity preserves currency units and stable avatar colors',
    (tester) async {
      const name = BeakScalarField<String>(
        model: NoteModel(),
        column: BeakStringColumn(key: 'title', label: 'Title'),
      );
      const cents = BeakScalarField<int>(
        model: NoteModel(),
        column: BeakIntColumn(key: 'cents', label: 'Amount'),
      );
      const colors = [
        BeakAvatarTone(
          background: Color(0xffeeeeff),
          foreground: Color(0xff333366),
        ),
      ];
      final template = BeakRecordTemplate(
        title: BeakValueBinding.field(name, strong: true),
        subtitle: [BeakValueBinding.field(cents.currency(minorUnits: true))],
        badges: [
          BeakValueBinding<String>.computed(
            dependencies: [cents],
            compute: (row) => (row.read(cents) ?? 0) > 3000
                ? 'Approval needed'
                : 'Within budget',
            badge: true,
            tone: (_) => BeakColor.warning,
          ),
        ],
        avatar: true,
        avatarPalette: colors,
        details: [
          BeakValueBinding.field(
            cents.currency(minorUnits: true),
            icon: OiIcons.wallet,
          ),
          BeakValueBinding<String>.computed(
            dependencies: [cents],
            visibleIf: (row) => row.read(cents) == 0,
            compute: (_) => 'Hidden when funded',
          ),
        ],
        footnote: BeakValueBinding<String>.computed(
          dependencies: [name],
          compute: (row) =>
              'Orders over €40.00 need approval by Katharina Ebner for ${row.read(name)}',
          icon: OiIcons.info,
          maxLines: null,
        ),
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFormattingScope(
            formatting: const BeakFormatting(locale: 'en_IE', currency: 'EUR'),
            child: Center(
              child: SizedBox(
                width: 300,
                child: BeakRecordTemplateView(
                  template: template,
                  record: BeakRecord.fromRow({
                    'id': 'a',
                    'title': 'Lena Hofer',
                    'cents': 3140,
                  }),
                  inlineSubtitle: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lena Hofer'), findsOneWidget);
      expect(find.text('€31.40'), findsNWidgets(2));
      expect(find.text('Hidden when funded'), findsNothing);
      final note = find.text(
        'Orders over €40.00 need approval by Katharina Ebner for Lena Hofer',
      );
      expect(note, findsOneWidget);
      expect(
        tester.getSize(note).height,
        greaterThan(25),
        reason:
            'An unbounded footnote wraps instead of losing approval details',
      );
      expect(find.byType(OiIcon), findsNWidgets(2));
      final avatar = tester.widget<OiAvatar>(find.byType(OiAvatar));
      expect(avatar.initials, 'LH');
      expect(
        tester.widget<OiBadge>(find.byType(OiBadge)).color,
        OiBadgeColor.warning,
      );
      expect(find.text('Approval needed'), findsOneWidget);
      expect(avatar.backgroundColor, colors.single.background);
      expect(avatar.foregroundColor, colors.single.foreground);
      expect(
        template.fields,
        containsAll([name, isA<BeakFormattedField<int>>()]),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

String _identity(BeakDraftReader _) => 'Lunch';
