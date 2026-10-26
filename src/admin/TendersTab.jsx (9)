import { useState, useEffect, useMemo } from 'preact/hooks';
import {
  egpStatus, egpLogin, fetchTenders, normalizeTenderList, normalizeItems,
  fetchTenderDetail, fetchQuotationItems, fetchResponseItems,
  fetchQuotationResponse, egpRegister, egpPushPriceOne, egpPushSpecOne,
} from '../data/egp.js';
import {
  saveTenders, getTenders, deleteTender,
  saveTenderDetail,
  saveTenderItems,
} from '../data/tenders.js';
import {
  getRateItems, addTenderAlias, createRateItem, getRateCategories,
} from '../data/ratebook.js';
import { buildIndex, matchAll } from '../data/match.js';

export function TendersTab({ onCreateProforma }) {
  const [status, setStatus]   = useState({ isAuthenticated: false, loading: true });
  const [rows, setRows]       = useState([]);
  const [search, setSearch]   = useState('Construction');
  const [top, setTop]         = useState(15);
  const [busy, setBusy]       = useState(false);
  const [msg, setMsg]         = useState('');
  const [error, setError]     = useState('');
  const [filter, setFilter]   = useState('');
  const [detail, setDetail]   = useState(null);
  const [loadingDetail, setLoadingDetail] = useState(false);

  const loadStored = async () => {
    try {
      const all = await getTenders();
      setRows(all.sort((a,b)=>String(b.invitationDate).localeCompare(String(a.invitationDate))));
    } catch (e) { setError('DB read failed: ' + e.message); }
  };

  const refreshStatus = async () => {
    try {
      const s = await egpStatus();
      setStatus({ ...s, loading: false });
    } catch (e) {
      setStatus({ isAuthenticated: false, loading: false, error: e.message });
      setError('Cannot reach /api/egp/status: ' + e.message);
    }
  };

  useEffect(() => {
    refreshStatus();
    loadStored();
    const t = setInterval(refreshStatus, 30_000);
    return () => clearInterval(t);
  }, []);

  const login = async () => {
    setBusy(true); setError('');
    try {
      const r = await egpLogin();
      if (!r.success) setError('Login failed: ' + JSON.stringify(r));
      await refreshStatus();
    } catch (e) { setError('Login request failed: ' + e.message); }
    setBusy(false);
  };

  const doFetch = async () => {
    setBusy(true); setMsg(''); setError('');
    try {
      const raw = await fetchTenders({ search, top });
      const norm = normalizeTenderList(raw);
      await saveTenders(norm);
      await loadStored();
      setMsg(`Fetched ${raw.total ?? '?'} total · ${norm.length} normalized · saved.`);
    } catch (e) { setError('Fetch failed: ' + e.message); }
    setBusy(false);
  };

  const openTender = async (t) => {
    setLoadingDetail(true); setError('');
    try {
      const d = await fetchTenderDetail(t);
      const qrid = d.quotationRequestId || d.quatationRequestId || null;
      let items = [], response = null;

      if (t.sourceApplication === 'Purchasing' && qrid) {
        try { response = await fetchQuotationResponse(qrid); } catch (e) { console.warn(e); }
        if (response?.id) {
          try { items = normalizeItems(await fetchResponseItems(response.id)); } catch (e) { console.warn(e); }
        }
        if (items.length === 0) {
          try { items = normalizeItems(await fetchQuotationItems(qrid)); } catch (e) { console.warn(e); }
        }
      }

      await saveTenderDetail({ lotId: t.id, quotationRequestId: qrid, detail: d, items, response, fetchedAt: Date.now() });
      if (qrid) await saveTenderItems({ key: qrid, lotId: t.id, items, response, fetchedAt: Date.now() });
      setDetail({ tender: t, detail: d, items, response });
    } catch (e) { setError('Detail failed: ' + e.message); }
    setLoadingDetail(false);
  };

  const removeTender = async (id) => {
    if (!confirm('Remove this tender from your list?')) return;
    try { await deleteTender(id); loadStored(); } catch (e) { setError(e.message); }
  };

  const filtered = useMemo(() => {
    const s = filter.trim().toLowerCase();
    if (!s) return rows;
    return rows.filter(t =>
      (t.lotName || '').toLowerCase().includes(s) ||
      (t.procuringEntity || '').toLowerCase().includes(s) ||
      (t.procurementReferenceNo || '').toLowerCase().includes(s)
    );
  }, [rows, filter]);

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Tenders ({rows.length})</h2>
        <div class="pf-actions" style="margin:0;">
          {status.loading
            ? <span class="pf-status draft">Checking session...</span>
            : status.isAuthenticated
              ? <span class="pf-status accepted">{status.name || 'Signed in'} · {Math.round((status.expiresInSeconds||0)/60)}m left</span>
              : <button class="btn-add" disabled={busy} onClick={login}>{busy ? 'Logging in...' : 'Login to eGP'}</button>}
        </div>
      </div>

      {error && <div class="staff-err" style="margin-bottom:12px;">{error}</div>}

      <div class="admin-card">
        <div class="admin-grid3">
          <div class="admin-field"><label>Search keyword</label>
            <input value={search} onInput={e=>setSearch(e.target.value)} /></div>
          <div class="admin-field"><label>Fetch top N</label>
            <input type="number" value={top} onInput={e=>setTop(+e.target.value||15)} /></div>
          <div class="admin-field"><label>&nbsp;</label>
            <button class="btn-add" disabled={busy || !status.isAuthenticated} onClick={doFetch}>
              {busy ? 'Fetching...' : 'Fetch from eGP'}
            </button>
          </div>
        </div>
        {msg && <div class="admin-msg">{msg}</div>}
      </div>

      <div class="admin-field" style="margin-bottom:12px;">
        <input placeholder="Filter stored tenders..." value={filter} onInput={e=>setFilter(e.target.value)} />
      </div>

      {filtered.length === 0 && <div class="admin-card">No tenders yet. Log in, then click <strong>Fetch from eGP</strong>.</div>}

      {filtered.map(t => (
        <div class="admin-card" key={t.id}>
          <div class="admin-card-head">
            <strong style="flex:1;min-width:200px;">{t.lotName}</strong>
            <span class="pf-status draft">{t.procurementCategory || t.sourceApplication}</span>
          </div>
          <div style="font-size:0.84rem;color:var(--gray);">
            {t.procuringEntity} · Ref {t.procurementReferenceNo}
            {t.submissionDeadline && ` · Deadline ${String(t.submissionDeadline).slice(0,10)}`}
          </div>
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => openTender(t)}>
              {loadingDetail ? '...' : 'View detail'}
            </button>
            <button class="btn-del" onClick={() => removeTender(t.id)}>Remove</button>
          </div>
        </div>
      ))}

      {detail && (
        <TenderDetailModal
          data={detail}
          onClose={() => setDetail(null)}
          onCreateProforma={(payload) => { setDetail(null); onCreateProforma(payload); }}
        />
      )}
    </div>
  );
}

