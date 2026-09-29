import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'}),
        },
        'categories': {
          'c1': BeakRecord.fromRow(const {'id': 'c1', 'name': 'News'}),
        },
        'articles': {
          'a1': BeakRecord.fromRow(const {'id': 'a1', 'title': 'Article'}),
        },
      },
    );
  });

  Future<void> pumpForm(
    WidgetTester tester,
    Widget form, {
    Size surface = const Size(1200, 2400),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(OiApp(theme: OiThemeData.light(), home: form));
    await tester.pumpAndSettle();
  }

  group('create mode', () {
    testWidgets('unmounting during a save ignores the late response', (
      tester,
    ) async {
      final source = _DeferredWrite();
      var saved = false;
      await pumpForm(
        tester,
        BeakConfiguredForm(
          model: const NoteFormModel(),
          dataSource: source,
          onSaved: (_) => saved = true,
        ),
      );
      await tester.enterText(find.byType(EditableText).first, 'Pending');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      source.pending.complete(
        BeakRecord.fromRow(const {'id': 'n1', 'title': 'Saved'}),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(saved, isFalse);
    });

    testWidgets('renders the matching OiAf* widget per column type', (
      tester,
    ) async {
      await pumpForm(
        tester,
        BeakConfiguredForm(model: const ArticleModel(), dataSource: dataSource),
      );

      expect(find.byType(OiAfTextInput<Enum>), findsWidgets);
      expect(find.byType(OiAfNumberInput<Enum>), findsNWidgets(2));
      expect(find.byType(OiAfSwitch<Enum>), findsOneWidget);
      expect(find.byType(OiAfSelect<Enum, Enum>), findsOneWidget);
      expect(find.byType(OiDateTimeInput), findsOneWidget);
      expect(find.byType(OiAfColorInput<Enum>), findsOneWidget);
      expect(find.byType(OiAfRichEditor<Enum>), findsOneWidget);
      expect(find.byType(BeakUploadField), findsNWidgets(2));
      expect(find.byType(BeakConfiguredForm), findsOneWidget);
      // Custom columns stay out of auto forms; many-relations wait for edit
      // mode.
      expect(find.text('Badge'), findsNothing);
      expect(find.byType(BeakRelationManager), findsNothing);
    });

    testWidgets('client-side validation blocks submit and shows messages', (
      tester,
    ) async {
      await pumpForm(
        tester,
        BeakConfiguredForm(
          model: const NoteFormModel(),
          dataSource: dataSource,
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(dataSource.createCalls, isEmpty);
      expect(find.text('This field is required.'), findsWidgets);
    });

    testWidgets('a valid submit calls create with the typed record', (
      tester,
    ) async {
      BeakRecord? savedRecord;
      await pumpForm(
        tester,
        BeakConfiguredForm(
          model: const NoteFormModel(),
          dataSource: dataSource,
          onSaved: (record) => savedRecord = record,
        ),
      );

      await tester.enterText(find.byType(EditableText).first, 'Fresh note');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(dataSource.createCalls, hasLength(1));
      final (String table, BeakRecord sent) = dataSource.createCalls.single;
      expect(table, 'notes');
      expect(sent['title'], const BeakStringValue('Fresh note'));
      expect(savedRecord?['title'], const BeakStringValue('Fresh note'));
    });

    testWidgets('a 422 maps its errors onto the offending fields', (
      tester,
    ) async {
      await pumpForm(
        tester,
        BeakConfiguredForm(
          model: const NoteFormModel(),
          dataSource: _Rejecting(),
        ),
      );

      await tester.enterText(find.byType(EditableText).first, 'Duplicate');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Already taken.'), findsWidgets);
    });

    testWidgets('non-validation failures surface as a global error', (
      tester,
    ) async {
      await pumpForm(
        tester,
        BeakConfiguredForm(model: const NoteFormModel(), dataSource: _Broken()),
      );

      await tester.enterText(find.byType(EditableText).first, 'Any');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('disk on fire'), findsWidgets);
    });
  });

  group('edit mode', () {
    testWidgets('prefills from getOne and submits through update', (
      tester,
    ) async {
      await pumpForm(
        tester,
        BeakConfiguredForm(
          model: const NoteFormModel(),
          dataSource: dataSource,
          recordId: 'n1',
        ),
      );

      expect(find.text('One'), findsWidgets);

      await tester.enterText(find.byType(EditableText).first, 'One updated');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(dataSource.updateCalls, hasLength(1));
      final (String table, Object id, BeakRecord sent) =
          dataSource.updateCalls.single;
      expect(table, 'notes');
      expect(id, 'n1');
      expect(sent['title'], const BeakStringValue('One updated'));
    });
  });

  group('sections', () {
    testWidgets('render titles and honor visibility predicates', (
      tester,
    ) async {
      await pumpForm(
        tester,
        BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: dataSource,
          layout: BeakFormLayout(
            children: [
              BeakSection(
                title: 'Basics',
                children: [
                  const BeakScalarField<String>(
                    model: ArticleModel(),
                    column: ArticleColumns.title,
                  ).input(),
                  const BeakScalarField<bool>(
                    model: ArticleModel(),
                    column: ArticleColumns.active,
                  ).input(),
                ],
              ),
              BeakSection(
                title: 'Pricing',
                visibleIf: (state) =>
                    state.read(
                      const BeakScalarField<bool>(
                        model: ArticleModel(),
                        column: ArticleColumns.active,
                      ),
                    ) ??
                    false,
                children: [
                  const BeakScalarField<double>(
                    model: ArticleModel(),
                    column: ArticleColumns.price,
                  ).input(),
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('Pricing'), findsNothing);

      final OiAfSwitch<Enum> activeSwitch = tester.widget(
        find.byType(OiAfSwitch<Enum>),
      );
      expect(activeSwitch, isNotNull);
      await tester.tap(find.byType(OiAfSwitch<Enum>));
      await tester.pumpAndSettle();

      expect(find.text('Pricing'), findsOneWidget);
    });
  });
}

final class _DeferredWrite extends FakeDataSource {
  final pending = Completer<BeakRecord>();

  @override
  Future<BeakRecord> create(String table, BeakRecord data) => pending.future;
}

/// A notes model whose title is required — the minimal form fixture.
final class NoteFormModel extends BeakModel {
  /// Creates the model.
  const NoteFormModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title', rules: [BeakRequired()]),
  ];
}

/// Rejects every write with a validation failure on `title`.
final class _Rejecting extends FakeDataSource {
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    throw const BeakValidationException(
      'Validation failed.',
      fieldErrors: {
        'title': ['Already taken.'],
      },
    );
  }
}

/// Fails every write with a storage failure.
final class _Broken extends FakeDataSource {
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    throw const BeakStorageException('disk on fire');
  }
}
