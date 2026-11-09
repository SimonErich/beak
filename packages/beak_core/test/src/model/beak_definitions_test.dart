import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

const _name = BeakStringColumn(key: 'name', label: 'Name');
const _alias = BeakStringColumn(key: 'alias', label: 'Alias');
const _locked = BeakBoolColumn(key: 'locked', label: 'Locked');

/// A model shaped like a generated one: it reads its authored behavior and
/// rules from the bound definitions instead of importing them.
final class _Menu extends BeakModel {
  const _Menu([this.table = 'menus']);

  @override
  final String table;

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    _name,
    _alias,
    _locked,
  ];

  @override
  BeakModelBehavior get behavior => BeakDefinitions.behaviorOf(this);

  @override
  List<BeakRecordRule> get validationRules => BeakDefinitions.rulesOf(this);
}

const _menus = _Menu();
const _orders = _Menu('orders');
const _lockedBehavior = BeakModelBehavior(actions: [_lock]);
const _lock = BeakModelAction(name: 'lock', label: 'Lock');
const _nameField = BeakScalarField<String>(model: _menus, column: _name);
const _aliasField = BeakScalarField<String>(model: _menus, column: _alias);
const _nameRule = BeakSameAs<String>(_nameField, _aliasField);

// --8<-- [start:definitionsSet]
BeakDefinitions _definitions() => BeakDefinitions(const [
  BeakModelDefinition(_menus, behavior: _lockedBehavior, rules: [_nameRule]),
]);
// --8<-- [end:definitionsSet]

