import { useState, useEffect } from 'preact/hooks';
import { supabase } from './supabase.js';

export function useAuth() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(!!supabase);
  useEffect(() => {
    if (!supabase) return;
    let alive = true;
    supabase.auth.getSession().then(({ data }) => {
      if (!alive) return;
      setUser(data.session ? data.session.user : null);
      setLoading(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_evt, session) => {
      setUser(session ? session.user : null);
    });
    return () => { alive = false; sub.subscription.unsubscribe(); };
  }, []);
  return { user, loading };
}

export async function signInWithGoogle() {
  if (!supabase) throw new Error('Sign-in is not configured (missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY).');
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: window.location.origin }
  });
  if (error) throw error;
}

export async function signOut() {
  if (supabase) await supabase.auth.signOut();
}

// True only when the user exists in the admin_users table.
export async function isAdminUser(userId) {
  if (!supabase || !userId) return false;
  const { data, error } = await supabase.from('admin_users').select('user_id, role').eq('user_id', userId).maybeSingle();
  if (error) return false;
  return !!data;
}
