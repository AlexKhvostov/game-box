// Pure helpers used by the editor and offline tests.
export function cloneConfig(value) { return JSON.parse(JSON.stringify(value)); }
export function valueAt(config, path) { return path.split('.').reduce((v, key) => v?.[key], config); }
export function setValue(config, path, value) {
  const keys = path.split('.');
  let node = config;
  for (const key of keys.slice(0, -1)) node = node[key] ??= {};
  node[keys.at(-1)] = value;
}
export function defaultValue(rule) {
  if (rule.type === 'object') return Object.fromEntries(Object.entries(rule.fields).filter(([, r]) => !r.optional).map(([k, r]) => [k, defaultValue(r)]));
  if (rule.type === 'number') return rule.min ?? 0;
  if (rule.type === 'boolean') return false;
  if (rule.type === 'array') return [];
  if (rule.format === 'color') return '#172028';
  return rule.choices?.[0] ?? '';
}
function validateValue(value, rule, path, errors) {
  if (value === undefined && rule.optional) return;
  if (value === null && rule.nullable) return;
  if (rule.type === 'number') {
    if (typeof value !== 'number' || !Number.isFinite(value)) errors[path] = 'Нужно число';
    else if (value < rule.min || value > rule.max) errors[path] = `Допустимо от ${rule.min} до ${rule.max}`;
    else if (rule.step === 1 && !Number.isInteger(value)) errors[path] = 'Нужно целое число';
  } else if (rule.type === 'boolean') {
    if (typeof value !== 'boolean') errors[path] = 'Нужен переключатель';
  } else if (rule.type === 'string') {
    if (typeof value !== 'string') { errors[path] = 'Нужна строка'; return; }
    const length = [...value].length;
    if (length < (rule.minLength ?? 0) || length > (rule.maxLength ?? 128)) errors[path] = 'Проверьте длину строки';
    if (rule.choices && !rule.choices.includes(value)) errors[path] = 'Выберите значение из списка';
    const patterns = { color: /^#[0-9a-f]{6}$/i, identifier: /^[a-z0-9_-]{1,64}$/i, digits: /^\d*$/, rewardedId: /^\d*$/, interstitialId: /^(?:int-\d+)?$/ };
    if (patterns[rule.format] && !patterns[rule.format].test(value)) errors[path] = 'Неверный формат';
  } else if (rule.type === 'array') {
    if (!Array.isArray(value)) { errors[path] = 'Нужен список'; return; }
    if (value.length < rule.minItems || value.length > rule.maxItems) errors[path] = `Количество строк: от ${rule.minItems} до ${rule.maxItems}`;
    const ids = new Set();
    value.forEach((item, i) => {
      validateValue(item, rule.items, `${path}.${i}`, errors);
      if (item && typeof item.id === 'string') {
        if (ids.has(item.id)) errors[`${path}.${i}.id`] = 'ID должен быть уникальным';
        ids.add(item.id);
      }
    });
  } else if (rule.type === 'object') {
    if (!value || typeof value !== 'object' || Array.isArray(value)) { errors[path] = 'Нужен объект'; return; }
    for (const [key, field] of Object.entries(rule.fields)) validateValue(value[key], field, `${path}.${key}`, errors);
  }
}
export function validateConfig(config, schema) {
  const errors = {};
  if (!config || typeof config !== 'object' || Array.isArray(config)) return { config: 'Нужен JSON-объект' };
  for (const group of schema.groups) for (const field of group.fields) validateValue(valueAt(config, field.path), field, field.path, errors);
  if (Object.keys(errors).length) return errors;
  for (const [min, max] of [['angleMinDeg', 'angleMaxDeg'], ['speedMin', 'speedMax'], ['accelMin', 'accelMax']]) {
    if (config.enemies[min] > config.enemies[max]) errors[`enemies.${max}`] = 'Максимум не может быть меньше минимума';
  }
  if (config.economy.starsShop.packs.some(p => p.id === config.economy.starsShop.plus.id)) errors['economy.starsShop.plus.id'] = 'ID Plus совпадает с ID пакета';
  const area = config.player.size ** 2 * config.enemies.areaMultiplier;
  config.enemies.aspects.forEach((aspect, i) => {
    if (Math.sqrt(area * aspect) >= config.field.maxSide - 24 || Math.sqrt(area / aspect) >= config.field.maxSide - 24) errors[`enemies.aspects.${i}`] = 'Враг слишком большой для поля: уменьшите размер или площадь';
  });
  return errors;
}
export function exportConfig(config, scope, schema) {
  if (scope === 'all') return JSON.stringify(config, null, 2);
  if (!schema.remoteConfigKeys.includes(scope)) throw new Error('Неизвестный параметр Remote Config');
  const value = config[scope] ?? '';
  return typeof value === 'string' ? value : JSON.stringify(value, null, 2);
}
