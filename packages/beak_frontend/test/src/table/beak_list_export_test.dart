import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'title', label: 'Title', searchable: true),
);

void main() {
  testWidgets(
    'export delegates active query projection and formatting and downloads once',
    (tester) async {
      final requests = <Map<String, Object?>>[];
      final source = ModelBeakDataSource(
        registry: BeakModelRegistry()..register(const NoteModel()),
        fallback: HttpBeakDataSource(
          BeakClient(
            baseUrl: 'https://api.test',
            httpClient: MockClient((request) async {
              expect(request.url.path, '/api/notes/export');
              requests.add(jsonDecode(request.body) as Map<String, Object?>);
              return http.Response('Title\r\nExported\r\n', 200);
            }),
          ),
        ),
      );
      addTearDown(source.dispose);
      final controller = BeakQueryController(
        model: const NoteModel(),
        searchFields: const [_title],
      );
      addTearDown(controller.dispose);
      controller.setSearch('Exported');
      controller.applyFilters({'title': _title.eq('Exported')});
      controller.goToPage(3);
      final downloads = <(String, String)>[];
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakFormattingScope(
            formatting: const BeakFormatting(locale: 'de_DE', currency: 'EUR'),
            child: Center(
              child: BeakListExportButton(
                definition: const BeakListExport(
                  fields: [_title],
                  fileName: 'selected.csv',
                ),
                controller: controller,
                source: source,
                download: (contents, name) async =>
                    downloads.add((contents, name)),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single['columns'], ['title']);
      expect(BeakQuerySpec.fromJson(requests.single), controller.query);
      expect((requests.single['formatting'] as Map)['locale'], 'de_DE');
      expect(downloads, [('Title\r\nExported\r\n', 'selected.csv')]);
    },
  );

  testWidgets('denied exports do not download and can be retried', (
    tester,
  ) async {
    var calls = 0;
    var downloads = 0;
    final source = HttpBeakDataSource(
      BeakClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({'error': 'authorization', 'message': 'Denied'}),
            403,
          );
        }),
      ),
    );
    final controller = BeakQueryController(model: const NoteModel());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: Center(
          child: BeakListExportButton(
            definition: const BeakListExport(fields: [_title], raw: true),
            controller: controller,
            source: source,
            download: (_, _) async {
              downloads++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(downloads, 0);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  test(
    'typed currency projection carries minor unit metadata without changing storage',
    () {
      const id = BeakScalarField<int>(
        model: NoteModel(),
        column: BeakIntColumn(key: 'amount', label: 'Amount'),
      );
      final export = BeakListExport(fields: [id.currency(minorUnits: true)]);
      expect(
        export.formats['amount']?.toJson(),
        const BeakExportFormat(
          BeakValueFormat.currency,
          minorUnits: true,
        ).toJson(),
      );
      expect(
        BeakListExport(
          fields: [id.currency(minorUnits: true)],
          raw: true,
        ).formats,
        isEmpty,
      );
    },
  );

  testWidgets('a wrong export projection fails when the button builds', (
    tester,
  ) async {
    final source = FakeDataSource();
    final controller = BeakQueryController(model: const NoteModel());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakListExportButton(
          definition: const BeakListExport(fields: [_title, _title]),
          controller: controller,
          source: source,
        ),
      ),
    );

    expect(tester.takeException(), isA<BeakConfigurationException>());
  });

  test('invalid projections and unsupported sources fail explicitly', () async {
    expect(
      () => const BeakListExport(fields: []).columnsFor(const NoteModel()),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => const BeakListExport(
        fields: [_title, _title],
      ).columnsFor(const NoteModel()),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () =>
          const BeakListExport(fields: [_title]).columnsFor(const LabelModel()),
      throwsA(isA<BeakConfigurationException>()),
    );
    final source = ModelBeakDataSource(
      registry: BeakModelRegistry()..register(const NoteModel()),
      fallback: FakeDataSource(),
    );
    addTearDown(source.dispose);
    await expectLater(
      source.export(const BeakQuerySpec(table: 'notes')),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}
