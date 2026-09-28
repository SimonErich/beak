import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  testWidgets(
    'compact timeline keeps newest-first order and collapses columns',
    (tester) async {
      const title = BeakScalarField<String>(
        model: NoteModel(),
        column: BeakStringColumn(key: 'title', label: 'Title'),
      );
      const time = BeakScalarField<DateTime>(
        model: NoteModel(),
        column: BeakDateTimeColumn(key: 'at', label: 'Time'),
      );
      final entries = [
        BeakRecord.fromRow({
          'title': 'Earlier',
          'at': DateTime.utc(2026, 9, 27, 10),
        }),
        BeakRecord.fromRow({
          'title': 'Latest',
          'at': DateTime.utc(2026, 9, 27, 11),
        }),
        BeakRecord.fromRow({'title': 'No timestamp'}),
      ];
      Future<void> pump(double width) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            home: BeakRecordTimeline(
              entries: entries,
              title: title,
              time: time,
              compact: true,
              columns: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(800);
      expect(find.byType(OiTimeline), findsNothing);
      expect(
        tester.getTopLeft(find.text('Latest')).dy,
        tester.getTopLeft(find.text('Earlier')).dy,
      );
      expect(
        tester.getTopLeft(find.text('Latest')).dx,
        lessThan(tester.getTopLeft(find.text('Earlier')).dx),
      );
      await pump(390);
      expect(
        tester.getTopLeft(find.text('Latest')).dy,
        lessThan(tester.getTopLeft(find.text('Earlier')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Earlier')).dy,
        lessThan(tester.getTopLeft(find.text('No timestamp')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
