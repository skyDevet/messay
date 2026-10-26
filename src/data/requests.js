import { put, getAll, del } from './db.js';
export async function saveRequest(req) { return put('quote_requests', req); }
export async function getRequests() { return getAll('quote_requests'); }
export async function deleteRequest(id) { return del('quote_requests', id); }
export async function updateRequestStatus(id, status) {
  const all = await getAll('quote_requests');
  const r = all.find(x => x.id === id);
  if (!r) return null;
  const next = Object.assign({}, r, { status });
  await put('quote_requests', next);
  return next;
}
export function newRequestId() { return 'req_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 6); }
