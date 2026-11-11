import 'package:beak_core/beak_core.dart';

import 'beak_write_handler.dart';

/// Maps every write binding a project generated to the handler that persists
/// it.
///
/// A generated model names its binding in [BeakModel.admission] (an enum value
/// such as `ShopWrite.menu`). The host writes one exhaustive `switch` over the
/// enum:
///
/// ```dart
/// final writes = BeakWriteBindings<ShopWrite>(
///   (binding) => switch (binding) {
///     ShopWrite.configuration => const BeakWriteHandler.stock(),
///     ShopWrite.menu => const BeakWriteHandler.derive(stampPublication),
///     ShopWrite.order => BeakWriteHandler.commands(
///       actions: {OrderActions.cancel: cancelOrder},
///       otherwise: BeakUnmatched.refuse,
///     ),
///   },
/// );
/// ```
///
/// [validate] runs once at startup and fails loudly on wiring that could never
/// work: a writable model with no binding, a binding that names a command the
/// model does not declare, or a read-only model that reports a write binding.
final class BeakWriteBindings<W extends Enum> {
  /// Creates the bindings from [handlerFor].
  const BeakWriteBindings(this.handlerFor);

  /// The handler of one binding value.
  final BeakWriteHandler Function(W binding) handlerFor;

  /// The handler every admitted write of [model] runs through.
  ///
  /// Throws a [BeakConfigurationException] when [model] admits writes but names
  /// no binding.
  BeakWriteHandler handlerForModel(BeakModel model) {
    final binding = model.admission?.write;
    if (binding == null) {
      throw BeakConfigurationException(
        'Model "${model.table}" admits writes but names no write binding.',
      );
    }
    if (binding is! W) {
      throw BeakConfigurationException(
        'Model "${model.table}" names the write binding "$binding", which is '
        'not a value of $W.',
      );
    }
    return handlerFor(binding);
  }

  /// Fails when these bindings cannot serve [registry].
  ///
  /// Every model with an admission that reports a write binding must use a
  /// value of [W], every command a handler binds must be declared by the
  /// model's behavior, and a model without a write binding must be read only:
  /// a write capability it cannot execute is a mistake.
  void validate(BeakModelRegistry registry) {
    for (final model in registry.all) {
      final admission = model.admission;
      if (admission == null) continue;
      final writes = model.capabilities.any(
        (operation) => operation != BeakOperation.read,
      );
      final binding = admission.write;
      if (binding == null) {
        if (writes) {
          throw BeakConfigurationException(
            'Model "${model.table}" declares ${_operationsOf(model)} but its '
            'admission has no write binding. Add a binding, or close the '
            'write operations.',
          );
        }
        continue;
      }
      if (binding is! W) {
        throw BeakConfigurationException(
          'Model "${model.table}" names the write binding "$binding", which '
          'is not a value of $W.',
        );
      }
      final handler = handlerFor(binding);
      final declared = {
        for (final action in model.behavior.actions) action.name,
      };
      for (final name in handler.actionNames) {
        if (!declared.contains(name)) {
          throw BeakConfigurationException(
            'The write binding "$binding" of "${model.table}" binds the '
            'command "$name", which the model does not declare.',
          );
        }
      }
    }
  }

  static String _operationsOf(BeakModel model) => [
    for (final operation in model.capabilities)
      if (operation != BeakOperation.read) operation.name,
  ].join(', ');
}
