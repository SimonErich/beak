# Auth and policies

> Identify the caller, then decide what they may read, write, delete and run, with sessions, deny-by-default rules, row scopes, field rules and actions.

Hiding a button in the panel protects nothing. Every rule on this page runs in the backend, on every route, for every client. After it you can close a Beak server: name who is calling, list what each role may do to each model, narrow which rows and fields they see, and prove that a request the panel would never send is refused.

The default is open. A `BeakServer` built without a `policy` allows everything to everyone, anonymous callers included. Bound beyond loopback it prints one `warning:` line at boot, and that is all it does. That is right for the first hour and wrong for the second, so the first thing to do with `lib/server.dart` is give it a `BeakPolicies`.

## At a glance

A request is judged in this order. The first check that fails ends it.

| Step | Question | Owner | Refusal |
| --- | --- | --- | --- |
| 1. Guard | Who is this? | `BeakAuthGuard`, fed by `authSessions` or your own | `401` when credentials are present and wrong |
| 2. Policy | May this principal do this to this model? | `BeakPolicy`, usually `BeakPolicies` | `401` anonymous, `403` signed in |
| 3. Fields | May they read or supply each field the request names? | `BeakFieldPolicy`, `hiddenFields`, `readOnlyFields` | `401` or `403`, or `422` for a read-only field |
| 4. Rows | Which rows may they touch? | `rowScope` of a `BeakModelRules` | The row is absent: `404` for one row, a smaller page for a query |
| 5. Action | May they run this named command? | `BeakModelRules.actions`, `BeakActionPolicy` | A rejected receipt |

```dart
// Illustrative: lib/server.dart of a scratch project. Every name is real, and the file was run.
BeakServer beakServer(BeakServerDefaults defaults) {
  final String secret = defaults.environment['AUTH_SECRET'] ?? 'dev-secret';
  final staff = BeakAccess.role('staff');
  return defaults.build(
    authSessions: BeakAuthSessions(
      store: InMemoryTokenSessionStore(),
      secret: secret,
      users: [
        BeakUserAccount(
          username: 'sam',
          passwordHash: hashBeakPassword('s3cret', secret: secret),
          principal: const BeakPrincipal(id: 'sam', roles: {'staff'}),
        ),
      ],
    ),
    policy: BeakPolicies(
      rules: [
        BeakModelRules(
          const ProductModel(),
          read: BeakAccess.authenticated,
          write: staff,
          delete: BeakAccess.role('manager'),
          readOnlyFields: {ProductModel.price},
        ),
      ],
    ),
  );
}
```

That is the whole shape. The next sections take the two halves apart. Panel permissions (`canEdit`, `canDelete`, hidden resources) only decide what to draw. The panel asks the server what it may show through `GET /api/{table}/capabilities`, and the server then judges every request again.

## Who is calling

Authentication is one interface, called by the auth middleware on every request:

```dart title="packages/beak_backend/lib/src/auth/beak_auth_guard.dart"
abstract interface class BeakAuthGuard {
  /// The principal behind [request], or `null` when it carries no
  /// credentials.
  Future<BeakPrincipal?> authenticate(Request request);
}
```

`null` means anonymous. Credentials that are present and wrong must throw a `BeakAuthenticationException`, never return `null`, so a forged token is a `401` and never quietly becomes an anonymous request. A `BeakPrincipal` is an `id` and a set of `roles`, which are plain strings.

### Built-in sessions

`authSessions:` on `defaults.build` mounts `POST /api/auth/login`, `POST /api/auth/logout` and `GET /api/auth/me`, and installs a `TokenSessionAuthGuard` over the same store, so the tokens it issues are the tokens it checks. Pass `authGuard:` only to identify callers another way (a JWT, a gateway header); an explicit guard takes over.

`BeakAuthSessions` takes a `TokenSessionStore`, a list of `BeakUserAccount`s and a `secret`. Each account stores `hashBeakPassword(password, secret: secret)`, an HMAC-SHA256 under that secret, and never the password. Beak has no environment variable for the secret. Read yours through `defaults.environment`, so a test that injects an environment injects it here too. An empty secret, or two accounts with one username, fails at startup with a `BeakConfigurationException`, so one account can never silently replace another.

