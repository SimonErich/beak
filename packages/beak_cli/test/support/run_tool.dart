import 'dart:io';

/// What the Dart analysis server prints when its own usage ping cannot reach
/// the network and takes the server down. It says nothing about the code under
/// test.
const List<String> _analysisServerCrash = [
  'analysis server crashed unexpectedly',
  'analysis server shut down unexpectedly',
  'google-analytics.com',
];

/// Runs [command] in [workingDirectory] and retries up to [attempts] times
/// when the Dart analysis server crashes at startup.
///
/// `dart analyze` starts an analysis server, and that server sends a usage
/// ping before it does any work. Without a network the ping throws and takes
/// the server down, so an unrelated crash would fail a test about generated
/// code. Any other failure is returned on the first attempt.
Future<ProcessResult> runTool(
  List<String> command, {
  required String workingDirectory,
  int attempts = 3,
}) async {
  late ProcessResult result;
  for (int attempt = 1; attempt <= attempts; attempt++) {
    result = await Process.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
    );
    final String output = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (!_analysisServerCrash.any(output.contains)) {
      return result;
    }
  }
  return result;
}