function TenderDetailModal({ data, onClose, onCreateProforma }) {
  const { tender, detail, items: initialItems, response: initialResponse } = data;
  const li = detail.lotInformation || {};
  const addr = li.address || {};
  const qrid = detail.quotationRequestId || detail.quatationRequestId || tender.id;

  const [working, setWorking] = useState(false);
  const [response, setResponse] = useState(initialResponse);
  const [items, setItems] = useState(initialItems);
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const [matchSummary, setMatchSummary] = useState(null);
  const [rateIndex, setRateIndex] = useState(null);
  const [rateCats, setRateCats] = useState([]);

  const [pickerFor, setPickerFor] = useState(null);
  const [pickerQuery, setPickerQuery] = useState('');
  const [pickerAm, setPickerAm] = useState('');
  const [pickerPrice, setPickerPrice] = useState('');

  const isGoodsTender = String(tender.procurementCategory || '').toLowerCase().includes('good');
  const source = isGoodsTender ? 'goods' : 'works';

  const ensureIndex = async () => {
    if (rateIndex) return rateIndex;
    const [ri, rc] = await Promise.all([getRateItems(source), getRateCategories(source)]);
    const idx = buildIndex(ri);
    setRateIndex(idx);
    setRateCats(rc);
    return idx;
  };

  const reloadResponse = async () => {
    try { const r = await fetchQuotationResponse(qrid); setResponse(r); return r; }
    catch { return null; }
  };

  const reloadItems = async (responseId) => {
    if (responseId) {
      try {
        const raw = await fetchResponseItems(responseId);
        const norm = normalizeItems(raw);
        if (norm.length > 0) { setItems(norm); return norm; }
      } catch (e) { console.warn(e); }
    }
    try {
      const raw = await fetchQuotationItems(qrid);
      const norm = normalizeItems(raw);
      setItems(norm);
      return norm;
    } catch { return null; }
  };

  const doRegister = async () => {
    setWorking(true); setMsg(''); setErr('');
    try {
      const r = await egpRegister(qrid, li.name || tender.lotName);
      if (r.ok) {
        setMsg('Registered. Loading items…');
        const resp = await reloadResponse();
        let list = await reloadItems(resp?.id);
        for (let i = 0; i < 3 && (!list || list.length === 0); i++) {
          await new Promise(res => setTimeout(res, 2000));
          list = await reloadItems(resp?.id);
        }
        setMsg(list && list.length > 0
          ? `Registered. Loaded ${list.length} items.`
          : 'Registered. Items not populated yet — try Refresh.');
      } else {
        setErr('Register failed: ' + JSON.stringify(r.data));
      }
    } catch (e) { setErr('Register error: ' + e.message); }
    setWorking(false);
  };

  const refreshItems = async () => {
    setWorking(true); setMsg(''); setErr('');
    const list = await reloadItems(response?.id);
    if (list && list.length > 0) setMsg(`Refreshed: ${list.length} items.`);
    else setErr('No items returned.');
    setWorking(false);
  };

  // ---- Push prices (financial offer) ----
  const doPushPrices = async () => {
    if (!response?.id) { setErr('Register first.'); return; }
    setWorking(true); setMsg(''); setErr('');

    let ok = 0, fail = 0, skip = 0;
    const failures = [];

    for (const it of items) {
      if (!it.rate || it.rate <= 0) { skip++; continue; }
      if (!it.responseItemId) { skip++; continue; }

      const r = await egpPushPriceOne({
        id: it.responseItemId,
        quotationRequestResponseId: response.id,
        quotationRequestId: qrid,
        lotItemId: it.lotItemId,
        name: it.name || '',
        description: it.description || '',
        quantity: it.qty,
        currency: 'ETB',
        unitMeasure: it.unit,
        unitPrice: it.rate,
        deliveryTime: null,
        taxAmount: null,
        tax: 'VAT',
      });
      if (r.ok) ok++;
      else { fail++; failures.push({ lotItemId: it.lotItemId, status: r.status, body: r.data }); }
    }

    setMsg(`Prices pushed: ${ok} ok, ${fail} failed, ${skip} skipped.`);
    if (fail) setErr('Failures: ' + JSON.stringify(failures.slice(0, 2)));
    setWorking(false);
  };

  // ---- Push specs (technical offer) ----
  const doPushSpecs = async () => {
    if (!response?.id) { setErr('Register first.'); return; }
    setWorking(true); setMsg(''); setErr('');

    let ok = 0, fail = 0, skip = 0;
    const failures = [];

    for (const it of items) {
      if (!it.lotItemId) { skip++; continue; }
      if (!it.offeredSpecification || !it.offeredSpecification.trim()) { skip++; continue; }

      const r = await egpPushSpecOne({
        quotationRequestResponseId: response.id,
        lotItemId: it.lotItemId,
        offeredSpecification: it.offeredSpecification.trim(),
      });
      if (r.ok) ok++;
      else { fail++; failures.push({ lotItemId: it.lotItemId, status: r.status, body: r.data }); }
    }

    setMsg(`Specs pushed: ${ok} ok, ${fail} failed, ${skip} skipped.`);
    if (fail) setErr('Failures: ' + JSON.stringify(failures.slice(0, 2)));
    setWorking(false);
  };

  const setRate = (idx, v) => {
    setItems(items.map((it, i) => i === idx ? { ...it, rate: Math.max(0, parseFloat(v) || 0) } : it));
  };
  const setSpec = (idx, v) => {
    setItems(items.map((it, i) => i === idx ? { ...it, offeredSpecification: v } : it));
  };

  const fillFromRateBook = async () => {
    setWorking(true); setMsg(''); setErr(''); setMatchSummary(null);
    try {
      setRateIndex(null);
      const idx = await ensureIndex();
      if (!idx || idx.length === 0) {
        setErr(
          source === 'goods'
            ? 'Goods catalog is empty. Open Rate Book → Goods → "Load goods catalog" first.'
            : 'Civil works rate book is empty. Open Rate Book → Works → "Reload works" first.'
        );
        setWorking(false); return;
      }
      const fresh = items.map(it => ({ ...it, rate: 0, _match: null }));
      const filled = matchAll(fresh, idx, { minScore: 0.25 });
      setItems(filled);
      const matched = filled.filter(x => x._match?.matched).length;
      const needsManual = filled.filter(x => !x.rate || x.rate === 0).length;
      setMatchSummary({ matched, total: filled.length, needsManual, source });
      setMsg(`Matched ${matched} of ${filled.length} items against ${source === 'goods' ? 'Goods' : 'Works'} catalog.`);
    } catch (e) { setErr('Match failed: ' + e.message); }
    setWorking(false);
  };

  const clearRates = () => {
    setItems(items.map(it => ({ ...it, rate: 0, _match: null })));
    setMatchSummary(null);
    setMsg('Cleared all rates.');
  };

  const openLinkPicker = async (idx) => {
    await ensureIndex();
    setPickerFor({ idx, mode: 'link' });
    setPickerQuery('');
  };
  const confirmLink = async (rateItem) => {
    const row = items[pickerFor.idx];
    if (!row || !rateItem) { setPickerFor(null); return; }
    setItems(items.map((it, i) => i === pickerFor.idx
      ? { ...it, rate: rateItem.contractorPrice || 0, _match: { matched: true, score: 1, source: rateItem, manual: true } }
      : it));
    try { await addTenderAlias(rateItem.id, row.description); } catch {}
    setMsg(`Linked "${row.description.slice(0,40)}…" → ${rateItem.description.slice(0,40)}…`);
    setRateIndex(null);
    setPickerFor(null);
  };

  const openAddPicker = (idx) => {
    const row = items[idx];
    setPickerFor({ idx, mode: 'add' });
    setPickerAm('');
    setPickerQuery(row?.description || '');
    setPickerPrice(row?.rate > 0 ? String(row.rate) : '');
  };
  const confirmAdd = async () => {
    const row = items[pickerFor.idx];
    if (!row) { setPickerFor(null); return; }
    const desc = pickerQuery.trim() || row.description;
    const rate = parseFloat(pickerPrice) || 0;
    if (!desc) { setErr('Description required.'); return; }
    if (rate <= 0) { setErr('Enter a base price greater than 0.'); return; }
    try {
      const created = await createRateItem({
        description: desc,
        descriptionAm: pickerAm.trim(),
        unit: row.unit,
        rate,
        categoryId: (isGoodsTender ? 'goods:' : 'works:') + 'custom',
        source: isGoodsTender ? 'goods' : 'works'
      });
      setItems(items.map((it, i) => i === pickerFor.idx
        ? { ...it, rate, _match: { matched: true, score: 1, source: created, manual: true } }
        : it));
      setMsg(`Added "${desc.slice(0,40)}…" @ ${rate}.`);
      setRateIndex(null);
      setPickerPrice('');
    } catch (e) { setErr('Add failed: ' + e.message); }
    setPickerFor(null);
  };

  const pickerRow = pickerFor ? items[pickerFor.idx] : null;
  const pickerResults = useMemo(() => {
    if (!rateIndex || !pickerFor) return [];
    const q = pickerQuery.trim().toLowerCase();
    if (!q) return rateIndex.slice(0, 30);
    return rateIndex
      .filter(e =>
        String(e.item.code).toLowerCase().includes(q) ||
        String(e.item.description).toLowerCase().includes(q) ||
        String(e.item.descriptionAm || '').includes(q) ||
        (e.item.tenderAliases || []).some(a => a.toLowerCase().includes(q))
      )
      .slice(0, 30);
  }, [rateIndex, pickerFor, pickerQuery]);

  const missingResponseItemId = items.some(it => !it.responseItemId && it.rate > 0);

  return (
    <div class="modal-overlay" onClick={onClose}>
      <div class="modal" style="max-width:1100px;" onClick={e=>e.stopPropagation()}>
        <button class="modal-close" onClick={onClose}>X</button>
        <h2>{li.name || tender.lotName}</h2>
        <p style="color:var(--gray);font-size:0.88rem;">{li.description}</p>
        <div class="modal-meta">
          <span><strong>Entity:</strong> {li.procuring_entity || tender.procuringEntity}</span>
          <span><strong>Ref:</strong> {li.reference_no || tender.procurementReferenceNo}</span>
          <span><strong>Deadline:</strong> {li.submission_deadline || tender.submissionDeadline}</span>
          <span><strong>Town:</strong> {addr.town || '-'}</span>
          <span><strong>Catalog:</strong> {isGoodsTender ? 'Goods' : 'Works'}</span>
        </div>

        {response && (
          <div class="admin-msg" style="margin-top:12px;">
            Response: <strong>{response.status}</strong> · id <code style="font-size:0.75rem;">{response.id}</code>
          </div>
        )}

        <div class="pf-actions" style="margin-top:12px;">
          <button class="btn-add" disabled={working || items.length === 0} onClick={fillFromRateBook}>
            {working ? 'Matching...' : 'Match to rate book'}
          </button>
          <button class="btn btn-back" disabled={working || items.length === 0} onClick={clearRates}>
            Clear rates
          </button>
          <button class="btn btn-back" disabled={working || !response?.id} onClick={refreshItems}>
            Refresh items
          </button>
          {matchSummary && (
            <span style="font-size:0.82rem;color:var(--gray);align-self:center;">
              {matchSummary.matched} matched · {matchSummary.needsManual} need manual entry
            </span>
          )}
        </div>

        {missingResponseItemId && (
          <div class="admin-msg" style="margin-top:8px;background:#fef3c7;">
            Some items have no <code>responseItemId</code> — prices can't be pushed for those. Register first, then click <strong>Refresh items</strong>.
          </div>
        )}

        <h3 style="margin-top:14px;">Items ({items.length})</h3>
        {items.length === 0 && <p style="color:var(--gray);font-size:0.85rem;">No items.</p>}
        {items.length > 0 && (
          <table class="pf-table">
            <thead>
              <tr>
                <th>Description</th>
                <th>Unit</th>
                <th>Qty</th>
                <th>Offered spec</th>
                <th>Rate</th>
                <th>Match</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => (
                <tr key={it.responseItemId || it.lotItemId || i}>
                  <td>{it.description}</td>
                  <td>{it.unit}</td>
                  <td>{it.qty}</td>
                  <td>
                    <input type="text"
                      placeholder="Compliant"
                      value={it.offeredSpecification || ''}
                      onInput={e => setSpec(i, e.target.value)}
                      style="width:130px;font-size:0.78rem;" />
                  </td>
                  <td>
                    <input type="number" min="0" step="any" value={it.rate || ''}
                      onInput={e => setRate(i, e.target.value)}
                      placeholder="0"
                      style={{
                        width: '100px',
                        background: it._match?.matched ? '#f0fdf4' : (it.rate > 0 ? '#fff' : '#fef3c7')
                      }} />
                  </td>
                  <td style="font-size:0.72rem;color:var(--gray);max-width:180px;">
                    {it._match?.matched
                      ? <>
                          <span title={it._match.source?.description}>
                            {it._match.manual ? 'manual' : `✓ ${Math.round(it._match.score * 100)}%`}
                          </span>
                          <br />
                          <span style="font-size:0.68rem;" title={it._match.source?.description}>
                            {(it._match.source?.description || '').slice(0, 40)}
                            {(it._match.source?.description || '').length > 40 ? '…' : ''}
                          </span>
                        </>
                      : it.rate > 0
                        ? <span style="color:#92400e;">manual</span>
                        : <span style="color:#dc2626;">no match</span>}
                  </td>
                  <td style="white-space:nowrap;">
                    <button type="button" class="btn btn-back" style="font-size:0.72rem;padding:3px 8px;"
                      onClick={() => openLinkPicker(i)}>
                      Link
                    </button>
                    {' '}
                    <button type="button" class="btn btn-back" style="font-size:0.72rem;padding:3px 8px;"
                      onClick={() => openAddPicker(i)}>
                      +New
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {pickerFor && (
          <div class="admin-card" style="margin-top:14px;border:2px solid var(--primary);">
            <div class="admin-panel-head" style="margin-bottom:8px;">
              <strong>
                {pickerFor.mode === 'link'
                  ? `Link to ${source === 'goods' ? 'Goods' : 'Works'} catalog`
                  : `Add new ${source === 'goods' ? 'Goods' : 'Works'} item`}
              </strong>
              <button class="btn btn-back" onClick={() => setPickerFor(null)}>Cancel</button>
            </div>
            <div style="font-size:0.82rem;color:var(--gray);margin-bottom:8px;">
              Tender item: <strong>{pickerRow?.description}</strong> · {pickerRow?.unit} · qty {pickerRow?.qty}
            </div>

            {pickerFor.mode === 'link' && (
              <>
                <div class="admin-field">
                  <label>Search catalog (code, EN, AM, or alias)</label>
                  <input value={pickerQuery} onInput={e => setPickerQuery(e.target.value)} placeholder="e.g. cement, ሲሚንቶ, 12" />
                </div>
                <div style="max-height:260px;overflow-y:auto;border:1px solid var(--border);border-radius:6px;">
                  {pickerResults.length === 0 && <div style="padding:10px;color:var(--gray);font-size:0.85rem;">No matches.</div>}
                  {pickerResults.map(e => (
                    <div key={e.item.id}
                      style="padding:8px 10px;border-bottom:1px solid var(--border);cursor:pointer;font-size:0.85rem;"
                      onClick={() => confirmLink(e.item)}
                      onMouseEnter={ev => ev.currentTarget.style.background = '#f9fafb'}
                      onMouseLeave={ev => ev.currentTarget.style.background = 'transparent'}
                    >
                      <div><strong>{e.item.code || e.item.id}</strong> · {e.item.description}</div>
                      {e.item.descriptionAm && <div style="color:var(--gray);font-size:0.78rem;">{e.item.descriptionAm}</div>}
                      <div style="color:var(--gray);font-size:0.74rem;">
                        {e.item.contractorPrice != null ? e.item.contractorPrice + ' ETB' : '—'} / {e.item.unit}
                        {e.item.tenderAliases && e.item.tenderAliases.length > 0 && ` · ${e.item.tenderAliases.length} aliases`}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}

            {pickerFor.mode === 'add' && (
              <>
                <div class="admin-field">
                  <label>Description (English)</label>
                  <input value={pickerQuery} onInput={e => setPickerQuery(e.target.value)} />
                </div>
                <div class="admin-field">
                  <label>Description (Amharic, optional)</label>
                  <input value={pickerAm} onInput={e => setPickerAm(e.target.value)} />
                </div>
                <div class="admin-field">
                  <label>Base price (ETB) *</label>
                  <input type="number" min="0" step="any"
                    value={pickerPrice} onInput={e => setPickerPrice(e.target.value)}
                    placeholder="e.g. 1050" />
                </div>
                <div style="font-size:0.82rem;color:var(--gray);margin-bottom:8px;">
                  Unit: <strong>{pickerRow?.unit}</strong> · Catalog: <strong>{isGoodsTender ? 'Goods' : 'Works'}</strong>
                </div>
                <button class="btn-add" onClick={confirmAdd}>Create in Custom category</button>
              </>
            )}
          </div>
        )}

        {msg && <div class="admin-msg" style="margin-top:8px;">{msg}</div>}
        {err && <div class="staff-err" style="margin-top:8px;">{err}</div>}

        <div class="pf-actions" style="margin-top:14px;">
          {!response && tender.sourceApplication === 'Purchasing' && (
            <button class="btn-add" disabled={working} onClick={doRegister}>
              {working ? 'Registering...' : 'Register on eGP'}
            </button>
          )}

          {response && (
            <>
              <button class="btn-add" disabled={working || items.length === 0} onClick={doPushSpecs}>
                {working ? '...' : 'Push specs (technical)'}
              </button>
              <button class="btn-add" disabled={working || items.length === 0} onClick={doPushPrices}>
                {working ? '...' : 'Push prices (financial)'}
              </button>
            </>
          )}

          <button class="btn btn-primary" disabled={items.length === 0}
            onClick={() => onCreateProforma({
              tender,
              detail: li,
              items: items.map(it => ({
                lotItemId: it.lotItemId,
                name: it.name,
                description: it.description,
                unit: it.unit,
                qty: it.qty,
                rate: it.rate || 0,
              })),
            })}>
            Create Proforma
          </button>

          <button class="btn btn-back" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}