```console
$ curl -s -X POST localhost:8392/api/auth/login -H 'content-type: application/json' \
    -d '{"username":"sam","password":"s3cret"}'
{"token":"5dbf942e08efb21ac9a2ee7ab1b97b0e80e1c7552edf99738713af4b8323f635","principal":{"id":"sam","roles":["staff"]}}
$ curl -s -w ' [%{http_code}]\n' localhost:8392/api/auth/me -H "authorization: Bearer $TOKEN"
{"id":"admin","roles":["manager","staff"]} [200]
$ curl -s -w ' [%{http_code}]\n' localhost:8392/api/auth/me
{"code":"authentication","message":"Sign in to continue.","requestId":"b9d739c328070019"} [401]
```

The default `InMemoryTokenSessionStore` gives every session 12 hours from login (`sessionTtl`, fixed and not extended by use), keeps them in process memory, and loses them on restart. Logout revokes only the token it presents. This is a login for building a panel, not an account system:

| Property | What it is |
| --- | --- |
| Accounts | A list built at boot: no user table, no password change, no disabling one without a deploy |
| Password hash | One shared secret, no per-user salt, no work factor. Compared in constant time, for an unknown username too |
| Login attempts | Not counted, throttled or locked out |
| Sessions | Per process, so a second instance does not know the first one's tokens |

For production, put identity somewhere that does this well. Implement `BeakAuthGuard` over your provider or gateway, or implement `TokenSessionStore` over shared storage if you keep Beak's sessions:

```dart title="packages/beak_backend/lib/src/auth/token_session_store.dart"
abstract interface class TokenSessionStore {
  /// Mints a new opaque token for [principal] and stores the session.
  Future<String> createSession(BeakPrincipal principal);

  /// The principal behind [token], or `null` when the token is unknown or
  /// the session expired.
  Future<BeakPrincipal?> sessionFor(String token);

  /// Invalidates [token]; unknown tokens are a no-op.
  Future<void> revoke(String token);
}
```

[Security](../shipping/security.md) has the full hardening list, and [Auth and idle lock](../panel/auth-and-idle-lock.md) is the panel side of the same routes.

## What may they do

`BeakPolicies` is the shape to use on a server that faces anyone. It holds one `BeakModelRules` per model and denies whatever it does not list. Each rule states who may read, write and delete, and every part left out is denied:

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
/// Notes are readable by anyone signed in, writable by editors and deletable
/// by managers, and each principal sees only the notes of their own author.
BeakPolicies _policies({
  BeakModel notes = const NoteModel(),
  Set<BeakFieldRef<Object>> readOnly = const {},
  Map<BeakFieldRef<Object>, BeakAccess> hidden = const {},
  Map<BeakModelAction, BeakAccess> actions = const {},
}) => BeakPolicies(
  rules: [
    BeakModelRules(
      notes,
      read: BeakAccess.authenticated,
      write: _editor,
      delete: _manager,
      rowScope: (principal) => NoteModel.authorId.eq(principal.id),
      readOnlyFields: readOnly,
      hiddenFields: hidden,
      actions: actions,
    ),
    BeakModelRules(const AuthorModel(), read: BeakAccess.authenticated),
    BeakModelRules(
      const LabelModel(),
      read: BeakAccess.authenticated,
      write: _editor,
    ),
  ],
);
```

| Rule part | Covers |
| --- | --- |
| `read` | Query, aggregate, summary, batch, get one, capabilities, export, upload URL lookups, and reading the model through a relationship |
| `write` | Create, update, restore, attach and detach, and uploading a file |
| `delete` | Delete, and removing an uploaded file |
| `rowScope` | Which rows all of the above may touch, see below |
| `readOnlyFields` | Fields the server owns, see below |
| `hiddenFields` | Fields hidden from the principals an access value names, see below |
| `actions` | Who may run each named command of the model |

A part is a `BeakAccess`: `BeakAccess.role('staff')`, `BeakAccess.authenticated`, `BeakAccess.anyone`, and `any`, `all` and `not` to combine them. An empty `any` or `all` grants nothing, so a list that lost its entries never opens a resource.

A model with no rule is invisible. Its routes answer `401` to an anonymous request and `403` to anyone else, and no other model's relationship exposes it. A model you add next month stays closed until someone opens it. The test that pins this walks six routes:

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
for (final (name, method, path, body) in unlisted) {
  test(
    '$name answers 401 anonymously and 403 to a signed-in caller',
    () async {
      expect((await call(method, path, body: body)).statusCode, 401);
      final denied = await call(
        method,
        path,
        body: body,
        token: managerToken,
      );
      expect(denied.statusCode, 403);
      expect(await denialCode(denied), 'authorization');
    },
  );
}
```

