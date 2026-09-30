import 'dart:convert';

import '../common/beak_exception.dart';

/// One configurable dimension of a sellable variant.
final class BeakVariantAxis {
  /// Captures a stable key and the allowed values in presentation order.
  BeakVariantAxis({
    required this.key,
    required this.label,
    required Iterable<String> values,
  }) : values = List.unmodifiable(values) {
    if (key.isEmpty ||
        label.isEmpty ||
        this.values.isEmpty ||
        this.values.any((value) => value.trim().isEmpty) ||
        this.values.toSet().length != this.values.length) {
      throw const BeakConfigurationException(
        'Variant axes need unique nonempty values.',
      );
    }
  }

  /// Stable dimension identity.
  final String key;

  /// Human-readable dimension title.
  final String label;

  /// Choices for this dimension.
  final List<String> values;
}

/// A proposed combination, independent of product-specific SKU or price rules.
final class BeakVariantCombination {
  /// Captures values by axis key.
  BeakVariantCombination(Map<String, String> values)
    : values = Map.unmodifiable(values);

  /// One selected value per axis.
  final Map<String, String> values;

  /// Stable collision-safe identity, independent of axis ordering.
  String get key {
    final keys = values.keys.toList()..sort();
    return jsonEncode([
      for (final key in keys) [key, values[key]],
    ]);
  }

  /// A compact default variant label in axis presentation order.
  String get label => values.values.join(' / ');
}

/// Generates a bounded, deterministic preview before relationship rows are added.
final class BeakVariantMatrix {
  /// Creates a matrix without making any records or network requests.
  BeakVariantMatrix(
    Iterable<BeakVariantAxis> axes, {
    this.maximumCombinations = 500,
  }) : axes = List.unmodifiable(axes) {
    if (maximumCombinations < 1 ||
        this.axes.map((axis) => axis.key).toSet().length != this.axes.length) {
      throw const BeakConfigurationException(
        'Invalid variant matrix bounds or duplicate axes.',
      );
    }
    var count = this.axes.isEmpty ? 0 : 1;
    for (final axis in this.axes) {
      count *= axis.values.length;
      if (count > maximumCombinations) {
        throw BeakValidationException(
          'Choose fewer variant values; the limit is $maximumCombinations combinations.',
        );
      }
    }
  }

  /// Dimensions in presentation order.
  final List<BeakVariantAxis> axes;

  /// Explicit guard against accidentally constructing enormous drafts.
  final int maximumCombinations;

  /// Returns only combinations not already represented by [existing].
  List<BeakVariantCombination> preview({
    Iterable<BeakVariantCombination> existing = const [],
  }) {
    if (axes.isEmpty) return const [];
    var combinations = <Map<String, String>>[{}];
    for (final axis in axes) {
      combinations = [
        for (final combination in combinations)
          for (final value in axis.values) {...combination, axis.key: value},
      ];
    }
    final existingKeys = existing.map((combination) => combination.key).toSet();
    return List.unmodifiable(
      combinations
          .map(BeakVariantCombination.new)
          .where((combination) => !existingKeys.contains(combination.key)),
    );
  }
}
