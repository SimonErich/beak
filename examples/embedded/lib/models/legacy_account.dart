import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'legacy_account.beak.dart';

/// An account row owned by the system Beak was pointed at.
///
/// `managesSchema: false` says another system migrates this table: Beak reads
/// and writes it, renders it and relates to it, but generates no migration for
/// it and `beak doctor` does not ask why one is missing.
///
/// This is the usual way Beak arrives at an existing product — one table it
/// owns, one it borrows.
@Resource(table: 'accounts', managesSchema: false)
final class LegacyAccount extends BeakSchema {
  /// The company name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Billing contact.
  @Column(searchable: true)
  late final String email;

  /// Which plan they are on. The legacy system writes this column.
  @Column(filterable: true, columnName: 'plan_code')
  late final String plan;
}
