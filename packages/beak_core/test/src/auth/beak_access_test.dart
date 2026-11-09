import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

const _staffer = BeakPrincipal(id: 'u1', roles: {'staff'});
const _boss = BeakPrincipal(id: 'u2', roles: {'staff', 'manager'});
const _guest = BeakPrincipal(id: 'u3');

const _staff = BeakAccess.role('staff');
const _manager = BeakAccess.role('manager');

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

  group('BeakPrincipal', () {
    test('carries its roles and answers hasRole', () {
      expect(_boss.hasRole('manager'), isTrue);
      expect(_guest.hasRole('manager'), isFalse);
    });

    test('equality ignores the order of roles', () {
      expect(
        const BeakPrincipal(id: 'a', roles: {'x', 'y'}),
        const BeakPrincipal(id: 'a', roles: {'y', 'x'}),
      );
      expect(
        const BeakPrincipal(id: 'a', roles: {'x'}),
        isNot(const BeakPrincipal(id: 'a', roles: {'x', 'y'})),
      );
    });

    test('equal principals share a hash code, whatever the role order', () {
      expect(
        const BeakPrincipal(id: 'a', roles: {'x', 'y'}).hashCode,
        const BeakPrincipal(id: 'a', roles: {'y', 'x'}).hashCode,
      );
    });

    test('toString names the id and the sorted roles', () {
      expect(
        const BeakPrincipal(id: 'a', roles: {'z', 'b'}).toString(),
        'BeakPrincipal(a, roles: [b, z])',
      );
    });

    test('serialises with sorted roles for a stable wire shape', () {
      expect(const BeakPrincipal(id: 'a', roles: {'z', 'b'}).toJson(), {
        'id': 'a',
        'roles': ['b', 'z'],
      });
    });
  });
}
