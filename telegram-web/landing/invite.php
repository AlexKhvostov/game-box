<?php
// Fixed Play destination only. No cookie, credential, player data or mandatory landing page.
$value = $_GET['code'] ?? null;
$code = is_string($value) && strlen($value) <= 64 ? strtoupper(trim($value)) : '';
header('Cache-Control: no-store');
header('Referrer-Policy: no-referrer');
if (!preg_match('/^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$/D', $code)) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Invitation not found';
    exit;
}
$play = 'https://play.google.com/store/apps/details?id=com.best4u.untouch&referrer=' . rawurlencode('invite=' . $code);
header('Location: ' . $play, true, 302);
exit;
