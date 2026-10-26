import { useState, useEffect } from 'preact/hooks';
import { getRequests, saveRequest, deleteRequest } from '../data/requests.js';
import { fetchRemoteRequests, updateRemoteRequestStatus, deleteRemoteRequest } from '../data/remote.js';

const STATUSES = ['new', 'quoted', 'closed'];

export function RequestsTab({ onBuildProforma }) {
  const [rows, setRows] = useState(null);
  const [kind, setKind] = useState('all');
  const [openId, setOpenId] = useState(null);

  const load = async () => {
    const local = await getRequests();
    let remote = [];
    try { remote = await fetchRemoteRequests(); } catch (e) {}
    const map = new Map();
    remote.forEach(r => map.set(r.id, r));
    local.forEach(r => map.set(r.id, Object.assign({}, map.get(r.id) || {}, r)));
    setRows(Array.from(map.values()).sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt))));
  };
  useEffect(() => { load(); }, []);

  const setStatus = async (r, status) => {
    await saveRequest(Object.assign({}, r, { status }));
    updateRemoteRequestStatus(r.id, status);
    setRows(rows.map(x => x.id === r.id ? Object.assign({}, x, { status }) : x));
  };
  const remove = async (r) => {
    if (!confirm('Delete this request?')) return;
    await deleteRequest(r.id);
    deleteRemoteRequest(r.id);
    setRows(rows.filter(x => x.id !== r.id));
  };

  if (!rows) return <div class="admin-panel"><h2>Quote Requests</h2><p>Loadingâ€¦</p></div>;
  const list = kind === 'all' ? rows : rows.filter(r => r.kind === kind);

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Quote Requests ({list.length})</h2>
        <div class="pf-mode-tabs">
          {['all', 'services', 'materials'].map(k => (
            <button class={'pf-mode ' + (kind === k ? 'active' : '')} key={k} onClick={() => setKind(k)}>{k}</button>
          ))}
        </div>
      </div>
      {list.length === 0 && <div class="admin-card">No requests yet.</div>}
      {list.map(r => {
        const c = r.client || {};
        const isOpen = openId === r.id;
        return (
          <div class="admin-card" key={r.id}>
            <div class="admin-card-head">
              <strong style="flex:1;min-width:160px;">{c.name || '(no name)'} Â· {c.phone}</strong>
              <span class={'pf-status ' + (r.status === 'new' ? 'draft' : r.status)}>{r.kind}</span>
              <select value={r.status} onChange={e => setStatus(r, e.target.value)}>
                {STATUSES.map(s => <option value={s}>{s}</option>)}
              </select>
            </div>
            <div style="font-size:0.8rem;color:var(--gray);">
              {String(r.createdAt || '').slice(0, 10)}{c.projectName ? ' Â· ' + c.projectName : ''}{r.userEmail ? ' Â· ' + r.userEmail : ''}
            </div>
            {isOpen && (
              <div class="admin-subcard" style="margin-top:10px;">
                <div>{[c.company, c.email, c.siteAddress].filter(Boolean).join(' Â· ')}</div>
                {r.description && <p style="margin-top:6px;">{r.description}</p>}
                {r.serviceType && <div>Service: {r.serviceType} Â· Budget: {r.budgetRange || 'â€”'} Â· Timeline: {r.timeline || 'â€”'}</div>}
                {c.notes && <p style="margin-top:6px;">Notes: {c.notes}</p>}
                {r.cart && r.cart.length > 0 && (
                  <table class="pf-table">
                    <thead><tr><th>Item</th><th>Qty</th><th>Unit</th></tr></thead>
                    <tbody>{r.cart.map(l => <tr><td>{l.name}</td><td>{l.qty}</td><td>{l.unit}</td></tr>)}</tbody>
                  </table>
                )}
              </div>
            )}
            <div class="pf-actions">
              <button class="btn btn-back" onClick={() => setOpenId(isOpen ? null : r.id)}>{isOpen ? 'Hide details' : 'View details'}</button>
              <button class="btn btn-primary" onClick={() => onBuildProforma(r)}>Build Proforma</button>
              <button class="btn-del" onClick={() => remove(r)}>Delete</button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
