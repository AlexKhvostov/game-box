export interface AdResult { done: boolean; error: boolean; description?: string; state?: string }
export interface AdController { show(): Promise<AdResult>; destroy(): void; addEventListener(event: string, callback: () => void): void; removeEventListener(event: string, callback: () => void): void }
export interface AdsgramSdk { init(options: { blockId: string; debug: boolean; debugConsole: boolean }): AdController }
declare global { interface Window { Adsgram?: AdsgramSdk } }
let loading: Promise<AdsgramSdk> | null = null;
function loadSdk() {
  if (window.Adsgram) return Promise.resolve(window.Adsgram);
  return loading ??= new Promise<AdsgramSdk>((resolve, reject) => {
    const script = document.createElement('script'); script.src = 'https://sad.adsgram.ai/js/sad.min.js'; script.async = true;
    const timer = setTimeout(() => reject(Error('ad_unavailable')), 15000);
    script.onload = () => { clearTimeout(timer); window.Adsgram ? resolve(window.Adsgram) : reject(Error('ad_unavailable')); };
    script.onerror = () => { clearTimeout(timer); reject(Error('ad_unavailable')); }; document.head.append(script);
  }).catch(error => { loading = null; throw error; });
}
// Inject the SDK in tests. A client completion is a provider callback, not SSV.
export function createAdPresenter(load: () => Promise<AdsgramSdk> = loadSdk) {
  let active: AdController | null = null, activeCancel: (() => void) | null = null;
  let generation=0, pending: number | null=null;
  return {
    async show(blockId: string, rewarded: boolean, debug = false, canShow = () => true) {
      if (active || pending!==null) throw Error('ad_busy');
      if (!(rewarded ? /^\d+$/ : /^int-\d+$/).test(blockId)) throw Error('ad_unavailable');
      const epoch=++generation;pending=epoch;
      let sdk:AdsgramSdk;
      try{sdk=await load();}finally{if(pending===epoch)pending=null;}
      if(epoch!==generation||!canShow())return false;
      if (active) throw Error('ad_busy');
      const controller = sdk.init({ blockId, debug, debugConsole: false }); active = controller;
      let earned = false, canceled = false;
      const reward = () => earned = true;
      let settleCancel!: (result: AdResult) => void;
      const canceledResult = new Promise<AdResult>(resolve => settleCancel = resolve);
      const cancel = () => { canceled = true; settleCancel({done:false,error:false}); controller.destroy(); };
      activeCancel = cancel;
      const watchdog = setTimeout(cancel, 180000);
      controller.addEventListener('onReward', reward);
      const visibility = () => { if (document.hidden) cancel(); };
      document.addEventListener('visibilitychange', visibility);
      try {
        const result = await Promise.race([controller.show(), canceledResult]);
        return !canceled && !result.error && (rewarded ? earned && result.done === true : true);
      } catch { return false; }
      finally { clearTimeout(watchdog); controller.removeEventListener('onReward', reward); document.removeEventListener('visibilitychange', visibility); controller.destroy(); if (active === controller) { active = null; activeCancel = null; } }
    },
    destroy() { generation++;pending=null;activeCancel?.(); active = null; activeCancel = null; }
  };
}
export const adPresenter = createAdPresenter();
