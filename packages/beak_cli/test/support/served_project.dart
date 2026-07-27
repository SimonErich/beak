/// Running a scaffolded project's own server, and talking to it.
///
/// The end-to-end proofs are only worth their cost if they exercise the real
/// entrypoints, so they start `bin/serve.dart` and speak HTTP to it rather
/// than reaching into the database. This is the plumbing that makes that
/// readable.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A port nothing is listening on, released before it is handed over.
Future<int> freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final int port = probe.port;
  await probe.close();
  return port;
}

/// Starts [project]'s `bin/serve.dart` on [port] and waits for it to listen.
///
/// Throws with the process output when it exits instead, which is the whole
/// value of doing this rather than sleeping: a server that failed to boot
/// says why.
Future<Process> serveProject(Directory project, {required int port}) async {
  final Process server = await Process.start(
    'dart',
    ['run', 'bin/serve.dart'],
    workingDirectory: project.path,
    environment: {'PORT': '$port', 'HOST': '127.0.0.1'},
  );
  await _listening(server);
  return server;
}

/// Stops [server] and waits for it to be gone.
Future<void> stopServer(Process server) async {
  server.kill(ProcessSignal.sigkill);
  await server.exitCode;
}

/// POSTs [body] as JSON to [path] on [port], returning the decoded response.
///
/// Throws when the status is not 2xx, with the body, since a failed call in a
/// proof is a defect rather than a case to handle.
Future<Object?> postJson(
  int port,
  String path,
  Map<String, Object?> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final HttpClientResponse response = await request.close();
    final String text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('POST $path answered ${response.statusCode}: $text');
    }
    return jsonDecode(text);
  } finally {
    client.close();
  }
}

/// The `values` maps of a query response's items.
List<Map<String, Object?>> recordsOf(Object? queryResponse) =>
    switch (queryResponse) {
      {'items': final List<Object?> items} => [
        for (final item in items)
          switch (item) {
            {'values': final Map<String, Object?> values} => values,
            _ => throw StateError('an item carried no "values": $item'),
          },
      ],
      _ => throw StateError('the response carried no "items": $queryResponse'),
    };

/// Waits for [server] to say it is listening, or to die trying.
///
/// Watches both streams: the generated entrypoint logs to stderr, and a
/// failure to boot arrives on whichever one the failure chose.
Future<void> _listening(Process server) async {
  final ready = Completer<void>();
  final output = StringBuffer();
  void watch(Stream<List<int>> stream) {
    stream.transform(utf8.decoder).listen((chunk) {
      output.write(chunk);
      if (!ready.isCompleted && output.toString().contains('listening on')) {
        ready.complete();
      }
    });
  }

  watch(server.stdout);
  watch(server.stderr);
  unawaited(
    server.exitCode.then((code) {
      if (!ready.isCompleted) {
        ready.completeError(StateError('the server exited $code:\n$output'));
      }
    }),
  );
  await ready.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () => throw StateError('the server never listened:\n$output'),
  );
}
