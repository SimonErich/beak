import 'package:uuid/uuid_value.dart';

/// An enum resolved through its declared type, not a locally parsed token.
enum Status {
  /// First lifecycle state.
  open,

  /// Final lifecycle state.
  closed,
}

/// Shared generated-like parent fields.
class Base {
  /// Creates the inherited timestamp.
  Base({required this.createdAt});

  /// The original instant.
  final DateTime createdAt;
}

/// Existing model with an inherited field and an ordinary public factory.
abstract class Account extends Base {
  Account._({required super.createdAt, required this.id, this.name});

  /// Constructs an account through the generated public contract.
  factory Account({
    required DateTime createdAt,
    required UuidValue id,
    String? name,
  }) = _Account;

  /// UUID identity.
  final UuidValue id;

  /// Optional account name.
  final String? name;
}

final class _Account extends Account {
  _Account({required super.createdAt, required super.id, super.name})
    : super._();
}

/// A composed DTO; neither a table nor a second persistence model.
class View {
  /// Creates a read projection.
  const View({
    required this.account,
    required this.status,
    this.alias,
    this.members,
  });

  /// Nested identity and inherited fields.
  final Account account;

  /// Enum in its original Dart type.
  final Status status;

  /// Optional nested projection.
  final Account? alias;

  /// Related objects are retained without flattening their list semantics.
  final List<Account>? members;
}

/// A flattened path may collide with an existing compound property name.
class Collision {
  /// Creates the original DTO shape.
  const Collision({required this.account, required this.accountId});

  /// Nested object identity.
  final Account account;

  /// Separate text value whose name collides with the flattened path.
  final String accountId;
}

/// A command with explicit nullable replacement values.
class Input {
  /// Creates the typed command.
  const Input({required this.name, required this.active, required this.ids});

  /// Null explicitly clears the name.
  final String? name;

  /// Null and false remain distinct.
  final bool? active;

  /// UUID list supplied by a typed picker.
  final List<UuidValue> ids;
}

/// A nested create command.
class Create {
  /// Creates a command using the existing nested input type.
  const Create({required this.input, required this.password});

  /// Existing command shape.
  final Input input;

  /// Initial credential.
  final String password;
}

/// Unsupported arbitrary schema shapes must fail instead of silently stringify.
class Unsupported {
  /// Creates the fixture.
  const Unsupported({required this.metadata});

  /// No lossless scalar-field descriptor exists for arbitrary maps.
  final Map<String, String> metadata;
}

/// Positional constructors are outside the generated command contract.
class Positional {
  /// Creates the fixture.
  const Positional(this.name);

  /// A scalar cannot repair an incompatible constructor contract.
  final String name;
}

/// Nullable nested list items are deliberately unsupported.
class NullableChildren {
  /// Creates the fixture.
  const NullableChildren({required this.children});

  /// Null objects need an explicit wire representation before support is added.
  final List<Account?> children;
}
