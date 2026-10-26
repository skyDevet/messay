import { useState, useEffect, useMemo } from 'preact/hooks';
import { useStore, setData, uid } from '../data/store.js';
import { supabase } from '../lib/supabase.js';
import { getRateCategories, getRateItems } from '../data/ratebook.js';
import { saveProductImage, deleteProductImage, getProductImageURL } from '../data/images.js';
import { BUSINESS_FIELDS } from './fields.js';

const save = (data, key, value) => setData(Object.assign({}, data, { [key]: value }));
const upd = (list, id, k, v) => list.map(x => x.id === id ? Object.assign({}, x, { [k]: v }) : x);

function Field({ label, value, onInput, type = 'text', step }) {
  return (
    <div class="admin-field">
      <label>{label}</label>
      <input type={type} step={step} value={value == null ? '' : value}
        onInput={e => onInput(type === 'number' ? (e.target.value === '' ? '' : +e.target.value) : e.target.value)} />
    </div>
  );
}
function Area({ label, value, onInput, rows = 3 }) {
  return (
    <div class="admin-field">
      <label>{label}</label>
      <textarea rows={rows} value={value || ''} onInput={e => onInput(e.target.value)} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// MATERIALS CATALOG — products from the rate book, images from IndexedDB
// ---------------------------------------------------------------------------
export function CatalogTab() {
  const [data] = useStore();
  const list = data.products;
  const [cats, setCats] = useState([]);
  const [items, setItems] = useState([]);
  const [q, setQ] = useState('');
  const [cat, setCat] = useState('all');
  const [picking, setPicking] = useState(false);
  const [busyId, setBusyId] = useState(null);
  const [urls, setUrls] = useState({});      // productId -> objectURL
  const [err, setErr] = useState('');

  useEffect(() => {
    (async () => {
      try {
        setCats(await getRateCategories());
        setItems(await getRateItems());
      } catch (e) { console.error('Catalog ratebook load failed:', e); }
    })();
  }, []);

  // Load object URLs for every product that has an image
  useEffect(() => {
    let alive = true;
    (async () => {
      const next = {};
      for (const p of list) {
        if (!p.imageId) continue;
        const url = await getProductImageURL(p.imageId);
        if (url) next[p.id] = url;
      }
      if (alive) setUrls(next);
    })();
    return () => { alive = false; };
  }, [list.map(p => p.imageId).join('|')]);

  const results = useMemo(() => {
    const s = q.trim().toLowerCase();
    return items.filter(i =>
      (cat === 'all' || i.categoryId === cat) &&
      (!s || String(i.code).toLowerCase().includes(s) ||
              String(i.description).toLowerCase().includes(s))
    );
  }, [items, q, cat]);

  const set = (id, k, v) => save(data, 'products', upd(list, id, k, v));
  const setPrice = (id, v) => save(data, 'products',
    list.map(p => p.id === id
      ? Object.assign({}, p, { basePrice: v, contractorPrice: v })
      : p));

  const ensureCategory = (rateCatId) => {
    const rateCat = cats.find(c => String(c.id) === String(rateCatId));
    const title = rateCat ? rateCat.title : String(rateCatId);
    const existing = data.categories.find(c => c.id === String(rateCatId));
    if (existing) return existing.id;
    const newCat = { id: String(rateCatId), name: title, nameAm: title, icon: '📦' };
    setData(Object.assign({}, data, { categories: [...data.categories, newCat] }));
    return newCat.id;
  };

  const addFromRate = (rate) => {
    if (list.some(p => p.rateId === rate.id)) return;
    const catId = ensureCategory(rate.categoryId);
    const product = {
      id: uid(),
      rateId: rate.id,
      category: catId,
      name: rate.description,
      code: rate.code,
      unit: rate.unit,
      basePrice: rate.contractorPrice != null ? rate.contractorPrice : 0,
      contractorPrice: rate.contractorPrice != null ? rate.contractorPrice : 0,
      stock: 0,
      leadTimeDays: 0,
      taxable: true,
      imageId: null,        // key into product_images store
      tiers: []
    };
    save(data, 'products', [...list, product]);
  };

  const addBlank = () => save(data, 'products', [...list, {
    id: uid(), rateId: null,
    category: data.categories[0] ? data.categories[0].id : '',
    name: 'New product', code: '', unit: 'piece',
    basePrice: 0, contractorPrice: 0, stock: 0, leadTimeDays: 0,
    taxable: true, imageId: null, tiers: []
  }]);

  const remove = async (p) => {
    if (!confirm('Delete this product?')) return;
    if (p.imageId) await deleteProductImage(p.imageId);
    save(data, 'products', list.filter(x => x.id !== p.id));
  };

  // Upload a File into IndexedDB for this product
  const onImageFile = async (p, file) => {
    if (!file) return;
    setErr('');
    setBusyId(p.id);
    try {
      if (!file.type.startsWith('image/')) throw new Error('Not an image file.');
      if (file.size > 5 * 1024 * 1024) throw new Error('Image is larger than 5 MB.');
      const imageId = p.imageId || ('img_' + p.id);
      await saveProductImage(imageId, file);
      // Re-read to force the object URL effect to run
      set(p.id, 'imageId', imageId);
      const url = await getProductImageURL(imageId);
      if (url) setUrls(u => Object.assign({}, u, { [p.id]: url }));
    } catch (e) {
      setErr(e.message || String(e));
    }
    setBusyId(null);
  };

  const clearImage = async (p) => {
    if (!p.imageId) return;
    if (!confirm('Remove this image?')) return;
    await deleteProductImage(p.imageId);
    set(p.id, 'imageId', null);
    setUrls(u => { const n = Object.assign({}, u); delete n[p.id]; return n; });
  };

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Materials Catalog ({list.length})</h2>
        <div class="pf-actions" style="margin:0;">
          <button class="btn-add" onClick={() => setPicking(!picking)}>
            {picking ? 'Close rate book' : '+ Add from Rate Book'}
          </button>
          <button class="btn btn-back" onClick={addBlank}>+ Blank product</button>
        </div>
      </div>

      {err && <div class="staff-err" style="margin-bottom:10px;">{err}</div>}

      {picking && (
        <div class="admin-card">
          <strong>Pick items from the rate book</strong>
          <div class="pf-pick-filters" style="margin-top:10px;">
            <input placeholder="Search code or description"
                   value={q} onInput={e => setQ(e.target.value)} />
            <select value={cat} onChange={e => setCat(e.target.value)}>
              <option value="all">All categories</option>
              {cats.map(c => <option value={c.id}>{c.id}. {c.title}</option>)}
            </select>
          </div>
          {items.length === 0 ? (
            <p style="color:var(--gray);font-size:0.9rem;">
              The rate book is empty. Import it from the Rate Book tab first.
            </p>
          ) : (
            <div class="pf-pick-list">
              {results.slice(0, 60).map(i => {
                const already = list.some(p => p.rateId === i.id);
                return (
                  <div class="pf-pick-row" key={i.id}>
                    <span class="rb-code">{i.code}</span>
                    <span class="rb-desc">{i.description}</span>
                    <span class="rb-unit">{i.unit}</span>
                    <span class="rb-price">{i.contractorPrice == null ? '—' : i.contractorPrice}</span>
                    <button type="button" class="btn-add" disabled={already}
                            onClick={() => addFromRate(i)}>
                      {already ? '✓ Added' : '+ Add'}
                    </button>
                  </div>
                );
              })}
              {results.length === 0 && <div class="pf-pick-row">No matching items.</div>}
            </div>
          )}
          {results.length > 60 &&
            <p style="font-size:0.78rem;color:var(--gray);">
              Showing first 60 of {results.length}. Refine the search.
            </p>}
        </div>
      )}

      {list.map(p => {
        const url = urls[p.id];
        return (
          <div class="admin-card" key={p.id}>
            <div class="admin-grid2">
              <Field label="Name" value={p.name} onInput={v => set(p.id, 'name', v)} />
              <Field label="Code (optional)" value={p.code || ''} onInput={v => set(p.id, 'code', v)} />
            </div>

            {/* Image row */}
            <div class="admin-image-row">
              <div class="admin-image-preview">
                {url
                  ? <img src={url} alt={p.name}
                         onError={e => { e.currentTarget.style.display = 'none'; }} />
                  : <span class="admin-image-empty">
                      {busyId === p.id ? 'Saving…' : 'No image'}
                    </span>}
              </div>
              <div class="admin-image-controls">
                <label class="btn-add" style="cursor:pointer;">
                  {url ? 'Replace image' : 'Upload image'}
                  <input type="file" accept="image/*" style="display:none;"
                         disabled={busyId === p.id}
                         onChange={e => {
                           const f = e.target.files && e.target.files[0];
                           e.target.value = '';
                           if (f) onImageFile(p, f);
                         }} />
                </label>
                {url && (
                  <button class="btn-del" onClick={() => clearImage(p)}>Remove image</button>
                )}
              </div>
            </div>

            <div class="admin-grid3">
              <div class="admin-field">
                <label>Category</label>
                <select value={p.category} onChange={e => set(p.id, 'category', e.target.value)}>
                  {data.categories.map(c => <option value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <Field label="Unit" value={p.unit} onInput={v => set(p.id, 'unit', v)} />
              <Field label="Price" type="number" step="any" value={p.basePrice}
                     onInput={v => setPrice(p.id, v)} />
              <Field label="Stock" type="number" value={p.stock}
                     onInput={v => set(p.id, 'stock', v)} />
              <Field label="Lead time (days)" type="number" value={p.leadTimeDays}
                     onInput={v => set(p.id, 'leadTimeDays', v)} />
            </div>

            <button class="btn-del" onClick={() => remove(p)}>Delete</button>
          </div>
        );
      })}

      {list.length === 0 && (
        <div class="admin-card">
          No products yet. Click <strong>+ Add from Rate Book</strong> to pick items.
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// PROJECTS
// ---------------------------------------------------------------------------
export function ProjectsTab() {
  const [data] = useStore();
  const list = data.projects;
  const set = (id, k, v) => save(data, 'projects', upd(list, id, k, v));
  const add = () => save(data, 'projects', [...list, { id: uid(), title: 'New project', type: '', icon: '🏢', image: '', desc: '', budget: '', duration: '', year: new Date().getFullYear(), client: '' }]);
  const remove = (id) => { if (confirm('Delete this project?')) save(data, 'projects', list.filter(p => p.id !== id)); };
  return (
    <div class="admin-panel">
      <div class="admin-panel-head"><h2>Projects ({list.length})</h2><button class="btn-add" onClick={add}>+ Add project</button></div>
      {list.map(p => (
        <div class="admin-card" key={p.id}>
          <div class="admin-grid2">
            <Field label="Title" value={p.title} onInput={v => set(p.id, 'title', v)} />
            <Field label="Type" value={p.type} onInput={v => set(p.id, 'type', v)} />
            <Field label="Icon" value={p.icon} onInput={v => set(p.id, 'icon', v)} />
            <Field label="Image path" value={p.image} onInput={v => set(p.id, 'image', v)} />
            <Field label="Budget" value={p.budget} onInput={v => set(p.id, 'budget', v)} />
            <Field label="Duration" value={p.duration} onInput={v => set(p.id, 'duration', v)} />
            <Field label="Year" type="number" value={p.year} onInput={v => set(p.id, 'year', v)} />
            <Field label="Client" value={p.client} onInput={v => set(p.id, 'client', v)} />
          </div>
          <Area label="Description" value={p.desc} onInput={v => set(p.id, 'desc', v)} />
          <button class="btn-del" onClick={() => remove(p.id)}>Delete</button>
        </div>
      ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// REVIEWS
// ---------------------------------------------------------------------------
export function ReviewsTab() {
  const [data] = useStore();
  const list = data.reviews;
  const set = (id, k, v) => save(data, 'reviews', upd(list, id, k, v));
  const add = () => save(data, 'reviews', [...list, { id: uid(), name: 'New client', loc: '', stars: 5, text: '' }]);
  const remove = (id) => { if (confirm('Delete this review?')) save(data, 'reviews', list.filter(r => r.id !== id)); };
  return (
    <div class="admin-panel">
      <div class="admin-panel-head"><h2>Reviews ({list.length})</h2><button class="btn-add" onClick={add}>+ Add review</button></div>
      {list.map(r => (
        <div class="admin-card" key={r.id}>
          <div class="admin-grid3">
            <Field label="Name" value={r.name} onInput={v => set(r.id, 'name', v)} />
            <Field label="Location" value={r.loc} onInput={v => set(r.id, 'loc', v)} />
            <Field label="Stars (1-5)" type="number" value={r.stars} onInput={v => set(r.id, 'stars', Math.min(5, Math.max(1, v || 1)))} />
          </div>
          <Area label="Review" value={r.text} onInput={v => set(r.id, 'text', v)} />
          <button class="btn-del" onClick={() => remove(r.id)}>Delete</button>
        </div>
      ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// BUSINESS INFO
// ---------------------------------------------------------------------------
export function BusinessTab() {
  const [data] = useStore();
  const b = data.business;
  const set = (k, v) => save(data, 'business', Object.assign({}, b, { [k]: v }));
  return (
    <div class="admin-panel">
      <h2>Business Info</h2>
      <div class="admin-card">
        <div class="admin-grid2">
          {BUSINESS_FIELDS.map(([k, label]) => <Field key={k} label={label} value={b[k]} onInput={v => set(k, v)} />)}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// SETTINGS
// ---------------------------------------------------------------------------
export function SettingsTab() {
  const [data] = useStore();
  const b = data.business;
  const set = (k, v) => save(data, 'business', Object.assign({}, b, { [k]: v }));
  const zones = data.freight.zones;
  const setZone = (id, k, v) => setData(Object.assign({}, data, { freight: Object.assign({}, data.freight, { zones: upd(zones, id, k, v) }) }));
  return (
    <div class="admin-panel">
      <h2>Settings</h2>
      <div class="admin-card">
        <div class="admin-grid3">
          <Field label="Currency" value={b.currency} onInput={v => set('currency', v)} />
          <Field label="VAT rate (0.15 = 15%)" type="number" step="any" value={b.vatRate} onInput={v => set('vatRate', v)} />
          <Field label="Proforma valid (days)" type="number" value={b.validDays} onInput={v => set('validDays', v)} />
          <Field label="Markup %" type="number" step="any" value={b.markupPct} onInput={v => set('markupPct', v)} />
          <Field label="Contingency %" type="number" step="any" value={b.contingencyPct} onInput={v => set('contingencyPct', v)} />
          <Field label="Inflation factor" type="number" step="any" value={b.inflationFactor} onInput={v => set('inflationFactor', v)} />
        </div>
        <Area label="Disclaimer" value={b.disclaimer} onInput={v => set('disclaimer', v)} />
        <Area label="Default terms" value={b.defaultTerms} onInput={v => set('defaultTerms', v)} />
      </div>
      <div class="admin-card">
        <strong>Freight zones</strong>
        {zones.map(z => (
          <div class="admin-grid3" key={z.id} style="margin-top:10px;">
            <Field label="Zone name" value={z.name} onInput={v => setZone(z.id, 'name', v)} />
            <Field label="Flat" type="number" step="any" value={z.flat} onInput={v => setZone(z.id, 'flat', v)} />
            <Field label="Per ton" type="number" step="any" value={z.perTon} onInput={v => setZone(z.id, 'perTon', v)} />
          </div>
        ))}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// USERS / ROLES
// ---------------------------------------------------------------------------
export function UsersTab() {
  const [rows, setRows] = useState(null);
  const [newId, setNewId] = useState('');
  const [role, setRole] = useState('admin');
  const [msg, setMsg] = useState('');
  const [me, setMe] = useState('');

  const load = async () => {
    if (!supabase) { setRows([]); return; }
    const { data: s } = await supabase.auth.getSession();
    setMe(s.session ? s.session.user.id : '');
    const { data, error } = await supabase.from('admin_users').select('user_id, role, created_at').order('created_at');
    if (error) setMsg(error.message);
    setRows(data || []);
  };
  useEffect(() => { load(); }, []);

  const add = async () => {
    if (!newId.trim()) return;
    const { error } = await supabase.from('admin_users').insert({ user_id: newId.trim(), role });
    setMsg(error ? error.message : 'Added.');
    if (!error) setNewId('');
    load();
  };
  const remove = async (r) => {
    if (r.user_id === me) { setMsg('You cannot remove your own admin access.'); return; }
    if (!confirm('Remove this admin?')) return;
    const { error } = await supabase.from('admin_users').delete().eq('user_id', r.user_id);
    setMsg(error ? error.message : 'Removed.');
    load();
  };
  const changeRole = async (r, v) => {
    const { error } = await supabase.from('admin_users').update({ role: v }).eq('user_id', r.user_id);
    setMsg(error ? error.message : 'Role updated.');
    load();
  };

  if (!supabase) return <div class="admin-panel"><h2>Users/Roles</h2><div class="admin-msg">Supabase is not configured.</div></div>;
  return (
    <div class="admin-panel">
      <h2>Users/Roles</h2>
      {msg && <div class="admin-msg">{msg}</div>}
      <div class="admin-card">
        <strong>Add an admin</strong>
        <p style="font-size:0.8rem;color:var(--gray);margin:4px 0 10px;">Paste the user's id from Supabase → Authentication → Users. They must have signed in at least once.</p>
        <div class="admin-grid3">
          <div class="admin-field"><label>User id</label><input value={newId} onInput={e => setNewId(e.target.value)} placeholder="uuid" /></div>
          <div class="admin-field"><label>Role</label>
            <select value={role} onChange={e => setRole(e.target.value)}><option value="admin">admin</option><option value="staff">staff</option></select>
          </div>
          <div class="admin-field"><label>&nbsp;</label><button class="btn-add" onClick={add}>Add</button></div>
        </div>
      </div>
      {(rows || []).map(r => (
        <div class="admin-card" key={r.user_id}>
          <div class="admin-card-head">
            <span style="flex:1;font-family:monospace;font-size:0.8rem;word-break:break-all;">{r.user_id}{r.user_id === me ? ' (you)' : ''}</span>
            <select value={r.role} onChange={e => changeRole(r, e.target.value)}><option value="admin">admin</option><option value="staff">staff</option></select>
            <button class="btn-del" onClick={() => remove(r)}>Remove</button>
          </div>
        </div>
      ))}
      {rows && rows.length === 0 && <div class="admin-card">No admins listed.</div>}
    </div>
  );
}