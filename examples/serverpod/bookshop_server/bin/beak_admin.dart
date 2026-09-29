// Grants and revokes admin access for an email account.
//
//   dart run bin/beak_admin.dart grant <email> [-- <serverpod args>]
//   dart run bin/beak_admin.dart revoke <email> [-- <serverpod args>]
//
// Run it from the server package, next to `config/`. It goes through
// Serverpod (`withSession` and AuthServices), never through SQL: with the
// embedded Postgres it attaches to the database a running server owns, or
// starts one for the call and stops it again.
//
// `grant` adds `beak.admin` (opens the Beak tunnel) and `bookshop.staff`
// (may read and write authors and books) to the account's scopes. It merges,
// because `authUsers.update(scopes:)` replaces the whole set. Scopes are copied
// into a token when it is issued, so the user signs in again to pick the grant
// up.
//
// `revoke` removes both and revokes every token of the user: removing a scope
// alone ends nothing while the client keeps refreshing its token. An access
// token that was already issued stays valid until it expires (10 minutes by
// default).
import 'dart:io';

import 'package:bookshop_server/server.dart' show initializeBookshopAuth;
import 'package:bookshop_server/src/beak/bookshop_scopes.dart';
import 'package:bookshop_server/src/generated/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

const String _usage =
    'usage: dart run bin/beak_admin.dart grant|revoke <email> '
    '[-- <serverpod args>]';

/// The scopes `grant` adds and `revoke` removes.
final Set<Scope> _adminScopes = {BookshopScopes.admin, BookshopScopes.staff};

Future<void> main(List<String> arguments) async {
  final int split = arguments.indexOf('--');
  final List<String> ours = split < 0 ? arguments : arguments.sublist(0, split);
  final List<String> serverpodArgs = split < 0
      ? const []
      : arguments.sublist(split + 1);
  if (ours.length != 2 || !{'grant', 'revoke'}.contains(ours.first)) {
    stderr.writeln(_usage);
    exit(64);
  }
  final String command = ours[0];
  final String email = ours[1].trim().toLowerCase();

  final pod = Serverpod(serverpodArgs);
  initializeBookshopAuth(pod);
  var exitStatus = 0;
  try {
    await pod.withSession((session) async {
      final account = await AuthServices.getIdentityProvider<EmailIdp>().admin
          .findAccount(session, email: email);
      if (account == null) {
        stderr.writeln('No email account for $email. Sign up first.');
        exitStatus = 1;
        return;
      }
      final users = AuthServices.instance.authUsers;
      final Set<String> before = (await users.get(
        session,
        authUserId: account.authUserId,
      )).scopeNames;
      final Set<String> adminNames = {
        for (final scope in _adminScopes) scope.name!,
      };
      final Set<String> after = switch (command) {
        'grant' => {...before, ...adminNames},
        _ => before.difference(adminNames),
      };
      await users.update(
        session,
        authUserId: account.authUserId,
        scopes: {for (final name in after) Scope(name)},
      );
      stdout.writeln(
        '$command $email: ${_sorted(before)} -> ${_sorted(after)}',
      );
      if (command == 'grant') {
        stdout.writeln(
          'Scopes are copied into a token when it is issued: '
          'sign in again to use them.',
        );
      } else {
        await AuthServices.instance.tokenManager.revokeAllTokens(
          session,
          authUserId: account.authUserId,
        );
        stdout.writeln('Revoked every token of $email.');
      }
    });
  } finally {
    await pod.shutdown(exitProcess: false);
  }
  exit(exitStatus);
}

String _sorted(Set<String> scopes) => '{${([...scopes]..sort()).join(', ')}}';
