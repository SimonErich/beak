import 'package:beak_core/beak_core.dart';

import '../auth/beak_query_authorizer.dart';

/// The query behind the asynchronous checks of a write to [model]: uniqueness
/// and existence.
///
/// A uniqueness check asks about the whole table. A value is taken whoever
/// holds it, so asking through the caller's view would fail on a column the
/// caller may not read and miss a duplicate in a row they may not see, and it
/// runs unscoped. An existence check asks whether the caller may point at
/// something at all, so it goes through [authorizer], which applies the read
/// policy and row scope of the model it looks in.
///
/// The two are told apart by the table: a question about [model]'s own table is
/// a uniqueness check.
BeakValidationQuery beakValidationQuery({
  required BeakModel model,
  required BeakDataSource data,
  required BeakQueryAuthorizer authorizer,
}) =>
    (spec) => spec.table == model.table
    ? data.query(spec)
    : data.query(authorizer.authorizeQuery(spec));
