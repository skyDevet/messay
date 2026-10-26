import { useState, useEffect } from 'preact/hooks';
import { supabase, isSupabaseConfigured } from '../lib/supabase.js';
import { signInWithGoogle, signOut, isAdminUser } from '../lib/auth.js';

export function StaffLogin({ onSuccess, onExit }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  // Shared check for email/password and Google: the user must exist in admin_users
  const verify = async (user) => {
    const ok = await isAdminUser(user.id);
    if (!ok) {
      await signOut();
      sessionStorage.removeItem('mesay_staff');
      setErr('Not authorized. This account is not on the admin list.');
      setBusy(false);
      return false;
    }
    sessionStorage.setItem('mesay_staff', '1');
    onSuccess();
    return true;
  };

  const signInEmail = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!supabase) { setErr('Sign-in is not configured.'); return; }
    if (!email || !password) { setErr('Enter your email and password.'); return; }
    setErr(''); setBusy(true);
    const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error || !data.user) { setErr(error ? error.message : 'Sign-in failed.'); setBusy(false); return; }
    await verify(data.user);
  };

  const signInGoogle = async () => {
    setErr(''); setBusy(true);
    try {
      sessionStorage.setItem('mesay_admin_oauth', '1');
      await signInWithGoogle();
    } catch (e) {
      sessionStorage.removeItem('mesay_admin_oauth');
      setErr(e.message || 'Google sign-in failed.');
      setBusy(false);
    }
  };

  // Returning from the Google redirect: run the admin_users check
  useEffect(() => {
    if (!supabase || sessionStorage.getItem('mesay_admin_oauth') !== '1') return;
    let alive = true;
    (async () => {
      setBusy(true);
      const { data } = await supabase.auth.getSession();
      sessionStorage.removeItem('mesay_admin_oauth');
      if (!alive) return;
      if (data.session) await verify(data.session.user);
      else setBusy(false);
    })();
    return () => { alive = false; };
  }, []);

  return (
    <div class="staff-login">
      <form class="staff-login-card" onSubmit={signInEmail}>
        <h2>Staff Login</h2>
        <p>Sign in with your admin account.</p>
        {!isSupabaseConfigured && <div class="staff-err">Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in .env.</div>}
        <input type="email" placeholder="Email" autocomplete="username" value={email} onInput={e => setEmail(e.target.value)} />
        <input type="password" placeholder="Password" autocomplete="current-password" value={password} onInput={e => setPassword(e.target.value)} />
        {err && <div class="staff-err">{err}</div>}
        <div class="staff-login-actions">
          <button type="submit" class="btn btn-primary" disabled={busy}>{busy ? 'Signing in...' : 'Sign In'}</button>
          <button type="button" class="btn btn-back" onClick={onExit}>Cancel</button>
        </div>
        <div class="staff-login-actions" style="margin-top:10px;">
          <button type="button" class="btn btn-primary" disabled={busy} onClick={signInGoogle}>Sign in with Google</button>
        </div>
      </form>
    </div>
  );
}
