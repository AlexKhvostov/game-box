/** Telegram Mini App bridge (port of lib/telegram/telegram_bridge_web.dart). */

function readStoredLightTheme() {
  try {
    const d = JSON.parse(localStorage.getItem('untouch_tg_economy') || '{}');
    return d.lightTheme === true;
  } catch (_) {
    return false;
  }
}

export class TelegramBridge {
  constructor() {
    this.viewPadding = { top: 44, right: 0, bottom: 0, left: 0 };
    this.safeArea = { top: 0, right: 0, bottom: 0, left: 0 };
    this.contentSafeArea = { top: 0, right: 0, bottom: 0, left: 0 };
    this._tg = null;
    this.hapticEnabled = true;
    this.onResize = null;
    this._syncInsets();
  }

  boot() {
    const tg = window.Telegram && window.Telegram.WebApp;
    if (tg) {
      this._tg = tg;
      try {
        tg.ready();
        this.rememberStartParam();
        tg.expand();
        if (typeof tg.disableVerticalSwipes === 'function') tg.disableVerticalSwipes();
        if (typeof tg.requestFullscreen === 'function') tg.requestFullscreen();
        if (typeof tg.lockOrientation === 'function') tg.lockOrientation();
        this.applyUiTheme(readStoredLightTheme());
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
    this.applyUiTheme(readStoredLightTheme());
    this.rememberStartParam();
  }

  applyUiTheme(light) {
    const on = Boolean(light);
    document.documentElement.setAttribute('data-theme', on ? 'light' : 'dark');
    const chrome = on ? '#D7E2EA' : '#0E1419';
    const tg = this._tg;
    try {
      if (typeof tg?.setHeaderColor === 'function') tg.setHeaderColor(chrome);
      if (typeof tg?.setBackgroundColor === 'function') tg.setBackgroundColor(chrome);
    } catch (_) {}
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

  get initData() {
    return this._tg?.initData || '';
  }

  _looksLikeRef(value) {
    return typeof value === 'string' && /^r\d{1,20}$/.test(value.trim());
  }

  _readStoredRef() {
    try {
      return localStorage.getItem('untouch_pending_ref') || '';
    } catch (_) {
      return '';
    }
  }

  rememberStartParam(value = this.startParam) {
    if (!this._looksLikeRef(value)) return;
    try {
      localStorage.setItem('untouch_pending_ref', value.trim());
    } catch (_) {}
  }

  clearStoredRef() {
    try {
      localStorage.removeItem('untouch_pending_ref');
    } catch (_) {}
    try {
      document.cookie = 'untouch_ref=; Max-Age=0; path=/';
    } catch (_) {}
  }

  get startParam() {
    const fromTg = this._tg?.initDataUnsafe?.start_param;
    if (this._looksLikeRef(fromTg)) return String(fromTg).trim();

    const init = this.initData;
    if (init) {
      const match = /(?:^|&)start_param=([^&]+)/.exec(init);
      if (match) {
        const decoded = decodeURIComponent(match[1].replace(/\+/g, ' '));
        if (this._looksLikeRef(decoded)) return decoded.trim();
      }
    }

    try {
      const url = new URL(window.location.href);
      for (const key of ['ref', 'startapp', 'tgWebAppStartParam']) {
        const q = url.searchParams.get(key);
        if (this._looksLikeRef(q)) return q.trim();
      }
    } catch (_) {}

    const hash = String(window.location.hash || '');
    const hm = /(?:^|[&#])tgWebAppStartParam=([^&]+)/.exec(hash);
    if (hm) {
      const decoded = decodeURIComponent(hm[1].replace(/\+/g, ' '));
      if (this._looksLikeRef(decoded)) return decoded.trim();
    }

    const cookie = typeof document !== 'undefined'
      ? /(?:^|; )untouch_ref=([^;]+)/.exec(document.cookie)
      : null;
    if (cookie) {
      const decoded = decodeURIComponent(cookie[1]);
      if (this._looksLikeRef(decoded)) return decoded.trim();
    }

    const stored = this._readStoredRef();
    return this._looksLikeRef(stored) ? stored.trim() : '';
  }

  get inviteStartapp() {
    const id = this.user?.id;
    return id != null ? `r${id}` : '';
  }

  inviteUrl() {
    const param = this.inviteStartapp;
    return param
      ? `https://t.me/UntouchGameBot/untouch?startapp=${param}`
      : 'https://t.me/UntouchGameBot/untouch';
  }

  /** Короткая ссылка в бота с кодом /start r123. */
  inviteShareUrl() {
    const id = this.user?.id;
    return id != null
      ? `https://t.me/UntouchGameBot?start=r${id}`
      : 'https://t.me/UntouchGameBot';
  }

  canSharePreparedMessage() {
    return typeof this._tg?.shareMessage === 'function';
  }

  sharePreparedMessage(id) {
    return new Promise((resolve) => {
      if (!id || !this.canSharePreparedMessage()) {
        resolve(false);
        return;
      }
      try {
        this._tg.shareMessage(String(id), (ok) => resolve(Boolean(ok)));
      } catch (e) {
        console.warn('shareMessage', e);
        resolve(false);
      }
    });
  }

  openBotChat() {
    return this.openUserChat('UntouchGameBot');
  }

  requestWriteAccess() {
    return new Promise((resolve) => {
      const tg = this._tg;
      if (!tg || typeof tg.requestWriteAccess !== 'function') {
        resolve(false);
        return;
      }
      try {
        tg.requestWriteAccess((ok) => resolve(Boolean(ok)));
      } catch (e) {
        console.warn('requestWriteAccess', e);
        resolve(false);
      }
    });
  }

  /**
   * Opens Stars invoice. Resolves with Telegram status: paid | cancelled | failed | pending.
   */
  openInvoice(url) {
    return new Promise((resolve, reject) => {
      const tg = this._tg;
      if (!tg || typeof tg.openInvoice !== 'function') {
        reject(new Error('openInvoice unavailable'));
        return;
      }
      try {
        tg.openInvoice(url, (status) => resolve(status || 'unknown'));
      } catch (e) {
        reject(e);
      }
    });
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
    if (this.hapticEnabled === false) return;
    const hf = this._tg?.HapticFeedback;
    try {
      if (hf) {
        if (type === 'impact') {
          if (typeof hf.impactOccurred === 'function') hf.impactOccurred(style);
          else hf.impact?.(style);
        } else if (type === 'notification') {
          if (typeof hf.notificationOccurred === 'function') hf.notificationOccurred(style);
          else hf.notification?.(style);
        } else if (type === 'selection') {
          if (typeof hf.selectionChanged === 'function') hf.selectionChanged();
          else hf.selection?.();
        }
      }
    } catch (_) {}
  }

  /** Тот же канал, что проигрыш: notificationOccurred. style: success | warning | error */
  timerPulse(style = 'warning') {
    if (this.hapticEnabled === false) return;
    const kind = style === 'success' || style === 'error' ? style : 'warning';
    this.haptic('notification', kind);
  }

  async share(text, url = 'https://t.me/UntouchGameBot', blob = null) {
    const tg = this._tg;
    this.haptic('impact', 'medium');
    const fileName = blob ? 'untouch-invite.png' : 'untouch-record.png';

    if (blob && typeof File !== 'undefined' && navigator.canShare) {
      try {
        const file = new File([blob], fileName, { type: 'image/png' });
        if (navigator.canShare({ files: [file] })) {
          await navigator.share({
            title: 'Untouch',
            text: `${text}\n\n${url}`,
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
