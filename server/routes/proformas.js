import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin, pick } from '../middleware/auth.js';

const router = Router();
const FIELDS = ['number', 'status', 'source_request_id', 'client', 'lines', 'totals', 'terms', 'valid_days'];

router.use(requireAdmin);

router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('proformas').select('*').order('created_at', { ascending: false });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.get('/:id', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('proformas').select('*').eq('id', req.params.id).maybeSingle();
  if (error) return res.status(400).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Not found.' });
  res.json(data);
}));

router.post('/', ah(async (req, res) => {
  const row = Object.assign(pick(req.body, FIELDS), { created_by: req.user.id });
  const { data, error } = await supabaseAdmin.from('proformas').insert(row).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

router.put('/:id', ah(async (req, res) => {
  const patch = Object.assign(pick(req.body, FIELDS), { updated_at: new Date().toISOString() });
  const { data, error } = await supabaseAdmin.from('proformas').update(patch).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('proformas').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
