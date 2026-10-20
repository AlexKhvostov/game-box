export type ConnectionStatus = 'unknown' | 'online' | 'checking' | 'offline';
export function transportErrorText(code: string, locale: string): string | null {
  const messages: Record<string, [string, string]> = {
    network_unavailable: ['Запрос не прошёл. Повторите действие.', 'The request did not complete. Please retry.'],
    request_timeout: ['Сервер не ответил вовремя. Повторите действие.', 'The server did not respond in time. Please retry.'],
    service_unavailable: ['Сервер не смог выполнить запрос. Повторите позже.', 'The server could not process this request. Please retry later.'],
  };
  return messages[code]?.[locale === 'en' ? 1 : 0] ?? null;
}
type Ticket = { epoch: number; generation: number };
export class TransportError extends Error {
  code: 'network_unavailable' | 'request_timeout';
  constructor(code: 'network_unavailable' | 'request_timeout') { super(code); this.code = code; }
}

// HTTP reachability is independent of authentication, game errors and journal ACKs.
// A request started before a newer HTTP response cannot take the connection down.
export class ConnectionTracker {
  status: ConnectionStatus = 'unknown';
  private epoch = 0;
  private generation = 0;
  private changed: (status: ConnectionStatus) => void;
  constructor(changed: (status: ConnectionStatus) => void = () => {}) { this.changed = changed; }
  ticket(): Ticket { return { epoch: this.epoch, generation: this.generation }; }
  invalidate() { this.generation++; }
  response(_ticket: Ticket) {
    // Headers observed now are fresh evidence even if the request began before resume.
    // Only failures are invalidated by lifecycle changes.
    this.epoch++; this.set('online'); return true;
  }
  failure(ticket: Ticket, confirmed = false) {
    if (ticket.generation !== this.generation || ticket.epoch !== this.epoch) return false;
    this.set(confirmed ? 'offline' : 'checking'); return true;
  }
  private set(status: ConnectionStatus) { if (status !== this.status) { this.status = status; this.changed(status); } }
}

export class ApiTransport {
  readonly connection: ConnectionTracker;
  private active = true;
  private disposed = false;
  private probe: Promise<void> | null = null;
  private probeAbort: AbortController | null = null;
  private retry: ReturnType<typeof setTimeout> | null = null;
  private lastProbe = -Infinity;
  private retryDelay = 5000;
  private needsResumeCheck = false;
  private fetcher: typeof fetch;
  private now: () => number;
  private timeoutMs: number;
  private probeTimeoutMs: number;
  private cooldownMs: number;
  private endpoint: string;
  constructor(endpoint: string, options: {
    changed?: (status: ConnectionStatus) => void; fetcher?: typeof fetch; now?: () => number;
    timeoutMs?: number; probeTimeoutMs?: number; cooldownMs?: number;
  } = {}) {
    this.endpoint = endpoint;
    this.fetcher = options.fetcher ?? fetch; this.now = options.now ?? (() => performance.now());
    this.timeoutMs = options.timeoutMs ?? 20000; this.probeTimeoutMs = options.probeTimeoutMs ?? 6000;
    this.cooldownMs = options.cooldownMs ?? 3000;
    this.connection = new ConnectionTracker(status => {
      if (status === 'online') { this.retryDelay = 5000; this.clearRetry(); }
      options.changed?.(status);
    });
  }
  async request<T>(init: RequestInit, consume: (response: Response) => Promise<T>): Promise<T> {
    const ticket = this.connection.ticket(), abort = new AbortController(); let received = false;
    const timeout = setTimeout(() => abort.abort('deadline'), this.timeoutMs);
    try {
      const response = await this.fetcher(this.endpoint, { ...init, signal: abort.signal, cache: 'no-store' });
      if (response.type === 'opaque' || response.type === 'opaqueredirect') throw Error('inaccessible_response');
      received = true; this.reached(ticket);
      return await consume(response);
    } catch (error) {
      if (!received) {
        if (!this.disposed && this.connection.failure(ticket)) void this.check();
        throw new TransportError(abort.signal.aborted ? 'request_timeout' : 'network_unavailable');
      }
      if (abort.signal.aborted) throw new TransportError('request_timeout');
      throw error;
    } finally { clearTimeout(timeout); }
  }
  // Browser online/offline events are hints. Only a CORS-visible HTTP response
  // proves reachability; an opaque response cannot do so. OPTIONS never mutates a player.
  check(): Promise<void> {
    if (this.disposed || !this.active || !this.endpoint) return Promise.resolve();
    if (this.probe) return this.probe;
    const remaining = this.cooldownMs - (this.now() - this.lastProbe);
    if (remaining > 0) { this.schedule(remaining); return Promise.resolve(); }
    this.needsResumeCheck = false; this.clearRetry(); this.lastProbe = this.now();
    const ticket = this.connection.ticket(), abort = new AbortController(); this.probeAbort = abort;
    const timeout = setTimeout(() => abort.abort('deadline'), this.probeTimeoutMs);
    this.probe = (async () => {
      try {
        const response = await Promise.resolve().then(() => this.fetcher(this.endpoint, { method: 'OPTIONS', mode: 'cors', cache: 'no-store', signal: abort.signal }));
        if (response.type === 'opaque' || response.type === 'opaqueredirect') throw Error('inaccessible_response');
        if (!this.disposed) this.reached(ticket);
      } catch {
        if (!this.disposed && this.active && (!abort.signal.aborted || abort.signal.reason === 'deadline')) this.connection.failure(ticket, true);
      } finally {
        clearTimeout(timeout); this.probe = null; this.probeAbort = null;
        if (!this.disposed && this.active && this.needsResumeCheck) queueMicrotask(() => { void this.check(); });
        else if (!this.disposed && this.active && ['offline', 'checking'].includes(this.connection.status)) {
          this.schedule(this.retryDelay); this.retryDelay = Math.min(30000, this.retryDelay * 2);
        }
      }
    })();
    return this.probe;
  }
  setActive(active: boolean) {
    if (this.active === active || this.disposed) return;
    this.active = active; this.connection.invalidate(); this.clearRetry();
    if (!active) this.probeAbort?.abort('suspended');
    else { this.needsResumeCheck = true; void this.check(); }
  }
  dispose() { this.disposed = true; this.active = false; this.connection.invalidate(); this.clearRetry(); this.probeAbort?.abort('disposed'); }
  private clearRetry() { if (this.retry) clearTimeout(this.retry); this.retry = null; }
  private reached(ticket: Ticket) { if (!this.disposed && this.connection.response(ticket)) { this.retryDelay = 5000; this.clearRetry(); } }
  private schedule(ms: number) {
    if (this.retry || this.disposed || !this.active) return;
    this.retry = setTimeout(() => { this.retry = null; void this.check(); }, Math.max(1, ms));
  }
}