`BeakModelRules` throws a `BeakConfigurationException` at startup for a `readOnlyFields` or `hiddenFields` entry that is not a field of the model, an `actions` key the model does not declare, and a second rule for the same model. A rule that could never apply is a mistake worth failing on.

### What a refusal looks like

| Decision | Response |
| --- | --- |
| Anonymous, denied | `401` `authentication`: `Sign in to view "products".` |
| Signed in, denied | `403` `authorization`: `Principal "sam" is not allowed to delete "products".` |
| Row outside the caller's scope | `404`, as if it did not exist |
| A create or update that would leave the row outside the scope | `403` `authorization`: `The record would be outside your permitted scope of "notes".` |
| A read-only field in a body | `422` with a `fieldErrors` entry |
| A denied operation in `POST /api/commits` | `200` with an `unapplied` outcome, `reason: rejected` and `error.code` `authorization` or `authentication` |

The last row is easy to miss. A graph save is a transaction, and a refusal inside it is a rejected receipt, so the form can show it next to the field and not treat it as a broken request. The messages there are generic on purpose:

```console
$ curl -s -w ' [%{http_code}]\n' -X POST localhost:8392/api/commits ... # sam deletes a product
{"saveId":"del1","mode":"atomic","outcomes":[{"id":"d","status":"unapplied","error":{"code":"authorization","message":"This operation is not permitted.","fieldErrors":{}},"reason":"rejected"}]} [200]
```

A save the policy refused as a whole reached no data and is not stored: the same `saveId` is decided again, `GET /api/commits/<saveId>` answers `404`, and a caller who may not write cannot grow the receipt table by trying. A rejection for validation, a conflict or a stale version is stored and belongs to its `saveId` and principal. Sending the same plan again with the same id returns the same rejection, even if the rules changed in between, so a client that wants a fresh decision on those needs a fresh `saveId`.

## Which rows

`read: authenticated` answers "may this caller read orders". It does not answer "may this caller read these orders". Without a row scope, a rule meant as "customers see only their own orders" is bypassed by any query with a filter the caller writes, because the filter comes from the client.

A `rowScope` is a typed filter built for the signed-in principal, and it is intersected with every read and write of the model: query, aggregate, summary, batch, get, update, delete, restore, attach, detach, export, upload lookups and graph commits. A write is judged twice: the row must be inside the scope before the write, and the row a create inserts or an update leaves behind must be inside it too, so a caller cannot plant a record in someone else's slice or hand one of theirs away. A write that breaks that is a `403`. Relation loads and filters that reach a related model apply that model's scope too, so loading a record through another resource grants nothing.

```dart
  rowScope: (principal) => NoteModel.authorId.eq(principal.id),
```

The filter is built from the model's fields, so renaming one is a compile error and not a rule that silently matches nothing. The server decides it against the values a write leaves behind, which it can do for equality, inequality, ordering, list membership, `isNull`, `and` and `or`. A scope that goes through a relationship or a text match cannot be decided before the row exists, so a create is refused with a `422`, and so is an update that changes a field the scope reads. An anonymous request has no principal to build it for, and under `BeakPolicies` it sees no rows.

