// Same invitation alphabet/lengths as Android and the previous PHP route.
// The destination is fixed; no URL, query parameter or credential is accepted.
export function playInvitationUrl(pathname) {
  if (typeof pathname !== 'string' || pathname.length > 64) return null;
  const match = /^\/a\/((?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12}))\/?$/i.exec(pathname);
  if (!match) return null;
  const code = match[1].toUpperCase();
  return 'https://play.google.com/store/apps/details?id=com.best4u.untouch&referrer=' + encodeURIComponent('invite=' + code);
}

if (typeof document !== 'undefined') {
  const destination = playInvitationUrl(location.pathname);
  const message = document.querySelector('#invitation-message');
  if (destination) {
    const link = document.querySelector('#invitation-play');
    link.href = destination;
    link.hidden = false;
    message.textContent = 'Открываем Google Play… / Opening Google Play…';
    location.replace(destination);
  } else {
    document.title = 'Untouch — приглашение не найдено';
    document.querySelector('#invitation-title').textContent = 'Приглашение не найдено / Invitation not found';
    message.textContent = 'Проверьте ссылку приглашения. / Check your invitation link.';
  }
}
