<?php
// CLI only. Prepare invitation tables explicitly; never upload this as a public endpoint.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../telegram-web/api/mobile_invites.php';
try {
    $options = getopt('', ['apply', 'prefix:']);
    $dsn = getenv('UNTOUCH_INVITES_DSN');
    if (!is_string($dsn) || strncmp($dsn, 'mysql:', 6) !== 0) throw new RuntimeException('Provide UNTOUCH_INVITES_DSN for the explicitly selected database');
    $pdo = new PDO($dsn, getenv('UNTOUCH_INVITES_DB_USER') ?: '', getenv('UNTOUCH_INVITES_DB_PASSWORD') ?: '',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES => false]);
    $prefix = $options['prefix'] ?? '';
    if (isset($options['apply'])) mobile_invites_migrate($pdo, $prefix);
    echo json_encode(['ok' => true, 'applied' => isset($options['apply']),
        'schemaReady' => mobile_invites_schema_ready($pdo, $prefix)], JSON_PRETTY_PRINT) . PHP_EOL;
} catch (Throwable $error) {
    // DSNs/credentials and database diagnostics must not enter operator output.
    fwrite(STDERR, 'Invitation maintenance failed: ' . get_class($error) . PHP_EOL);
    exit(1);
}
