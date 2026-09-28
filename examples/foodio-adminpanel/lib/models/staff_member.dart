import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'staff_member.beak.dart';

/// StaffMember configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class StaffMember extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Email.
  @Column(searchable: true)
  late final String email;

  /// Role.
  @Column(defaultValue: 'administrator')
  late final String role;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
