import { useStore } from '../data/store.js';

export function Hero({ onOpenForm }) {
  const [data, lang] = useStore();
  const b = data.business, h = data.hero;

  return (
    <header class="hero">
      <div class="hero-content">
        

        <div class="grade-badge">
          {lang === 'am' ? 'አጠቃላይ ተቋራጭ' : 'GENERAL CONTRACTOR'} · G5
        </div>

        <h1>{lang === 'am' ? b.taglineAm : b.taglineEn}</h1>
        <p>{lang === 'am' ? b.subtitleAm : b.subtitleEn}</p>

        <div class="hero-btns">
          <button
            type="button"
            class="btn btn-primary"
            onClick={() => onOpenForm('services')}
          >
            {lang === 'am' ? 'የአገልግሎት ዋጋ ጠይቅ' : 'Request Service Quote'}
          </button>
          <button
            type="button"
            class="btn btn-outline"
            onClick={() => onOpenForm('materials')}
          >
            {lang === 'am' ? 'የቁሳቁስ ዋጋ ጠይቅ' : 'Request Materials Quote'}
          </button>
        </div>

        <div class="hero-badges">
          <span>{lang === 'en' ? h.badge1Am : h.badge1En}</span>
          <span>{lang === 'am' ? h.badge2Am : h.badge2En}</span>
          <span>{lang === 'am' ? h.badge3Am : h.badge3En}</span>
        </div>

        <div class="hero-contact">      
          <span>📞 {b.cell1}</span>
          <span>📞 {b.cell2}</span>
          <span>📍 {b.zoneSubCity} · Woreda {b.woreda}</span>
        </div>
      </div>
    </header>
  );
}
