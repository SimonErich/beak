-- Initialization for the worm_mysql test database.
--
-- MySQL 8.4 defaults new accounts to `caching_sha2_password`, whose
-- handshake over a non-TLS connection requires RSA public-key
-- retrieval. To let the test suite connect with `secure: false` we
-- switch the app user to `mysql_native_password` (re-enabled by the
-- container's `--mysql-native-password=ON` flag) and grant it full
-- access to the test schema.
ALTER USER 'worm'@'%' IDENTIFIED WITH mysql_native_password BY 'worm';
GRANT ALL PRIVILEGES ON worm_test.* TO 'worm'@'%';
FLUSH PRIVILEGES;
