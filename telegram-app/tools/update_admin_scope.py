"""One-time explicit source edits for the existing admin form; no deployment."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'admin-console/src/app.js'
s=p.read_text(encoding='utf-8')
replacements={
 'НАСТРОЙКИ ANDROID':'НАСТРОЙКИ ИГРЫ',
 '<strong>Remote Config <span class="small-badge">Android</span></strong>':'<strong>Remote Config <span class="small-badge">${escape(scopeLabels[scope])}</span></strong>',
 '<span>/</span> Android <span>/</span>':'<span>/</span> Android · Telegram <span>/</span>',
 '<section class="config-summary"':'<label class="scope-selector">Область настроек<select id="config-scope">${Object.entries(scopeLabels).map(([key,label])=>`<option value="${key}" ${key===scope?\'selected\':\'\'}>${label}</option>`).join(\'\')}</select></label><section class="config-summary"',
 "  $('#search').oninput=event=>":"  $('#config-scope').onchange=event=>task(async()=>{const next=event.target.value;if(delta().length&&!confirm('Переключить область? Несохранённые изменения формы будут потеряны.')){event.target.value=scope;return;}configureScope(next);state.section=scope==='common'?'energy':'platform';state.query='';state.base=structuredClone(defaultsSnapshot);state.config=structuredClone(state.base.config);if(localPreview)render();else await loadLive();});\n  $('#search').oninput=event=>",
 '<p>Изменятся только перечисленные параметры Android.</p>':'<p>${scope===\'common\'?\'Общие правила изменятся для Android и Telegram.\':`Изменятся только параметры ${scopeLabels[scope]}.`}</p>',
 'localStorage.setItem(draftKey,JSON.stringify(patches()))':"localStorage.setItem(draftKey+'-'+scope,JSON.stringify(patches()))",
 "localStorage.getItem(draftKey)||'null'":"localStorage.getItem(draftKey+'-'+scope)||'null'",
}
for a,b in replacements.items():
    if b in s:continue
    if a not in s:raise SystemExit(f'Missing source anchor: {a[:90]}')
    s=s.replace(a,b)
p.write_text(s,encoding='utf-8')
print('Admin scope selector and review wording updated; no publication')
