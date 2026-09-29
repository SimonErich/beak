import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

const _model = _Model();
const _quantity = BeakScalarField<int>(
  model: _model,
  column: BeakIntColumn(key: 'quantity', label: 'Quantity'),
);
const _price = BeakScalarField<int>(
  model: _model,
  column: BeakIntColumn(key: 'price', label: 'Price'),
);
const _total = BeakScalarField<int>(
  model: _model,
  column: BeakIntColumn(key: 'total', label: 'Total'),
);
const _suggestion = BeakScalarField<int>(
  model: _model,
  column: BeakIntColumn(key: 'suggestion', label: 'Suggestion'),
);
const _state = BeakScalarField<String>(
  model: _model,
  column: BeakStringColumn(key: 'state', label: 'State'),
);
const _snapshot = BeakScalarField<int>(
  model: _model,
  column: BeakIntColumn(key: 'snapshot', label: 'Snapshot'),
);

final class _Model extends BeakModel {
  const _Model();
  @override
  String get table => 'orders';
  @override
  String get displayColumnKey => 'state';
  @override
  List<BeakColumn> get columns => [
    _quantity.column,
    _price.column,
    _total.column,
    _suggestion.column,
    _state.column,
    _snapshot.column,
  ];
}

final _issue = BeakModelAction(
  name: 'issue',
  label: 'Issue',
  availableWhen: (record) => _state.readFrom(record) == 'draft',
  values: [
    BeakValueBehavior<String>.derived(field: _state, resolve: (_) => 'issued'),
  ],
);

BeakModelBehavior _behavior() => BeakModelBehavior(
  values: [
    BeakValueBehavior<int>.snapshot(
      field: _snapshot,
      onAction: _issue,
      dependencies: [_total],
      resolve: (context) => context.read(_total),
    ),
    BeakValueBehavior<int>.derived(
      field: _total,
      dependencies: [_quantity, _price],
      resolve: (context) =>
          (context.read(_quantity) ?? 0) * (context.read(_price) ?? 0),
    ),
    BeakValueBehavior<int>.suggested(
      field: _suggestion,
      dependencies: [_quantity],
      resolve: (context) => context.read(_quantity),
    ),
    BeakValueBehavior<String>.initial(field: _state, resolve: (_) => 'draft'),
  ],
  actions: [_issue],
  editableWhen: (record) => _state.readFrom(record) == 'draft',
);

