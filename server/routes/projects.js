import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin, pick } from '../middleware/auth.js';

const router = Router();
const FIELDS = ['title', 'type', 'icon', 'image', 'description', 'budget', 'duration', 'year', 'client'];

// Public
router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('projects').select('*').order('created_at', { ascending: true });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.post('/', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('projects').insert(pick(req.body, ['id'].concat(FIELDS))).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

router.put('/:id', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('projects').update(pick(req.body, FIELDS)).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', requireAdmin, ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('projects').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
