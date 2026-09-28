import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

final class _BoundModel extends BeakModel {
  const _BoundModel({
    this.dataSource,
    this.permissions = const BeakPermissions.allowAll(),
    this.capabilities = const {BeakOperation.read},
  });

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const NoteModel().columns;

  @override
  final BeakDataSource? dataSource;

  @override
  final BeakPermissions permissions;

  @override
  final Set<BeakOperation> capabilities;
}

final class _EditSource extends FakeDataSource implements BeakEditDataSource {
  bool fail = false;

  @override
  Future<BeakRecord> loadEditValues(String table, Object id) async {
    if (fail) throw const FormatException('private transport detail');
    return BeakRecord.fromRow({'email': 'edit@example.test'});
  }
}

void main() {
  test(
    'panel registers model transport without a separate source list',
    () async {
      final container = GetIt.asNewInstance();
      addTearDown(container.reset);
      final source = FakeDataSource(
        records: {
          'notes': {
            '1': BeakRecord.fromRow({'id': '1', 'title': 'From model'}),
          },
        },
      );
      final config = BeakPanelConfig(
        title: 'Test',
        resources: [
          BeakResource(
            model: _BoundModel(
              dataSource: source,
              capabilities: const {BeakOperation.read},
            ),
            icon: const BeakIconToken(OiIcons.notebook),
          ),
        ],
      );
      registerBeakDependencies(
        config: config,
        locator: container,
        externalAuthentication: true,
      );
      final page = await container<BeakDataSource>().query(
        const BeakQuerySpec(table: 'notes'),
      );
      expect(page.items, isNotEmpty);
      expect(container.isRegistered<BeakClient>(), isFalse);
      expect(
        () => container<BeakDataSource>().query(
          const BeakQuerySpec(table: 'unknown'),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test('model permissions and supported operations govern every resource', () {
    var canRead = true;
    final resource = BeakResource(
      model: _BoundModel(
        permissions: BeakPermissions({
          BeakOperation.read: () => canRead,
          BeakOperation.create: () => true,
        }),
      ),
      icon: const BeakIconToken(OiIcons.notebook),
    );
    expect(resource.isVisible, isTrue);
    expect(resource.allowsCreate, isFalse);
    expect(resource.allowsEdit, isFalse);
    expect(resource.allowsDelete, isFalse);
    final custom = resource.copyWith(createBuilder: (_) => const SizedBox());
    expect(custom.allowsCreate, isTrue);
    canRead = false;
    expect(resource.isVisible, isFalse);
    expect(custom.allowsCreate, isFalse);
  });

  test(
    'edit projection and failures use the shared transport boundary',
    () async {
      final source = _EditSource();
      final registry = BeakModelRegistry()
        ..register(_BoundModel(dataSource: source));
      final panelSource = ModelBeakDataSource(
        registry: registry,
        mapException: (exception, _) => exception is FormatException
            ? const BeakValidationException('Safe localized message')
            : null,
      );
      final values = await panelSource.loadEditValues('notes', '1');
      expect(values['email']?.raw, 'edit@example.test');
      source.fail = true;
      await expectLater(
        panelSource.loadEditValues('notes', '1'),
        throwsA(
          isA<BeakValidationException>().having(
            (error) => error.message,
            'message',
            'Safe localized message',
          ),
        ),
      );
    },
  );

  test(
    'an explicit panel source overrides bound transports for tests',
    () async {
      final bound = _EditSource()..fail = true;
      final registry = BeakModelRegistry()
        ..register(_BoundModel(dataSource: bound));
      final replacement = FakeDataSource(
        records: {
          'notes': {
            '2': BeakRecord.fromRow({'id': '2', 'title': 'Replacement'}),
          },
        },
      );
      final source = ModelBeakDataSource(
        registry: registry,
        fallback: replacement,
        overrideBindings: true,
      );
      expect(
        (await source.loadEditValues('notes', '2'))['title']?.raw,
        'Replacement',
      );
    },
  );

  test('fallback sources serve authorized dashboard-only tables', () async {
    final registry = BeakModelRegistry()..register(const NoteModel());
    final fallback = FakeDataSource(
      records: {
        'prior_notes': {
          '1': BeakRecord.fromRow({'id': '1', 'title': 'Previous'}),
        },
      },
    );
    final source = ModelBeakDataSource(registry: registry, fallback: fallback);
    final count = await source.aggregate(
      const BeakAggregateSpec.count(table: 'prior_notes'),
    );
    expect(count, 1);
  });
}
