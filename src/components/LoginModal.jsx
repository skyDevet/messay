import { useState } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { signInWithGoogle } from '../lib/auth.js';

export function LoginModal({ formKind, cart, onClose }) {
  const [data, lang] = useStore();
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const go = async () => {
    setErr(''); setBusy(true);
    try {
      // OAuth leaves the page, so remember which form to reopen (and the cart) on return
      sessionStorage.setItem('mesay_pending_form', formKind || 'services');
      if (cart && cart.length) sessionStorage.setItem('mesay_pending_cart', JSON.stringify(cart));
      await signInWithGoogle();
    } catch (e) {
      sessionStorage.removeItem('mesay_pending_form');
      sessionStorage.removeItem('mesay_pending_cart');
      setErr(e.message || 'Sign-in failed. Please try again.');
      setBusy(false);
    }
  };

  return (
    <div class="modal-overlay" onClick={onClose}>
      <div class="modal login-modal" onClick={e => e.stopPropagation()}>
        <button class="modal-close" onClick={onClose} aria-label="Close">âœ•</button>
        <h2>{lang === 'am' ? 'áˆˆáˆ˜á‰€áŒ áˆ á‹­áŒá‰¡' : 'Sign in to continue'}</h2>
        <p>{lang === 'am' ? 'á‹¨á‹‹áŒ‹ áŒ¥á‹«á‰„ áˆˆáˆ˜áˆ‹áŠ­ á‰ Google áˆ˜áˆˆá‹«á‹Ž á‹­áŒá‰¡á¢' : 'Please sign in with Google to send a quote request.'}</p>
        <button type="button" class="btn btn-primary login-google" disabled={busy} onClick={go}>
          {busy ? '...' : (lang === 'am' ? 'á‰ Google á‹­áŒá‰¡' : 'Continue with Google')}
        </button>
        {err && <div class="login-err">{err}</div>}
      </div>
    </div>
  );
}
