import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
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

/// The command shape an edit form of [_ProjectedModel] submits.
final class _ProfileEdit extends BeakModel {
  const _ProfileEdit();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'email';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'email', label: 'Email'),
    BeakStringColumn(key: 'nickname', label: 'Nickname'),
  ];
}

/// A model whose edit form is a separate command shape.
final class _ProjectedModel extends BeakModel {
  const _ProjectedModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const NoteModel().columns;

  @override
  BeakModel? get editModel => const _ProfileEdit();
}

final class _ProjectionSource extends FakeDataSource
    implements BeakEditDataSource {
  _ProjectionSource()
    : super(
        records: {
          'notes': {
            '1': BeakRecord.fromRow({'id': '1', 'title': 'Stored'}),
          },
        },
      );

  @override
  Future<BeakRecord> loadEditValues(String table, Object id) async =>
      BeakRecord.fromRow({'email': 'edit@example.test'});
}

void main() {
  testWidgets(
    'the edit page fills the model edit projection and submits every field',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(
          resources: const [BeakResource(model: _ProjectedModel())],
          dataSource: _ProjectionSource(),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes/1/edit');
      await tester.pumpAndSettle();

      final form = tester.widget<BeakConfiguredForm>(
        find.byType(BeakConfiguredForm),
      );
      expect(form.model, isA<_ProfileEdit>());
      expect(form.valueMode, BeakFormValueMode.complete);
      expect(find.text('edit@example.test'), findsOneWidget);
      expect(find.text('Nickname'), findsWidgets);
    },
  );

  testWidgets('a plain model submits only what a form populates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        resources: const [BeakResource(model: NoteModel())],
        dataSource: FakeDataSource(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes/create');
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<BeakConfiguredForm>(find.byType(BeakConfiguredForm))
          .valueMode,
      BeakFormValueMode.populated,
    );
  });

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
    final custom = resource.copyWith(
      screens: [
        BeakCustomResourceScreen(
          roles: const {BeakScreenRole.create},
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    expect(custom.allowsCreate, isTrue);
    expect(custom.allowsEdit, isFalse);
    canRead = false;
    expect(resource.isVisible, isFalse);
    expect(custom.allowsCreate, isFalse);
  });

  test('a custom edit screen supplies an edit the transport lacks', () {
    final resource = BeakResource(
      model: const _BoundModel(),
      icon: const BeakIconToken(OiIcons.notebook),
      screens: [
        BeakCustomResourceScreen(
          roles: const {BeakScreenRole.edit},
          builder: (_, id) => Text('edit $id'),
        ),
      ],
    );
    expect(resource.allowsEdit, isTrue);
    expect(resource.allowsCreate, isFalse);
    expect(
      resource.copyWith(canEdit: false).allowsEdit,
      isFalse,
      reason: 'canEdit still switches a custom edit screen off',
    );
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
