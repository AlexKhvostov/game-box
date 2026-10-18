<?php
// Run once during release maintenance; ordinary requests only check the version.
function tg_ensure_score_tables(PDO $pdo) {
    if (tg_schema_ready($pdo, 'scores', 2)) return;
                $pdo->exec("
                    CREATE TABLE IF NOT EXISTS `scores` (
                        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                        `score_day` VARCHAR(10) NOT NULL DEFAULT '',
                        `user_id` VARCHAR(64) NULL,
                        `username` VARCHAR(64) NULL,
                        `first_name` VARCHAR(128) NULL,
                        `last_name` VARCHAR(128) NULL,
                        `player_name` VARCHAR(128) NOT NULL,
                        `photo_url` VARCHAR(512) NULL,
                        `time_ms` INT UNSIGNED NOT NULL,
                        `run_distance` INT UNSIGNED NOT NULL DEFAULT 0,
                        `risk_count` INT UNSIGNED NOT NULL DEFAULT 0,
                        `score` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                        `had_jump` TINYINT(1) NOT NULL DEFAULT 0,
                        `had_helmet` TINYINT(1) NOT NULL DEFAULT 0,
                        `created_at` BIGINT UNSIGNED NOT NULL,
                        KEY `idx_score_day` (`score_day`),
                        KEY `idx_user_day` (`user_id`, `score_day`),
                        KEY `idx_time_ms` (`time_ms`),
                        KEY `idx_score` (`score`),
                        KEY `idx_user_id` (`user_id`),
                        KEY `idx_username` (`username`),
                        KEY `idx_created_at` (`created_at`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                ");

    $columns = $pdo->query('SHOW COLUMNS FROM `scores`')->fetchAll(PDO::FETCH_COLUMN);
    foreach (['score'=>"BIGINT UNSIGNED NOT NULL DEFAULT 0", 'score_day'=>"VARCHAR(10) NOT NULL DEFAULT ''", 'hide_telegram'=>"TINYINT(1) NOT NULL DEFAULT 0"] as $name => $definition) {
        if (!in_array($name, $columns, true)) $pdo->exec('ALTER TABLE `scores` ADD COLUMN `' . $name . '` ' . $definition);
    }
    $indexes = $pdo->query('SHOW INDEX FROM `scores`')->fetchAll();
    $names = array_column($indexes, 'Key_name');
    foreach (['idx_score'=>'`score`', 'idx_score_day'=>'`score_day`', 'idx_user_day'=>'`user_id`,`score_day`', 'idx_user_time_created'=>'`user_id`,`time_ms`,`created_at`'] as $name => $columns) {
        if (!in_array($name, $names, true)) $pdo->exec('ALTER TABLE `scores` ADD INDEX `' . $name . '` (' . $columns . ')');
    }
    $pdo->exec("UPDATE `scores` SET `score_day` = DATE_FORMAT(FROM_UNIXTIME(`created_at` / 1000), '%Y-%m-%d') WHERE `score_day` = ''");

        $cntStmt = $pdo->query("SELECT COUNT(*) FROM `scores`");
        if ($cntStmt && (int)$cntStmt->fetchColumn() === 0) {
            $existingFileScores = json_decode(@file_get_contents(__DIR__ . '/scores.json') ?: '[]', true) ?: [];
            if (!empty($existingFileScores)) {
                $migStmt = $pdo->prepare("
                    INSERT INTO `scores` (
                        `user_id`, `username`, `first_name`, `last_name`, `player_name`, `photo_url`,
                        `time_ms`, `run_distance`, `risk_count`, `score`, `had_jump`, `had_helmet`, `created_at`, `score_day`
                    ) VALUES (
                        :user_id, :username, :first_name, :last_name, :player_name, :photo_url,
                        :time_ms, :run_distance, :risk_count, :score, :had_jump, :had_helmet, :created_at, :score_day
                    )
                ");
                $pdo->beginTransaction();
                try {
                foreach ($existingFileScores as $fs) {
                    $tMs = (int)($fs['timeMs'] ?? 0);
                    $rDist = (int)($fs['runDistance'] ?? 0);
                    $rCount = (int)($fs['riskCount'] ?? 0);
                    $calcScore = (int)round(($tMs / 1000.0) * $rDist * (1 + $rCount));
                    $migStmt->execute([
                        ':user_id'      => $fs['userId'] ?? null,
                        ':username'     => $fs['username'] ?? null,
                        ':first_name'   => $fs['firstName'] ?? null,
                        ':last_name'    => $fs['lastName'] ?? null,
                        ':player_name'  => $fs['playerName'] ?? 'Игрок',
                        ':photo_url'    => $fs['photoUrl'] ?? null,
                        ':time_ms'      => $tMs,
                        ':run_distance' => $rDist,
                        ':risk_count'   => $rCount,
                        ':score'        => $calcScore,
                        ':had_jump'     => !empty($fs['hadJump']) ? 1 : 0,
                        ':had_helmet'   => !empty($fs['hadHelmet']) ? 1 : 0,
                        ':created_at'   => (int)($fs['createdAt'] ?? (time() * 1000)),
                        ':score_day' => gmdate('Y-m-d', (int)(($fs['createdAt'] ?? time()*1000)/1000)),
                    ]);
                }
                $pdo->commit();
                } catch (Throwable $error) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $error; }
            }
        }

    tg_schema_complete($pdo, 'scores', 2);
}


