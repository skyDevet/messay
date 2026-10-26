import { supabase } from '../lib/supabase.js';

// Best-effort sync of quote requests to Supabase. The local IndexedDB copy is always kept.
export async function pushRequest(req) {
  if (!supabase || !req.userId) return null;
  try {
    const row = {
      id: req.id,
      user_id: req.userId,
      user_email: req.userEmail || null,
      kind: req.kind,
      status: req.status || 'new',
      client: req.client || {},
      cart: req.cart || null,
      description: req.description || null,
      service_type: req.serviceType || null,
      budget_range: req.budgetRange || null,
      timeline: req.timeline || null
    };
    const { error } = await supabase.from('quote_requests').insert(row);
    if (error) console.warn('Remote request save failed:', error.message);
  } catch (e) { console.warn('Remote request save failed:', e); }
  return null;
}

// Admin only (RLS returns nothing for other users).
export async function fetchRemoteRequests() {
  if (!supabase) return [];
  const { data, error } = await supabase.from('quote_requests').select('*').order('created_at', { ascending: false });
  if (error || !data) return [];
  return data.map(r => ({
    id: r.id,
    kind: r.kind,
    createdAt: r.created_at,
    status: r.status,
    client: r.client || {},
    cart: r.cart || undefined,
    description: r.description || undefined,
    serviceType: r.service_type || undefined,
    budgetRange: r.budget_range || undefined,
    timeline: r.timeline || undefined,
    userId: r.user_id,
    userEmail: r.user_email
  }));
}

export async function updateRemoteRequestStatus(id, status) {
  if (!supabase) return;
  try { await supabase.from('quote_requests').update({ status }).eq('id', id); } catch (e) {}
}

export async function deleteRemoteRequest(id) {
  if (!supabase) return;
  try { await supabase.from('quote_requests').delete().eq('id', id); } catch (e) {}
}
