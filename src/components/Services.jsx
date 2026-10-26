import { useStore } from '../data/store.js';
export function Services() {
  const [data, lang] = useStore();
  return (
    <section class="section" id="services"><div class="container">
      <div class="section-header">
        <h2>{lang === 'am' ? 'አገልግሎቶቻችን' : 'Our Services'}</h2>
        <p>{lang === 'am' ? 'በፈቃዳችን መሰረት የምንሰጣቸው አገልግሎቶች።' : 'Licensed capabilities under our General Contractor 511114 field of business.'}</p>
      </div>
      <div class="services-grid">
        {data.services.map(s => (<div class="service-card"><div class="service-icon">{s.icon}</div><h3>{lang === 'am' ? s.titleAm : s.titleEn}</h3><p>{s.descEn}</p></div>))}
      </div>
    </div></section>
  );
}
