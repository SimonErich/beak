import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A minimal in-process FTP server speaking just enough of RFC 959 (USER,
/// PASS, TYPE, PASV, MKD, STOR, RETR, DELE, SIZE, QUIT) to exercise
/// `SocketFtpTransport` over real sockets — no Docker service needed.
final class MiniFtpServer {
  /// Creates a server accepting [user]/[password] logins.
  MiniFtpServer({this.user = 'beak', this.password = 'secret'});

  /// Accepted login user.
  final String user;

  /// Accepted login password.
  final String password;

  /// Stored files, keyed by absolute remote path.
  final Map<String, Uint8List> files = {};

  /// Existing directories as absolute paths; the root always exists.
  final Set<String> directories = {'/'};

  /// When true, every STOR is refused with a `451` reply.
  bool refuseStores = false;

  late ServerSocket _listener;
  StreamSubscription<Socket>? _connections;

  /// The ephemeral control port the server listens on.
  int get port => _listener.port;

  /// Binds the control listener on a loopback ephemeral port.
  Future<void> start() async {
    _listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _connections = _listener.listen((socket) {
      unawaited(_serve(socket));
    });
  }

  /// Stops accepting connections.
  Future<void> stop() async {
    await _connections?.cancel();
    await _listener.close();
  }

  Future<void> _serve(Socket control) async {
    control.write('220 MiniFtpServer ready\r\n');
    String? pendingUser;
    var authenticated = false;
    ServerSocket? passiveListener;
    try {
      final lines = const LineSplitter().bind(utf8.decoder.bind(control));
      await for (final line in lines) {
        final space = line.indexOf(' ');
        final verb = (space < 0 ? line : line.substring(0, space))
            .toUpperCase();
        final argument = space < 0 ? '' : line.substring(space + 1);
        switch (verb) {
          case 'USER':
            pendingUser = argument;
            control.write('331 Password required\r\n');
          case 'PASS':
            authenticated = pendingUser == user && argument == password;
            control.write(
              authenticated ? '230 Logged in\r\n' : '530 Login incorrect\r\n',
            );
          case 'QUIT':
            control.write('221 Goodbye\r\n');
            await control.flush();
            return;
          case _ when !authenticated:
            control.write('530 Not logged in\r\n');
          case 'TYPE':
            control.write('200 Type set\r\n');
          case 'PASV':
            await passiveListener?.close();
            final listener = await ServerSocket.bind(
              InternetAddress.loopbackIPv4,
              0,
            );
            passiveListener = listener;
            final p = listener.port;
            control.write(
              '227 Entering Passive Mode '
              '(127,0,0,1,${p >> 8},${p & 0xff})\r\n',
            );
          case 'MKD':
            final dir = _normalize(argument);
            if (directories.contains(dir)) {
              control.write('550 Directory already exists\r\n');
            } else if (!directories.contains(_parentOf(dir))) {
              control.write('550 Parent directory missing\r\n');
            } else {
              directories.add(dir);
              control.write('257 "$dir" created\r\n');
            }
          case 'STOR':
            final listener = passiveListener;
            if (listener == null) {
              control.write('425 Use PASV first\r\n');
            } else if (refuseStores) {
              control.write('451 Local error in processing\r\n');
            } else if (!directories.contains(_parentOf(_normalize(argument)))) {
              control.write('550 No such directory\r\n');
            } else {
              control.write('150 Ok to send data\r\n');
              final data = await listener.first;
              final builder = BytesBuilder(copy: false);
              await data.forEach(builder.add);
              data.destroy();
              await listener.close();
              passiveListener = null;
              files[_normalize(argument)] = builder.takeBytes();
              control.write('226 Transfer complete\r\n');
            }
          case 'RETR':
            final listener = passiveListener;
            final source = files[_normalize(argument)];
            if (listener == null) {
              control.write('425 Use PASV first\r\n');
            } else if (source == null) {
              await listener.close();
              passiveListener = null;
              control.write('550 File not found\r\n');
            } else {
              control.write('150 Opening data connection\r\n');
              final data = await listener.first;
              data.add(source);
              await data.flush();
              await data.close();
              await listener.close();
              passiveListener = null;
              control.write('226 Transfer complete\r\n');
            }
          case 'DELE':
            if (files.remove(_normalize(argument)) == null) {
              control.write('550 File not found\r\n');
            } else {
              control.write('250 File deleted\r\n');
            }
          case 'SIZE':
            final stored = files[_normalize(argument)];
            control.write(
              stored == null
                  ? '550 Could not get file size\r\n'
                  : '213 ${stored.length}\r\n',
            );
          default:
            control.write('502 Command not implemented\r\n');
        }
      }
    } finally {
      await passiveListener?.close();
      control.destroy();
    }
  }

  static String _normalize(String path) {
    final collapsed = path.replaceAll(RegExp('/+'), '/');
    final trimmed = collapsed.endsWith('/') && collapsed.length > 1
        ? collapsed.substring(0, collapsed.length - 1)
        : collapsed;
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  static String _parentOf(String path) {
    final cut = path.lastIndexOf('/');
    return cut <= 0 ? '/' : path.substring(0, cut);
  }
}
