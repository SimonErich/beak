import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_test/beak_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

const _title = BeakScalarField<String>(model: _Model(), column: _Model.title);

final class _Model extends BeakModel {
  const _Model();
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    rules: [BeakRequired()],
  );
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakDateTimeColumn(key: 'updated_at', label: 'Updated'),
    title,
  ];
}

final class _Source extends BeakRecordingDataSource
    implements BeakCommitDataSource, BeakCapabilityDataSource {
  _Source()
    : super(
        InMemoryBeakDataSource(
          registry: (BeakModelRegistry()..register(const _Model())),
        ),
      );
  final plans = <BeakSavePlan>[];
  bool interrupted = false;
  String? rejectedTitle;
  Object? rejectedId;
  Object? deniedId;
  Completer<void>? pendingCommit;
  final Map<Object, BeakRecord> currentRecords = {};
  @override
  Future<BeakRecord?> getOne(String table, Object id) async =>
      currentRecords[id] ?? await super.getOne(table, id);
  final capabilityIds = <Object?>[];
  BeakAccessCapabilities access = const BeakAccessCapabilities();
  Completer<BeakAccessCapabilities>? pendingAccess;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();
  BeakSaveResult receipt(String id) => BeakSaveResult(
    saveId: id,
    mode: BeakSaveMode.atomic,
    outcomes: [
      BeakOperationResult(id: 'row', status: BeakWriteOutcome.applied),
    ],
  );
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    plans.add(plan);
    await pendingCommit?.future;
    if ((rejectedTitle != null &&
            plan.operations.single.values['title']?.raw == rejectedTitle) ||
        (rejectedId != null && plan.root.id == rejectedId)) {
      return BeakSaveResult(
        saveId: plan.saveId,
        mode: BeakSaveMode.atomic,
        outcomes: [
          BeakOperationResult(
            id: 'row',
            status: BeakWriteOutcome.unapplied,
            error: BeakSaveError.fromException(
              const BeakValidationException('Title is unavailable.'),
            ),
          ),
        ],
      );
    }
    if (interrupted) throw const BeakStorageException('Connection lost');
    return receipt(plan.saveId);
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async => receipt(saveId);
  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async {
    capabilityIds.add(id);
    if (id != null && id == deniedId) {
      return const BeakAccessCapabilities(writableFields: {});
    }
    return pendingAccess == null ? access : pendingAccess!.future;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _Source source, String csv) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: SingleChildScrollView(
          child: BeakImportView(
            definition: BeakImportDefinition(
              model: const _Model(),
              fields: [_title],
            ),
            dataSource: source,
            initialCsv: csv,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'bulk review displays before and after values and checks update capabilities',
    (tester) async {
      final source = _Source();
      final updated = DateTime.utc(2026, 1, 1);
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakBulkEditView(
            model: const _Model(),
            records: [
              BeakRecord.fromRow({
                'id': 'n1',
                'title': 'Before',
                'updated_at': updated,
              }),
            ],
            changes: const [BeakFieldChange(_title, 'After')],
            dataSource: source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview changes'));
      await tester.pumpAndSettle();
      expect(source.capabilityIds, ['n1']);
      expect(find.text('Title: Before → After'), findsOneWidget);
      expect(source.plans, isEmpty);
      await tester.tap(find.text('Update 1 records'));
      await tester.pumpAndSettle();
      expect(source.plans.single.operations.single.expectedUpdatedAt, updated);
      expect(
        source.plans.single.operations.single.values['title']?.raw,
        'After',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('valid rows require review and save only on explicit import', (
    tester,
  ) async {
    final source = _Source();
    await pump(tester, source, 'Title\nOne\nTwo');
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    expect(find.text('Title: One'), findsOneWidget);
    expect(source.plans, isEmpty);
    await tester.tap(find.text('Import 2 records'));
    await tester.pumpAndSettle();
    expect(source.plans, hasLength(2));
    expect(find.text('2 of 2 records saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'permission check locks input and denied fields never enable import',
    (tester) async {
      final source = _Source()
        ..pendingAccess = Completer<BeakAccessCapabilities>();
      await pump(tester, source, 'Title\nOne');
      await tester.tap(find.text('Preview import'));
      await tester.pump();
      expect(
        tester.widget<OiTextInput>(find.byType(OiTextInput)).enabled,
        isFalse,
      );
      source.pendingAccess!.complete(
        const BeakAccessCapabilities(writableFields: {}),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Some import fields are not writable by your account.'),
        findsOneWidget,
      );
      expect(find.text('Import 1 records'), findsNothing);
      expect(source.plans, isEmpty);
    },
  );
  testWidgets(
    'interrupted import recovers its receipt before resuming remaining rows',
    (tester) async {
      final source = _Source()..interrupted = true;
      await pump(tester, source, 'Title\nOne\nTwo');
      await tester.tap(find.text('Preview import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import 2 records'));
      await tester.pumpAndSettle();
      expect(source.plans, hasLength(1));
      expect(
        tester.widget<OiTextInput>(find.byType(OiTextInput)).enabled,
        isFalse,
      );
      await tester.tap(find.text('Check interrupted save'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 records saved.'), findsOneWidget);
      // A confirmed first receipt still locks the original preview until all rows finish.
      expect(
        tester.widget<OiTextInput>(find.byType(OiTextInput)).enabled,
        isFalse,
      );
      source.interrupted = false;
      await tester.tap(find.text('Resume import'));
      await tester.pumpAndSettle();
      expect(source.plans.map((plan) => plan.saveId).toSet(), hasLength(2));
      expect(source.plans, hasLength(2));
      expect(find.text('2 of 2 records saved.'), findsOneWidget);
    },
  );
  testWidgets('equivalent parent rebuild preserves interrupted recovery', (
    tester,
  ) async {
    final source = _Source()..interrupted = true;
    await pump(tester, source, 'Title\nOne');
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import 1 records'));
    await tester.pumpAndSettle();
    expect(find.text('Check interrupted save'), findsOneWidget);
    await pump(tester, source, 'Title\nOne');
    expect(find.text('Check interrupted save'), findsOneWidget);
    expect(source.plans, hasLength(1));
  });
  testWidgets('rejected rows can be corrected without replaying saved rows', (
    tester,
  ) async {
    final source = _Source()..rejectedTitle = 'Bad';
    await pump(tester, source, 'Title\nOne\nBad\nThree');
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import 3 records'));
    await tester.pumpAndSettle();
    final rejectedId = source.plans.last.saveId;
    expect(find.text('1 of 3 records saved.'), findsOneWidget);
    await tester.tap(find.text('Edit remaining rows'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText),
      'Title\nChanged saved row\nFixed\nThree',
    );
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Row 2 has already been saved.'),
      findsOneWidget,
    );
    expect(source.plans, hasLength(2));
    await tester.enterText(
      find.byType(EditableText),
      'Title\nOne\nFixed\nThree',
    );
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume import'));
    await tester.pumpAndSettle();
    expect(
      source.plans.map((plan) => plan.operations.single.values['title']?.raw),
      ['One', 'Bad', 'Fixed', 'Three'],
    );
    expect(source.plans[2].saveId, isNot(rejectedId));
    expect(find.text('3 of 3 records saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source replacement drains the current write and blocks continuation',
    (tester) async {
      final source = _Source()..pendingCommit = Completer<void>();
      final replacement = _Source();
      await pump(tester, source, 'Title\nOne\nTwo');
      await tester.tap(find.text('Preview import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import 2 records'));
      await tester.pump();
      expect(source.plans, hasLength(1));
      await pump(tester, replacement, 'Title\nReplacement');
      expect(
        find.textContaining('The source or batch configuration changed.'),
        findsOneWidget,
      );
      source.pendingCommit!.complete();
      await tester.pumpAndSettle();
      expect(source.plans, hasLength(1));
      expect(replacement.plans, isEmpty);
      expect(find.text('1 of 2 records saved.'), findsOneWidget);
      expect(
        tester
            .widget<OiButton>(find.widgetWithText(OiButton, 'Resume import'))
            .onTap,
        isNull,
      );
      await tester.tap(find.text('Start new review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview import'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OiTextInput>(find.byType(OiTextInput)).controller!.text,
        'Title\nReplacement',
      );
      expect(replacement.capabilityIds, [null]);
      expect(replacement.plans, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bulk conflict reload retains completed rows and refreshes unsaved baselines',
    (tester) async {
      final source = _Source()..rejectedId = 'n2';
      final oldRevision = DateTime.utc(2026, 1, 1);
      final freshRevision = DateTime.utc(2026, 2, 1);
      source.currentRecords['n2'] = BeakRecord.fromRow({
        'id': 'n2',
        'title': 'New baseline',
        'updated_at': freshRevision,
      });
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakBulkEditView(
            model: const _Model(),
            records: [
              BeakRecord.fromRow({
                'id': 'n1',
                'title': 'Already saved',
                'updated_at': oldRevision,
              }),
              BeakRecord.fromRow({
                'id': 'n2',
                'title': 'Old baseline',
                'updated_at': oldRevision,
              }),
            ],
            changes: const [BeakFieldChange(_title, 'After')],
            dataSource: source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update 2 records'));
      await tester.pumpAndSettle();
      final rejectedId = source.plans.last.saveId;
      source.rejectedId = null;
      source.deniedId = 'n1';
      await tester.tap(find.text('Reload remaining records'));
      await tester.pumpAndSettle();
      expect(find.text('Title: New baseline → After'), findsOneWidget);
      await tester.tap(find.text('Resume updates'));
      await tester.pumpAndSettle();
      expect(source.plans.map((plan) => plan.root.id), ['n1', 'n2', 'n2']);
      expect(source.plans.last.saveId, isNot(rejectedId));
      expect(
        source.plans.last.operations.single.expectedUpdatedAt,
        freshRevision,
      );
      expect(find.text('2 of 2 records saved.'), findsOneWidget);
    },
  );
  testWidgets('permission revocation after preview prevents dispatch', (
    tester,
  ) async {
    final source = _Source();
    await pump(tester, source, 'Title\nOne');
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    source.access = const BeakAccessCapabilities(writableFields: {});
    await tester.tap(find.text('Import 1 records'));
    await tester.pumpAndSettle();
    expect(source.plans, isEmpty);
    expect(
      find.text('Some import fields are not writable by your account.'),
      findsOneWidget,
    );
    expect(
      tester.widget<OiTextInput>(find.byType(OiTextInput)).enabled,
      isTrue,
    );
  });

  testWidgets(
    'changed source cannot discard an unknown receipt before recovery',
    (tester) async {
      final source = _Source()..interrupted = true;
      final replacement = _Source();
      await pump(tester, source, 'Title\nOne');
      await tester.tap(find.text('Preview import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import 1 records'));
      await tester.pumpAndSettle();
      await pump(tester, replacement, 'Title\nOne');
      expect(
        tester
            .widget<OiButton>(find.widgetWithText(OiButton, 'Start new review'))
            .onTap,
        isNull,
      );
      expect(find.text('Edit remaining rows'), findsNothing);
      await tester.tap(find.text('Check interrupted save'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 records saved.'), findsOneWidget);
      expect(source.plans, hasLength(1));
      expect(replacement.plans, isEmpty);
      expect(
        tester
            .widget<OiButton>(find.widgetWithText(OiButton, 'Start new review'))
            .onTap,
        isNotNull,
      );
    },
  );

  testWidgets(
    'cancelling during submit permission checks dispatches no writes',
    (tester) async {
      final source = _Source();
      await pump(tester, source, 'Title\nOne');
      await tester.tap(find.text('Preview import'));
      await tester.pumpAndSettle();
      source.pendingAccess = Completer<BeakAccessCapabilities>();
      await tester.tap(find.text('Import 1 records'));
      await tester.pump();
      await tester.tap(find.text('Stop after current record'));
      source.pendingAccess!.complete(const BeakAccessCapabilities());
      await tester.pumpAndSettle();
      expect(source.plans, isEmpty);
      expect(
        tester.widget<OiTextInput>(find.byType(OiTextInput)).enabled,
        isTrue,
      );
    },
  );
}
