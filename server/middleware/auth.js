import { supabaseAdmin } from '../lib/supabase.js';

// Wrap async handlers so errors reach the error middleware
export const ah = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

export function requireDb(req, res, next) {
  if (!supabaseAdmin) return res.status(503).json({ error: 'Supabase is not configured on the server.' });
  next();
}

async function userFromRequest(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return null;
  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data || !data.user) return null;
  return data.user;
}

export async function isAdmin(userId) {
  const { data } = await supabaseAdmin.from('admin_users').select('user_id').eq('user_id', userId).maybeSingle();
  return !!data;
}

export const requireUser = ah(async (req, res, next) => {
  const user = await userFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Sign in required.' });
  req.user = user;
  next();
});

export const requireAdmin = ah(async (req, res, next) => {
  const user = await userFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Sign in required.' });
  if (!(await isAdmin(user.id))) return res.status(403).json({ error: 'Not authorized.' });
  req.user = user;
  next();
});

export function pick(obj, keys) {
  const out = {};
  keys.forEach(k => { if (obj && obj[k] !== undefined) out[k] = obj[k]; });
  return out;
}
