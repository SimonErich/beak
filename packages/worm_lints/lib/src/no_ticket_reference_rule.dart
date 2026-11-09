/// Forbid internal ticket references (WI-XXX, AC-N) in comments.
library;

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Flags comments that contain `WI-<digits>` or `AC-<digits>`.
///
/// Internal ticket identifiers belong in commits, PR
/// descriptions, and the issue tracker — not in the
/// source tree, where they go stale and obscure the
/// "why" the comment is supposed to convey.
class NoTicketReferenceRule extends AnalysisRule {
  /// Creates a [NoTicketReferenceRule].
  NoTicketReferenceRule()
    : super(
        name: 'no_ticket_reference',
        description: 'Comments must not contain internal ticket references.',
      );

  /// The diagnostic reported at every offending comment.
  static const LintCode code = LintCode(
    'no_ticket_reference',
    'Comments must not contain internal ticket references (WI-XXX / AC-N).',
    correctionMessage:
        'Rewrite the comment with intent-focused language; '
        'track tickets in commits, PR descriptions, or the '
        'issue tracker instead.',
    severity: DiagnosticSeverity.WARNING,
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

  /// Every comment of [unit] that contains a ticket reference, in source
  /// order.
  static List<CommentToken> ticketCommentsIn(CompilationUnit unit) {
    final found = <CommentToken>[];
    Token? token = unit.beginToken;
    while (token != null) {
      CommentToken? comment = token.precedingComments;
      while (comment != null) {
        if (matches(comment.lexeme)) {
          found.add(comment);
        }
        final next = comment.next;
        comment = next is CommentToken ? next : null;
      }
      if (token == unit.endToken) break;
      token = token.next;
    }
    return found;
  }

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final NoTicketReferenceRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    NoTicketReferenceRule.ticketCommentsIn(node).forEach(rule.reportAtToken);
  }
}
