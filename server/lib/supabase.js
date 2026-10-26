import './env.js';
import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  console.warn('[server] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are missing in .env. API routes will answer 503.');
}

// Service role key: bypasses RLS. Server only, never ship it to the browser.
export const supabaseAdmin = url && serviceKey
  ? createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } })
  : null;
