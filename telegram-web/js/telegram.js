/** Telegram Mini App bridge (port of lib/telegram/telegram_bridge_web.dart). */

export class TelegramBridge {
  constructor() {
    this.viewPadding = { top: 44, right: 0, bottom: 0, left: 0 };
    this.safeArea = { top: 0, right: 0, bottom: 0, left: 0 };
    this.contentSafeArea = { top: 0, right: 0, bottom: 0, left: 0 };
    this._tg = null;
    this.onResize = null;
    this._syncInsets();
  }

  boot() {
    const tg = window.Telegram && window.Telegram.WebApp;
    if (tg) {
      this._tg = tg;
      try {
        tg.ready();
        tg.expand();
        if (typeof tg.disableVerticalSwipes === 'function') tg.disableVerticalSwipes();
        if (typeof tg.requestFullscreen === 'function') tg.requestFullscreen();
        if (typeof tg.lockOrientation === 'function') tg.lockOrientation();
        if (typeof tg.setHeaderColor === 'function') tg.setHeaderColor('#0E1419');
        if (typeof tg.setBackgroundColor === 'function') tg.setBackgroundColor('#0E1419');
        if (typeof tg.requestSafeArea === 'function') tg.requestSafeArea();
        if (typeof tg.requestContentSafeArea === 'function') tg.requestContentSafeArea();
      } catch (e) {
        console.warn('Telegram WebApp boot', e);
      }
      this._syncInsets();
      tg.onEvent?.('viewportChanged', () => {
        this._syncInsets();
        if (typeof this.onResize === 'function') this.onResize();
      });
      tg.onEvent?.('fullscreenChanged', () => {
        this._syncInsets();
        if (typeof this.onResize === 'function') this.onResize();
      });
      tg.onEvent?.('safeAreaChanged', () => {
        this._syncInsets();
        if (typeof this.onResize === 'function') this.onResize();
      });
      tg.onEvent?.('contentSafeAreaChanged', () => {
        this._syncInsets();
        if (typeof this.onResize === 'function') this.onResize();
      });
    } else {
      this._syncInsets();
    }
  }

  _syncInsets() {
    const tg = this._tg;
    if (tg) {
      try {
        if (typeof tg.disableVerticalSwipes === 'function') tg.disableVerticalSwipes();
      } catch (_) {}
    }
    const sa = tg?.safeAreaInset || {};
    const csa = tg?.contentSafeAreaInset || {};
    this.safeArea = {
      top: sa.top || 0,
      right: sa.right || 0,
      bottom: sa.bottom || 0,
      left: sa.left || 0,
    };
    this.contentSafeArea = {
      top: csa.top || 0,
      right: csa.right || 0,
      bottom: csa.bottom || 0,
      left: csa.left || 0,
    };

    let topPad = this.safeArea.top + this.contentSafeArea.top;
    const isFullscreen = Boolean(tg?.isFullscreen);
    if (topPad < 1) {
      topPad = isFullscreen ? 54 : 44;
    }

    this.viewPadding = {
      top: topPad,
      right: this.safeArea.right + this.contentSafeArea.right,
      bottom: this.safeArea.bottom + this.contentSafeArea.bottom,
      left: this.safeArea.left + this.contentSafeArea.left,
    };

    const headerH = Math.max(this.contentSafeArea.top, 44);
    const btnPad = Math.max(this.contentSafeArea.left, this.contentSafeArea.right, 52);

    if (typeof document !== 'undefined') {
      const root = document.documentElement.style;
      root.setProperty('--tg-pad-top', `${this.viewPadding.top}px`);
      root.setProperty('--tg-pad-right', `${this.viewPadding.right}px`);
      root.setProperty('--tg-pad-bottom', `${this.viewPadding.bottom}px`);
      root.setProperty('--tg-pad-left', `${this.viewPadding.left}px`);
      root.setProperty('--tg-safe-top', `${this.safeArea.top}px`);
      root.setProperty('--tg-header-h', `${headerH}px`);
      root.setProperty('--tg-header-btn-pad', `${btnPad}px`);
    }
  }

  get user() {
    return this._tg?.initDataUnsafe?.user ?? null;
  }

  get playerInfo() {
    const u = this.user;
    return {
      userId: u?.id ? String(u.id) : null,
      username: u?.username ? `@${u.username.replace(/^@/, '')}` : null,
      firstName: u?.first_name || '',
      lastName: u?.last_name || '',
      photoUrl: u?.photo_url || null,
      playerName: this.playerName,
    };
  }

  get playerName() {
    const u = this.user;
    if (!u) return 'Игрок';
    if (u.username) return `@${u.username}`;
    const full = [u.first_name, u.last_name].filter(Boolean).join(' ');
    return full || 'Игрок';
  }

  get userPhotoUrl() {
    return this.user?.photo_url ?? null;
  }

  openUserChat(username, userId) {
    this.haptic('impact', 'light');
    let url = null;
    if (username) {
      const clean = String(username).replace(/^@/, '').trim();
      if (clean) url = `https://t.me/${clean}`;
    }
    if (!url && userId) {
      url = `tg://user?id=${userId}`;
    }
    if (!url) return false;

    if (this._tg?.openTelegramLink) {
      try {
        this._tg.openTelegramLink(url);
        return true;
      } catch (e) {
        console.warn('openTelegramLink failed', e);
      }
    }
    window.open(url, '_blank');
    return true;
  }

  haptic(type = 'impact', style = 'light') {
    try {
      this._tg?.HapticFeedback?.[type]?.(style);
    } catch (_) {}
  }

  async share(text, url = 'https://t.me/UntouchGameBot', blob = null) {
    const tg = this._tg;
    this.haptic('impact', 'medium');

    if (blob && typeof File !== 'undefined' && navigator.canShare) {
      try {
        const file = new File([blob], 'untouch-record.png', { type: 'image/png' });
        if (navigator.canShare({ files: [file] })) {
          await navigator.share({
            title: 'Untouch',
            text: `${text}\n${url}`,
            files: [file],
          });
          return true;
        }
      } catch (err) {
        console.warn('navigator.share with file failed', err);
      }
    }

    const shareUrl = `https://t.me/share/url?url=${encodeURIComponent(url)}&text=${encodeURIComponent(text)}`;

    if (tg?.openTelegramLink) {
      try {
        tg.openTelegramLink(shareUrl);
        return true;
      } catch (e) {
        console.warn('Telegram openTelegramLink failed', e);
      }
    }

    if (navigator.share) {
      try {
        await navigator.share({ title: 'Untouch', text, url });
        return true;
      } catch (_) {}
    }

    try {
      const win = window.open(shareUrl, '_blank');
      if (!win) {
        navigator.clipboard?.writeText?.(`${text}\n${url}`);
      }
    } catch (_) {
      navigator.clipboard?.writeText?.(`${text}\n${url}`);
    }
    return true;
  }

  syncInsets() {
    this._syncInsets();
  }
}

export const telegram = new TelegramBridge();
