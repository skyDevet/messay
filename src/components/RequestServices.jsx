import { useState } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { saveRequest, newRequestId } from '../data/requests.js';
import { pushRequest } from '../data/remote.js';

export function RequestServices({ onClose, user }) {
  const [data, lang] = useStore();
  const [form, setForm] = useState({ serviceType: 'sv1', name: '', phone: '', email: '', company: '', projectName: '', siteAddress: '', description: '', budgetRange: '', timeline: 'planning' });
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const set = (k, v) => setForm(Object.assign({}, form, { [k]: v }));

  const submit = async () => {
    if (!form.name || !form.phone || !form.description) return;
    setBusy(true);
    const req = {
      id: newRequestId(),
      kind: 'services',
      createdAt: new Date().toISOString(),
      status: 'new',
      client: { name: form.name, phone: form.phone, email: form.email, company: form.company, projectName: form.projectName, siteAddress: form.siteAddress },
      serviceType: form.serviceType,
      description: form.description,
      budgetRange: form.budgetRange,
      timeline: form.timeline,
      userId: user ? user.id : null,
      userEmail: user ? user.email : null
    };
    await saveRequest(req);
    pushRequest(req);
    setBusy(false); setDone(true);
  };

  return (
    <section class="section" id="request-services">
      <div class="container">
        <div class="section-header" style="position:relative;">
          <button type="button" class="form-close" onClick={onClose} aria-label="Close">âœ•</button>
          <h2>{lang === 'am' ? 'á‹¨áŠ áŒˆáˆáŒáˆŽá‰µ á‹‹áŒ‹ áŒ á‹­á‰…' : 'Request Service Quote'}</h2>
          <p>Tell us about your project.</p>
        </div>

        {done ? (
          <div class="wizard" style="text-align:center;">
            <div class="wizard-success">
              <div class="check">âœ“</div>
              <h2>Request Received!</h2>
              <p style="color: var(--gray); margin-top: 8px;">
                Thanks {form.name}! Our estimating team will be in touch.
              </p>
              <button class="btn btn-primary" style="margin-top:16px;" onClick={onClose}>Close</button>
            </div>
          </div>
        ) : (
          <div class="pf-builder">
            <h3>Project Type</h3>
            <div class="wizard-options">
              {data.services.map(s => (
                <button
                  class={'wizard-option ' + (form.serviceType === s.id ? 'selected' : '')}
                  onClick={() => set('serviceType', s.id)}
                >
                  {s.icon} {lang === 'am' ? s.titleAm : s.titleEn}
                </button>
              ))}
            </div>

            <h3>Your Details</h3>
            <div class="pf-grid">
              <input placeholder="Full name *" value={form.name} onInput={e => set('name', e.target.value)} />
              <input placeholder="Phone *" value={form.phone} onInput={e => set('phone', e.target.value)} />
              <input placeholder="Email" value={form.email} onInput={e => set('email', e.target.value)} />
              <input placeholder="Company" value={form.company} onInput={e => set('company', e.target.value)} />
              <input placeholder="Project name" value={form.projectName} onInput={e => set('projectName', e.target.value)} />
              <input placeholder="Site address" value={form.siteAddress} onInput={e => set('siteAddress', e.target.value)} />
              <select value={form.budgetRange} onChange={e => set('budgetRange', e.target.value)}>
                <option value="">Estimated budget (optional)</option>
                <option value="lt5m">Under ETB 5M</option>
                <option value="5-20m">ETB 5M â€“ 20M</option>
                <option value="20-100m">ETB 20M â€“ 100M</option>
                <option value="100m+">ETB 100M+</option>
              </select>
              <select value={form.timeline} onChange={e => set('timeline', e.target.value)}>
                <option value="planning">Just planning</option>
                <option value="3-6mo">3â€“6 months</option>
                <option value="1-3mo">1â€“3 months</option>
                <option value="asap">ASAP</option>
              </select>
            </div>

            <textarea rows="4" placeholder="Describe your project *" value={form.description} onInput={e => set('description', e.target.value)} />

            <div class="pf-actions">
              <button class="btn btn-primary" disabled={busy || !form.name || !form.phone || !form.description} onClick={submit}>
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
