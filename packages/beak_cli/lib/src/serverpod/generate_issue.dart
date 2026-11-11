/// One thing `beak generate` refuses to continue past, and where it is.
final class BeakGenerateIssue {
  /// Creates an issue found in the file at [path].
  const BeakGenerateIssue({required this.path, required this.message});

  /// The file the issue is in, as the project names it.
  final String path;

  /// What is wrong, and how to fix it.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Thrown when `beak generate` cannot produce output: every issue at once,
/// so one run reports them all.
final class BeakGenerateException implements Exception {
  /// Creates an exception holding [issues], which must not be empty.
  BeakGenerateException(this.issues) : assert(issues.isNotEmpty);

  /// Creates an exception for a single problem.
  BeakGenerateException.single(String path, String message)
    : this([BeakGenerateIssue(path: path, message: message)]);

  /// Every problem found, in the order they were met.
  final List<BeakGenerateIssue> issues;

  @override
  String toString() => issues.join('\n');
}

/// Collects issues and throws them together.
final class BeakIssueSink {
  /// The issues reported so far.
  final List<BeakGenerateIssue> issues = [];

  /// Reports [message] against the file at [path].
  void add(String path, String message) =>
      issues.add(BeakGenerateIssue(path: path, message: message));

  /// Throws a [BeakGenerateException] when anything was reported.
  void throwIfAny() {
    if (issues.isNotEmpty) throw BeakGenerateException(List.of(issues));
  }
}
