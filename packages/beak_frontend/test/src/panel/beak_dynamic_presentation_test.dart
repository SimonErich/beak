import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import '../../support/panel_fixtures.dart';

void main() {
  const field = BeakScalarField<String>(
    model: NoteModel(),
    column: BeakStringColumn(key: 'title', label: 'Title'),
  );
  testWidgets('record state chooses one decorative marker and a named badge', (
    tester,
  ) async {
    final template = BeakRecordTemplate(
      title: BeakValueBinding<String>.computed(
        dependencies: [field],
        compute: (row) => row.read(field),
        badge: true,
        badgeDot: true,
        badgeDotFor: (row) => row.read(field) != 'Failed',
        iconFor: (row) =>
            row.read(field) == 'Failed' ? OiIcons.circleAlert : null,
      ),
    );
    for (final state in ['Ready', 'Failed']) {
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakRecordTemplateView(
            template: template,
            record: BeakRecord.fromRow({'title': state}),
          ),
        ),
      );
      final badge = tester.widget<OiBadge>(find.byType(OiBadge));
      expect(badge.label, state);
      expect(badge.showDot, state == 'Ready');
      expect(badge.icon, state == 'Failed' ? OiIcons.circleAlert : null);
    }
  });

  testWidgets(
    'conditional text tone inherits ink and explicit font weight survives',
    (tester) async {
      final theme = OiThemeData.light();
      final template = BeakRecordTemplate(
        title: BeakValueBinding<String>.computed(
          dependencies: [field],
          compute: (row) => row.read(field),
          tone: (row) =>
              row.read(field) == 'Unavailable' ? BeakColor.muted : null,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      );
      for (final state in ['Ready', 'Unavailable']) {
        await tester.pumpWidget(
          OiApp(
            theme: theme,
            home: BeakRecordTemplateView(
              template: template,
              record: BeakRecord.fromRow({'title': state}),
            ),
          ),
        );
        final text = tester.widget<Text>(find.text(state));
        expect(text.style!.fontWeight, FontWeight.w500);
        expect(
          text.style!.color,
          state == 'Unavailable' ? theme.colors.textMuted : theme.colors.text,
        );
      }
    },
  );
  testWidgets('identity tone dependencies load and override the palette', (
    tester,
  ) async {
    const neutral = BeakAvatarTone(
      background: Color(0xFFeeeeee),
      foreground: Color(0xFF222222),
    );
    const company = BeakAvatarTone(
      background: Color(0xFFddeeff),
      foreground: Color(0xFF224466),
    );
    final template = BeakRecordTemplate(
      title: BeakValueBinding<String>.computed(
        dependencies: const [],
        compute: (_) => 'Customer',
      ),
      avatar: true,
      avatarPalette: const [neutral],
      avatarTone: BeakValueBinding<BeakAvatarTone>.computed(
        dependencies: [field],
        compute: (row) => row.read(field) == 'Company' ? company : null,
      ),
    );
    expect(template.fields, contains(field));
    for (final value in ['Company', 'Private']) {
      await tester.pumpWidget(
        OiApp(
          home: BeakRecordTemplateView(
            template: template,
            record: BeakRecord.fromRow({'title': value}),
          ),
        ),
      );
      final avatar = tester.widget<OiAvatar>(find.byType(OiAvatar));
      expect(
        avatar.backgroundColor,
        value == 'Company' ? company.background : neutral.background,
      );
      expect(
        avatar.foregroundColor,
        value == 'Company' ? company.foreground : neutral.foreground,
      );
    }
  });
}
