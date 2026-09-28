import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _aux = BeakToOneField(
  model: _Owner(),
  relation: _Owner.aux,
  target: _Simple('aux'),
);
const _rows = BeakToManyField(
  model: _Owner(),
  relation: _Owner.rows,
  target: _Line(),
);
const _selection = BeakToOneField(
  model: _Line(),
  relation: _Line.variant,
  target: _Variant(),
);
const _auxFlag = BeakScalarField<bool>(model: _Owner(), column: _Owner.auxFlag);
const _catalogFlag = BeakScalarField<bool>(
  model: _Owner(),
  column: _Owner.catalogFlag,
);
const _auxActive = BeakScalarField<bool>(
  model: _Simple('aux'),
  column: _Simple.active,
);
const _variantActive = BeakScalarField<bool>(
  model: _Variant(),
  column: _Variant.active,
);
const _name = BeakScalarField<String>(model: _Variant(), column: _Variant.name);
const _productName = BeakScalarField<String>(
  model: _Variant(),
  column: _Simple.name,
  path: [_Variant.product],
);
const _models = [
  _Owner(),
  _Line(),
  _Variant(),
  _Simple('aux'),
  _Simple('products'),
];

void main() {
  for (final wrapped in [false, true]) {
    testWidgets(
      'catalog refresh follows query and source changes, not unrelated local options (panel source: $wrapped)',
      (tester) async {
        final storage = _Storage();
        addTearDown(storage.dispose);
        final registry = BeakModelRegistry();
        for (final model in _models) {
          registry.register(model);
        }
        final panel = wrapped
            ? ModelBeakDataSource(registry: registry, fallback: storage)
            : null;
        if (panel != null) addTearDown(panel.dispose);
        final BeakDataSource source = panel ?? storage;
        late BeakFormSession session;
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            home: BeakConfiguredForm(
              model: const _Owner(),
              dataSource: source,
              onSession: (value) => session = value,
              layout: BeakFormLayout(
                children: [
                  _auxFlag.inputCheckbox(),
                  _catalogFlag.inputCheckbox(),
                  _aux.inputSearch(
                    options: (state) => _aux.options(
                      filter: _auxActive.eq(state.read(_auxFlag) ?? true),
                    ),
                  ),
                  _rows.tableForm(
                    children: const [],
                    catalog: BeakRelationCatalog(
                      selection: _selection,
                      presentation: BeakCatalogPresentation.rows,
                      template: BeakRecordTemplate(
                        title: BeakValueBinding.field(_name),
                        subtitle: [BeakValueBinding.field(_productName)],
                      ),
                      options: (state) => _selection.options(
                        filter: _variantActive.eq(
                          state.read(_catalogFlag) ?? true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        int catalogQueries() => storage.queryCalls
            .where((query) => query.table == 'variants')
            .length;
        expect(find.text('Regular'), findsOneWidget);
        final initial = catalogQueries();
        expect(initial, 1);
        session.root.set(_auxFlag, false);
        await tester.pumpAndSettle();
        expect(
          catalogQueries(),
          initial,
          reason:
              'Unrelated picker predicate changes must not reload the catalog',
        );
        expect(find.text('Regular'), findsOneWidget);

        session.root.set(_catalogFlag, false);
        await tester.pumpAndSettle();
        expect(catalogQueries(), initial + 1);
        expect(find.text('Regular'), findsNothing);
        expect(find.text('Large'), findsOneWidget);

        await source.update(
          'variants',
          'large',
          BeakRecord.fromRow({'name': 'Fresh large'}),
        );
        if (!wrapped) storage.events.add(BeakDataChange(['variants']));
        await tester.pumpAndSettle();
        expect(
          catalogQueries(),
          initial + 2,
          reason:
              'Catalog-only source mutations refresh even without an unrelated relation input',
        );
        expect(find.text('Fresh large'), findsOneWidget);

        await source.update(
          'aux',
          'a',
          BeakRecord.fromRow({'name': 'New auxiliary'}),
        );
        if (!wrapped) storage.events.add(BeakDataChange(['aux']));
        await tester.pumpAndSettle();
        expect(
          catalogQueries(),
          initial + 2,
          reason: 'Unrelated source tables do not reload catalog choices',
        );
        if (wrapped) {
          await source.update(
            'products',
            'p',
            BeakRecord.fromRow({'name': 'Updated product'}),
          );
          await tester.pumpAndSettle();
          expect(
            catalogQueries(),
            initial + 3,
            reason:
                'Panel mutation expansion refreshes nested catalog metadata',
          );
          expect(find.text('Updated product'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final class _Owner extends BeakModel {
  const _Owner();
  static const auxFlag = BeakBoolColumn(
    key: 'aux_flag',
    label: 'Auxiliary active',
    defaultValue: true,
  );
  static const catalogFlag = BeakBoolColumn(
    key: 'catalog_flag',
    label: 'Catalog active',
    defaultValue: true,
  );
  static const aux = BeakBelongsTo(
    key: 'aux',
    label: 'Auxiliary',
    relatedTable: 'aux',
    foreignKey: 'aux_id',
    displayColumnKey: 'name',
  );
  static const rows = BeakHasMany(
    key: 'rows',
    label: 'Items',
    relatedTable: 'lines',
    foreignKey: 'owner_id',
    displayColumnKey: 'id',
    owned: true,
  );
  @override
  String get table => 'owners';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'aux_id', label: 'Auxiliary'),
    auxFlag,
    catalogFlag,
  ];
  @override
  List<BeakRelationship> get relationships => const [aux, rows];
  @override
  List<BeakModel> get relatedModels => const [_Simple('aux'), _Line()];
}

final class _Line extends BeakModel {
  const _Line();
  static const variant = BeakBelongsTo(
    key: 'variant',
    label: 'Variant',
    relatedTable: 'variants',
    foreignKey: 'variant_id',
    displayColumnKey: 'name',
  );
  @override
  String get table => 'lines';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'owner_id', label: 'Owner'),
    BeakStringColumn(key: 'variant_id', label: 'Variant'),
  ];
  @override
  List<BeakRelationship> get relationships => const [variant];
  @override
  List<BeakModel> get relatedModels => const [_Variant()];
}

final class _Variant extends BeakModel {
  const _Variant();
  static const name = BeakStringColumn(key: 'name', label: 'Name');
  static const active = BeakBoolColumn(key: 'active', label: 'Active');
  static const product = BeakBelongsTo(
    key: 'product',
    label: 'Product',
    relatedTable: 'products',
    foreignKey: 'product_id',
    displayColumnKey: 'name',
  );
  @override
  String get table => 'variants';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'product_id', label: 'Product'),
    name,
    active,
  ];
  @override
  List<BeakRelationship> get relationships => const [product];
  @override
  List<BeakModel> get relatedModels => const [_Simple('products')];
}

final class _Simple extends BeakModel {
  const _Simple(this.table);
  static const name = BeakStringColumn(key: 'name', label: 'Name');
  static const active = BeakBoolColumn(key: 'active', label: 'Active');
  @override
  final String table;
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    name,
    active,
  ];
}

final class _Storage extends FakeDataSource implements BeakMutationSource {
  _Storage()
    : super(
        models: _models,
        records: {
          'aux': {
            'a': BeakRecord.fromRow({
              'id': 'a',
              'name': 'Auxiliary',
              'active': true,
            }),
          },
          'products': {
            'p': BeakRecord.fromRow({'id': 'p', 'name': 'Product'}),
          },
          'variants': {
            'regular': BeakRecord.fromRow({
              'id': 'regular',
              'name': 'Regular',
              'active': true,
              'product_id': 'p',
            }),
            'large': BeakRecord.fromRow({
              'id': 'large',
              'name': 'Large',
              'active': false,
              'product_id': 'p',
            }),
          },
        },
      );
  final events = StreamController<BeakDataChange>.broadcast();
  Future<void> dispose() => events.close();
  @override
  Stream<BeakDataChange> get changes => events.stream;
}