A scope narrows, it does not refuse. `read` false is a `403` with no data. A scope is a successful request with fewer rows:

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
test('query: 401 anonymous, then a page scoped to the caller', () async {
  expect(
    (await call('POST', '/api/notes/query', body: querySpec)).statusCode,
    401,
  );
  final mine = await call(
    'POST',
    '/api/notes/query',
    body: querySpec,
    token: editorToken,
  );
  expect(mine.statusCode, 200);
  final items = await itemsOf(mine);
  expect(items, hasLength(1));
  expect(jsonEncode(items), contains('Mine'));
  expect(jsonEncode(items), isNot(contains('Theirs')));
});

test(
  'query: a signed-in caller with no rows gets an empty page, not a 403',
  () async {
    final response = await call(
      'POST',
      '/api/notes/query',
      body: querySpec,
      token: readerToken,
    );
    expect(response.statusCode, 200);
    final page = await objectOf(response);
    expect(page['items'], isEmpty);
    expect(page['total'], 0);
  },
);
```

Use the refusal when the table is none of their business and the scope when some of it is. To implement the scope by hand, `BeakRowPolicy` adds one method, and `null` from it means every row:

```dart title="packages/beak_backend/lib/src/auth/beak_policy.dart"
abstract interface class BeakRowPolicy implements BeakPolicy {
  /// The filter every read and write of [model] is additionally constrained
  /// by, or `null` when [principal] may touch every row.
  ///
  /// Returning a filter that matches nothing is how a policy says "no rows":
  /// the request still succeeds, with an empty page, which is what a row
  /// scope means — as opposed to `canView` returning false, which is a 403.
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model);
}
```

Scopes may depend on fields the caller cannot read, because they are trusted server code. Two scopes that reach each other through relationships are reported as `Cyclic relationship row policies.`, a `500` at request time.

## Which fields

With `BeakPolicies`, field access follows the model: a caller who may read the model may read every field of it, and a caller who may write it may supply every field. `hiddenFields` and `readOnlyFields` are the field-level tools. `readOnlyFields` names values the server owns, such as a calculated total or a number minted at creation, and a request that supplies one is rejected before anything else happens:

```console
$ curl -s -w ' [%{http_code}]\n' -X PATCH localhost:8392/api/products/$ID \
    -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d '{"price":9}'
{"code":"validation","message":"Read-only fields cannot be written.","fieldErrors":{"price":["This field is read-only."]},"requestId":"442aa717300a9e46"} [422]
$ curl -s "localhost:8392/api/products/capabilities?id=$ID" -H "authorization: Bearer $TOKEN"
{"readableFields":["id","name","price","active","created_at","updated_at"],"writableFields":["id","name","active","created_at","updated_at"],"executableActions":[],"canCreate":true,"canDelete":false}
```

Values the server derives itself are unaffected, and the capabilities response leaves a read-only field out of `writableFields`, so a configured form never offers it. The same response carries `canCreate` and `canDelete`, taken from the policy, so a table can leave out the delete action for a role that would be refused. A name that is not a field of the model is a `422` too, so there is no mass-assignment path to a column the model does not declare.

To hide one field from some callers, name it in `hiddenFields` with the access value it is hidden from. `BeakAccess.not(manager)` hides it from everyone but managers, and `staff` hides it from staff:

```dart
BeakModelRules(
  const ProductModel(),
  read: staff,
  write: staff,
  hiddenFields: {ProductModel.supplierCostInCents: BeakAccess.not(manager)},
)
```

A hidden field is neither readable nor writable for those callers, and it only narrows: it never grants what `read` and `write` withhold. For anything the map cannot say, implement `BeakFieldPolicy` next to the resource policy. `canReadField` and `canWriteField` receive the principal, the model and the typed field, and `isSameFieldAs` compares fields (a generated reference is a new object on every access, so `==` does not work):

```dart title="packages/beak_backend/test/src/auth/field_authorization_test.dart"
final class _Policy extends BeakAllowAllPolicy
    implements BeakFieldPolicy, BeakRowPolicy {
  const _Policy();
  @override
  bool canReadField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) =>
      !field.isSameFieldAs(ProductModel.price) &&
      !field.isSameFieldAs(ReviewModel.body);
  @override
  bool canWriteField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => !field.isSameFieldAs(ProductModel.price) && field.key != 'tags';
  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is ProductModel ? ProductModel.price.gt(0) : null;
}
```

What a `false` from `canReadField` does, everywhere:

- The value is removed from responses and from eager-loaded relationships.
- A filter, sort, search or aggregate that names the field is refused with `401` or `403`. It is not ignored, because an ignored filter would still tell the caller something.
- The column is left out of CSV exports, header included.
- A relationship and its linking foreign key share one boundary. Reading, filtering or loading through a relationship needs both, and a belongs-to write needs the alias and the key even when the client sends only the key.

What `canWriteField` does: the fields the client supplied are checked before behavior or graph preparation runs. That lets a trusted calculation fill a column the caller may not write.

`BeakPolicies` is a `final` class, so it cannot be extended, and a hand-written policy replaces it. Prefer `hiddenFields` and `readOnlyFields` while they say what you mean. Extend `BeakAllowAllPolicy` (declared `base` for this) and restrict what you need, or delegate to a `BeakPolicies` from your own class. Either way, deny-by-default is now your code's job.

## Which commands

A model's named commands (its `BeakModelAction`s, declared in its behavior) are authorized separately from general update permission. List them per rule; a declared command that no rule lists cannot be run by anyone:

```dart
  actions: {OrderModel.ship: staff},
