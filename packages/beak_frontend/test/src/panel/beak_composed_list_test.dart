import 'dart:ui' show PointerDeviceKind;

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/query/beak_list_toolbar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
  ),
);

void main() {
  testWidgets('compact page lists scroll heading and rows to pagination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        dataSource: FakeDataSource(
          records: {
            'notes': {
              for (var i = 0; i < 30; i++)
                '$i': BeakRecord.fromRow({'id': '$i', 'title': 'Note $i'}),
            },
          },
        ),
        resources: [
          BeakResource(
            model: const NoteModel(),
            screens: [
              BeakTableScreen(
                definition: BeakListDefinition(
                  scrollMode: BeakListScrollMode.page,
                  pageSize: 15,
                  columns: [BeakTableColumn.field(_title)],
                  showPresetCounts: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
    await tester.pumpAndSettle();
    final heading = find.descendant(
      of: find.byType(OiPageHeader),
      matching: find.text('Notes'),
    );
    final next = find.byWidgetPredicate(
      (widget) => widget is OiTappable && widget.semanticLabel == 'Next page',
    );
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    expect(next.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(heading).dy, lessThan(0));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OiTable<BeakRecord>>(find.byType(OiTable<BeakRecord>))
          .controller!
          .pagination
          .currentPage,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('page scroll mode keeps intrinsic rows and reaches pagination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final mode in BeakListScrollMode.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      final source = FakeDataSource(
        records: {
          'notes': {
            for (var i = 0; i < 30; i++)
              '$i': BeakRecord.fromRow({'id': '$i', 'title': 'Note $i'}),
          },
        },
      );
      await tester.pumpWidget(
        BeakPanel(
          dataSource: source,
          resources: [
            BeakResource(
              model: const NoteModel(),
              screens: [
                BeakTableScreen(
                  definition: BeakListDefinition(
                    scrollMode: mode,
                    pageSize: 15,
                    columns: [BeakTableColumn.field(_title)],
                    showPresetCounts: false,
                    presets: const [
                      BeakQueryPreset(key: 'all', label: 'All', rowHeight: 56),
                    ],
                    initialPreset: 'all',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
      await tester.pumpAndSettle();
      final table = find.byType(OiTable<BeakRecord>);
      final next = find.byWidgetPredicate(
        (widget) => widget is OiTappable && widget.semanticLabel == 'Next page',
      );
      if (mode == BeakListScrollMode.page) {
        expect(tester.getSize(table).height, greaterThan(840));
        expect(tester.getTopLeft(next).dy, greaterThan(700));
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        expect(next.hitTestable(), findsOneWidget);
      } else {
        expect(tester.getSize(table).height, lessThan(700));
        expect(next.hitTestable(), findsOneWidget);
      }
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OiTable<BeakRecord>>(table)
            .controller!
            .pagination
            .currentPage,
        1,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('compact composed lists keep rows and pagination reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final titleFilter = _title.textFilter(label: 'Note title');
    await tester.pumpWidget(
      BeakPanel(
        dataSource: _SummarySource(),
        resources: [
          BeakResource(
            model: const NoteModel(),
            screens: [
              BeakTableScreen(
                definition: BeakListDefinition(
                  pageSize: 1,
                  showHeaderToggle: true,
                  presets: const [
                    BeakQueryPreset(key: 'all', label: 'All notes'),
                  ],
                  initialPreset: 'all',
                  columns: [BeakTableColumn.field(_title)],
                  filters: [titleFilter],
                  quickFilters: [titleFilter],
                  header: BeakWidgetBlock(
                    (_) => const SizedBox(
                      height: 260,
                      child: Text('Tall responsive overview'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
    await tester.pumpAndSettle();
    final table = find.byType(OiTable<BeakRecord>);
    expect(tester.getSize(table).height, greaterThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
    final next = find.byWidgetPredicate(
      (widget) => widget is OiTappable && widget.semanticLabel == 'Next page',
    );
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    expect(next.hitTestable(), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OiTable<BeakRecord>>(table)
          .controller!
          .pagination
          .currentPage,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation counts share permanent scopes and refresh after writes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _SummarySource();
      final resource = BeakResource(
        model: const NoteModel(),
        screens: [
          BeakTableScreen(
            query: BeakQuerySpec(
              table: 'notes',
              filter: _title.eq('Urgent note'),
            ),
            definition: BeakListDefinition(
              initialPreset: 'all',
              columns: [BeakTableColumn.field(_title)],
              presets: [
                const BeakQueryPreset(key: 'all', label: 'All'),
                BeakQueryPreset(
                  key: 'ordinary',
                  label: 'Ordinary',
                  filter: _title.eq('Ordinary note'),
                ),
              ],
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        BeakPanel(
          resources: [resource],
          dataSource: source,
          navigation: const BeakNavigation(
            sections: [
              BeakNavigationSection(
                key: 'work',
                label: 'Work',
                icon: OiIcons.inbox,
                items: [
                  BeakNavigationItem.resource(NoteModel(), showCount: true),
                  BeakNavigationItem.resource(
                    NoteModel(),
                    label: 'Ordinary destination',
                    preset: 'ordinary',
                    showCount: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      OiAppShell shell() => tester.widget<OiAppShell>(find.byType(OiAppShell));
      expect(shell().navigation.map((item) => item.badge), ['1', '0']);
      await beakDependencies(
        tester.element(find.byType(OiAppShell)),
      )<BeakDataSource>().create(
        'notes',
        BeakRecord.fromRow({'id': 'c', 'title': 'Urgent note'}),
      );
      await tester.pumpAndSettle();
      expect(shell().navigation.map((item) => item.badge), ['2', '0']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'counted presets share query, columns, URL and summary population',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _SummarySource();
      const count = BeakSummaryMeasure.count('records');
      final resource = BeakResource(
        model: const NoteModel(),
        screens: [
          BeakTableScreen(
            definition: BeakListDefinition(
              initialPreset: 'all',
              title: 'Order operations',
              subtitleBuilder: (counts) =>
                  '${counts['all'] ?? '—'} total · ${counts['attention'] ?? '—'} urgent',
              showHeaderToggle: true,
              presets: [
                const BeakQueryPreset(key: 'all', label: 'All'),
                BeakQueryPreset(
                  key: 'attention',
                  label: 'Attention',
                  filter: _title.eq('Urgent note'),
                  columns: [
                    BeakTableColumn(
                      key: 'issue',
                      label: 'Issue',
                      template: BeakRecordTemplate.fields(title: _title),
                    ),
                  ],
                ),
              ],
              columns: [BeakTableColumn.field(_title)],
              header: BeakSummaryBlock(
                title: 'Matching records',
                query: BeakSummarySpec(table: 'notes', measures: [count]),
                values: [
                  const BeakSummaryValue(measure: count, label: 'Records'),
                ],
              ),
              collapsedHeader: BeakSummaryBlock(
                title: 'Compact population',
                query: BeakSummarySpec(table: 'notes', measures: [count]),
                values: const [
                  BeakSummaryValue(measure: count, label: 'matching notes'),
                ],
                presentation: BeakSummaryPresentation.strip,
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        BeakPanel(resources: [resource], dataSource: source),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      router.go('/notes');
      await tester.pumpAndSettle();
      expect(find.text('Urgent note'), findsOneWidget);
      expect(find.text('Ordinary note'), findsOneWidget);
      expect(find.text('2 total · 1 urgent'), findsOneWidget);
      await beakDependencies(
        tester.element(find.byType(OiAppShell)),
      )<BeakDataSource>().create(
        'notes',
        BeakRecord.fromRow({'id': 'c', 'title': 'Another note'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 total · 1 urgent'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'All · 3',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Attention'));
      await tester.pumpAndSettle();
      expect(find.text('Issue'), findsWidgets);
      expect(find.text('Ordinary note'), findsNothing);
      expect(source.lastSummary?.filter, _title.eq('Urgent note'));
      await tester.tap(find.text('Show charts'));
      await tester.pumpAndSettle();
      expect(find.text('Matching records'), findsNothing);
      expect(find.text('matching notes'), findsOneWidget);
      expect(source.lastSummary?.filter, _title.eq('Urgent note'));
      expect(
        BeakQueryController.readUri(
          router.routeInformationProvider.value.uri,
        )?.preset,
        'attention',
      );
      expect(
        BeakQueryController.readUri(
          router.routeInformationProvider.value.uri,
        )?.showHeader,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'contextual record navigation returns to the originating preset and clears on plain URL',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final resource = BeakResource(
        model: const NoteModel(),
        screens: [
          BeakTableScreen(
            definition: BeakListDefinition(
              initialPreset: 'all',
              columns: [BeakTableColumn.field(_title)],
              presets: [
                const BeakQueryPreset(key: 'all', label: 'All'),
                BeakQueryPreset(
                  key: 'attention',
                  label: 'Attention',
                  filter: _title.eq('Urgent note'),
                ),
              ],
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        BeakPanel(
          resources: [resource],
          dataSource: _SummarySource(),
          navigation: const BeakNavigation(
            currentRecordBranch: true,
            sections: [
              BeakNavigationSection(
                key: 'work',
                label: 'Work',
                icon: OiIcons.shoppingBag,
                items: [
                  BeakNavigationItem.resource(
                    NoteModel(),
                    recordLabelMonospace: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      router.go('/notes');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attention'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Urgent note'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/notes/a');
      final shell = tester.widget<OiAppShell>(find.byType(OiAppShell));
      expect(shell.breadcrumbs!.map((item) => item.label), [
        'Notes',
        'Urgent note',
      ]);
      expect(shell.navigation.single.children!.single.label, 'Urgent note');
      expect(shell.navigation.single.children!.single.contextChild, isTrue);
      expect(shell.navigation.single.children!.single.monospace, isTrue);
      expect(shell.breadcrumbs!.last.monospace, isTrue);
      expect(find.text('Current record'), findsNothing);
      expect(find.byType(OiBreadcrumbs), findsOneWidget);
      await tester.tap(find.byType(BeakBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Ordinary note'), findsNothing);
      expect(
        BeakQueryController.readUri(
          router.routeInformationProvider.value.uri,
        )?.preset,
        'attention',
      );
      router.go('/notes');
      await tester.pumpAndSettle();
      expect(find.text('Ordinary note'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short result tables keep selection actions at the page bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<BeakRecord>? received;
    final resource = BeakResource(
      model: const NoteModel(),
      bulkActions: [
        BeakBulkAction(
          key: 'archive',
          label: 'Archive notes',
          onExecute: (records, _) async => received = records,
        ),
      ],
      screens: [
        BeakTableScreen(
          definition: BeakListDefinition(
            fitTableToRows: true,
            floatingBulkActions: true,
            columns: [BeakTableColumn.field(_title)],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      BeakPanel(resources: [resource], dataSource: _SummarySource()),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
    await tester.pumpAndSettle();
    final table = find.byType(OiTable<BeakRecord>);
    expect(tester.getSize(table).height, lessThan(350));
    final tableTop = tester.getTopLeft(table);
    final select = find.byWidgetPredicate(
      (widget) =>
          widget is OiCheckbox && widget.semanticLabel == 'Select row 1',
    );
    await tester.tap(select, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.byType(OiBulkBar), findsOneWidget);
    expect(tester.getTopLeft(table), tableTop);
    expect(tester.getBottomLeft(find.byType(OiBulkBar)).dy, greaterThan(800));
    await tester.tap(find.text('Archive notes'));
    await tester.pumpAndSettle();
    expect(received, hasLength(1));
    expect(received!.single['id']?.raw, 'a');
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is OiButton && widget.semanticLabel == 'Clear selection',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OiBulkBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filter sheet previews without changing active rows until Apply',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final titleFilter = _title.textFilter(label: 'Note title');
      final resource = BeakResource(
        model: const NoteModel(),
        screens: [
          BeakTableScreen(
            definition: BeakListDefinition(
              showSearch: false,
              columns: [BeakTableColumn.field(_title)],
              filters: [titleFilter],
              quickFilters: [titleFilter],
              quickFilterLabels: {titleFilter: 'Title'},
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        BeakPanel(resources: [resource], dataSource: _SummarySource()),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OiFilterChip, 'Title'), findsOneWidget);
      await tester.tap(find.widgetWithText(OiFilterChip, 'Title'));
      await tester.pumpAndSettle();
      expect(find.text('Note title'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'Urgent');
      await tester.pumpAndSettle();
      expect(find.text('Show 1 records'), findsOneWidget);
      expect(find.text('Ordinary note'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is OiTappable && widget.semanticLabel == 'Close',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ordinary note'), findsOneWidget);
      await tester.tap(find.text('All filters'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Urgent');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 1 records'));
      await tester.pumpAndSettle();
      expect(find.text('Ordinary note'), findsNothing);
      expect(find.text('All filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'long filter drawers keep review actions visible while fields scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final resource = BeakResource(
        model: const NoteModel(),
        screens: [
          BeakTableScreen(
            definition: BeakListDefinition(
              showSearch: false,
              columns: [BeakTableColumn.field(_title)],
              filters: [
                for (var index = 0; index < 12; index++)
                  BeakTextFilter(
                    field: BeakScalarField<Object>(
                      model: const NoteModel(),
                      column: BeakStringColumn(
                        key: 'filter_$index',
                        label: 'Filter $index',
                      ),
                    ),
                    label: 'Filter $index',
                  ),
              ],
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        BeakPanel(resources: [resource], dataSource: _SummarySource()),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
      await tester.pumpAndSettle();
      await tester.tap(find.text('All filters'));
      await tester.pumpAndSettle();
      final apply = find.text('Show 2 records');
      final original = tester.getCenter(apply);
      expect(apply.hitTestable(), findsOneWidget);
      expect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is OiTappable && widget.semanticLabel == 'Close',
            )
            .hitTestable(),
        findsOneWidget,
      );
      final scroll = find.descendant(
        of: find.byType(BeakFilterEditor),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.getCenter(apply), original);
      expect(apply.hitTestable(), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is OiTappable && widget.semanticLabel == 'Close',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BeakFilterEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('workspace header and bottom navigation share shell routing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        dataSource: _SummarySource(),
        resources: const [BeakResource(model: NoteModel())],
        pages: const [
          BeakScreen(
            path: '/settings',
            title: 'Workspace settings',
            icon: BeakIconToken(OiIcons.settings),
            body: BeakTextBlock('Settings content'),
          ),
        ],
        navigation: BeakNavigation(
          headerBuilder: (_, section) => OiLabel.body('Workspace: $section'),
          userMenu: const OiLabel.body('Account menu'),
          searchPlaceholder: 'Search the workspace',
          showThemeToggle: false,
          sections: const [
            BeakNavigationSection(
              key: 'work',
              label: 'Work',
              icon: OiIcons.shoppingBag,
              items: [BeakNavigationItem.resource(NoteModel())],
            ),
            BeakNavigationSection(
              key: 'settings',
              label: 'Settings',
              icon: OiIcons.settings,
              bottom: true,
              items: [
                BeakNavigationItem.page(
                  '/settings',
                  label: 'Workspace settings',
                  icon: OiIcons.settings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Workspace: Work'), findsOneWidget);
    expect(find.text('Account menu'), findsOneWidget);
    expect(find.text('Search the workspace'), findsOneWidget);
    expect(find.byType(OiThemeToggle), findsNothing);
    final rails = tester
        .widgetList<OiNavigationRail>(find.byType(OiNavigationRail))
        .toList();
    expect(rails, hasLength(2));
    expect(rails.last.items.single.label, 'Settings');
    expect(
      tester.getTopLeft(find.byType(OiNavigationRail).last).dy,
      greaterThan(800),
    );
    rails.last.onTap(0);
    await tester.pumpAndSettle();
    expect(find.text('Workspace: Settings'), findsOneWidget);
    expect(find.text('Settings content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _SummarySource extends FakeDataSource
    implements BeakSummaryDataSource {
  _SummarySource()
    : super(
        records: {
          'notes': {
            'a': BeakRecord.fromRow({'id': 'a', 'title': 'Urgent note'}),
            'b': BeakRecord.fromRow({'id': 'b', 'title': 'Ordinary note'}),
          },
        },
      );
  BeakSummarySpec? lastSummary;
  @override
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) async {
    lastSummary = spec;
    final page = await query(
      BeakQuerySpec(
        table: spec.table,
        filter: spec.filter,
        search: spec.search,
      ),
    );
    return BeakSummaryResult(
      rows: [
        BeakSummaryRow(
          group: const BeakNullValue(),
          values: {'records': page.total},
        ),
      ],
      truncated: false,
    );
  }
}
