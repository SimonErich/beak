/// Forbid internal ticket references (WI-XXX, AC-N) in comments.
library;

import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags comments that contain `WI-<digits>` or `AC-<digits>`.
///
/// Internal ticket identifiers belong in commits, PR
/// descriptions, and the issue tracker — not in the
/// source tree, where they go stale and obscure the
/// "why" the comment is supposed to convey.
class NoTicketReferenceRule extends DartLintRule {
  /// Creates a [NoTicketReferenceRule].
  NoTicketReferenceRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'no_ticket_reference',
    problemMessage:
        'Comments must not contain internal ticket references '
        '(WI-XXX / AC-N).',
    correctionMessage:
        'Rewrite the comment with intent-focused language; '
        'track tickets in commits, PR descriptions, or the '
        'issue tracker instead.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  /// Pattern detected by this rule.
  ///
  /// Exposed for direct unit testing — the test does not
  /// need to spin up the analyzer to verify the
  /// classification logic.
  static final RegExp pattern = RegExp(r'WI-\d+|AC-\d+');

  /// Returns `true` when [commentText] contains a forbidden
  /// ticket reference.
  static bool matches(String commentText) => pattern.hasMatch(commentText);

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      Token? token = node.beginToken;
      while (token != null) {
        CommentToken? comment = token.precedingComments;
        while (comment != null) {
          if (matches(comment.lexeme)) {
            reporter.atToken(comment, _code);
          }
          final next = comment.next;
          comment = next is CommentToken ? next : null;
        }
        if (token == node.endToken) break;
        token = token.next;
      }
    });
  }
}
