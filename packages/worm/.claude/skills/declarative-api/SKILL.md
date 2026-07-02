---
name: declarative-api
description: Mandatory guardrail companion for Dart API design. Enforces extension-first thinking when adding behavior to any type — domain models, enums, DTOs, or third-party types. Ensures APIs read declaratively (object.action) rather than procedurally (doActionOnObject).
role: guardrail
scope: general
trigger: auto_with_workflow
pairs_with:
  - create-reusable-helpers
  - serverpod-extensions
  - flutter-dart-official-rules
---

# Declarative API Rules

Use this skill to constrain API design decisions in Dart. Read it before creating a new class, helper function, utility, or any public API surface.

## Absolute Rule

**Before creating a standalone function, utility class, or helper, ask: can this be an extension method on the type it operates on?** Extensions produce declarative, self-documenting APIs that read like natural language. Prefer `order.isExpired` over `isOrderExpired(order)`.

## Why Extensions First

```dart
// Procedural — reader must parse function name to find the subject
final allowed = userCanStillOrder(user, order);
final name = formatProductDisplayName(product);
final valid = validateVoucherCode(code);

// Declarative — subject is obvious, intent reads naturally
final allowed = order.allowedFor(user);
final name = product.displayName;
final valid = code.isValidVoucher;
```

Extensions make the subject explicit. The reader immediately knows what type is being operated on and what question is being asked.

## When to Use Extensions

Use an extension when ALL of these are true:

1. **Pure** — computable from the object's own state (and optionally parameters)
2. **No DI** — does not need injected services, repositories, or service locators
3. **No side effects** — does not write to DB, send network requests, or mutate external state
4. **Clear owner** — one type naturally owns the behavior (see ownership rule below)

## When NOT to Use Extensions

Use a service, use case, or standalone class when ANY of these are true:

| Signal | Use instead |
|---|---|
| Needs dependency injection | Service or use case class |
| Performs DB calls or network requests | Repository or service |
| Mutates external state | Service or use case |
| Combines multiple unrelated types equally | Standalone function or service |
| Needs interface polymorphism (`implements`) | Standalone class |
| Complex multi-step orchestration | Application/service class |
| Needs to be mocked in tests | Interface + service class |

Extensions are the **public API layer for pure logic**. Services handle operations requiring DI or side effects.

## Ownership Rule: Domain-Owner

When a method could live on multiple types, the type with **richer domain context** owns it:

```dart
// Order knows ordering rules better than User does
extension OrderChecks on Order {
  /// Whether this order is still allowed for the given [user].
  bool allowedFor(User user) =>
      !isExpired && user.status == UserStatus.active;
}

// Product knows pricing rules
extension ProductPricing on Product {
  /// The effective price in cents, considering active promotions.
  int get effectivePriceInCents => promoPriceInCents ?? priceInCents;
}

// User knows auth rules
extension UserAuth on User {
  /// Whether the user has the given [permission].
  bool hasPermission(Permission permission) =>
      roles.any((r) => r.permissions.contains(permission));
}
```

**Heuristic:** Ask "which type's documentation would a developer check first?" That type owns the extension.

## Applies to All Dart Types

This rule applies universally — not just domain models:

### Enums

```dart
// BAD — procedural
String getStatusLabel(OrderStatus status) {
  switch (status) { ... }
}
Color getStatusColor(OrderStatus status) { ... }

// GOOD — declarative
extension OrderStatusDisplay on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.confirmed => 'Confirmed',
    OrderStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    OrderStatus.pending => Colors.orange,
    OrderStatus.confirmed => Colors.green,
    OrderStatus.cancelled => Colors.red,
  };
}

// Call site
Text(order.status.label, style: TextStyle(color: order.status.color))
```

### Third-Party and Built-In Types

```dart
// BAD — procedural
bool isValidEmail(String email) => RegExp(r'...').hasMatch(email);
String formatCurrency(int cents) => (cents / 100).toStringAsFixed(2);
bool isToday(DateTime date) => ...;

// GOOD — declarative
extension EmailValidation on String {
  bool get isValidEmail => RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$').hasMatch(this);
}

extension CurrencyFormatting on int {
  String get asCurrency => (this / 100).toStringAsFixed(2);
}

extension DateChecks on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

// Call site
if (email.isValidEmail) { ... }
Text('${priceInCents.asCurrency} EUR')
if (createdAt.isToday) { ... }
```

