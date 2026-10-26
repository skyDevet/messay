import { useState, useEffect, useMemo } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { getRateCategories, getRateItems } from '../data/ratebook.js';
import { saveProforma, getProformas } from '../data/proformas.js';
import { calcLineFromRate, calcProforma, nextProformaNumber, addDays, formatMoney } from '../data/pricing.js';
import { egpAddItems } from '../data/egp.js';

const EMPTY_CLIENT = { name: '', phone: '', email: '', company: '', projectName: '', siteAddress: '', zone: 'addis' };
const STEP_LABELS = ['Client', 'Items', 'Proforma'];

const redo = (l, qty, price) => calcLineFromRate(
  { id: l.sku, description: l.name, unit: l.unit, code: l.code || '', basePrice: l.basePrice, contractorPrice: l.contractorPrice },
  qty, price
);

export function ProformaBuilder({ mode, request, onClose, onSaved }) {
  const [data] = useStore();
  const b = data.business;
  const fromRequest = mode === 'from-request';
  const fromTender = mode === 'from-tender';

  const [step, setStep] = useState(1);
  const [editing, setEditing] = useState(!fromRequest);
  const [client, setClient] = useState(() => {
    if (fromRequest && request) return Object.assign({}, EMPTY_CLIENT, request.client);
    if (fromTender && request) {
      const li = request.detail || {};
      const addr = li.address || {};
      return Object.assign({}, EMPTY_CLIENT, {
        name: li.procuring_entity || request.tender?.procuringEntity || '',
        company: li.procuring_entity || '',
        email: addr.email || '',
        phone: [addr.telephone?.code, addr.telephone?.number].filter(Boolean).join(' '),
        projectName: li.name || request.tender?.lotName || '',
        siteAddress: [addr.town, addr.street].filter(Boolean).join(', '),
      });
    }
    return Object.assign({}, EMPTY_CLIENT);
  });
  const [lines, setLines] = useState(() => {
    if (fromTender && request && Array.isArray(request.items)) {
      return request.items.map((it, i) => ({
        sku: it.lotItemId || ('tender_' + i),
        name: it.description,
        code: '',
        unit: it.unit,
        qty: it.qty,
        basePrice: 0,
        contractorPrice: it.rate || 0,
        lineTotal: (it.rate || 0) * it.qty,
        margin: 0,
        taxable: true,
        leadTimeDays: 0,
        source: 'tender',
      }));
    }
    return [];
  });
  const [cats, setCats] = useState([]);
  const [items, setItems] = useState([]);
  const [search, setSearch] = useState('');
  const [cat, setCat] = useState('all');
  const [discountPct, setDiscountPct] = useState(0);
  const [markupPct, setMarkupPct] = useState(b.markupPct || 0);
  const [contingencyPct, setContingencyPct] = useState(b.contingencyPct || 0);
  const [validDays, setValidDays] = useState(b.validDays || 30);
  const [terms, setTerms] = useState(b.defaultTerms || '');
  const [number, setNumber] = useState('');
  const [pfId] = useState(() => 'pf_' + Math.random().toString(36).slice(2, 9));
  const [today] = useState(() => new Date().toISOString().slice(0, 10));
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [pushMsg, setPushMsg] = useState('');

  useEffect(() => {
    (async () => {
      try {
        setCats(await getRateCategories());
        setItems(await getRateItems());
        setNumber(nextProformaNumber(await getProformas()));
      } catch (e) { console.error('Proforma builder load failed:', e); }
    })();
  }, []);

  const setC = (k, v) => setClient(Object.assign({}, client, { [k]: v }));
  const locked = !editing;

  const results = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter(i =>
      (cat === 'all' || i.categoryId === cat) &&
      (!q || String(i.code).toLowerCase().includes(q) || String(i.description).toLowerCase().includes(q))
    );
  }, [items, search, cat]);

  const addLine = (item) => {
    const existing = lines.find(l => l.sku === item.id);
    if (existing) setLines(lines.map(l => l.sku === item.id ? redo(l, l.qty + 1, l.contractorPrice) : l));
    else setLines([...lines, calcLineFromRate(item, 1)]);
  };
  const setQty = (sku, v) => setLines(lines.map(l => l.sku === sku ? redo(l, Math.max(0, parseFloat(v) || 0), l.contractorPrice) : l));
  const setRate = (sku, v) => setLines(lines.map(l => l.sku === sku ? redo(l, l.qty, Math.max(0, parseFloat(v) || 0)) : l));
  const removeLine = (sku) => setLines(lines.filter(l => l.sku !== sku));

  const totals = calcProforma({
    lines,
    freightZone: client.zone,
    zones: data.freight.zones,
    discountPct: parseFloat(discountPct) || 0,
    vatRate: b.vatRate || 0,
    markupPct: parseFloat(markupPct) || 0,
    contingencyPct: parseFloat(contingencyPct) || 0
  });

  const days = parseInt(validDays, 10) || 0;
  const pf = {
    id: pfId,
    number,
    createdAt: today,
    validDays: days,
    validUntil: addDays(today, days),
    status: 'draft',
    mode,
    sourceRequestId: request && request.id ? request.id : null,
    sourceTenderId: fromTender && request?.tender ? request.tender.id : null,
    quotationRequestId: fromTender && request
      ? (request.detail?.quotationRequestId || request.detail?.quatationRequestId || request.tender?.id || null)
      : null,
    client,
    lines,
    freightZone: client.zone,
    discountPct: parseFloat(discountPct) || 0,
    markupPct: parseFloat(markupPct) || 0,
    contingencyPct: parseFloat(contingencyPct) || 0,
    vatRate: b.vatRate || 0,
    totals,
    terms
  };

  const save = async () => {
    setBusy(true); setErr('');
    try {
      await saveProforma(pf);
      setSaved(true);
      if (onSaved) onSaved(pf);
    } catch (e) { setErr('Could not save: ' + (e.message || e)); }
    setBusy(false);
  };

  const canNext1 = client.name.trim() !== '';
  const canNext2 = lines.length > 0;
  const lockCls = locked ? 'pf-locked' : '';

  return (
    <div class="pf-builder pf-wizard">
      <div class="no-print">
        <div class="admin-panel-head">
          <h2>{fromRequest ? 'Proforma from request' : (fromTender ? 'Proforma from tender' : 'Internal proforma')}</h2>
          <button class="btn btn-back" onClick={onClose}>{saved ? 'Done' : 'Cancel'}</button>
        </div>
        <div class="pf-steps">
          {STEP_LABELS.map((l, i) => (
            <span key={l} class={'pf-step ' + (step === i + 1 ? 'active ' : '') + (step > i + 1 ? 'done' : '')}>{i + 1}. {l}</span>
          ))}
        </div>
      </div>

      {step === 1 && (
        <div>
          <div class="admin-panel-head">
            <h3>Client details</h3>
            {fromRequest && (
              <button type="button" class="btn btn-back" onClick={() => setEditing(!editing)}>{editing ? 'Lock details' : 'Edit details'}</button>
            )}
          </div>
          {fromRequest && !request && <div class="admin-msg">No request attached.</div>}
          {fromTender && !request && <div class="admin-msg">No tender attached.</div>}
          <div class="pf-grid">
            <label>Full name *<input class={lockCls} readOnly={locked} value={client.name} onInput={e => setC('name', e.target.value)} /></label>
            <label>Phone<input class={lockCls} readOnly={locked} value={client.phone} onInput={e => setC('phone', e.target.value)} /></label>
            <label>Email<input class={lockCls} readOnly={locked} value={client.email} onInput={e => setC('email', e.target.value)} /></label>
            <label>Company<input class={lockCls} readOnly={locked} value={client.company} onInput={e => setC('company', e.target.value)} /></label>
            <label>Project name<input class={lockCls} readOnly={locked} value={client.projectName} onInput={e => setC('projectName', e.target.value)} /></label>
            <label>Site address<input class={lockCls} readOnly={locked} value={client.siteAddress} onInput={e => setC('siteAddress', e.target.value)} /></label>
            <label>Delivery zone
              <select class={lockCls} disabled={locked} value={client.zone} onChange={e => setC('zone', e.target.value)}>
                {data.freight.zones.map(z => <option value={z.id}>{z.name}</option>)}
              </select>
            </label>
          </div>
          <div class="pf-actions">
            <button class="btn btn-primary" disabled={!canNext1} onClick={() => setStep(2)}>Next: Items</button>
          </div>
        </div>
      )}

      {step === 2 && (
        <div>
          {!fromTender && (
            <>
              <h3>Pick items from the rate book</h3>
              <div class="pf-pick-filters">
                <input placeholder="Search code or description" value={search} onInput={e => setSearch(e.target.value)} />
                <select value={cat} onChange={e => setCat(e.target.value)}>
                  <option value="all">All categories</option>
                  {cats.map(c => <option value={c.id}>{c.id}. {c.title}</option>)}
                </select>
              </div>
              {items.length === 0 ? (
                <p style="color:var(--gray);font-size:0.9rem;">The rate book is empty. Import it from the Rate Book tab first.</p>
              ) : (
                <div class="pf-pick-list">
                  {results.slice(0, 60).map(i => (
                    <div class="pf-pick-row" key={i.id}>
                      <span class="rb-code">{i.code}</span>
                      <span class="rb-desc">{i.description}</span>
                      <span class="rb-unit">{i.unit}</span>
                      <span class="rb-price">{i.contractorPrice == null ? '-' : formatMoney(i.contractorPrice)}</span>
                      <button type="button" class="btn-add" onClick={() => addLine(i)}>+ Add</button>
                    </div>
                  ))}
                  {results.length === 0 && <div class="pf-pick-row">No matching items.</div>}
                </div>
              )}
              {results.length > 60 && <p style="font-size:0.78rem;color:var(--gray);">Showing the first 60 of {results.length} matches.</p>}
            </>
          )}

          <h3>Selected items ({lines.length})</h3>
          {lines.length === 0 ? <p style="color:var(--gray);font-size:0.9rem;">No items yet.</p> : (
            <table class="pf-table">
              <thead><tr><th>Code</th><th>Description</th><th>Unit</th><th>Qty</th><th>Rate</th><th>Amount</th><th></th></tr></thead>
              <tbody>
                {lines.map(l => (
                  <tr key={l.sku}>
                    <td>{l.code}</td>
                    <td>{l.name}</td>
                    <td>{l.unit}</td>
                    <td><input type="number" min="0" step="any" value={l.qty} onInput={e => setQty(l.sku, e.target.value)} /></td>
                    <td><input type="number" min="0" step="any" value={l.contractorPrice} onInput={e => setRate(l.sku, e.target.value)} /></td>
                    <td>{formatMoney(l.lineTotal)}</td>
                    <td><button type="button" class="btn-del" onClick={() => removeLine(l.sku)}>X</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => setStep(1)}>Back</button>
            <button class="btn btn-primary" disabled={!canNext2} onClick={() => setStep(3)}>Next: Proforma</button>
          </div>
        </div>
      )}

      {step === 3 && (
        <div>
          <div class="no-print">
            <h3>Terms and charges</h3>
            <div class="pf-grid">
              <label>Delivery zone
                <select value={client.zone} disabled={saved} onChange={e => setC('zone', e.target.value)}>
                  {data.freight.zones.map(z => <option value={z.id}>{z.name}</option>)}
                </select>
              </label>
              <label>Discount %<input type="number" min="0" step="any" disabled={saved} value={discountPct} onInput={e => setDiscountPct(e.target.value)} /></label>
              <label>Markup %<input type="number" min="0" step="any" disabled={saved} value={markupPct} onInput={e => setMarkupPct(e.target.value)} /></label>
              <label>Contingency %<input type="number" min="0" step="any" disabled={saved} value={contingencyPct} onInput={e => setContingencyPct(e.target.value)} /></label>
              <label>Valid for (days)<input type="number" min="0" disabled={saved} value={validDays} onInput={e => setValidDays(e.target.value)} /></label>
            </div>
            <textarea rows="3" placeholder="Terms" disabled={saved} value={terms} onInput={e => setTerms(e.target.value)} />
          </div>

          <ProformaDoc pf={pf} />

          {err && <div class="staff-err">{err}</div>}
          {pushMsg && <div class="admin-msg">{pushMsg}</div>}
          <div class="pf-actions no-print">
            {!saved && <button class="btn btn-back" onClick={() => setStep(2)}>Back</button>}
            {!saved && <button class="btn btn-primary" disabled={busy || !number} onClick={save}>{busy ? 'Saving...' : 'Save Proforma'}</button>}
            {saved && <div class="admin-msg" style="flex:1;margin:0;">Saved as {number}</div>}
            {saved && <button class="btn btn-back" onClick={() => window.print()}>Print</button>}
            {saved && fromTender && request?.tender?.sourceApplication === 'Purchasing' && (
              <button class="btn-add" onClick={async () => {
                setPushMsg('');
                const qrid = request.detail?.quotationRequestId || request.detail?.quatationRequestId || request.tender.id;
                const resp = await fetch(`/api/egp/tender/${qrid}/response`).then(r => r.json()).catch(() => null);
                if (!resp?.id) { setPushMsg('Register on eGP first (Tenders tab).'); return; }
                const itemsToPush = lines.filter(l => l.contractorPrice > 0).map(l => ({
                  lotItemId: l.sku, name: l.name, description: l.name,
                  quantity: l.qty, unitMeasure: l.unit,
                }));
                const r = await egpAddItems(resp.id, itemsToPush);
                setPushMsg(r.ok ? `Pushed ${itemsToPush.length} items to eGP.` : 'Push failed: ' + JSON.stringify(r.data));
              }}>Push prices to eGP</button>
            )}
            {saved && <button class="btn btn-primary" onClick={onClose}>Done</button>}
          </div>
        </div>
      )}
    </div>
  );
}

export function ProformaDoc({ pf }) {
  const [data] = useStore();
  const b = data.business;
  const c = pf.client || {};
  const t = pf.totals || {};
  const lines = pf.lines || [];
  const zone = (data.freight.zones.find(z => z.id === pf.freightZone) || {}).name;

  return (
    <div class="pf-doc">
      <div class="pf-doc-header">
        <div>
          <h1>{b.nameEn}</h1>
          <p>{b.addressEn}</p>
          <p>{b.cell1} · {b.cell2} · {b.email}</p>
          <p>TIN {b.tin} · License {b.businessLicenseNo}</p>
        </div>
        <div class="pf-doc-meta">
          <h2>PROFORMA</h2>
          <strong>{pf.number}</strong>
          <p>Date: {pf.createdAt}</p>
          <p>Valid until: {pf.validUntil}</p>
        </div>
      </div>

      <div class="pf-doc-client">
        <div>
          <strong>Client</strong>
          <p>{c.name}</p>
          {c.company && <p>{c.company}</p>}
          {c.phone && <p>{c.phone}</p>}
          {c.email && <p>{c.email}</p>}
        </div>
        <div>
          <strong>Project</strong>
          {c.projectName && <p>{c.projectName}</p>}
          {c.siteAddress && <p>{c.siteAddress}</p>}
          {zone && <p>Delivery: {zone}</p>}
        </div>
      </div>

      <table class="pf-table pf-doc-table">
        <thead><tr><th>#</th><th>Code</th><th>Description</th><th>Unit</th><th>Qty</th><th>Rate</th><th>Amount</th></tr></thead>
        <tbody>
          {lines.map((l, i) => (
            <tr key={l.sku}>
              <td>{i + 1}</td><td>{l.code}</td><td>{l.name}</td><td>{l.unit}</td><td>{l.qty}</td>
              <td>{formatMoney(l.contractorPrice)}</td><td>{formatMoney(l.lineTotal)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div class="pf-doc-totals">
        <div><span>Subtotal</span><span>{formatMoney(t.subtotal)}</span></div>
        {t.markup > 0 && <div><span>Markup ({pf.markupPct}%)</span><span>{formatMoney(t.markup)}</span></div>}
        {t.contingency > 0 && <div><span>Contingency ({pf.contingencyPct}%)</span><span>{formatMoney(t.contingency)}</span></div>}
        {t.discount > 0 && <div><span>Discount ({pf.discountPct}%)</span><span>- {formatMoney(t.discount)}</span></div>}
        <div><span>Freight</span><span>{formatMoney(t.freight)}</span></div>
        <div><span>VAT ({Math.round((pf.vatRate || 0) * 100)}%)</span><span>{formatMoney(t.vat)}</span></div>
        <div class="pf-grand"><span>Grand Total</span><span>{formatMoney(t.grandTotal)}</span></div>
      </div>

      <div class="pf-doc-terms">
        <strong>Terms</strong>
        <p>{pf.terms}</p>
        <p style="margin-top:8px;">{b.disclaimer}</p>
      </div>

      <div class="pf-doc-sign">
        <span>Prepared by: ____________________</span>
        <span>Client acceptance: ____________________</span>
      </div>
    </div>
  );
}