import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'user.dart';
import '../../profiles/models/profile.dart';

part 'user_profile_connection.beak.dart';

/// UserProfileConnection schema; all metadata and typed helpers are generated.
@Resource()
final class UserProfileConnection extends BeakSchema {
  /// Label identifying this customer's delivery profile.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// The owning customer; populated by the relationship editor.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final User user;

  /// Shared delivery profile selected or created through the picker.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Profile profile;

  /// Instructions specific to this customer and profile.
  late final BeakText? notes;
}
