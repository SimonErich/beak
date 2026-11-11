/// The one file of `beak_serverpod_generator` that imports `package:analyzer`.
///
/// The generator reads the element model of a resolved library: how a context
/// is opened, how a library is fetched from it and how a name is looked up in
/// its export namespace have all changed between analyzer majors, while the
/// element and type classes the emitters read have stayed put. Those lookups
/// live here, and the classes are re-exported, so a new analyzer major
/// changes this file and nothing else.
library;

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';

export 'package:analyzer/dart/element/element.dart'
    show
        ClassElement,
        Element,
        EnumElement,
        FieldElement,
        InterfaceElement,
        LibraryElement,
        MethodElement;
export 'package:analyzer/dart/element/nullability_suffix.dart'
    show NullabilitySuffix;
export 'package:analyzer/dart/element/type.dart'
    show DartType, InterfaceType, VoidType;

/// Resolves [library] (a URI) inside the package at [packageRoot] and hands
/// its element to [use], then releases the analysis context.
///
/// Throws a [FormatException] when the library cannot be resolved.
Future<T> withResolvedLibrary<T>({
  required String packageRoot,
  required String library,
  required T Function(LibraryElement element) use,
}) async {
  final contexts = AnalysisContextCollection(includedPaths: [packageRoot]);
  try {
    final session = contexts.contextFor(packageRoot).currentSession;
    final result = await session.getLibraryByUri(library);
    if (result is! LibraryElementResult) {
      throw FormatException(
        'Cannot resolve library $library from $packageRoot.',
      );
    }
    return use(result.element);
  } finally {
    await contexts.dispose();
  }
}

/// What [library] exports under [name], or `null` when it exports nothing by
/// that name.
Element? exportedElement(LibraryElement library, String name) =>
    library.exportNamespace.get2(name);
