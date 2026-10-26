import { Router } from 'express';
import {
  doPasswordLogin, doRefresh, status, egpGet, egpRequest,
} from '../egpAuth.js';

const r = Router();

// ---- Auth ----
r.post('/login',   async (_req, res) => res.json({ success: await doPasswordLogin(), ...status() }));
r.post('/refresh', async (_req, res) => res.json({ success: await doRefresh(), ...status() }));
r.get ('/status',  (_req, res) => res.json(status()));

// ---- Tender list ----
r.get('/tenders', async (req, res) => {
  const qs = req.originalUrl.split('?')[1] || '';
  const p = '/po-gw/cms-v2/api/sourcing/get-grouped-sourcing' + (qs ? '?' + qs : '');
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Tender detail ----
r.get('/tender/:id', async (req, res) => {
  const { id } = req.params;
  const source = String(req.query.source || '').toLowerCase();
  const p = source === 'purchasing'
    ? `/po-gw/federal/purchasing/api/quotation-invitations/get-quotation-invitation/${id}`
    : `/po-gw/cms-v2/api/sourcing/get-lot/${id}`;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Tender-level items ----
r.get('/tender/:quotationRequestId/items', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-requests/get-quotation-request-items-by-quotation-request-id/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Response-level items (has responseItemId) ----
r.get('/tender/:responseId/response-items', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-request-responses/get-quotation-request-response-items-v2'
          + '?quatationRequestResponseId=' + encodeURIComponent(req.params.responseId);
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Schedule of requirements per lotItemId ----
r.get('/schedule/:lotItemId', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-requests/get-schedule-of-requirement-by-quotation-request-id-v2/'
          + req.params.lotItemId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Registered response ----
r.get('/tender/:quotationRequestId/response', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-request-responses/get-public-quotation-request-response-v2/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Register ----
r.post('/register', async (req, res) => {
  const { quotationRequestId, quotationRequestName } = req.body || {};
  if (!quotationRequestId || !quotationRequestName) {
    return res.status(400).json({ error: 'quotationRequestId + quotationRequestName required' });
  }
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-registrations/create-quotation-request-registration',
    { quatationRequestId: quotationRequestId, quatationRequestName: quotationRequestName }
  );
  res.status(s).json(body);
});

// ---- Push ONE price (financial offer) ----
// The client sends the full payload that eGP's own UI sends.
r.post('/push-price-one', async (req, res) => {
  const p = req.body || {};
  if (!p.id || !p.quotationRequestResponseId || !p.quotationRequestId || !p.lotItemId || p.unitPrice == null) {
    return res.status(400).json({
      error: 'id, quotationRequestResponseId, quotationRequestId, lotItemId, unitPrice required'
    });
  }
  const payload = {
    id: p.id,
    quotationRequestResponseId: p.quotationRequestResponseId,
    quotationRequestId: p.quotationRequestId,
    lotItemId: p.lotItemId,
    name: p.name || '',
    description: p.description || '',
    quantity: Number(p.quantity) || 0,
    currency: p.currency || 'ETB',
    unitMeasure: p.unitMeasure || '',
    unitPrice: Number(p.unitPrice),
    deliveryTime: p.deliveryTime ?? null,
    taxAmount: p.taxAmount ?? null,
    tax: p.tax ?? 'VAT',
  };
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-responses/update-quotation-request-response-item',
    payload
  );
  res.status(s).json({ ok: s >= 200 && s < 300, status: s, body });
});

// ---- Push ONE spec (technical offer) ----
// Needs: responseId, lotItemId. Server looks up responseItemId + schedule internally.
r.post('/push-spec-one', async (req, res) => {
  const { quotationRequestResponseId, lotItemId, offeredSpecification } = req.body || {};
  if (!quotationRequestResponseId || !lotItemId) {
    return res.status(400).json({ error: 'quotationRequestResponseId + lotItemId required' });
  }

  // 1. Fetch schedule of requirements
  const schedPath = '/po-gw/federal/purchasing/api/quotation-requests/get-schedule-of-requirement-by-quotation-request-id-v2/' + lotItemId;
  const sched = await egpGet(schedPath);
  const scheduleItems = (sched.body?.items || []).filter(x => !x.isCancelled);
  if (scheduleItems.length === 0) {
    return res.status(400).json({ error: 'no schedule requirements for this lotItemId' });
  }

  // 2. Look up responseItemId from response-items list
  const respPath = '/po-gw/federal/purchasing/api/quotation-request-responses/get-quotation-request-response-items-v2'
                 + '?quatationRequestResponseId=' + encodeURIComponent(quotationRequestResponseId);
  const respItems = await egpGet(respPath);
  const matching = (respItems.body?.items || []).find(x => x.lotItemId === lotItemId);
  if (!matching?.id) {
    return res.status(400).json({ error: 'response item not found for this lotItemId' });
  }

  // 3. Build payload and push
  const payload = {
    quotationRequestResponseId,
    quotationRequestResponseItemId: matching.id,
    quotationRequestResponseItemDetails: scheduleItems.map(s => ({
      quotationRequestResponseId,
      quotationRequestResponseItemId: matching.id,
      lotItemId,
      scheduleofRequirementId: s.id,
      offeredSpecification: offeredSpecification || s.requirement || 'Compliant',
      attribute: s.reqAttribute || 'Technical Detail',
    })),
  };
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-responses/add-quotation-request-response-item-details',
    payload
  );
  res.status(s).json({ ok: s >= 200 && s < 300, status: s, body });
});

// ---- Deprecated (kept harmless) ----
r.post('/add-items', async (_req, res) => {
  res.status(410).json({ error: 'Deprecated. Use /push-price-one and /push-spec-one.' });
});

// ---- Submit (path still unconfirmed; left as-is) ----
r.post('/submit/:responseId', async (req, res) => {
  const { status: s, body } = await egpRequest(
    'POST',
    `/po-gw/federal/purchasing/api/quotation-request-responses/submit-quotation-request-response/${req.params.responseId}`,
    {}
  );
  res.status(s).json(body);
});

export default r;