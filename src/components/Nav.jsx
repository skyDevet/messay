import { useState } from 'preact/hooks';
import { useStore } from '../data/store.js';

export function Nav({ onStaff, onRequestQuote }) {
  const [open, setOpen] = useState(false);
  const [data, lang, setLang] = useStore();
    const links = [
    ['#services', lang === 'am' ? 'አገልግሎቶች' : 'Services'],
    ['#projects', lang === 'am' ? 'ፕሮጀክቶች' : 'Projects'],
    ['#catalog', lang === 'am' ? 'ቁሳቁሶች' : 'Materials'],
  ];
  return (
    <nav class="nav">
      <div class="nav-inner"> 
        <img 
          src="img/logo.png" 
          alt="Messay Abebebe General Contractor Logo" 
          class="logo" 
        />
       <button class="nav-toggle" onClick={() => setOpen(!open)}>☰</button>
    
        <div class={'nav-links ' + (open ? 'open' : '')}>
          {links.map(([h, l]) => <a href={h} onClick={() => setOpen(false)}>{l}</a>)}
          <button
            class="nav-lang"
            onClick={() => { setOpen(false); onRequestQuote && onRequestQuote(); }}
          >
            {lang === 'am' ? 'ዋጋ ጠይቅ' : 'Request Quote'}
          </button>
          <button class="nav-lang" onClick={() => setLang(lang === 'en' ? 'am' : 'en')}>
            {lang === 'en' ? 'አማ' : 'EN'}
          </button>
          <a href={'tel:' + data.business.cell1.replace(/\s/g, '')} class="nav-cta">📞</a>
          <button class="nav-admin" onClick={onStaff}>🔒</button>
        </div>
      </div>
    </nav>
  );
}