```

The check runs inside the graph commit, before the command's own availability test. Capabilities offer a command only when the caller may write the model (create, or update for an existing record), the command's `BeakActionPolicy` decision is yes, and, on create, the command has `allowOnCreate`. The capabilities do not evaluate the command's workflow state: whether it is available for this record right now is a separate predicate. Do not use that predicate or an `editableWhen` guard as a replacement for authorization. They protect the workflow from a valid user, not the data from an invalid one. [Behavior and actions](../reference/behavior-and-actions.md) describes the model side.

## Uploads

Uploading a file needs `canCreate` and write access to the column. Removing one needs `canDeleteUpload`, which under `BeakPolicies` is the `delete` part. Resolving a stored key's URL needs `canView`, read access to the column, and, when the model has a row scope, a visible record that references the key. `BeakUploadReadPolicy.canViewUpload` adds a key-aware check on top, for a hand-written policy.

A URL, once handed out, is only as private as the storage behind it. The local driver and a public bucket serve it to anyone who holds it. [Uploads and storage wiring](uploads-and-storage-wiring.md) has the details.

## Graph commits

`POST /api/commits` applies the same rules per operation. The table-level decision (`canCreate`, `canUpdate`, `canDelete`, plus `canUpdate` on an owner for its children) is taken before any behavior or `preparePlan` hook runs, so application code never executes for a write the principal may not make. Field write access is checked for the operations the client sent. Operations a `preparePlan` adds skip only that check, because a derived column is often one the client may not write, and every other check still applies to them. Receipts are redacted again under the current policy when they are read back.

One gap deserves care. A `preparePlan` you write reads through the transaction-bound data source, which applies no row scopes on purpose: a capacity rule has to count rows the caller cannot see. `BeakCandidateGraph.open` accepts an `authorizeRead` callback for the records the plan names, the built-in behavior pass passes one, and the transaction source hands the same callback to your preparer as `transaction.authorizeRead`. Pass it when the preparer loads a graph; filter any other read yourself. [Transactional business rules](graph-business-rules.md) shows the preparer.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| No `policy` means `BeakAllowAllPolicy` | Every route answers every caller, and the server binds `0.0.0.0` by default. A server bound beyond loopback prints one `warning:` line at boot (through `onWarning`); nothing else stops it |
| Only `BeakPolicies` denies by default | A hand-written `BeakPolicy` is exactly as open as its methods |
| `BeakPolicies` field access is per model, plus `hiddenFields` | A field is hidden from the principals its access value names, and from nobody else. A rule that depends on the value of the field, or on the record, needs a hand-written `BeakFieldPolicy`, which replaces `BeakPolicies` |
| Roles are strings on the principal | There is no hierarchy. `manager` does not imply `staff`; give the principal both, or list both in `BeakAccess.any` |
| An excluded row is a `404` | The response never confirms that a row you may not see exists |
| Denials on `/api/commits` are answered as receipts, and not stored | `200` with `unapplied` outcomes and generic messages. Nothing is kept, so the same `saveId` is decided again |
| A preparer's reads are not scoped | Pass `authorizeRead: transaction.authorizeRead` to `BeakCandidateGraph.open` so the records the plan names stay within the caller's scope |
| Sessions are per process and last 12 hours from login | A restart or a second instance signs users out. Implement `TokenSessionStore` over shared storage |
| The probes and the login skip the guard and the policy | `/healthz` and `/readyz` need no rule, and the guard never looks at them, so an `Authorization` header a load balancer adds cannot fail a probe. `POST /api/auth/login` is skipped too, so a token left over from an expired session does not answer 401 to the sign-in that replaces it |

## Verify it

Check a policy the way an attacker would: with requests the panel never sends. Anonymous first, then each role, then the edge of each rule. `$TOKEN` is the token from `POST /api/auth/login` and `$ID` the id of a product.

```console
$ curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:8392/api/products/query \
    -H 'content-type: application/json' -d '{"table":"products"}'
