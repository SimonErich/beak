import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../companies/models/company.dart';
import 'user_profile_connection.dart';

part 'user.beak.dart';

/// User schema; all metadata and typed helpers are generated.
@Resource()
final class User extends BeakSchema {
  /// Customer given name.
  @Column(searchable: true)
  late final String firstName;

  /// Customer family name.
  @Column(searchable: true)
  late final String lastName;

  /// The customer identity shown in picker results.
  @Display()
  @Column(searchable: true, unique: true, rules: [BeakEmail()])
  late final String email;

  /// Optional employer, independently managed.
  @BelongsTo(inverse: false)
  late final Company? company;

  /// Whether invoices should use the selected company.
  @Column(defaultValue: false)
  late final bool invoiceCompany;

  /// Editable association records; deleting one never deletes the profile.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<UserProfileConnection> profiles;
}
