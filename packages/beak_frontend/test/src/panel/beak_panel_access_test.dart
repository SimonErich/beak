import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals.dart';
import 'package:signals_flutter/signals_flutter.dart' show SignalBuilder;

import '../../support/panel_fixtures.dart';

const _reader = BeakPrincipal(id: 'r', roles: {'reader'});
const _writer = BeakPrincipal(id: 'w', roles: {'reader', 'writer'});
const _refund = BeakModelAction(name: 'refund', label: 'Refund');

/// A model whose reads, writes and one command need different roles.
final class _GuardedModel extends BeakModel {
  const _GuardedModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const NoteModel().columns;

  @override
  BeakPermissions get permissions => const BeakPermissions(
    read: BeakAccess.role('reader'),
    write: BeakAccess.role('writer'),
    actions: {'refund': BeakAccess.role('finance')},
  );

  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(actions: [_refund]);
}

/// An adapter whose identity the test changes while the panel is open.
final class _Account extends BeakAuthAdapter {
  _Account(Set<String>? roles)
    : _state = signal(
        roles == null
            ? const BeakAuthGuest()
            : BeakAuthAuthenticated(
                BeakAuthIdentity(id: 'account', roles: roles),
              ),
      );

  final Signal<BeakAuthState> _state;

  @override
  ReadonlySignal<BeakAuthState> get state => _state;

  void grant(Set<String> roles) => _state.value = BeakAuthAuthenticated(
    BeakAuthIdentity(id: 'account', roles: roles),
  );

  void signOut() => _state.value = const BeakAuthGuest();

  @override
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  }) async => const BeakOk(null);

  @override
  Future<BeakResult<void>> logout() async => const BeakOk(null);

  @override
  Future<BeakResult<void>> refresh() async => const BeakOk(null);
}