void main() {
  test(
    'dependency order, initial defaults, suggestions, and read-only derivation',
    () {
      final behavior = _behavior();
      behavior.validate(_model);
      expect(behavior.relationLoads, isEmpty);
      final first = behavior.apply(
        BeakRecord.fromRow({'quantity': 3, 'price': 5}),
      );
      expect(first.toRow(), {
        'quantity': 3,
        'price': 5,
        'total': 15,
        'state': 'draft',
        'suggestion': 3,
      });
      final next = behavior.apply(_quantity.writeTo(first, 4));
      expect(_suggestion.readFrom(next), 4);
      expect(_total.readFrom(next), 20);
      final manual = behavior.apply(
        _suggestion.writeTo(next, 9),
        overriddenFields: {'suggestion'},
      );
      expect(_suggestion.readFrom(manual), 9);
      expect(behavior.canEdit('total', first), isFalse);
      expect(behavior.canEdit('quantity', first), isTrue);
    },
  );

  test(
    'persisted suggestions follow their source but retain explicit values and nulls',
    () {
      final behavior = _behavior();
      final initial = behavior.apply(
        BeakRecord.fromRow({'quantity': 3, 'price': 5}),
      );
      expect(
        _suggestion.readFrom(
          behavior.apply(_quantity.writeTo(initial, 4), initial: initial),
        ),
        4,
      );
      final override = _suggestion.writeTo(initial, 8);
      expect(
        _suggestion.readFrom(
          behavior.apply(_quantity.writeTo(override, 4), initial: override),
        ),
        8,
      );
      final nullableOverride = _suggestion.writeTo(initial, null);
      expect(
        _suggestion.readFrom(
          behavior.apply(
            _quantity.writeTo(nullableOverride, 4),
            initial: nullableOverride,
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'named transition freezes snapshot and ordinary state edits are rejected',
    () {
      final behavior = _behavior();
      final initial = behavior.apply(
        BeakRecord.fromRow({'quantity': 3, 'price': 5}),
      );
      expect(
        () => behavior.validateEdits(
          _state.writeTo(initial, 'issued'),
          initial: initial,
        ),
        throwsA(isA<BeakValidationException>()),
      );
      final issued = behavior.apply(initial, initial: initial, action: 'issue');
      expect(_snapshot.readFrom(issued), 15);
      expect(_state.readFrom(issued), 'issued');
      expect(
        () => behavior.validateEdits(
          _quantity.writeTo(issued, 10),
          initial: issued,
        ),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => behavior.apply(issued, initial: issued, action: 'issue'),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        _snapshot.readFrom(
          behavior.apply(_price.writeTo(issued, 20), initial: issued),
        ),
        15,
      );
    },
  );

  test('explicit null default stays null and action arguments stay typed', () {
    final behavior = BeakModelBehavior(
      values: [
        BeakValueBehavior<int>.initial(field: _quantity, resolve: (_) => 4),
      ],
      actions: [
        BeakModelAction(
          name: 'set',
          label: 'Set',
          values: [
            BeakValueBehavior<int>.derived(
              field: _price,
              resolve: (context) => context.argument(_quantity),
            ),
          ],
        ),
      ],
    );
    expect(
      behavior.apply(BeakRecord.fromRow({'quantity': null}))['quantity']?.raw,
      isNull,
    );
    expect(
      _price.readFrom(
        behavior.apply(
          const BeakRecord(values: {}),
          action: 'set',
          arguments: BeakRecord.fromRow({'quantity': 7}),
        ),
      ),
      7,
    );
  });

  test(
    'cycles, duplicate targets and undeclared snapshot commands fail early',
    () {
      expect(
        () => BeakModelBehavior(
          values: [
            BeakValueBehavior<int>.derived(
              field: _total,
              dependencies: [_price],
              resolve: (_) => 1,
            ),
            BeakValueBehavior<int>.derived(
              field: _price,
              dependencies: [_total],
              resolve: (_) => 1,
            ),
          ],
        ).validate(_model),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakModelBehavior(
          values: [
            BeakValueBehavior<int>.derived(field: _price, resolve: (_) => 1),
            BeakValueBehavior<int>.initial(field: _price, resolve: (_) => 1),
          ],
        ).validate(_model),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakModelBehavior(
          values: [
            BeakValueBehavior<int>.snapshot(
              field: _price,
              onAction: const BeakModelAction(
                name: 'missing',
                label: 'Missing',
              ),
              resolve: (_) => 1,
            ),
          ],
        ).validate(_model),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'save-plan wire roundtrip preserves command payload and reference equality',
    () {
      const root = BeakRecordRef.existing('orders', 1);
      final plan = BeakSavePlan(
        saveId: 'issue-1',
        root: root,
        action: 'issue',
        arguments: BeakRecord.fromRow({'quantity': 3}),
        operations: [],
      );
      final copy = BeakSavePlan.fromJson(plan.toJson());
      expect(copy.action, 'issue');
      expect(copy.arguments, plan.arguments);
      expect(copy.root, root);
      expect(copy.root.hashCode, root.hashCode);
    },
  );

  test('a save plan answers whether it runs a declared command', () {
    const root = BeakRecordRef.existing('orders', 1);
    const other = BeakModelAction(name: 'cancel', label: 'Cancel');
    final plan = BeakSavePlan(
      saveId: 'issue-2',
      root: root,
      action: _issue.name,
      operations: [],
    );
    final plain = BeakSavePlan(saveId: 'plain', root: root, operations: []);
    expect(plan.runs(_issue), isTrue);
    expect(plan.runs(other), isFalse);
    expect(plan.runsAny([other, _issue]), isTrue);
    expect(plan.runsAny([other]), isFalse);
    expect(plan.runsAny(const []), isFalse);
    expect(plain.runs(_issue), isFalse);
    expect(plain.runsAny([_issue, other]), isFalse);
  });
  test(
    'initialization, original values and command-aware edit validation preserve explicit input',
    () {
      final behavior = _behavior();
      const empty = BeakRecord(values: {});
      final initial = behavior.initialize(empty);
      expect(_state.readFrom(initial), 'draft');
      expect(
        behavior.initialize(_state.writeTo(initial, null))['state']?.raw,
        isNull,
      );
      behavior.validateEdits(empty);
      behavior.validateEdits(
        _state.writeTo(initial, 'issued'),
        initial: initial,
        actionName: 'issue',
      );
      behavior.validateEdits(
        BeakRecord.fromRow({'state': 'draft', 'snapshot': null, 'price': 1}),
        initial: initial,
        isCreate: true,
      );
      expect(
        () => behavior.validateEdits(
          BeakRecord.fromRow({'state': 'draft', 'snapshot': 5}),
          initial: initial,
          isCreate: true,
        ),
        throwsA(isA<BeakValidationException>()),
      );
      expect(const BeakValueContext(record: empty).original(_price), isNull);
      expect(
        BeakValueContext(
          record: empty,
          initial: _price.writeTo(empty, 4),
        ).original(_price),
        4,
      );
      expect(
        () => behavior.action('missing'),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'configuration diagnostics reject mismatched behavior and dependency models',
    () {
      const wrong = BeakScalarField<int>(
        model: _model,
        column: BeakIntColumn(key: 'missing', label: 'Missing'),
      );
      expect(
        () => BeakModelBehavior(
          values: [
            BeakValueBehavior<int>.derived(field: wrong, resolve: (_) => 1),
          ],
        ).validate(_model),
        throwsA(isA<BeakConfigurationException>()),
      );
      const other = _Other();
      const dependency = BeakScalarField<int>(
        model: other,
        column: BeakIntColumn(key: 'price', label: 'Price'),
      );
      expect(
        () => BeakModelBehavior(
          values: [
            BeakValueBehavior<int>.derived(
              field: _total,
              dependencies: [dependency],
              resolve: (_) => 1,
            ),
          ],
        ).validate(_model),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => const BeakModelBehavior(
          actions: [BeakModelAction(name: '', label: 'Invalid')],
        ).validate(_model),
        throwsA(isA<BeakConfigurationException>()),
      );
      const relation = BeakBelongsTo(
        key: 'item',
        label: 'Item',
        relatedTable: 'other',
        displayColumnKey: 'price',
        foreignKey: 'item_id',
      );
      const path = BeakScalarField<int>(
        model: _model,
        column: BeakIntColumn(key: 'price', label: 'Price'),
        path: [relation],
      );
      final behavior = BeakModelBehavior(
        values: [
          BeakValueBehavior<int>.derived(
            field: _total,
            dependencies: [path],
            resolve: (_) => 1,
          ),
        ],
      );
      expect(behavior.relationLoads.single.relationKey, 'item');
    },
  );
  test('commands require a named nonempty operation graph before dispatch', () {
    final registry = BeakModelRegistry()..register(_model);
    const root = BeakRecordRef.existing('orders', 1);
    expect(
      () => BeakSavePlan(
        saveId: 'empty',
        root: root,
        action: 'issue',
        operations: [],
      ).orderedOperations(registry),
      throwsA(isA<BeakConfigurationException>()),
    );
    final operation = BeakSaveOperation(
      id: 'root',
      kind: BeakSaveOperationKind.update,
      target: root,
    );
    expect(
      () => BeakSavePlan(
        saveId: 'bad-name',
        root: root,
        action: '',
        operations: [operation],
      ).orderedOperations(registry),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      BeakSavePlan(
        saveId: 'valid',
        root: root,
        action: 'issue',
        operations: [operation],
      ).orderedOperations(registry),
      [operation],
    );
  });
  test('action arguments are an immutable submission snapshot', () {
    final fields = {'price': const BeakIntValue(5)};
    final plan = BeakSavePlan(
      saveId: 'snapshot',
      root: const BeakRecordRef.existing('orders', 1),
      operations: [],
      action: 'issue',
      arguments: BeakRecord(values: fields),
    );
    fields['price'] = const BeakIntValue(9);
    expect(plan.arguments['price']?.raw, 5);
  });
}

final class _Other extends BeakModel {
  const _Other();
  @override
  String get table => 'other';
  @override
  String get displayColumnKey => 'price';
  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'price', label: 'Price'),
  ];
}
