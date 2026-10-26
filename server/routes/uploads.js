import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin } from '../middleware/auth.js';

const router = Router();
const BUCKET = process.env.SUPABASE_STORAGE_BUCKET || 'uploads';

// Admin: get a signed upload URL, then PUT the file straight to Supabase Storage from the browser.
// Body: { filename: "site.jpg", folder?: "projects" }
router.post('/', requireAdmin, ah(async (req, res) => {
  const filename = String((req.body && req.body.filename) || '').trim();
  if (!filename) return res.status(400).json({ error: 'filename is required.' });
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
  const folder = String((req.body && req.body.folder) || 'misc').replace(/[^a-zA-Z0-9_-]/g, '');
  const path = folder + '/' + Date.now() + '-' + safe;

  const { data, error } = await supabaseAdmin.storage.from(BUCKET).createSignedUploadUrl(path);
  if (error) return res.status(400).json({ error: error.message });
  const pub = supabaseAdmin.storage.from(BUCKET).getPublicUrl(path);
  res.status(201).json({ bucket: BUCKET, path: data.path, token: data.token, signedUrl: data.signedUrl, publicUrl: pub.data.publicUrl });
}));

export default router;
