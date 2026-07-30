import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'managed_file.dart';

part 'file_share.beak.dart';

/// The access a file share grants.
enum SharePermission {
  /// Read only.
  view,

  /// Read and comment.
  comment,

  /// Read and edit.
  edit,
}

/// The file-shares resource — a file granted to a user with a permission.
@Resource()
final class FileShare extends BeakSchema {
  /// The shared file.
  @BelongsTo()
  late final ManagedFile? file;

  /// The user the file is shared with.
  @BelongsTo(label: 'Shared with')
  late final User? sharedWith;

  /// The granted permission.
  @Display()
  @Column(filterable: true, defaultValue: SharePermission.view)
  @Badges({
    SharePermission.view: BeakColor.muted,
    SharePermission.comment: BeakColor.info,
    SharePermission.edit: BeakColor.success,
  })
  late final SharePermission? permission;

  /// When the file was shared.
  @Column(label: 'Shared', format: BeakDateFormat.relative, sortable: true)
  late final DateTime? sharedAt;
}
