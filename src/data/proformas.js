import { put, get, getAll, del } from './db.js';

export async function saveProforma(pf) { return put('proformas', pf); }
export async function getProforma(id) { return get('proformas', id); }
export async function getProformas() { return getAll('proformas'); }
export async function deleteProforma(id) { return del('proformas', id); }

export async function updateProforma(id, patch) {
  const current = await get('proformas', id);
  if (!current) return null;
  const next = Object.assign({}, current, patch);
  await put('proformas', next);
  return next;
}

export async function updateProformaStatus(id, status) {
  return updateProforma(id, { status });
}

export async function duplicateProforma(id) {
  const src = await get('proformas', id);
  if (!src) return null;
  const all = await getAll('proformas');
  const today = new Date().toISOString().slice(0, 10);
  const ymd = today.replace(/-/g, '');
  const todays = all.filter(p => p.number && p.number.includes(ymd));
  const number = 'MA-PF-' + ymd + '-' + String(todays.length + 1).padStart(4, '0');
  const copy = Object.assign({}, src, {
    id: 'pf_' + Math.random().toString(36).slice(2, 9),
    number,
    createdAt: today,
    status: 'draft'
  });
  await put('proformas', copy);
  return copy;
}
