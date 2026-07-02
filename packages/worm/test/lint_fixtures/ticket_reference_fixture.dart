// Intentionally bad: this file exists to assert that
// `no_ticket_reference` fires on internal ticket
// identifiers in comments. It is excluded from the
// real lint sweep but scanned by the rule's own test
// harness.
//
// WI-001 — should fire.
// AC-1 — should fire.

/// WI-42 — should fire on this doc comment.
/// AC-9 — and this one.
const String legacyAccount = 'LEGACY_ACCOUNT'; // identifier — must NOT fire.

/// Throws [WormException] on miss — must NOT fire.
String describeWormException() => 'no fire';

/* Block comment with WI-007 — should fire. */
const int answer = 42;
