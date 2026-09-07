<?php
/**
 * Короткая ссылка приглашения:
 *   https://untouch.ballaball.xyz/i/123456
 * Людям — редирект в бота с кодом (?start=r123), затем кнопка Играть.
 * Превью Telegram — карточка с картинкой, без длинного startapp.
 */
$id = isset($_GET['r']) ? preg_replace('/\D+/', '', (string)$_GET['r']) : '';
if (strlen($id) > 20) $id = substr($id, 0, 20);
$startapp = $id !== '' ? ('r' . $id) : '';
$play = $startapp !== ''
    ? ('https://t.me/UntouchGameBot?start=' . rawurlencode($startapp))
    : 'https://t.me/UntouchGameBot';

$ua = isset($_SERVER['HTTP_USER_AGENT']) ? (string)$_SERVER['HTTP_USER_AGENT'] : '';
$isPreview = (bool)preg_match('/TelegramBot|facebookexternalhit|Twitterbot|Slackbot|WhatsApp|LinkedInBot/i', $ua);

if ($startapp !== '') {
    setcookie('untouch_ref', $startapp, [
        'expires' => time() + 7 * 86400,
        'path' => '/',
        'secure' => true,
        'httponly' => false,
        'samesite' => 'Lax',
    ]);
}

if (!$isPreview) {
    header('Location: ' . $play, true, 302);
    header('Cache-Control: no-store');
    exit;
}

$image = 'https://untouch.ballaball.xyz/assets/branding/botfather_webapp_640x360.jpg';
$title = 'Попробуй побить мой рекорд в Untouch';
$desc = 'Заходи, уводи кубик от красных. Новым игрокам — бонус новичка.';
header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <title><?php echo htmlspecialchars($title, ENT_QUOTES, 'UTF-8'); ?></title>
  <meta name="description" content="<?php echo htmlspecialchars($desc, ENT_QUOTES, 'UTF-8'); ?>">
  <meta property="og:type" content="website">
  <meta property="og:title" content="<?php echo htmlspecialchars($title, ENT_QUOTES, 'UTF-8'); ?>">
  <meta property="og:description" content="<?php echo htmlspecialchars($desc, ENT_QUOTES, 'UTF-8'); ?>">
  <meta property="og:image" content="<?php echo htmlspecialchars($image, ENT_QUOTES, 'UTF-8'); ?>">
  <meta property="og:image:width" content="640">
  <meta property="og:image:height" content="360">
  <meta property="og:url" content="https://untouch.ballaball.xyz/i/<?php echo htmlspecialchars($id, ENT_QUOTES, 'UTF-8'); ?>">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<?php echo htmlspecialchars($title, ENT_QUOTES, 'UTF-8'); ?>">
  <meta name="twitter:description" content="<?php echo htmlspecialchars($desc, ENT_QUOTES, 'UTF-8'); ?>">
  <meta name="twitter:image" content="<?php echo htmlspecialchars($image, ENT_QUOTES, 'UTF-8'); ?>">
</head>
<body>
  <p><?php echo htmlspecialchars($desc, ENT_QUOTES, 'UTF-8'); ?></p>
  <p><a href="<?php echo htmlspecialchars($play, ENT_QUOTES, 'UTF-8'); ?>">Играть в Untouch</a></p>
</body>
</html>
