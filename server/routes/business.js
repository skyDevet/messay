import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin } from '../middleware/auth.js';

const router = Router();

// Public
router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('business_info').select('data').eq('id', 1).maybeSingle();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data ? data.data : {});
}));

// Admin: replace the single business_info row
router.put('/', requireAdmin, ah(async (req, res) => {
  const row = { id: 1, data: req.body || {}, updated_at: new Date().toISOString() };
  const { data, error } = await supabaseAdmin.from('business_info').upsert(row).select('data').single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data.data);
}));

export default router;
