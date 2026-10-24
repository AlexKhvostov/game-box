import { telegram, isNativeTelegram } from '../platform/telegram';
import type { ApiResult } from './contracts';
import {ApiTransport,TransportError,type ConnectionStatus} from './connection';
export class ApiError extends Error { code: string; retryAfterMs?: number; source: 'api' | 'transport'; constructor(code: string, retryAfterMs?: number, source: 'api' | 'transport' = 'api') { super(code); this.code = code; this.retryAfterMs = retryAfterMs; this.source = source; } }
export const localQa = import.meta.env.DEV && ['127.0.0.1', 'localhost'].includes(location.hostname);
export class TelegramApi {
  private initData = '';
  private endpoint = import.meta.env.VITE_TELEGRAM_API_URL || (localQa ? '/qa-api' : '');
  private transport: ApiTransport;
  constructor(changed?: (status: ConnectionStatus) => void) { this.transport = new ApiTransport(this.endpoint, {changed}); }
  checkConnection() { return this.transport.check(); }
  setActive(active: boolean) { this.transport.setActive(active); }
  dispose() { this.transport.dispose(); }
  sessionMaterial() {return this.initData;}
  cacheNamespace() {return `telegram-v2|${this.endpoint}|${import.meta.env.VITE_TELEGRAM_APP_URL??''}`;}
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
    try {
      return await this.transport.request({ method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `tma ${this.initData}` },
        body: JSON.stringify(body) }, async response => {
        let result;
        try { result=await response.json(); } catch(error) { if(error instanceof SyntaxError)throw new ApiError('service_unavailable');throw error; }
        if (!response.ok || result?.ok !== true) throw new ApiError(result?.error ?? 'service_unavailable', result?.retryAfterMs);
        return result;
      });
    } catch(error) { if(error instanceof ApiError)throw error;if(error instanceof TransportError)throw new ApiError(error.code,undefined,'transport');throw new ApiError('service_unavailable'); }
  }
}
