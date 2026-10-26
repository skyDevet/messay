import { useStore } from '../data/store.js';

export function Projects({ onOpen, onRequest }) {
  const [data, lang] = useStore();

  return (
    <section class="section alt" id="projects">
      <div class="container">
        <div class="section-header">
          <h2>{lang === 'am' ? 'የቅርብ ጊዜ ፕሮጀክቶች' : 'Recent Projects'}</h2>
          <p>
            {lang === 'am'
              ? 'በአዲስ አበባ የተጠናቀቁ — ህንፃዎች፣ መንገዶች፣ ማስተካከያዎች።'
              : 'Delivered across Addis Ababa — buildings, roads, fit-outs.'}
          </p>
        </div>

        <div class="gallery-grid">
          {data.projects.map((p) => (
            <div class="project-card" key={p.id} onClick={() => onOpen(p)}>
              <div class="project-img">
                {p.image && (
                  <img
                    src={p.image}
                    alt={p.title}
                    class="project-photo"
                    loading="lazy"
                    onError={(e) => {
                      e.currentTarget.style.display = 'none';
                      const fb = e.currentTarget.nextElementSibling;
                      if (fb) fb.style.display = 'flex';
                    }}
                  />
                )}               <div
                  class="project-fallback"
                  style={p.image ? { display: 'none' } : { display: 'flex' }}
                >
                  {p.icon || '📁'}
                </div>
                <span class="project-tag">{p.type}</span>
              </div>


              <div class="project-info">
                <h3>{p.title}</h3>
                <p>{p.desc}</p>
                <div class="project-meta">
                  <span>💰 {p.budget}</span>
                  <span>⏱ {p.duration}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
