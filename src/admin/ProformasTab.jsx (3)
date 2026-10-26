import { useState, useEffect } from 'preact/hooks';
import { getProformas, deleteProforma, duplicateProforma, updateProformaStatus } from '../data/proformas.js';
import { formatMoney } from '../data/pricing.js';
import { ProformaDoc } from '../components/ProformaBuilder.jsx';

const STATUSES = ['draft', 'sent', 'accepted', 'rejected', 'expired'];

export function ProformasTab({ onNew, onGoRequests, onGoTenders }) {
  const [rows, setRows] = useState(null);
  const [chooser, setChooser] = useState(false);
  const [viewing, setViewing] = useState(null);

  const load = async () => {
    const all = await getProformas();
    setRows(all.sort((a, b) => String(b.number).localeCompare(String(a.number))));
  };
  useEffect(() => { load(); }, []);

  const setStatus = async (p, status) => { await updateProformaStatus(p.id, status); load(); };
  const dup = async (p) => { await duplicateProforma(p.id); load(); };
  const remove = async (p) => { if (confirm('Delete proforma ' + p.number + '?')) { await deleteProforma(p.id); load(); } };

  if (viewing) {
    return (
      <div class="admin-panel">
        <div class="pf-actions no-print">
          <button class="btn btn-back" onClick={() => setViewing(null)}>Back</button>
          <button class="btn btn-primary" onClick={() => window.print()}>Print</button>
        </div>
        <ProformaDoc pf={viewing} />
      </div>
    );
  }
  if (!rows) return <div class="admin-panel"><h2>Proformas</h2><p>Loading...</p></div>;

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Proformas ({rows.length})</h2>
        <button class="btn-add" onClick={() => setChooser(!chooser)}>+ New Proforma</button>
      </div>
      {chooser && (
        <div class="admin-card">
          <strong>Start a proforma</strong>
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => { setChooser(false); onGoRequests && onGoRequests(); }}>
              From a request
            </button>
            <button class="btn btn-primary" onClick={() => { setChooser(false); onNew('internal'); }}>
              Internal / open bidding
            </button>
            <button class="btn btn-back" onClick={() => { setChooser(false); onGoTenders && onGoTenders(); }}>
              From eGP tender
            </button>
          </div>
        </div>
      )}
      {rows.length === 0 && <div class="admin-card">No proformas yet.</div>}
      {rows.map(p => (
        <div class="admin-card" key={p.id}>
          <div class="admin-card-head">
            <strong style="flex:1;min-width:160px;">{p.number}</strong>
            <span class={'pf-status ' + p.status}>{p.status}</span>
            <select value={p.status} onChange={e => setStatus(p, e.target.value)}>
              {STATUSES.map(s => <option value={s}>{s}</option>)}
            </select>
          </div>
          <div style="font-size:0.85rem;color:var(--gray);">
            {(p.client && p.client.name) || '-'} · {p.createdAt} · {p.mode === 'internal' ? 'Internal' : (p.mode === 'from-tender' ? 'From tender' : 'From request')} · <strong>{formatMoney(p.totals && p.totals.grandTotal)}</strong>
          </div>
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => setViewing(p)}>View</button>
            <button class="btn btn-back" onClick={() => dup(p)}>Duplicate</button>
            <button class="btn-del" onClick={() => remove(p)}>Delete</button>
          </div>
        </div>
      ))}
    </div>
  );
}