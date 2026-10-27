// Additive policy: missing fields retain legacy behavior without changing a
// published snapshot or its revision merely by reading it.
export const adFormatsDefaults = Object.freeze({
  banner: Object.freeze({enabled:false,installDelaySec:86400,unitId:''}),
  automatic: Object.freeze({enabled:true,longAbsenceSec:300,resumeGraceSec:180}),
  rewarded: Object.freeze({enabled:true})
});
export function adFormatsConfig(raw){
  if(raw!==undefined&&(!raw||typeof raw!=='object'||Array.isArray(raw)))throw Error('ad_formats_invalid');
  const out={};
  for(const key of Object.keys(raw??{}))if(!Object.hasOwn(adFormatsDefaults,key))throw Error('ad_formats_invalid');
  for(const [format,defaults]of Object.entries(adFormatsDefaults)){
    const value=raw?.[format];
    if(value!==undefined&&(!value||typeof value!=='object'||Array.isArray(value)))throw Error('ad_formats_invalid');
    for(const key of Object.keys(value??{}))if(!Object.hasOwn(defaults,key))throw Error('ad_formats_invalid');
    out[format]={...defaults,...value};
    for(const [key,defaultValue]of Object.entries(defaults)){
      const actual=out[format][key];
      if(typeof actual!==typeof defaultValue)throw Error('ad_formats_invalid');
      if(typeof actual==='number'&&(!Number.isSafeInteger(actual)||actual<0||actual>2592000))throw Error('ad_formats_invalid');
      if(key==='unitId'&&actual!==''&&!/^R-M-\d+-\d+$/.test(actual))throw Error('ad_formats_invalid');
    }
  }
  return out;
}
