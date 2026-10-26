import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireUser, requireAdmin, pick } from '../middleware/auth.js';

const router = Router();

// Public: approved reviews only
router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('reviews').select('*').eq('approved', true).order('created_at', { ascending: false });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

// Admin: every review, including pending ones
router.get('/all', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('reviews').select('*').order('created_at', { ascending: false });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

// Signed-in users submit a review; it stays hidden until an admin approves it
router.post('/', requireUser, ah(async (req, res) => {
  const row = Object.assign(pick(req.body, ['name', 'loc', 'stars', 'text']), { approved: false });
  const { data, error } = await supabaseAdmin.from('reviews').insert(row).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

router.patch('/:id', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('reviews').update(pick(req.body, ['name', 'loc', 'stars', 'text', 'approved'])).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', requireAdmin, ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('reviews').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
