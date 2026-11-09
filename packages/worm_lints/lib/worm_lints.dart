/// Lint rules enforcing worm ORM coding conventions.
///
/// The analysis server loads these through `package:worm_lints/main.dart`; this
/// barrel exposes the rules for direct use in tests.
library;

export 'src/no_ticket_reference_rule.dart' show NoTicketReferenceRule;
