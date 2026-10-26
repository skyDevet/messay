import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireUser, requireAdmin, isAdmin, pick } from '../middleware/auth.js';

const router = Router();

// Signed-in user creates a quote request (user_id/email come from the token, never the body)
router.post('/', requireUser, ah(async (req, res) => {
  const body = pick(req.body, ['id', 'kind', 'client', 'cart', 'description', 'service_type', 'budget_range', 'timeline']);
  if (!['materials', 'services'].includes(body.kind)) return res.status(400).json({ error: 'kind must be "materials" or "services".' });
  const row = Object.assign({}, body, { user_id: req.user.id, user_email: req.user.email || null, status: 'new' });
  const { data, error } = await supabaseAdmin.from('quote_requests').insert(row).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

// Admins see every request, other users only their own
router.get('/', requireUser, ah(async (req, res) => {
  let q = supabaseAdmin.from('quote_requests').select('*').order('created_at', { ascending: false });
  if (!(await isAdmin(req.user.id))) q = q.eq('user_id', req.user.id);
  if (req.query.status) q = q.eq('status', String(req.query.status));
  const { data, error } = await q;
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.patch('/:id', requireAdmin, ah(async (req, res) => {
  const patch = pick(req.body, ['status']);
  const { data, error } = await supabaseAdmin.from('quote_requests').update(patch).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', requireAdmin, ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('quote_requests').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
