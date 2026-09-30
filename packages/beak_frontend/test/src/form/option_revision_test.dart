import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _first = BeakToOneField(
  model: _Owner(),
  relation: _Owner.first,
  target: _Target('first'),
);
const _second = BeakToOneField(
  model: _Owner(),
  relation: _Owner.second,
  target: _Target('second'),
);
const _activeOnly = BeakScalarField<bool>(
  model: _Owner(),
  column: _Owner.activeOnly,
);
const _active = BeakScalarField<bool>(
  model: _Target('second'),
  column: _Target.active,
);

void main() {
  testWidgets(
    'relation query changes preserve unrelated choices and mutations still recheck selection',
    (tester) async {
      final source = _Source();
      addTearDown(source.dispose);
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Owner(),
            dataSource: source,
            onSession: (value) => session = value,
            layout: BeakFormLayout(
              children: [
                _activeOnly.inputCheckbox(),
                _first.inputSearch(),
                _second.inputSearch(
                  options: (state) => _second.options(
                    filter: _active.eq(state.read(_activeOnly) ?? true),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      int queries(String table) =>
          source.queryCalls.where((query) => query.table == table).length;
      expect(queries('first'), 1);
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(session.root.read(_second)?['id']?.raw, 'b');
      final firstBefore = queries('first');
      session.root.set(_activeOnly, false);
      await tester.pumpAndSettle();
      expect(
        queries('first'),
        firstBefore,
        reason:
            'An unrelated option predicate must not trigger another network request',
      );
      expect(
        session.root.read(_second),
        isNull,
        reason: 'Changed eligibility still invalidates the selected option',
      );
      expect(find.text('Two'), findsNothing);
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(session.root.read(_first)?['id']?.raw, 'a');
      final secondBefore = queries('second');
      await source.delete('first', 'a');
      source.events.add(BeakDataChange(['first']));
      await tester.pumpAndSettle();
      expect(queries('first'), greaterThan(firstBefore));
      expect(
        queries('second'),
        secondBefore,
        reason: 'Only the mutated relation needs new choices',
      );
      expect(
        session.root.read(_first),
        isNull,
        reason:
            'Source mutations retain the selected-record availability guard',
      );
      expect(find.text('One'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  Future<BeakFormSession> mountDefault(
    WidgetTester tester,
    _Source source, {
    bool Function(BeakRecord, BeakFormReader)? matcher,
    String? Function(BeakRecord, BeakFormReader)? disabled,
  }) async {
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _Owner(),
          dataSource: source,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              _activeOnly.inputCheckbox(),
              _second.inputCards(
                options: (state) => _second.options(
                  filter: _active.eq(state.read(_activeOnly) ?? true),
                ),
                dependencies: const [_activeOnly],
                defaultOptionMatch: matcher ?? (record, state) => true,
                selectDefaultOption: true,
                disabledReason: disabled,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('eligible defaults select once and preserve manual selections', (
    tester,
  ) async {
    final source = _Source();
    addTearDown(source.dispose);
    final session = await mountDefault(tester, source);
    expect(session.root.read(_second)?['id']?.raw, 'b');
    final manual = BeakRecord.fromRow({
      'id': 'manual',
      'name': 'Manual',
      'active': true,
    });
    await source.create('second', manual);
    session.root.select(_second, manual);
    source.events.add(BeakDataChange(['second']));
    await tester.pumpAndSettle();
    expect(session.root.read(_second)?['id']?.raw, 'manual');
    expect(tester.takeException(), isNull);
  });

  for (final unavailable in [false, true]) {
    testWidgets('unmatched or disabled preferences stay blank ($unavailable)', (
      tester,
    ) async {
      final source = _Source();
      addTearDown(source.dispose);
      final session = await mountDefault(
        tester,
        source,
        matcher: (record, state) => unavailable,
        disabled: unavailable ? (record, state) => 'Unavailable' : null,
      );
      expect(session.root.read(_second), isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dependency changes resolve only current eligible options', (
    tester,
  ) async {
    final source = _Source();
    addTearDown(source.dispose);
    await source.create(
      'second',
      BeakRecord.fromRow({'id': 'c', 'name': 'Next date', 'active': false}),
    );
    final session = await mountDefault(tester, source);
    expect(session.root.read(_second)?['id']?.raw, 'b');
    session.root.set(_activeOnly, false);
    await tester.pumpAndSettle();
    expect(session.root.read(_second)?['id']?.raw, 'c');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a stale option response cannot select the previous dependency default',
    (tester) async {
      final source = _Source();
      addTearDown(source.dispose);
      final session = await mountDefault(
        tester,
        source,
        matcher: (record, state) => false,
      );
      await source.create(
        'second',
        BeakRecord.fromRow({'id': 'c', 'name': 'Next date', 'active': false}),
      );
      final release = Completer<void>();
      source.holdNextQuery = release.future;
      final input = _second.inputCards(
        options: (state) => _second.options(
          filter: _active.eq(state.read(_activeOnly) ?? true),
        ),
        defaultOptionMatch: (record, state) => true,
        selectDefaultOption: true,
      );
      final oldRequest = session.root.search(input, '');
      await tester.pump();
      session.root.set(_activeOnly, false);
      final currentRequest = session.root.search(input, '');
      await tester.pumpAndSettle();
      expect(session.root.read(_second)?['id']?.raw, 'c');
      release.complete();
      await oldRequest;
      await currentRequest;
      await tester.pumpAndSettle();
      expect(session.root.read(_second)?['id']?.raw, 'c');
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Owner extends BeakModel {
  const _Owner();
  static const activeOnly = BeakBoolColumn(
    key: 'active_only',
    label: 'Active',
    defaultValue: true,
  );
  static const first = BeakBelongsTo(
    key: 'first',
    label: 'First',
    relatedTable: 'first',
    foreignKey: 'first_id',
    displayColumnKey: 'name',
  );
  static const second = BeakBelongsTo(
    key: 'second',
    label: 'Second',
    relatedTable: 'second',
    foreignKey: 'second_id',
    displayColumnKey: 'name',
  );
  @override
  String get table => 'owners';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'first_id', label: 'First'),
    BeakStringColumn(key: 'second_id', label: 'Second'),
    activeOnly,
  ];
  @override
  List<BeakRelationship> get relationships => const [first, second];
  @override
  List<BeakModel> get relatedModels => const [
    _Target('first'),
    _Target('second'),
  ];
}

final class _Target extends BeakModel {
  const _Target(this.table);
  static const active = BeakBoolColumn(key: 'active', label: 'Active');
  @override
  final String table;
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'name', label: 'Name'),
    active,
  ];
}

final class _Source extends FakeDataSource implements BeakMutationSource {
  _Source()
    : super(
        models: const [_Owner(), _Target('first'), _Target('second')],
        records: {
          'first': {
            'a': BeakRecord.fromRow({'id': 'a', 'name': 'One', 'active': true}),
          },
          'second': {
            'b': BeakRecord.fromRow({'id': 'b', 'name': 'Two', 'active': true}),
          },
        },
      );
  Future<void>? holdNextQuery;
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    final hold = holdNextQuery;
    holdNextQuery = null;
    final result = await super.query(spec);
    if (hold != null) await hold;
    return result;
  }

  final events = StreamController<BeakDataChange>.broadcast();
  Future<void> dispose() => events.close();
  @override
  Stream<BeakDataChange> get changes => events.stream;
}
