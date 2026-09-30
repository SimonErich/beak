import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

final class _Model extends BeakModel {
  const _Model();
  static const id = BeakScalarField<String>(
    model: _Model(),
    column: BeakStringColumn(key: 'id', label: 'Id'),
  );
  static const code = BeakScalarField<String>(
    model: _Model(),
    column: BeakStringColumn(key: 'code', label: 'Code', unique: true),
  );
  static const tenant = BeakScalarField<String>(
    model: _Model(),
    column: BeakStringColumn(key: 'tenant', label: 'Tenant'),
  );
  static const parent = BeakScalarField<String>(
    model: _Model(),
    column: BeakStringColumn(key: 'parent', label: 'Parent'),
  );
  @override
  String get table => 'rows';
  @override
  String get displayColumnKey => 'code';
  @override
  List<BeakColumn> get columns => [
    id.column,
    code.column,
    tenant.column,
    parent.column,
  ];
  @override
  List<BeakRecordRule> get validationRules => [
    const BeakUnique(code, scope: [tenant], ignoreNull: false),
    BeakExists(
      parent,
      id,
      where: code.eq('allowed'),
      matching: const [BeakFieldMatch(target: tenant, source: tenant)],
    ),
  ];
}

final class _Related extends BeakModel {
  const _Related({this.target});
  final BeakModel? target;
  @override
  String get table => 'related';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'target_id', label: 'Target'),
  ];
  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'target',
      label: 'Target',
      relatedTable: 'targets',
      displayColumnKey: 'uuid',
      foreignKey: 'target_id',
    ),
  ];
  @override
  List<BeakModel> get relatedModels => [?target];
}

final class _Target extends BeakModel {
  const _Target();
  @override
  String get table => 'targets';
  @override
  String get displayColumnKey => 'uuid';
  @override
  BeakColumn get primaryKey => columns.single;
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'uuid', label: 'Id'),
  ];
}

void main() {
  test(
    'belongs-to existence derives trusted metadata and custom identity keys',
    () async {
      final queries = <BeakQuerySpec>[];
      Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
        queries.add(spec);
        return const BeakPage(items: [], total: 0, page: 1, perPage: 1);
      }

      final record = BeakRecord.fromRow({'target_id': 'missing'});
      final registry = BeakModelRegistry()..register(const _Target());
      for (final (model, models, key)
          in <(_Related, BeakModelRegistry?, String)>[
            (const _Related(), null, 'id'),
            (const _Related(target: _Target()), null, 'uuid'),
            (const _Related(), registry, 'uuid'),
          ]) {
        final result = await const BeakAsyncValidation().validate(
          model,
          record,
          query: query,
          registry: models,
        );
        expect(result.fieldErrors, {
          'target_id': ['The selected value is not available.'],
        });
        final filter = queries.last.filter;
        expect(filter, isA<BeakAndFilter>());
        if (filter case BeakAndFilter(
          filters: [BeakFieldFilter(columnKey: final column)],
        )) {
          expect(column, key);
        }
      }
      queries.clear();
      expect(
        (await const BeakAsyncValidation().validate(
          const _Related(),
          BeakRecord.fromRow({}),
          query: query,
        )).valid,
        isTrue,
      );
      expect(queries, isEmpty);
    },
  );

  test(
    'authoritative queries retain global unique plus scope, eligibility and exclusion',
    () async {
      final queries = <BeakQuerySpec>[];
      final report = await const BeakAsyncValidation().validate(
        const _Model(),
        BeakRecord.fromRow({
          'code': 'value',
          'tenant': 'team',
          'parent': 'target',
        }),
        recordId: 'self',
        query: (spec) async {
          queries.add(spec);
          return BeakPage(
            items: queries.length <= 2
                ? [
                    BeakRecord.fromRow({'id': 'other'}),
                  ]
                : const [],
            total: 1,
            page: 1,
            perPage: 1,
          );
        },
      );
      expect(queries, hasLength(3));
      expect(queries[0].filter?.toJson().toString(), contains('self'));
      expect(queries[1].filter?.toJson().toString(), contains('team'));
      expect(queries[2].filter?.toJson().toString(), contains('allowed'));
      expect(queries[2].filter?.toJson().toString(), contains('target'));
      expect(report.fieldErrors.keys, ['code', 'parent']);
      expect(report.valid, isFalse);
    },
  );
  test(
    'optional null skips existence and nullable scoped uniqueness checks null explicitly',
    () async {
      final queries = <BeakQuerySpec>[];
      final report = await const BeakAsyncValidation().validate(
        const _Model(),
        BeakRecord.fromRow({}),
        query: (spec) async {
          queries.add(spec);
          return const BeakPage(items: [], total: 0, page: 1, perPage: 1);
        },
      );
      expect(report.valid, isTrue);
      expect(queries, hasLength(1));
      expect(queries.single.filter?.toJson().toString(), contains('isNull'));
    },
  );
  test(
    'validation transport round trips candidates but never transports rules',
    () {
      final request = BeakValidationRequest.forModel(
        const _Model(),
        BeakRecord.fromRow({'code': 'value'}),
        recordId: 'editing',
      );
      expect(
        BeakValidationRequest.fromJson(request.toJson()).toJson(),
        request.toJson(),
      );
      expect(request.toJson().keys, ['table', 'record', 'recordId']);
      final create = BeakValidationRequest.forModel(
        const _Model(),
        BeakRecord.fromRow({}),
      );
      expect(BeakValidationRequest.fromJson(create.toJson()).recordId, isNull);
      const report = BeakValidationReport(
        fieldErrors: {
          'code': ['Already used.'],
        },
      );
      expect(
        BeakValidationReport.fromJson(report.toJson()).fieldErrors,
        report.fieldErrors,
      );
      for (final json in <Map<String, Object?>>[
        {},
        {'table': '', 'record': {}},
        {'table': 'rows', 'record': {}, 'recordId': []},
      ]) {
        expect(
          () => BeakValidationRequest.fromJson(json),
          throwsA(isA<BeakConfigurationException>()),
        );
      }
      for (final json in <Map<String, Object?>>[
        {},
        {
          'fieldErrors': {'code': 'wrong'},
        },
        {
          'fieldErrors': {
            'code': [1],
          },
        },
      ]) {
        expect(
          () => BeakValidationReport.fromJson(json),
          throwsA(isA<BeakConfigurationException>()),
        );
      }
    },
  );
}
