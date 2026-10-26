export async function egpStatus()  { return (await fetch('/api/egp/status')).json(); }
export async function egpLogin()   { return (await fetch('/api/egp/login', { method:'POST' })).json(); }

export async function fetchTenders({ search='Construction', top=15, skip=0, locale='en' } = {}) {
  const p = new URLSearchParams();
  p.set('type','all'); p.set('skip',skip); p.set('top',top);
  p.set('locale',locale); p.set('search',search);
  ['lotName','sourceApplication','lotReferenceNo','procurementReferenceNo']
    .forEach((f,i)=>p.set(`searchFrom[${i}]`, f));
  p.set('orderBy[0].field','invitationDate');
  p.set('orderBy[0].direction','desc');
  const r = await fetch('/api/egp/tenders?' + p.toString());
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchTenderDetail(tender) {
  const q = tender.sourceApplication === 'Purchasing' ? '?source=purchasing' : '';
  const r = await fetch(`/api/egp/tender/${tender.sourceId || tender.id}${q}`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchQuotationItems(quotationRequestId) {
  const r = await fetch(`/api/egp/tender/${quotationRequestId}/items`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchResponseItems(responseId) {
  const r = await fetch(`/api/egp/tender/${responseId}/response-items`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchSchedule(lotItemId) {
  const r = await fetch(`/api/egp/schedule/${lotItemId}`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchQuotationResponse(quotationRequestId) {
  const r = await fetch(`/api/egp/tender/${quotationRequestId}/response`);
  if (!r.ok) return null;
  return r.json();
}

export async function egpRegister(quotationRequestId, quotationRequestName) {
  const r = await fetch('/api/egp/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ quotationRequestId, quotationRequestName }),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export async function egpPushPriceOne(payload) {
  const r = await fetch('/api/egp/push-price-one', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export async function egpPushSpecOne(payload) {
  const r = await fetch('/api/egp/push-spec-one', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

// Kept for compatibility, hits the deprecated route
export async function egpAddItems(quotationRequestResponseId, items) {
  const r = await fetch('/api/egp/add-items', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ quotationRequestResponseId, items }),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export async function egpSubmit(responseId) {
  const r = await fetch(`/api/egp/submit/${responseId}`, { method: 'POST' });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export function normalizeTenderList(payload) {
  const out = [];
  for (const pkg of payload.items || []) {
    for (const lot of pkg.result || []) {
      const pi = lot.packageInformation || {};
      out.push({
        id: lot.id,
        sourceId: lot.sourceId || null,
        lotName: lot.lotName || pi.packageName || '',
        lotDescription: (lot.lotDescription || pi.packageDescription || '').trim(),
        lotReferenceNo: lot.lotReferenceNo || '',
        procurementReferenceNo: lot.procurementReferenceNo || '',
        procurementCategory: lot.procurementCategory || '',
        procuringEntity: pi.procuringEntity?.en || lot.procuringEntity || '',
        procuringEntityAm: pi.procuringEntity?.am || '',
        sourceApplication: lot.sourceApplication || '',
        marketPlace: lot.marketPlace || '',
        method: lot.method || '',
        submissionDeadline: lot.submissionDeadline || null,
        openingSchedule: lot.openingSchedule || null,
        invitationDate: lot.invitationDate || null,
        address: pi.address || {},
        classification: (lot.procurementClassification || [])
          .map(c => c.title?.en).filter(Boolean),
        origin: lot.origin || '',
        originName: lot.originName?.en || '',
        fetchedAt: Date.now(),
      });
    }
  }
  const seen = new Set();
  return out.filter(t => seen.has(t.id) ? false : (seen.add(t.id), true));
}

// Preserves both tender-level and response-level shapes.
export function normalizeItems(payload) {
  const arr = Array.isArray(payload) ? payload : (payload.items || []);
  return arr.map(it => {
    const rawId = it.id;
    const responseItemId = rawId && rawId !== '00000000-0000-0000-0000-000000000000' ? rawId : null;
    return {
      responseItemId,
      lotItemId: it.lotItemId || (responseItemId ? null : rawId) || null,
      name: it.name || '',
      description: (it.description || '').trim().replace(/\s+/g, ' '),
      unit: it.unitOfMeasure || it.unitMeasure || it.unit || '',
      qty: Number(it.revisedQuantity ?? it.originalQuantity ?? it.quantity ?? it.qty ?? 0),
      rate: Number(it.unitPrice) || 0,
    };
  });
}