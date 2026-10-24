export interface TelegramWebApp {
  initData: string; platform: string; version: string; viewportHeight: number; isActive?: boolean;
  safeAreaInset?: { top: number; bottom: number; left: number; right: number };
  contentSafeAreaInset?: { top: number; bottom: number; left: number; right: number };
  ready(): void; expand(): void; disableVerticalSwipes?(): void; requestFullscreen?(): void;
  lockOrientation?(): void; isVersionAtLeast(version: string): boolean;
  onEvent(event: string, callback: (...args: unknown[]) => void): void;
  offEvent(event: string, callback: (...args: unknown[]) => void): void;
  setHeaderColor(color: string): void; setBackgroundColor(color: string): void;
  openTelegramLink(url: string): void; openLink(url: string): void;
  openInvoice?(url: string, callback: (status: 'paid' | 'cancelled' | 'failed' | 'pending') => void): void;
  HapticFeedback?: { impactOccurred(style: string): void; notificationOccurred(type: string): void };
  BackButton: { show(): void; hide(): void; onClick(fn: () => void): void; offClick(fn: () => void): void };
}
declare global { interface Window { Telegram?: { WebApp?: TelegramWebApp } } }
export const telegram = () => window.Telegram?.WebApp;
export const isNativeTelegram = () => !!telegram()?.initData && ['android', 'ios', 'tdesktop', 'macos'].includes(telegram()!.platform);
export function setupTelegram() {
  const tg = telegram(); if (!tg?.initData) return;
  tg.ready(); tg.expand(); tg.setHeaderColor('#061B2D'); tg.setBackgroundColor('#061B2D');
  if (tg.isVersionAtLeast('7.7')) tg.disableVerticalSwipes?.();
  if (tg.isVersionAtLeast('8.0')) { tg.requestFullscreen?.(); tg.lockOrientation?.(); }
}
export const safeInsets = () => {
  const tg = telegram(), a = tg?.safeAreaInset, b = tg?.contentSafeAreaInset;
  return { top: (a?.top ?? 0) + (b?.top ?? 0), bottom: (a?.bottom ?? 0) + (b?.bottom ?? 0), left: (a?.left ?? 0) + (b?.left ?? 0), right: (a?.right ?? 0) + (b?.right ?? 0) };
};