void main() {
  tearDown(BeakDefinitions.unbindForTesting);

  group('before anything is bound', () {
    test('behaviorOf throws and names the model and how to bind', () {
      expect(
        () => BeakDefinitions.behaviorOf(_menus),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            allOf(contains('menus'), contains('BeakDefinitions.bind')),
          ),
        ),
      );
    });

    test('rulesOf throws and names the model', () {
      expect(
        () => BeakDefinitions.rulesOf(_menus),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('menus'),
          ),
        ),
      );
    });

    test('a generated-style model fails closed instead of going bare', () {
      expect(() => _menus.behavior, throwsA(isA<BeakConfigurationException>()));
      expect(
        () => _menus.validationRules,
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('after binding', () {
    test('lookups return the authored behavior and rules', () {
      BeakDefinitions.bind(_definitions());
      expect(BeakDefinitions.behaviorOf(_menus), same(_lockedBehavior));
      expect(BeakDefinitions.rulesOf(_menus), [_nameRule]);
      expect(_menus.behavior.actions, [_lock]);
    });

    test('a model without an entry gets the empty behavior and no rules', () {
      BeakDefinitions.bind(_definitions());
      expect(BeakDefinitions.behaviorOf(_orders).isEmpty, isTrue);
      expect(BeakDefinitions.rulesOf(_orders), isEmpty);
    });

    test('binding the empty set leaves every model on the defaults', () {
      BeakDefinitions.bind(BeakDefinitions.none);
      expect(BeakDefinitions.behaviorOf(_menus).isEmpty, isTrue);
      expect(BeakDefinitions.rulesOf(_menus), isEmpty);
    });

    test('operator [] finds a definition by the model of its table', () {
      final definitions = _definitions();
      expect(definitions[_menus]?.behavior, same(_lockedBehavior));
      expect(definitions[_orders], isNull);
      expect(definitions.all, hasLength(1));
    });
  });

  group('rebinding', () {
    test('the same instance again is a no-op', () {
      final definitions = _definitions();
      BeakDefinitions.bind(definitions);
      BeakDefinitions.bind(definitions);
      expect(BeakDefinitions.behaviorOf(_menus), same(_lockedBehavior));
    });

    test('an equal set built again is a no-op', () {
      BeakDefinitions.bind(_definitions());
      BeakDefinitions.bind(_definitions());
      expect(BeakDefinitions.behaviorOf(_menus), same(_lockedBehavior));
    });

    test('a different set throws and keeps the first one bound', () {
      BeakDefinitions.bind(_definitions());
      expect(
        () => BeakDefinitions.bind(BeakDefinitions.none),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('already bound'),
          ),
        ),
      );
      expect(
        () => BeakDefinitions.bind(
          BeakDefinitions(const [BeakModelDefinition(_menus)]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(BeakDefinitions.behaviorOf(_menus), same(_lockedBehavior));
    });

    test('rules count as the same when every rule is the same instance', () {
      BeakDefinitions.bind(_withRules([_nameRule]));
      BeakDefinitions.bind(_withRules([_nameRule]));
      expect(BeakDefinitions.rulesOf(_menus), [_nameRule]);
    });

    test('a different rule at the same position is a different set', () {
      BeakDefinitions.bind(_withRules([_nameRule]));
      expect(
        () => BeakDefinitions.bind(
          _withRules([const BeakSameAs<String>(_aliasField, _nameField)]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a different number of rules is a different set', () {
      BeakDefinitions.bind(_withRules([_nameRule]));
      expect(
        () => BeakDefinitions.bind(_withRules([])),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a behavior built at runtime counts as a different set', () {
      BeakDefinitions.bind(
        BeakDefinitions([BeakModelDefinition(_menus, behavior: _runtime())]),
      );
      expect(
        () => BeakDefinitions.bind(
          BeakDefinitions([BeakModelDefinition(_menus, behavior: _runtime())]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('construction', () {
    test('two definitions for one table are rejected', () {
      expect(
        () => BeakDefinitions(const [
          BeakModelDefinition(_menus),
          BeakModelDefinition(_menus, behavior: _lockedBehavior),
        ]),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('menus'),
          ),
        ),
      );
    });

    test('a definition defaults to the empty behavior and no rules', () {
      const definition = BeakModelDefinition(_menus);
      expect(definition.behavior.isEmpty, isTrue);
      expect(definition.rules, isEmpty);
      expect(definition.model, same(_menus));
    });
  });

  group('withDefinitions', () {
    test('binds for the body and unbinds again afterwards', () {
      final seen = BeakDefinitions.withDefinitions(
        _definitions(),
        () => BeakDefinitions.behaviorOf(_menus),
      );
      expect(seen, same(_lockedBehavior));
      expect(
        () => BeakDefinitions.behaviorOf(_menus),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('restores the previous binding, also when the body throws', () {
      BeakDefinitions.bind(BeakDefinitions.none);
      expect(
        () => BeakDefinitions.withDefinitions<void>(
          _definitions(),
          () => throw StateError('body failed'),
        ),
        throwsStateError,
      );
      expect(BeakDefinitions.behaviorOf(_menus).isEmpty, isTrue);
    });

    test('the async form restores once the future completes', () async {
      final seen = await BeakDefinitions.withDefinitionsAsync(
        _definitions(),
        () async {
          await Future<void>.delayed(Duration.zero);
          return BeakDefinitions.behaviorOf(_menus);
        },
      );
      expect(seen, same(_lockedBehavior));
      expect(
        () => BeakDefinitions.behaviorOf(_menus),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('unbindForTesting makes the next bind start clean', () {
      BeakDefinitions.bind(_definitions());
      BeakDefinitions.unbindForTesting();
      BeakDefinitions.bind(BeakDefinitions.none);
      expect(BeakDefinitions.behaviorOf(_menus).isEmpty, isTrue);
    });
  });

  group('BeakModelRegistry.of', () {
    // --8<-- [start:registryOf]
    test('binds the definitions, then registers the models', () {
      final registry = BeakModelRegistry.of(const [
        _menus,
        _orders,
      ], definitions: _definitions());
      expect(registry.all, hasLength(2));
      expect(registry.byTableOrThrow('menus').behavior.actions, [_lock]);
      expect(registry.byTableOrThrow('orders').behavior.isEmpty, isTrue);
    });
    // --8<-- [end:registryOf]

    test('a second registry over the same set binds nothing new', () {
      final definitions = _definitions();
      BeakModelRegistry.of(const [_menus], definitions: definitions);
      expect(
        BeakModelRegistry.of(const [
          _menus,
          _orders,
        ], definitions: definitions).all,
        hasLength(2),
      );
    });

    test('a definition for a table outside the model set is rejected', () {
      expect(
        () =>
            BeakModelRegistry.of(const [_orders], definitions: _definitions()),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('menus'),
          ),
        ),
      );
      // Nothing stayed bound, so the failure cannot poison a later attempt.
      expect(
        () => BeakDefinitions.behaviorOf(_orders),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('without definitions a generated-style model fails closed', () {
      expect(
        () => BeakModelRegistry.of(const [_menus]),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a model granting access to an undeclared action is rejected', () {
      expect(
        () => BeakModelRegistry.of(const [
          _GrantingGhost(),
        ], definitions: BeakDefinitions.none),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('ghost'),
          ),
        ),
      );
    });

    test('two models for one table are still rejected', () {
      expect(
        () => BeakModelRegistry.of(const [
          _menus,
          _menus,
        ], definitions: _definitions()),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}

/// A set whose rule list is built at run time, so it is never the same list
/// as another call's.
BeakDefinitions _withRules(List<BeakRecordRule> rules) =>
    BeakDefinitions([BeakModelDefinition(_menus, rules: rules)]);

BeakModelBehavior _runtime() =>
    BeakModelBehavior(deletableWhen: (record) => true);

final class _GrantingGhost extends BeakModel {
  const _GrantingGhost();

  @override
  String get table => 'ghosts';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    _name,
  ];

  @override
  BeakPermissions get permissions => const BeakPermissions(
    read: BeakAccess.anyone,
    actions: {'ghost': BeakAccess.anyone},
  );
}
