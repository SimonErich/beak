import 'package:beak_backend/beak_backend.dart';
import 'package:bookshop_beak/bookshop_beak.dart';

import 'bookshop_scopes.dart';

// --8<-- [start:bookshopPolicy]
/// Who may do what in the bookshop admin.
///
/// Deny by default: holding `beak.admin` opens the tunnel and grants nothing.
/// Staff (the `bookshop.staff` scope) read and write authors and books.
/// Nobody may delete: a rule that is not written is a rule that is closed, so
/// removing an author (and, by cascade, their books) needs a deliberate rule.
final BeakPolicies bookshopPolicy = BeakPolicies(
  rules: [
    BeakModelRules(const AuthorModel(), read: _staff, write: _staff),
    BeakModelRules(const BookModel(), read: _staff, write: _staff),
  ],
);

final BeakAccess _staff = BeakAccess.role(BookshopScopes.staff.name!);
// --8<-- [end:bookshopPolicy]
