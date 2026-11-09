// Deliberately imports only the server library: BeakAccess and BeakPrincipal
// moved to beak_core, and a server must still need one import to write rules.
import 'package:beak_backend/beak_backend.dart';
import 'package:test/test.dart';

void main() {
  test('BeakAccess and BeakPrincipal come with the server library', () {
    const access = BeakAccess.any([
      BeakAccess.role('staff'),
      BeakAccess.role('manager'),
    ]);

    expect(
      access.allows(const BeakPrincipal(id: 'u1', roles: {'manager'})),
      isTrue,
    );
    expect(access.allows(null), isFalse);
  });
}
