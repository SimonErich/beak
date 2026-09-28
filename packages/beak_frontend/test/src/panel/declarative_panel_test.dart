import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  testWidgets('a resource list is enough to build a panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(resources: [NoteResource()], dataSource: FakeDataSource()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OiAppShell), findsOneWidget);
    expect(find.text('Writing'), findsOneWidget);
    await tester.tap(find.text('Writing'));
    await tester.pumpAndSettle();
    expect(find.byType(BeakResourceListPage), findsOneWidget);
    expect(find.text('Notes'), findsWidgets);
  });

  testWidgets('simultaneous panels keep dependencies and routes isolated', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = FakeDataSource(
      records: {
        'notes': {
          'a': BeakRecord.fromRow({'id': 'a', 'title': 'First store'}),
        },
      },
    );
    final second = FakeDataSource(
      records: {
        'notes': {
          'b': BeakRecord.fromRow({'id': 'b', 'title': 'Second store'}),
        },
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: BeakPanel(resources: [NoteResource()], dataSource: first),
            ),
            Expanded(
              child: BeakPanel(resources: [NoteResource()], dataSource: second),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final shells = tester.elementList(find.byType(OiAppShell)).toList();
    expect(
      beakDependencies(shells[0]),
      isNot(same(beakDependencies(shells[1]))),
    );
    GoRouter.of(shells[0]).go('/notes');
    GoRouter.of(shells[1]).go('/notes');
    await tester.pumpAndSettle();
    expect(find.text('First store'), findsOneWidget);
    expect(find.text('Second store'), findsOneWidget);
  });

  testWidgets('resource roles select configured forms and custom screens', (
    tester,
  ) async {
    const model = NoteModel();
    const name = BeakScalarField<String>(
      model: model,
      column: BeakStringColumn(key: 'title', label: 'Title'),
    );
    final resource = BeakResource(
      model: model,
      screens: [
        BeakFormScreen(
          roles: const {
            BeakScreenRole.read,
            BeakScreenRole.create,
            BeakScreenRole.edit,
          },
          layout: BeakFormLayout(
            children: [
              BeakCard(title: 'Configured note', children: [name.inputText()]),
            ],
          ),
        ),
        BeakCustomResourceScreen(
          roles: const {BeakScreenRole.list},
          builder: (_, _) => const OiLabel.body('Custom list'),
        ),
      ],
    );
    await tester.pumpWidget(
      BeakPanel(
        resources: [resource],
        dataSource: FakeDataSource(
          records: {
            'notes': {
              'a': BeakRecord.fromRow({'id': 'a', 'title': 'Existing note'}),
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go('/notes');
    await tester.pumpAndSettle();
    expect(find.text('Custom list'), findsOneWidget);
    router.go('/notes/a');
    await tester.pumpAndSettle();
    expect(find.byType(BeakConfiguredForm), findsOneWidget);
    expect(find.text('Configured note'), findsOneWidget);
    expect(
      tester.widget<BeakPageScaffold>(find.byType(BeakPageScaffold)).title,
      'Existing note',
    );
    expect(
      find.descendant(
        of: find.byType(OiCard),
        matching: find.textContaining('Existing note'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'record page title follows loaded data instead of a create default',
    (tester) async {
      final printed = <String?>[];
      const model = _DefaultTitleModel();
      const name = BeakScalarField<String>(
        model: model,
        column: _DefaultTitleModel.title,
      );
      final source = FakeDataSource(
        models: const [model],
        records: {
          'named_records': {
            'a': BeakRecord.fromRow({'id': 'a', 'title': 'Loaded record'}),
          },
        },
      );
      await tester.pumpWidget(
        BeakPanel(
          resources: [
            BeakResource(
              model: model,
              recordActions: [
                BeakRecordAction(
                  key: 'print',
                  label: 'Print record',
                  onExecute: (record, _) async =>
                      printed.add(name.readFrom(record)),
                ),
              ],
              screens: [
                BeakFormScreen(
                  recordHeader: BeakRecordTemplate(
                    title: BeakValueBinding.field(name),
                    subtitle: [
                      BeakValueBinding.field(
                        const BeakScalarField<String>(
                          model: model,
                          column: BeakStringColumn(key: 'id', label: 'Id'),
                        ),
                      ),
                    ],
                    badges: [
                      BeakValueBinding<String>.computed(
                        dependencies: const [],
                        compute: (_) => 'Ready',
                        badge: true,
                      ),
                    ],
                  ),
                  roles: const {BeakScreenRole.read, BeakScreenRole.edit},
                  layout: BeakFormLayout(
                    children: [
                      BeakCard(
                        title: 'Record data',
                        children: [
                          BeakFormTemplate(
                            template: BeakRecordTemplate.fields(title: name),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          dataSource: source,
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      router.go('/named_records/a');
      await tester.pumpAndSettle();
      expect(find.text('Draft'), findsNothing);
      final printButton = find.descendant(
        of: find.byType(OiPageHeader),
        matching: find.text('Print record'),
      );
      expect(printButton, findsOneWidget);
      await tester.tap(printButton);
      await tester.pumpAndSettle();
      expect(printed, ['Loaded record']);
      expect(
        find.descendant(
          of: find.byType(OiPageHeader),
          matching: find.text('Ready'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(OiPageHeader),
          matching: find.text('a'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<BeakPageScaffold>(find.byType(BeakPageScaffold)).title,
        'Loaded record',
      );
      expect(
        tester.widget<BeakPageScaffold>(find.byType(BeakPageScaffold)).surface,
        isFalse,
      );
      expect(
        find.descendant(
          of: find.byType(OiPageHeader),
          matching: find.text('Edit'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(OiPageHeader),
          matching: find.text('Save'),
        ),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await beakDependencies(
        tester.element(find.byType(OiAppShell)),
      )<BeakDataSource>().update(
        model.table,
        'a',
        BeakRecord.fromRow({'title': 'Refreshed record'}),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeakPageScaffold>(find.byType(BeakPageScaffold)).title,
        'Refreshed record',
      );
      expect(find.text('Loaded record'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('ambiguous routes and foreign search fields fail during setup', () {
    const duplicate = BeakPanelConfig(
      title: 'Admin',
      resources: [
        BeakResource(
          model: NoteModel(),
          screens: [BeakFormScreen(), BeakFormScreen()],
        ),
      ],
    );
    expect(duplicate.buildRegistry, throwsA(isA<BeakConfigurationException>()));
    const wrongSearch = BeakPanelConfig(
      title: 'Admin',
      resources: [
        BeakResource(
          model: NoteModel(),
          globalSearchSources: [
            BeakScalarField<String>(
              model: LabelModel(),
              column: BeakStringColumn(key: 'name', label: 'Label'),
            ),
          ],
        ),
      ],
    );
    expect(
      wrongSearch.buildRegistry,
      throwsA(isA<BeakConfigurationException>()),
    );
    const wrongTable = BeakPanelConfig(
      title: 'Admin',
      resources: [
        BeakResource(
          model: NoteModel(),
          screens: [BeakTableScreen(query: BeakQuerySpec(table: 'labels'))],
        ),
      ],
    );
    expect(
      wrongTable.buildRegistry,
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('navigation rank orders resources without changing registration', () {
    final notes = NoteResource();
    const labels = BeakResource(
      model: LabelModel(),
      navigationRank: 1,
      navigationGroup: 'Catalog',
    );
    final config = BeakPanelConfig(title: 'Admin', resources: [notes, labels]);
    expect(config.navigationResources, [labels, notes]);
    expect(config.resources, [notes, labels]);
    expect(notes.copyWith().navigationTitle, 'Writing');
    expect(notes.copyWith().navigationRank, 3);
  });

  test('related models are registered once without navigation entries', () {
    const config = BeakPanelConfig(
      title: 'Admin',
      resources: [BeakResource(model: ParentModel())],
    );
    expect(config.buildRegistry().all.map((model) => model.table), [
      'parents',
      'children',
    ]);
    expect(config.navigationResources, hasLength(1));
  });
}

class NoteResource extends BeakResource {
  NoteResource()
    : super(
        model: const NoteModel(),
        title: 'Notes',
        navigationTitle: 'Writing',
        navigationGroup: 'Content',
        navigationRank: 3,
      );
}

final class ParentModel extends BeakModel {
  const ParentModel();

  @override
  String get table => 'parents';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];

  @override
  List<BeakModel> get relatedModels => const [ChildModel()];
}

final class ChildModel extends BeakModel {
  const ChildModel();

  @override
  String get table => 'children';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];

  @override
  List<BeakModel> get relatedModels => const [ParentModel()];
}

final class _DefaultTitleModel extends BeakModel {
  const _DefaultTitleModel();
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    defaultValue: 'Draft',
  );
  @override
  String get table => 'named_records';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    title,
  ];
}
