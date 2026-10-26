import { useState } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { saveRequest, newRequestId } from '../data/requests.js';
import { pushRequest } from '../data/remote.js';

export function RequestMaterials({ cart, setCart, onClose, user }) {
  const [data, lang] = useStore();
  const [client, setClient] = useState({ name: '', phone: '', email: '', company: '', projectName: '', siteAddress: '', zone: 'addis', requiredBy: '', notes: '' });
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const set = (k, v) => setClient(Object.assign({}, client, { [k]: v }));

  const submit = async () => {
    if (!client.name || !client.phone || cart.length === 0) return;
    setBusy(true);
    const req = { id: newRequestId(), kind: 'materials', createdAt: new Date().toISOString(), status: 'new', client: Object.assign({}, client), cart: cart.slice(), userId: user ? user.id : null, userEmail: user ? user.email : null };
    await saveRequest(req);
    pushRequest(req);
    setBusy(false); setDone(true); setCart([]);
  };

  return (
    <section class="section alt" id="request-materials">
      <div class="container">
        <div class="section-header" style="position:relative;">
          <button
            type="button"
            class="form-close"
            onClick={onClose}
            aria-label="Close"
          >âœ•</button>
          <h2>{lang === 'am' ? 'á‹¨á‰áˆ³á‰áˆµ á‹‹áŒ‹ áŒ á‹­á‰…' : 'Request Materials Quote'}</h2>
          <p>Send us your list.</p>
        </div>

        {done ? (
          <div class="wizard" style="text-align:center;">
            <div class="wizard-success">
              <div class="check">âœ“</div>
              <h2>Request Received!</h2>
              <p style="color: var(--gray); margin-top: 8px;">
                Thanks {client.name}! Our staff will send you a formal quote within 24 hours.
              </p>
              <button class="btn btn-primary" style="margin-top:16px;" onClick={onClose}>
                Close
              </button>
            </div>
          </div>
        ) : (
          <div class="pf-builder">
            <h3>Your List ({cart.length} items)</h3>
            {cart.length === 0 ? (
              <p style="color: var(--gray); font-size:0.9rem;">
                Your list is empty. <a href="#catalog" style="color:var(--primary);" onClick={onClose}>Browse the catalog â†’</a>
              </p>
            ) : (
              <table class="pf-table">
                <thead><tr><th>Item</th><th>Qty</th><th>Unit</th><th></th></tr></thead>
                <tbody>
                  {cart.map(l => (
                    <tr>
                      <td>{l.name}</td>
                      <td><input type="number" min="1" value={l.qty} onInput={e => setCart(cart.map(c => c.sku === l.sku ? Object.assign({}, c, { qty: Math.max(1, +e.target.value || 1) }) : c))} /></td>
                      <td>{l.unit}</td>
                      <td><button class="btn-del" onClick={() => setCart(cart.filter(c => c.sku !== l.sku))}>âœ•</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            <h3>Your Details</h3>
            <div class="pf-grid">
              <input placeholder="Full name *" value={client.name} onInput={e => set('name', e.target.value)} />
              <input placeholder="Phone *" value={client.phone} onInput={e => set('phone', e.target.value)} />
              <input placeholder="Email" value={client.email} onInput={e => set('email', e.target.value)} />
              <input placeholder="Company" value={client.company} onInput={e => set('company', e.target.value)} />
              <input placeholder="Project name" value={client.projectName} onInput={e => set('projectName', e.target.value)} />
              <input placeholder="Site address" value={client.siteAddress} onInput={e => set('siteAddress', e.target.value)} />
              <select value={client.zone} onChange={e => set('zone', e.target.value)}>
                {data.freight.zones.map(z => <option value={z.id}>{z.name}</option>)}
              </select>
              <input type="date" value={client.requiredBy} onInput={e => set('requiredBy', e.target.value)} />
            </div>

            <textarea rows="3" placeholder="Additional notes" value={client.notes} onInput={e => set('notes', e.target.value)} />

            <div class="pf-actions">
              <button class="btn btn-primary" disabled={busy || !client.name || !client.phone || cart.length === 0} onClick={submit}>
                {busy ? 'Sending...' : (lang === 'am' ? 'áŒ¥á‹«á‰„ áˆ‹áŠ­' : 'Submit Request')}
              </button>
              <button type="button" class="btn btn-back" onClick={onClose}>Cancel</button>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
