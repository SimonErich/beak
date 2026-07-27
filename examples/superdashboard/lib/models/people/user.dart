import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../commerce/order.dart';
import '../invoices/invoice.dart';
import '../shared/enums.dart';
import 'activity.dart';
import 'skill.dart';

part 'user.beak.dart';

/// Access level of a user.
enum UserRole {
  /// Full administrative access.
  admin,

  /// Can edit any content.
  editor,

  /// Can author their own content.
  author,

  /// Maintains infrastructure and integrations.
  maintainer,

  /// Read-only subscriber.
  subscriber,
}

/// Account lifecycle state of a user.
enum AccountStatus {
  /// Active and signed-in-able.
  active,

  /// Deactivated.
  inactive,

  /// Awaiting verification.
  pending,
}

/// The users resource — the identity spine of the whole dashboard.
@Resource(softDeletes: true, timestamps: true)
final class User extends BeakSchema {
  /// Full name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Contact email (unique).
  @Column(searchable: true, sortable: true, rules: [BeakEmail()])
  late final String email;

  /// Contact phone number.
  @Column(rules: [BeakMaxLength(40)])
  late final String? phone;

  /// Access level, shown as a colored badge.
  @Column(filterable: true, defaultValue: UserRole.subscriber)
  @Badges({
    UserRole.admin: BeakColor.error,
    UserRole.editor: BeakColor.primary,
    UserRole.author: BeakColor.info,
    UserRole.maintainer: BeakColor.warning,
    UserRole.subscriber: BeakColor.muted,
  })
  late final UserRole? role;

  /// Account lifecycle state.
  @Column(filterable: true, defaultValue: AccountStatus.active)
  @Badges({
    AccountStatus.active: BeakColor.success,
    AccountStatus.inactive: BeakColor.muted,
    AccountStatus.pending: BeakColor.warning,
  })
  late final AccountStatus? status;

  /// Presence indicator.
  @Column(
    label: 'Presence',
    filterable: true,
    defaultValue: OnlineStatus.offline,
  )
  @Badges({
    OnlineStatus.online: BeakColor.success,
    OnlineStatus.away: BeakColor.warning,
    OnlineStatus.busy: BeakColor.error,
    OnlineStatus.offline: BeakColor.muted,
  })
  late final OnlineStatus? online;

  /// Long-form biography.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? bio;

  /// Avatar image.
  @Image(
    storagePath: 'users/avatars',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    thumbnail: BeakDimensions(widthInPixels: 96, heightInPixels: 96),
  )
  late final BeakImageRef? avatar;

  /// Profile cover image.
  @Image(
    storagePath: 'users/covers',
    maxSizeInBytes: 8 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  )
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakImageRef? cover;

  /// Country name.
  @Column(filterable: true, rules: [BeakMaxLength(80)])
  late final String? country;

  /// ISO 3166-1 alpha-2 country code.
  @Column(
    label: 'Country code',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMaxLength(2)],
  )
  late final String? countryCode;

  /// City name.
  @Column(rules: [BeakMaxLength(80)])
  late final String? city;

  /// Employer / organization.
  @Column(searchable: true, rules: [BeakMaxLength(120)])
  late final String? company;

  /// Account balance in dollars.
  @Column(sortable: true, prefix: r'$')
  late final double? balance;

  /// Lifetime completed tasks.
  @Column(label: 'Tasks done', sortable: true, min: 0)
  late final int? tasksDone;

  /// Lifetime completed projects.
  @Column(label: 'Projects done', sortable: true, min: 0)
  late final int? projectsDone;

  /// Orders this user placed.
  @HasMany()
  late final List<Order> orders;

  /// Invoices billed to this user.
  @HasMany()
  late final List<Invoice> invoices;

  /// Activity entries authored by this user.
  @HasMany(label: 'Activity')
  late final List<Activity> activities;

  /// Skills this user has, via the `user_skill` pivot.
  @BelongsToMany(pivotTable: 'user_skill')
  late final List<Skill> skills;
}
