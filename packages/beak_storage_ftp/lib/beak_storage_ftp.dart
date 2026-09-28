/// FTP storage driver for Beak's storage abstraction.
///
/// Plugs an FTP-backed driver into `beak_core`'s storage layer. Call
/// [registerFtpStorage] once at startup so a `BeakStorageRegistry` resolves
/// any `BeakFtpConfig` to an [FtpStorageDriver]. Because FTP has no expiring
/// links, stored files are served from a configured public base URL (an HTTP
/// server is expected to front the FTP directory).
///
/// ```dart
/// import 'package:beak_core/beak_core.dart';
/// import 'package:beak_storage_ftp/beak_storage_ftp.dart';
///
/// final registry = BeakStorageRegistry();
/// registerFtpStorage(registry);
///
/// final driver = registry.resolve(BeakFtpConfig(
///   host: 'ftp.example.com',
///   user: 'uploads',
///   password: '...',
///   baseDir: '/var/www/uploads',
///   publicBaseUrl: Uri.parse('https://cdn.example.com/uploads'),
/// ));
/// ```
///
/// [FtpTransport] is the wire seam the driver speaks through; production code
/// uses [SocketFtpTransport], and tests substitute a fake.
library;

export 'src/ftp_storage_driver.dart';
export 'src/ftp_transport.dart';

/// The version of the `beak_storage_ftp` package.
const String beakStorageFtpVersion = '0.9.0';
