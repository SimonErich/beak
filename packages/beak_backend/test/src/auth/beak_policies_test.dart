/// The typed rule set is a policy like any other: these tests pin what its
/// hooks answer, before any handler is involved.
library;

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/api_models.dart';

const _staffer = BeakPrincipal(id: 'u1', roles: {'staff'});
const _boss = BeakPrincipal(id: 'u2', roles: {'staff', 'manager'});
const _guest = BeakPrincipal(id: 'u3');

const _staff = BeakAccess.role('staff');
const _manager = BeakAccess.role('manager');

/// A model that declares one command, for the action rules.
final class _Ticket extends BeakModel {
  const _Ticket();

  static const close = BeakModelAction(name: 'close', label: 'Close');
  static const reopen = BeakModelAction(name: 'reopen', label: 'Reopen');

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => NoteColumns.values;

  @override
  BeakModelBehavior get behavior =>
      const BeakModelBehavior(actions: [close, reopen]);
}

void main() {
  group('BeakAccess', () {
    test('a role admits exactly the principals carrying it', () {
      expect(_staff.allows(_staffer), isTrue);
      expect(_staff.allows(_guest), isFalse);
      expect(_staff.allows(null), isFalse);
    });

    test('authenticated admits any signed-in principal, never anonymous', () {
      expect(BeakAccess.authenticated.allows(_guest), isTrue);
      expect(BeakAccess.authenticated.allows(_staffer), isTrue);
      expect(BeakAccess.authenticated.allows(null), isFalse);
    });

    test('anyone admits an anonymous request too', () {
      expect(BeakAccess.anyone.allows(null), isTrue);
      expect(BeakAccess.anyone.allows(_guest), isTrue);
    });

    test('any admits when one member does', () {
      const either = BeakAccess.any([_staff, _manager]);
      expect(either.allows(_staffer), isTrue);
      expect(
        either.allows(const BeakPrincipal(id: 'm', roles: {'manager'})),
        isTrue,
      );
      expect(either.allows(_guest), isFalse);
    });

    test('all admits only when every member does', () {
      const both = BeakAccess.all([_staff, _manager]);
      expect(both.allows(_boss), isTrue);
      expect(both.allows(_staffer), isFalse);
      expect(both.allows(null), isFalse);
    });

    test('an empty combinator grants nothing', () {
      expect(const BeakAccess.any([]).allows(_boss), isFalse);
      expect(const BeakAccess.all([]).allows(_boss), isFalse);
    });

    test('not inverts, so anonymous is admitted by not(authenticated)', () {
      const anonymousOnly = BeakAccess.not(BeakAccess.authenticated);
      expect(anonymousOnly.allows(null), isTrue);
      expect(anonymousOnly.allows(_guest), isFalse);
      expect(const BeakAccess.not(_staff).allows(_guest), isTrue);
    });
  });

  group('BeakModelRules', () {
    test('rejects a read-only field of another model', () {
      expect(
        () => BeakModelRules(
          const NoteModel(),
          readOnlyFields: {LabelModel.name},
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a read-only field reached through a relationship', () {
      final viaAuthor = BeakScalarField<String>(
        model: const NoteModel(),
        column: NoteColumns.title,
        path: [const NoteModel().relationships.first],
      );
      expect(
        () => BeakModelRules(const NoteModel(), readOnlyFields: {viaAuthor}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a hidden field of another model', () {
      expect(
        () => BeakModelRules(
          const NoteModel(),
          hiddenFields: {LabelModel.name: _staff},
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a hidden field reached through a relationship', () {
      final viaAuthor = BeakScalarField<String>(
        model: const NoteModel(),
        column: NoteColumns.title,
        path: [const NoteModel().relationships.first],
      );
      expect(
        () => BeakModelRules(
          const NoteModel(),
          hiddenFields: {viaAuthor: _staff},
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects an action the model does not declare', () {
      expect(
        () =>
            BeakModelRules(const NoteModel(), actions: {_Ticket.close: _staff}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('BeakPolicies', () {
    test('two rules for one model are a configuration error', () {
      expect(
        () => BeakPolicies(
          rules: [
            BeakModelRules(const NoteModel(), read: _staff),
            BeakModelRules(const NoteModel(), write: _staff),
          ],
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a model with no rule is invisible and immutable to everyone', () {
      final policies = BeakPolicies(
        rules: [BeakModelRules(const LabelModel(), read: BeakAccess.anyone)],
      );
      const note = NoteModel();
      for (final principal in [null, _guest, _staffer, _boss]) {
        expect(policies.canView(principal, note), isFalse);
        expect(policies.canCreate(principal, note), isFalse);
        expect(policies.canUpdate(principal, note, 'n1'), isFalse);
        expect(policies.canDelete(principal, note, 'n1'), isFalse);
        expect(
          policies.canDeleteUpload(principal, note, NoteColumns.avatar, 'k'),
          isFalse,
        );
        expect(policies.scopeFor(principal, note), isNull);
        expect(
          policies.canReadField(principal, note, NoteModel.title),
          isFalse,
        );
        expect(
          policies.canWriteField(principal, note, NoteModel.title),
          isFalse,
        );
      }
    });

    test(
      'an operation left out of a rule is denied, and none implies another',
      () {
        final policies = BeakPolicies(
          rules: [BeakModelRules(const NoteModel(), write: _staff)],
        );
        const note = NoteModel();
        expect(policies.canCreate(_staffer, note), isTrue);
        expect(policies.canUpdate(_staffer, note, 'n1'), isTrue);
        expect(policies.canView(_staffer, note), isFalse);
        expect(policies.canDelete(_staffer, note, 'n1'), isFalse);
      },
    );

    test('each operation consults its own access', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const NoteModel(),
            read: BeakAccess.authenticated,
            write: _staff,
            delete: _manager,
          ),
        ],
      );
      const note = NoteModel();
      expect(policies.canView(_guest, note), isTrue);
      expect(policies.canView(null, note), isFalse);
      expect(policies.canCreate(_staffer, note), isTrue);
      expect(policies.canUpdate(_staffer, note, 'n1'), isTrue);
      expect(policies.canUpdate(_guest, note, 'n1'), isFalse);
      expect(policies.canDelete(_staffer, note, 'n1'), isFalse);
      expect(policies.canDelete(_boss, note, 'n1'), isTrue);
    });

    test('removing an upload takes the delete access', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(const NoteModel(), write: _staff, delete: _manager),
        ],
      );
      expect(
        policies.canDeleteUpload(
          _staffer,
          const NoteModel(),
          NoteColumns.avatar,
          'k',
        ),
        isFalse,
      );
      expect(
        policies.canDeleteUpload(
          _boss,
          const NoteModel(),
          NoteColumns.avatar,
          'k',
        ),
        isTrue,
      );
    });

    test('a rule matches its model by table, not by instance', () {
      final policies = BeakPolicies(
        rules: [BeakModelRules(const NoteModel(), read: _staff)],
      );
      expect(policies.canView(_staffer, const _Ticket()), isTrue);
    });

    test('the row scope is built for the principal, or absent', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const NoteModel(),
            read: BeakAccess.authenticated,
            rowScope: (principal) => NoteModel.authorId.eq(principal.id),
          ),
          BeakModelRules(const LabelModel(), read: BeakAccess.authenticated),
        ],
      );
      expect(
        policies.scopeFor(_staffer, const NoteModel()),
        NoteModel.authorId.eq('u1'),
      );
      expect(policies.scopeFor(_staffer, const LabelModel()), isNull);
    });

    test('an anonymous request gets a scope that matches no row', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const NoteModel(),
            read: BeakAccess.anyone,
            rowScope: (principal) => NoteModel.authorId.eq(principal.id),
          ),
        ],
      );
      final scope = policies.scopeFor(null, const NoteModel());
      expect(scope, isNotNull);
      expect(scope, isNot(NoteModel.authorId.eq(null)));
    });

    test('a field is readable and writable exactly as its model is', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(const NoteModel(), read: _staff, write: _manager),
        ],
      );
      const note = NoteModel();
      expect(policies.canReadField(_staffer, note, NoteModel.title), isTrue);
      expect(policies.canReadField(_guest, note, NoteModel.title), isFalse);
      expect(policies.canWriteField(_staffer, note, NoteModel.title), isFalse);
      expect(policies.canWriteField(_boss, note, NoteModel.title), isTrue);
    });

    test('a hidden field is unreadable and unwritable for who it is hidden '
        'from, and open to the rest', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const NoteModel(),
            read: BeakAccess.authenticated,
            write: BeakAccess.authenticated,
            hiddenFields: {NoteModel.rating: const BeakAccess.not(_manager)},
          ),
        ],
      );
      const note = NoteModel();

      expect(policies.canReadField(_boss, note, NoteModel.rating), isTrue);
      expect(policies.canWriteField(_boss, note, NoteModel.rating), isTrue);
      expect(policies.canReadField(_staffer, note, NoteModel.rating), isFalse);
      expect(policies.canWriteField(_staffer, note, NoteModel.rating), isFalse);
      expect(policies.canReadField(_staffer, note, NoteModel.title), isTrue);
      expect(policies.canWriteField(_staffer, note, NoteModel.title), isTrue);
    });

    test('hiding a field never opens what the model rules deny', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const NoteModel(),
            read: _manager,
            hiddenFields: {NoteModel.rating: _staff},
          ),
        ],
      );
      const note = NoteModel();

      const managerOnly = BeakPrincipal(id: 'm', roles: {'manager'});

      expect(policies.canReadField(_staffer, note, NoteModel.title), isFalse);
      expect(
        policies.canReadField(managerOnly, note, NoteModel.rating),
        isTrue,
      );
      expect(policies.canReadField(_boss, note, NoteModel.rating), isFalse);
    });

    test('a hidden field belongs to the model that declared it', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const NoteModel(),
            read: BeakAccess.authenticated,
            hiddenFields: {NoteModel.rating: BeakAccess.authenticated},
          ),
          BeakModelRules(const LabelModel(), read: BeakAccess.authenticated),
        ],
      );

      expect(
        policies.canReadField(_staffer, const LabelModel(), LabelModel.name),
        isTrue,
      );
    });

    test('a read-only field is named by its typed reference', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const NoteModel(),
            write: _staff,
            readOnlyFields: {NoteModel.rating},
          ),
        ],
      );
      const note = NoteModel();
      expect(
        policies.isFieldReadOnly(_staffer, note, NoteModel.rating),
        isTrue,
      );
      expect(
        policies.isFieldReadOnly(_staffer, note, NoteModel.title),
        isFalse,
      );
      expect(
        policies.isFieldReadOnly(
          _staffer,
          const LabelModel(),
          NoteModel.rating,
        ),
        isFalse,
        reason: 'the field belongs to another model than the one asked about',
      );
    });

    test('only the listed actions run, each under its own access', () {
      final policies = BeakPolicies(
        rules: [
          BeakModelRules(
            const _Ticket(),
            write: _staff,
            actions: {_Ticket.close: _staff, _Ticket.reopen: _manager},
          ),
          BeakModelRules(const LabelModel(), write: _staff),
        ],
      );
      const ticket = _Ticket();
      expect(
        policies.canExecuteAction(_staffer, ticket, 't1', _Ticket.close),
        isTrue,
      );
      expect(
        policies.canExecuteAction(_staffer, ticket, 't1', _Ticket.reopen),
        isFalse,
      );
      expect(
        policies.canExecuteAction(_boss, ticket, 't1', _Ticket.reopen),
        isTrue,
      );
      expect(
        policies.canExecuteAction(null, ticket, null, _Ticket.close),
        isFalse,
      );
    });

    test('an action of a model with a rule but no action entry is denied', () {
      final policies = BeakPolicies(
        rules: [BeakModelRules(const _Ticket(), write: _staff)],
      );
      expect(
        policies.canExecuteAction(_boss, const _Ticket(), 't1', _Ticket.close),
        isFalse,
      );
    });
  });
}
