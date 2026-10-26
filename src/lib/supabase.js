import { createClient } from '@supabase/supabase-js';

// Frontend uses the public anon key only (VITE_ prefix). The service role key lives in the server .env.
const url = import.meta.env.VITE_SUPABASE_URL;
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const isSupabaseConfigured = Boolean(url && anon);
export const supabase = isSupabaseConfigured ? createClient(url, anon) : null;
