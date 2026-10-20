import { telegram, isNativeTelegram } from '../platform/telegram';
import type { ApiResult } from './contracts';
export class ApiError extends Error { code: string; retryAfterMs?: number; constructor(code: string, retryAfterMs?: number) { super(code); this.code = code; this.retryAfterMs = retryAfterMs; } }
export const localQa = import.meta.env.DEV && ['127.0.0.1', 'localhost'].includes(location.hostname);
export class TelegramApi {
  private initData = '';
  private endpoint = import.meta.env.VITE_TELEGRAM_API_URL || (localQa ? '/qa-api' : '');
  async initialize() {
    if (typeof structuredClone !== 'function' || !navigator.locks || !Array.prototype.at) throw new ApiError('browser_update_required');
    if (isNativeTelegram()) this.initData = telegram()!.initData;
    else if (localQa) {
      const response = await fetch('/qa-session', { cache: 'no-store' });
      if (!response.ok) throw new ApiError('qa_server_unavailable');
      this.initData = (await response.json()).initData;
    } else throw new ApiError('native_telegram_required');
    if (!this.endpoint) throw new ApiError('api_not_configured');
  }
  async execute(body: Record<string, unknown>): Promise<ApiResult> {
    const abort=new AbortController(),timeout=setTimeout(()=>abort.abort(),20000);
    try {
      const response = await fetch(this.endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `tma ${this.initData}` },
        body: JSON.stringify(body), signal: abort.signal, cache: 'no-store' });
      let result;
      try { result=await response.json(); } catch { throw new ApiError(abort.signal.aborted?'network_unavailable':'service_unavailable'); }
      if (!response.ok || result.ok !== true) throw new ApiError(result.error ?? 'service_unavailable', result.retryAfterMs);
      return result;
    } catch(error) { if(error instanceof ApiError)throw error;throw new ApiError('network_unavailable'); } finally { clearTimeout(timeout); }
  }
}
