export const metrikaCounters={qa:113772106,production:113772090} as const;
export function analyticsDestination(env:string|undefined,qaMode:string|undefined,hostname:string){
  const production=env==='production'&&qaMode==='false'&&hostname==='untouch-telegram-app.onrender.com';
  return {environment:production?'production':'qa',counter:production?metrikaCounters.production:metrikaCounters.qa} as const;
}
