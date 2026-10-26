import { useState, useEffect, useMemo } from 'preact/hooks';
import { useStore } from '../data/store.js';
import {
  getRateBookMeta, getRateCategories, getRateItems, updateRateItem,
  applyInflation, resetContractorPrices, seedFromModule,
} from '../data/ratebook.js';
import { importGoods, getGoodsMeta } from '../data/goods.js';
import { GOODS } from '../data/goods-data.js';

export function RateBookTab() {
  const [data] = useStore();
  const [source, setSource] = useState('works');
  const [meta, setMeta] = useState(null);
  const [goodsMeta, setGoodsMeta] = useState(null);
  const [cats, setCats] = useState([]);
  const [items, setItems] = useState([]);
  const [cat, setCat] = useState('all');
  const [q, setQ] = useState('');
  const [factor, setFactor] = useState(String(data.business.inflationFactor || 1));
  const [alsoContractor, setAlsoContractor] = useState(false);
  const [msg, setMsg] = useState('');
  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkText, setBulkText] = useState('');

  const load = async () => {
    const [m, gm, c, i] = await Promise.all([
      getRateBookMeta(),
      getGoodsMeta(),
      getRateCategories(),
      getRateItems(),
    ]);
    setMeta(m); setGoodsMeta(gm); setCats(c); setItems(i);
  };

  useEffect(() => { load(); }, []);
  useEffect(() => { load(); }, [source]);

  const activeMeta = source === 'goods' ? goodsMeta : meta;
  const activeCats = useMemo(() => cats.filter(c => (c.source || 'works') === source), [cats, source]);

  const results = useMemo(() => {
    const s = q.trim().toLowerCase();
    return items.filter(i => {
      if ((i.source || 'works') !== source) return false;
      if (cat !== 'all' && i.categoryId !== cat) return false;
      if (!s) return true;
      return (
        String(i.code).toLowerCase().includes(s) ||
        String(i.description).toLowerCase().includes(s) ||
        String(i.descriptionAm || '').includes(s) ||
        (i.tenderAliases || []).some(a => a.toLowerCase().includes(s))
      );
    });
  }, [items, cat, q, source]);

  const savePrice = async (item, raw) => {
    const v = raw === '' ? null : parseFloat(raw);
    await updateRateItem(item.id, { contractorPrice: v });
    setItems(items.map(i => i.id === item.id ? Object.assign({}, i, { contractorPrice: v }) : i));
  };

  const saveAmharic = async (item, v) => {
    await updateRateItem(item.id, { descriptionAm: v });
    setItems(items.map(i => i.id === item.id ? Object.assign({}, i, { descriptionAm: v }) : i));
  };

  const inflate = async () => {
    const f = parseFloat(factor);
    if (!f || f <= 0) { setMsg('Enter a valid factor, e.g. 1.05'); return; }
    if (!confirm(`Multiply all ${source} base prices by ${f}?`)) return;
    const n = await applyInflation(f, alsoContractor, source);
    setMsg('Updated ' + n + ' items.'); load();
  };

  const resetPrices = async () => {
    if (!confirm(`Reset every ${source} contractor price to its base price?`)) return;
    const n = await resetContractorPrices(source);
    setMsg('Reset ' + n + ' items.'); load();
  };

  const reseedWorks = async () => {
    if (!confirm('Reload the civil-works rate book? This replaces all civil-works items.')) return;
    const r = await seedFromModule();
    setMsg('Loaded ' + r.itemCount + ' works items.'); load();
  };

  const loadGoods = async () => {
    if (!confirm('Load the goods catalog? Existing goods items will be replaced.')) return;
    const r = await importGoods(GOODS);
    setMsg('Loaded ' + r.itemCount + ' goods items.'); load();
  };

  const applyBulk = async () => {
    const lines = bulkText.split('\n').map(l => l.trim()).filter(Boolean);
    if (lines.length === 0) { setMsg('Nothing to import.'); return; }
    let updated = 0, missed = 0;
    for (const line of lines) {
      const parts = line.split(/\t|,(?=[\u1200-\u137F])/);
      if (parts.length < 2) { missed++; continue; }
      const code = parts[0].trim();
      const am = parts.slice(1).join(',').trim();
      if (!code || !am) { missed++; continue; }
      const target = items.find(i => (i.source || 'works') === source && i.code === code);
      if (!target) { missed++; continue; }
      await updateRateItem(target.id, { descriptionAm: am });
      updated++;
    }
    await load();
    setMsg(`Bulk import: ${updated} updated, ${missed} skipped.`);
    setBulkText('');
    setBulkOpen(false);
  };

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Rate Book — {source === 'goods' ? 'Goods' : 'Civil works'} ({results.length} items)</h2>
        <div class="pf-actions" style="margin:0;">
          <select value={source} onChange={e => { setSource(e.target.value); setCat('all'); }}>
            <option value="works">Civil works</option>
            <option value="goods">Goods</option>
          </select>
          <button class="btn btn-back" onClick={load}>Refresh</button>
          <button class="btn btn-back" onClick={() => setBulkOpen(!bulkOpen)}>
            {bulkOpen ? 'Close bulk' : 'Bulk paste Amharic'}
          </button>
          {source === 'works'
            ? <button class="btn-add" onClick={reseedWorks}>Reload works</button>
            : <button class="btn-add" onClick={loadGoods}>Load goods catalog</button>}
        </div>
      </div>

      {activeMeta && (
        <div class="admin-card" style="font-size:0.85rem;color:var(--gray);">
          {activeMeta.source || ''} {activeMeta.quarter || ''} · imported {String(activeMeta.importedAt || '').slice(0, 10)}
        </div>
      )}
      {msg && <div class="admin-msg">{msg}</div>}

      {bulkOpen && (
        <div class="admin-card">
          <strong>Bulk Amharic import ({source})</strong>
          <p style="font-size:0.8rem;color:var(--gray);margin:4px 0 8px;">
            One line per item: <code>code&lt;TAB&gt;amharic description</code>.
          </p>
          <textarea
            rows="6"
            style="width:100%;font-family:monospace;font-size:0.82rem;padding:8px;border:1px solid var(--border);border-radius:6px;"
            value={bulkText}
            onInput={e => setBulkText(e.target.value)}
          />
          <div class="pf-actions">
            <button class="btn-add" onClick={applyBulk}>Apply</button>
            <button class="btn btn-back" onClick={() => { setBulkText(''); setBulkOpen(false); }}>Cancel</button>
          </div>
        </div>
      )}

      <div class="admin-card">
        <div class="admin-grid3">
          <div class="admin-field"><label>Inflation factor</label>
            <input type="number" step="any" value={factor} onInput={e => setFactor(e.target.value)} /></div>
          <div class="admin-field"><label>Also set contractor price</label>
            <select value={alsoContractor ? 'yes' : 'no'} onChange={e => setAlsoContractor(e.target.value === 'yes')}>
              <option value="no">No</option><option value="yes">Yes</option>
            </select></div>
          <div class="admin-field"><label>&nbsp;</label>
            <button class="btn-add" onClick={inflate}>Apply</button></div>
        </div>
        <button class="btn-del" onClick={resetPrices}>Reset contractor prices</button>
      </div>

      <div class="admin-grid2">
        <div class="admin-field"><label>Search (English or Amharic)</label>
          <input value={q} onInput={e => setQ(e.target.value)} placeholder="Code, description, or አማርኛ" /></div>
        <div class="admin-field"><label>Category</label>
          <select value={cat} onChange={e => setCat(e.target.value)}>
            <option value="all">All categories</option>
            {activeCats.map(c => (
              <option value={c.id}>{c.titleAm || c.title}</option>
            ))}
          </select>
        </div>
      </div>

      <div class="admin-card">
        {results.slice(0, 100).map(i => (
          <div class="ratebook-row" key={i.id} style="grid-template-columns: 70px 1fr 70px 50px 70px;">
            <span class="rb-code">{i.code}</span>
            <div style="display:flex;flex-direction:column;gap:4px;">
              <span class="rb-desc">{i.description}</span>
              <input
                placeholder="Amharic description (optional)"
                value={i.descriptionAm || ''}
                onInput={e => saveAmharic(i, e.target.value)}
                style="font-size:0.78rem;padding:2px 6px;border:1px solid var(--border);border-radius:4px;direction:auto;"
              />
            </div>
            <span class="rb-price">{i.basePrice == null ? '—' : i.basePrice}</span>
            <span class="rb-unit">{i.unit}</span>
            <input
              type="number" step="any"
              value={i.contractorPrice == null ? '' : i.contractorPrice}
              onChange={e => savePrice(i, e.target.value)}
            />
          </div>
        ))}
        {results.length === 0 && (
          <div>
            No items yet.
            {source === 'goods' && ' Click "Load goods catalog".'}
            {source === 'works' && ' Click "Reload works".'}
          </div>
        )}
        {results.length > 100 && (
          <p style="font-size:0.78rem;color:var(--gray);margin-top:8px;">
            Showing the first 100 of {results.length} matches.
          </p>
        )}
      </div>
    </div>
  );
}