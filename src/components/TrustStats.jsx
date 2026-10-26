import { useStore } from '../data/store.js';
export function TrustStats() {
  const [data, lang] = useStore();
  return (
    <section class="section alt"><div class="container"><div class="trust-grid">
      {data.stats.map(s => (<div class="trust-item"><span class="num">{s.num}</span><span class="lbl">{lang === 'am' ? s.lblAm : s.lblEn}</span></div>))}
    </div></div></section>
  );
}