401
$ curl -s -w ' [%{http_code}]\n' -X DELETE localhost:8392/api/products/$ID -H "authorization: Bearer $TOKEN"
{"code":"authorization","message":"Principal \"sam\" is not allowed to delete \"products\".","requestId":"012398d50a21f700"} [403]
$ curl -s -w ' [%{http_code}]\n' localhost:8392/healthz -H 'authorization: Bearer nope'
{"status":"ok"} [200]
$ curl -s -w ' [%{http_code}]\n' localhost:8392/api/products/capabilities -H 'authorization: Bearer nope'
{"code":"authentication","message":"The session token is invalid or expired.","requestId":"c72e4b0f5f0981e1"} [401]
```

In code, the two fixtures quoted above are the pattern: build the real router with `beakApiRouter`, a `BeakPolicies` and an `InMemoryTokenSessionStore`, mint a token per role, and assert the status of every route for every role. A model with rules and a model without them belong in the same test. `beak doctor` does not audit policies, so this test is the audit.

## Reference

- `packages/beak_backend/lib/src/auth/beak_policies.dart`: `BeakPolicies`, `BeakModelRules`.
- `packages/beak_backend/lib/src/auth/beak_access.dart`: `BeakAccess`.
- `packages/beak_backend/lib/src/auth/beak_policy.dart`: `BeakPolicy`, `BeakRowPolicy`, `BeakAllowAllPolicy`, `BeakUploadReadPolicy`, `enforcePolicyDecision`.
- `packages/beak_backend/lib/src/auth/beak_field_policy.dart`: `BeakFieldPolicy`, `BeakReadOnlyFieldPolicy`, `BeakFieldAccess`.
- `packages/beak_backend/lib/src/auth/beak_action_policy.dart`: `BeakActionPolicy`.
- `packages/beak_backend/lib/src/auth/beak_query_authorizer.dart`: how filters, sorts, searches and loads are authorized.
- `packages/beak_backend/lib/src/auth/auth_router.dart` and `packages/beak_backend/lib/src/auth/token_session_store.dart`: the sessions.

## Continue reading

- [Security](../shipping/security.md) the whole hardening list around these hooks: CORS, TLS, uploads, known gaps.
- [Transactional business rules](graph-business-rules.md) where server-side logic runs after these checks pass.
- [Middleware](middleware.md) the pipeline that puts the principal in front of the policy.
- [Where authority lives](../concepts/where-authority-lives.md) why the panel never decides.