void main() {
  group('BeakPanelAccess answers from the principal', () {
    test('role checks and the permission data decide every operation', () {
      const model = _GuardedModel();
      final reader = BeakPanelAccess.fixed(_reader);
      final writer = BeakPanelAccess.fixed(_writer);

      expect(reader.has('reader'), isTrue);
      expect(reader.has('writer'), isFalse);
      expect(reader.hasAny(['writer', 'reader']), isTrue);
      expect(reader.canRead(model), isTrue);
      expect(reader.can(model, BeakOperation.update), isFalse);
      expect(writer.can(model, BeakOperation.update), isTrue);
      expect(writer.can(model, BeakOperation.delete), isTrue);
      expect(BeakPanelAccess.anonymous.canRead(model), isFalse);
      expect(BeakPanelAccess.anonymous.principal, isNull);
    });

    test('a model that does not support an operation refuses it for all', () {
      const model = NoteModel();
      final access = BeakPanelAccess.fixed(_writer);

      expect(access.can(model, BeakOperation.create), isTrue);
      expect(
        access.can(const _ReadOnlyModel(), BeakOperation.create),
        isFalse,
        reason: 'the capabilities exclude create',
      );
      expect(
        access.permits(const _ReadOnlyModel(), BeakOperation.create),
        isTrue,
        reason: 'permits ignores the capabilities',
      );
    });

    test('a command needs read access and its own role', () {
      const model = _GuardedModel();

      expect(
        BeakPanelAccess.fixed(
          const BeakPrincipal(id: 'f', roles: {'reader', 'finance'}),
        ).canAction(model, _refund),
        isTrue,
      );
      expect(
        BeakPanelAccess.fixed(_writer).canAction(model, _refund),
        isFalse,
        reason: 'write does not stand in for the finance role',
      );
      expect(
        BeakPanelAccess.fixed(
          const BeakPrincipal(id: 'f', roles: {'finance'}),
        ).canAction(model, _refund),
        isFalse,
        reason: 'a command on a record the account cannot read',
      );
    });

    test('fromAuth follows the adapter through every state', () {
      final account = _Account(null);
      final access = BeakPanelAccess.fromAuth(account);
      final seen = <BeakPrincipal?>[];
      final stop = effect(() => seen.add(access.principal));
      addTearDown(stop);

      expect(access.principal, isNull);
      account.grant({'reader'});
      expect(
        access.principal,
        const BeakPrincipal(id: 'account', roles: {'reader'}),
      );
      account.grant({'reader', 'writer'});
      expect(access.has('writer'), isTrue);
      account.signOut();
      expect(access.principal, isNull);
      expect(seen.length, 4, reason: 'one change per transition');
    });

    test('an unchanged refresh does not announce a new principal', () {
      final account = _Account({'reader'});
      final access = BeakPanelAccess.fromAuth(account);
      var runs = 0;
      final stop = effect(() {
        access.principal;
        runs++;
      });
      addTearDown(stop);

      account.grant({'reader'});

      expect(runs, 1);
    });
  });

  group('BeakPanelAccess.of', () {
    testWidgets('builds the widget again when the roles change', (
      tester,
    ) async {
      final account = _Account({'reader'});
      final access = BeakPanelAccess.fromAuth(account);
      var builds = 0;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: _AccessProbe(access: access, onBuild: () => builds++),
        ),
      );
      expect(find.text('writer: no'), findsOneWidget);

      account.grant({'reader', 'writer'});
      await tester.pump();

      expect(find.text('writer: yes'), findsOneWidget);
      expect(builds, 2);
    });

    testWidgets('is anonymous outside a panel', (tester) async {
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: Builder(
            builder: (context) => Text(
              BeakPanelAccess.of(context).principal == null ? 'anon' : 'known',
            ),
          ),
        ),
      );

      expect(find.text('anon'), findsOneWidget);
    });
  });

  group('the panel follows live role changes', () {
    late _Account account;

    setUp(() => account = _Account({}));

    Future<GoRouter> pump(
      WidgetTester tester, {
      List<BeakScreen> pages = const [],
    }) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(
          config: BeakPanelConfig(
            title: 'Demo',
            resources: const [
              BeakResource(
                model: _GuardedModel(),
                title: 'Guarded notes',
                icon: BeakIconToken(OiIcons.lock),
              ),
              BeakResource(
                model: LabelModel(),
                icon: BeakIconToken(OiIcons.tag),
              ),
            ],
            pages: pages,
            auth: BeakAuthConfig(adapter: account),
          ),
          dataSource: FakeDataSource(),
        ),
      );
      await tester.pumpAndSettle();
      return GoRouter.of(tester.element(find.byType(OiAppShell)));
    }

    String pathOf(GoRouter router) =>
        router.routeInformationProvider.value.uri.path;

    testWidgets('a granted role opens the resource and its navigation entry', (
      tester,
    ) async {
      final router = await pump(tester);
      expect(find.text('Guarded notes'), findsNothing);
      router.go('/notes');
      await tester.pumpAndSettle();
      expect(pathOf(router), '/403');

      account.grant({'reader'});
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('Guarded notes'), findsWidgets);
      router.go('/notes');
      await tester.pumpAndSettle();
      expect(pathOf(router), '/notes');
    });

    testWidgets('create and edit routes need the write role', (tester) async {
      account.grant({'reader'});
      final router = await pump(tester);

      router.go('/notes/create');
      await tester.pumpAndSettle();
      expect(pathOf(router), '/403');
      router.go('/notes/n1/edit');
      await tester.pumpAndSettle();
      expect(pathOf(router), '/403');

      account.grant({'reader', 'writer'});
      await tester.pumpAndSettle();
      router.go('/notes/create');
      await tester.pumpAndSettle();
      expect(pathOf(router), '/notes/create');
    });

    testWidgets('the Create button follows the write role on the list', (
      tester,
    ) async {
      account.grant({'reader'});
      final router = await pump(tester);
      router.go('/notes');
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsNothing);

      account.grant({'reader', 'writer'});
      await tester.pumpAndSettle();

      expect(find.text('Create'), findsWidgets);
    });

    testWidgets('a screen guard and a visibility block follow the roles', (
      tester,
    ) async {
      account.grant({'reader'});
      final router = await pump(
        tester,
        pages: [
          BeakScreen(
            path: '/finance',
            title: 'Finance page',
            icon: const BeakIconToken(OiIcons.wallet),
            canAccess: (access) => access.has('finance'),
            body: BeakVisibilityBlock(
              visibleWhen: (access) => access.has('finance'),
              child: const BeakTextBlock('Ledger'),
            ),
          ),
        ],
      );
      router.go('/finance');
      await tester.pumpAndSettle();
      expect(pathOf(router), '/403');

      account.grant({'reader', 'finance'});
      await tester.pumpAndSettle();
      router.go('/finance');
      await tester.pumpAndSettle();

      expect(pathOf(router), '/finance');
      expect(find.text('Ledger'), findsOneWidget);
    });

    testWidgets('signing out hides everything that needs a role', (
      tester,
    ) async {
      account.grant({'reader'});
      await pump(tester);
      expect(find.text('Guarded notes'), findsWidgets);

      account.signOut();
      await tester.pumpAndSettle();

      expect(find.text('Guarded notes'), findsNothing);
    });

    testWidgets('the command bar lists what the roles allow', (tester) async {
      account.grant({'reader'});
      await pump(tester);
      final access = BeakPanelAccess.fromAuth(account);
      const config = BeakPanelConfig(
        title: 'Demo',
        resources: [
          BeakResource(model: _GuardedModel(), title: 'Guarded notes'),
        ],
      );

      expect(
        beakNavigationCommands(config, (_) {}, access: access),
        hasLength(1),
      );
      account.signOut();
      expect(beakNavigationCommands(config, (_) {}, access: access), isEmpty);
    });
  });
}

final class _ReadOnlyModel extends BeakModel {
  const _ReadOnlyModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const NoteModel().columns;

  @override
  Set<BeakOperation> get capabilities => const {BeakOperation.read};
}

class _AccessProbe extends HookWidget {
  const _AccessProbe({required this.access, required this.onBuild});

  final BeakPanelAccess access;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    // A SignalBuilder tracks every signal read below, like of(context) does.
    return SignalBuilder(
      builder: (context) {
        onBuild();
        return Text('writer: ${access.has('writer') ? 'yes' : 'no'}');
      },
    );
  }
}
