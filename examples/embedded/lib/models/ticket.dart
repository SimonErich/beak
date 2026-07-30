import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'legacy_account.dart';

part 'ticket.beak.dart';

/// How far along a ticket is.
enum TicketStatus {
  /// Waiting for a first reply.
  open,

  /// Being worked on.
  pending,

  /// Finished.
  closed,
}

/// A support ticket — a table this app owns outright.
@Resource(timestamps: true)
final class Ticket extends BeakSchema {
  /// One-line summary.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(160)])
  late final String subject;

  /// What the customer wrote.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? body;

  /// How far along it is.
  @Column(filterable: true)
  @Badges({
    TicketStatus.open: BeakColor.warning,
    TicketStatus.pending: BeakColor.info,
    TicketStatus.closed: BeakColor.success,
  })
  late final TicketStatus status;

  /// The account that raised it.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final LegacyAccount account;
}
