import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

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

/// Typed columns of the users resource — the single person entity threaded
/// through every domain (customer, bill-to, chat participant, assignee,
/// activity actor).
abstract final class UserColumns {
  /// Full name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// Contact email (unique).
  static const email = BeakStringColumn(
    key: 'email',
    label: 'Email',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakEmail()],
  );

  /// Contact phone number.
  static const phone = BeakStringColumn(
    key: 'phone',
    label: 'Phone',
    rules: [BeakMaxLength(40)],
  );

  /// Access level, shown as a colored badge.
  static const role = BeakEnumColumn<UserRole>(
    key: 'role',
    label: 'Role',
    values: UserRole.values,
    defaultValue: UserRole.subscriber,
    filterable: true,
    badgeColors: {
      UserRole.admin: BeakColor.error,
      UserRole.editor: BeakColor.primary,
      UserRole.author: BeakColor.info,
      UserRole.maintainer: BeakColor.warning,
      UserRole.subscriber: BeakColor.muted,
    },
  );

  /// Account lifecycle state.
  static const status = BeakEnumColumn<AccountStatus>(
    key: 'status',
    label: 'Status',
    values: AccountStatus.values,
    defaultValue: AccountStatus.active,
    filterable: true,
    badgeColors: {
      AccountStatus.active: BeakColor.success,
      AccountStatus.inactive: BeakColor.muted,
      AccountStatus.pending: BeakColor.warning,
    },
  );

  /// Presence indicator.
  static const online = BeakEnumColumn<OnlineStatus>(
    key: 'online',
    label: 'Presence',
    values: OnlineStatus.values,
    defaultValue: OnlineStatus.offline,
    filterable: true,
    badgeColors: {
      OnlineStatus.online: BeakColor.success,
      OnlineStatus.away: BeakColor.warning,
      OnlineStatus.busy: BeakColor.error,
      OnlineStatus.offline: BeakColor.muted,
    },
  );

  /// Long-form biography.
  static const bio = BeakTextColumn(
    key: 'bio',
    label: 'Bio',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Avatar image.
  static const avatar = BeakImageColumn(
    key: 'avatar',
    label: 'Avatar',
    storagePath: 'users/avatars',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    thumbnail: BeakDimensions(widthInPixels: 96, heightInPixels: 96),
  );

  /// Profile cover image.
  static const cover = BeakImageColumn(
    key: 'cover',
    label: 'Cover',
    storagePath: 'users/covers',
    maxSizeInBytes: 8 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Country name.
  static const country = BeakStringColumn(
    key: 'country',
    label: 'Country',
    filterable: true,
    rules: [BeakMaxLength(80)],
  );

  /// ISO 3166-1 alpha-2 country code.
  static const countryCode = BeakStringColumn(
    key: 'country_code',
    label: 'Country code',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMaxLength(2)],
  );

  /// City name.
  static const city = BeakStringColumn(
    key: 'city',
    label: 'City',
    rules: [BeakMaxLength(80)],
  );

  /// Employer / organization.
  static const company = BeakStringColumn(
    key: 'company',
    label: 'Company',
    searchable: true,
    rules: [BeakMaxLength(120)],
  );

  /// Account balance in dollars.
  static const balance = BeakDecimalColumn(
    key: 'balance',
    label: 'Balance',
    prefix: r'$',
    sortable: true,
  );

  /// Lifetime completed tasks.
  static const tasksDone = BeakIntColumn(
    key: 'tasks_done',
    label: 'Tasks done',
    min: 0,
    sortable: true,
  );

  /// Lifetime completed projects.
  static const projectsDone = BeakIntColumn(
    key: 'projects_done',
    label: 'Projects done',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    email,
    phone,
    role,
    status,
    online,
    bio,
    avatar,
    cover,
    country,
    countryCode,
    city,
    company,
    balance,
    tasksDone,
    projectsDone,
    SharedColumns.createdAt,
    SharedColumns.updatedAt,
  ];
}

/// Typed relationships of the users resource.
abstract final class UserRelations {
  /// Orders this user placed.
  static const orders = BeakHasMany(
    key: 'orders',
    label: 'Orders',
    relatedTable: 'orders',
    displayColumnKey: 'reference',
    foreignKey: 'user_id',
  );

  /// Invoices billed to this user.
  static const invoices = BeakHasMany(
    key: 'invoices',
    label: 'Invoices',
    relatedTable: 'invoices',
    displayColumnKey: 'number',
    foreignKey: 'user_id',
  );

  /// Activity entries authored by this user.
  static const activities = BeakHasMany(
    key: 'activities',
    label: 'Activity',
    relatedTable: 'activities',
    displayColumnKey: 'body',
    foreignKey: 'user_id',
  );

  /// Skills this user has, via the `user_skill` pivot.
  static const skills = BeakBelongsToMany(
    key: 'skills',
    label: 'Skills',
    relatedTable: 'skills',
    displayColumnKey: 'name',
    pivotTable: 'user_skill',
    foreignPivotKey: 'user_id',
    relatedPivotKey: 'skill_id',
    searchColumnKeys: ['name'],
  );
}

/// The users resource — the identity spine of the whole dashboard.
final class UserModel extends BeakModel {
  /// Creates the users model.
  const UserModel();

  @override
  String get table => 'users';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => UserColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    UserRelations.orders,
    UserRelations.invoices,
    UserRelations.activities,
    UserRelations.skills,
  ];

  @override
  bool get softDeletes => true;
}