### DTOs and Frontend-Only Classes

```dart
// BAD — utility function
bool isCartEmpty(CartState cart) => cart.items.isEmpty;
int cartTotalInCents(CartState cart) => cart.items.fold(0, ...);

// GOOD — declarative
extension CartStateChecks on CartState {
  bool get isEmpty => items.isEmpty;
  int get totalInCents => items.fold(0, (sum, item) => sum + item.totalInCents);
}
```

## Extension Naming Convention

| Extension purpose | Name pattern | Example |
|---|---|---|
| Boolean checks, state queries | `<Type>Checks` | `OrderChecks` |
| Display formatting, labels | `<Type>Display` or `<Type>Formatting` | `OrderStatusDisplay` |
| Computed properties, derived values | `<Type>Properties` or `<Type>Behavior` | `ProductPricing` |
| Query scopes (Serverpod Table) | `<Type>QueryScopes` | `ProductQueryScopes` |
| Validation | `<Type>Validation` | `EmailValidation` |

Use descriptive names that reflect the concern, not generic names like `ProductExtensions` or `ProductUtils`.

## Decision Flowchart

```
You need to add behavior to a type.
|
+-- Can it be computed from the object's own state (+ parameters)?
|   +-- YES: Is there a clear domain owner?
|   |   +-- YES -> Extension on that type
|   |   +-- NO: Do the types contribute equally?
|   |       +-- YES -> Standalone function or service
|   |       +-- NO -> Extension on the richer domain type
|   +-- NO: Does it need DI, DB, or network?
|       +-- YES -> Service or use case class
|       +-- NO: Does it need to be mocked?
|           +-- YES -> Interface + implementation class
|           +-- NO -> Extension (pass dependency as parameter)
```

## Relationship to Services

Extensions and services complement each other:

```dart
// Extension: pure API from object state
extension OrderChecks on Order {
  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get canBeCancelled => status == OrderStatus.pending && !isExpired;
}

// Service: operations requiring DI and side effects
class OrderService {
  final OrderRepository _repo;
  final NotificationService _notifications;

  /// Cancels the order if allowed.
  ///
  /// Throws [OrderNotCancellableException] if [Order.canBeCancelled] is false.
  Future<Order> cancel(Order order) async {
    if (!order.canBeCancelled) throw OrderNotCancellableException(order.id);
    final cancelled = order.copyWith(status: OrderStatus.cancelled);
    final saved = await _repo.update(cancelled);
    await _notifications.send(OrderCancelledNotification(saved));
    return saved;
  }
}
```

The extension defines the **question** (`canBeCancelled`). The service performs the **action** (`cancel`). The service uses the extension internally — this keeps the service logic readable too.

## Anti-Patterns

```dart
// BAD — extension with side effects
extension on Order {
  Future<void> cancel(OrderRepository repo) async {
    await repo.delete(this);
  }
}

// BAD — extension using service locator
extension on Order {
  bool get canBeCancelled => di<RuleEngine>().evaluate(this);
}

// BAD — procedural function when extension fits
bool isOrderExpired(Order order) => order.expiresAt.isBefore(DateTime.now());

// BAD — utility class that wraps a single type
class OrderHelper {
  static bool isExpired(Order order) => ...;
  static bool canBeCancelled(Order order) => ...;
}

// BAD — generic extension name
extension OrderExtensions on Order { ... }

// BAD — extension that mutates the object
extension on Order {
  void expire() { status = OrderStatus.expired; }
}
```

## Checklist

- [ ] Asked "can this be an extension?" before creating a class or function
- [ ] Extension is pure — no DI, no side effects, no state mutation
- [ ] Domain-owner rule applied — richer domain type owns the extension
- [ ] Extension name reflects the concern (not generic `*Extensions` or `*Utils`)
- [ ] Dartdoc on every public extension member
- [ ] Services handle operations requiring DI, DB, or network — not extensions
- [ ] No procedural functions that operate on a single type (should be extensions)
- [ ] No utility classes that wrap a single type (should be extensions)
