<?php
/**
 * Пример настроек бота. Скопируйте в bot_config.php на HostLand.
 * Файл bot_config.php не коммитится.
 */

return [
    'token' => 'YOUR_BOT_TOKEN',
    // Необязательно: секрет для setWebhook secret_token
    'webhook_secret' => '',
    // Необязательно: ключ для ?diag=KEY (без ключа диагностика закрыта)
    'diag_key' => '',
    // Обязательно для админки /admin/ — длинный секрет, не токен бота
    'admin_key' => '',
    // Если HostLand не достучаться до api.telegram.org (часто с РФ-хостинга):
    // 1) Cloudflare Worker из tools/telegram-api-proxy.worker.js → сюда его URL
    // 2) или SOCKS/HTTP прокси, например socks5://127.0.0.1:1080
    'api_base' => 'https://api.telegram.org',
    'proxy' => '',
    // Необязательно: username без @, для ссылок приглашения
    'bot_username' => 'UntouchGameBot',
];
