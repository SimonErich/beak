import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:worm_lints/worm_lints.dart';

void main() {
  group('NoTicketReferenceRule.matches', () {
    test('flags WI-001 in a comment', () {
      expect(NoTicketReferenceRule.matches('// WI-001 fix the thing'), isTrue);
    });

    test('flags WI-42 in a doc comment', () {
      expect(
        NoTicketReferenceRule.matches('/// WI-42 — backfill plan'),
        isTrue,
      );
    });

    test('flags AC-1 in a comment', () {
      expect(NoTicketReferenceRule.matches('// (AC-1)'), isTrue);
    });

    test('flags AC-9 in a comment', () {
      expect(NoTicketReferenceRule.matches('// AC-9 cancel chain'), isTrue);
    });

    test('flags WI-XXX and AC-N when both appear', () {
      expect(
        NoTicketReferenceRule.matches('// WI-001 / AC-3 ordering rules'),
        isTrue,
      );
    });

    test('does NOT flag LEGACY_ACCOUNT-style identifiers', () {
      expect(
        NoTicketReferenceRule.matches('// rename LEGACY_ACCOUNT to Account'),
        isFalse,
      );
    });

    test('does NOT flag doc references like [WormException]', () {
      expect(
        NoTicketReferenceRule.matches('/// Throws [WormException] on miss.'),
        isFalse,
      );
    });

    test('does NOT flag the bare letters AC or WI without -digit', () {
      expect(
        NoTicketReferenceRule.matches('// air conditioning AC unit'),
        isFalse,
      );
      expect(
        NoTicketReferenceRule.matches('// WI is the Wi-Fi prefix'),
        isFalse,
      );
    });

    test('does NOT flag WI- followed by non-digit', () {
      expect(
        NoTicketReferenceRule.matches('// WI-something not a ticket'),
        isFalse,
      );
    });

    test('does NOT flag lowercase variants (rule is case-sensitive)', () {
      expect(NoTicketReferenceRule.matches('// wi-001 lowercase'), isFalse);
      expect(NoTicketReferenceRule.matches('// ac-1 lowercase'), isFalse);
    });
  });

  group('rule scans the worm fixture file', () {
    test('finds exactly one comment per ticket-reference line', () async {
      // Resolve the fixture path through the package-resolution
      // machinery instead of the process CWD so the test passes
      // regardless of where `dart test` is invoked from.
      final barrelUri = await Isolate.resolvePackageUri(
        Uri.parse('package:worm_lints/worm_lints.dart'),
      );
      expect(
        barrelUri,
        isNotNull,
        reason: 'package:worm_lints/worm_lints.dart must be resolvable',
      );
      final wormLintsLib = File.fromUri(barrelUri!).parent;
      final worktreeRoot = wormLintsLib.parent.parent;
      final fixture = File(
        '${worktreeRoot.path}/worm/test/lint_fixtures/'
        'ticket_reference_fixture.dart',
      );
      expect(
        fixture.existsSync(),
        isTrue,
        reason: 'fixture missing at ${fixture.path}',
      );
      final unit = parseString(
        content: fixture.readAsStringSync(),
        throwIfDiagnostics: false,
      ).unit;
      final comments = NoTicketReferenceRule.ticketCommentsIn(unit);
      expect(comments, hasLength(5));
      expect(
        comments.map((comment) => comment.lexeme),
        everyElement(matches(NoTicketReferenceRule.pattern)),
        reason: 'every reported comment must carry a ticket reference',
      );
    });
  });
}
