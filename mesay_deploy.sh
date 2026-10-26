#!/bin/bash
set -e
echo "Creating project files..."
cat > package.json << 'END'
{
  "name": "mesayabebe",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0",
    "server": "node server/index.js",
    "all": "concurrently -n web,api -c cyan,magenta \"npm run dev\" \"npm run server\""
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.117.3",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "preact": "^10.20.1"
  },
  "devDependencies": {
    "@preact/preset-vite": "^2.8.2",
    "concurrently": "^8.2.2",
    "vite": "^5.2.0"
  }
}
END
cat > vite.config.js << 'END'
import { defineConfig } from 'vite';
import preact from '@preact/preset-vite';

export default defineConfig({
  plugins: [preact()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:3001', changeOrigin: true },
    },
  },
});END
cat > server.js << 'END'
END
cat > index.html << 'END'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Mesay Abebe General Contractor</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
END
cat > .gitignore << 'END'
# Dependencies
node_modules/
.cache/

# Build outputs - THESE WILL NOT BE PUSHED
dist/
.vite/
build/
.capacitor/


# OS files
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# Temporary
tmp/
backup_*/
END
mkdir -p src/components src/admin src/data 
cat > src/main.jsx << 'END'
import { render } from 'preact';
import { App } from './app.jsx';
import './style.css';
import './admin/admin.css';
import './print.css';
render(<App />, document.getElementById('app'));
END
cat > src/app.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { Nav } from './components/Nav.jsx';
import { Hero } from './components/Hero.jsx';
import { TrustStats } from './components/TrustStats.jsx';
import { Services } from './components/Services.jsx';
import { Projects } from './components/Projects.jsx';
import { Catalog } from './components/Catalog.jsx';
import { RequestMaterials } from './components/RequestMaterials.jsx';
import { RequestServices } from './components/RequestServices.jsx';
import { Reviews } from './components/Reviews.jsx';
import { ProjectModal } from './components/ProjectModal.jsx';
import { Footer } from './components/Footer.jsx';
import { StaffLogin } from './admin/StaffLogin.jsx';
import { Admin } from './admin/Admin.jsx';
import { getRateBookMeta, seedFromModule } from './data/ratebook.js';
import { LoginModal } from './components/LoginModal.jsx';
import { useAuth } from './lib/auth.js';
import { supabase } from './lib/supabase.js';
import { isAdminUser } from './lib/auth.js';

export function App() {
  const [activeProject, setActiveProject] = useState(null);
  const [staff, setStaff] = useState(sessionStorage.getItem('mesay_staff') === '1');
  const [loginOpen, setLoginOpen] = useState(false);
  const [cart, setCart] = useState([]);
  const [openForm, setOpenForm] = useState(null); // 'materials' | 'services' | null
  const { user } = useAuth();
  const [pendingForm, setPendingForm] = useState(null); // quote form waiting for Google sign-in

  // Gate: any quote form needs a signed-in user; otherwise show the login modal first
  const requestForm = (kind) => {
    if (user) { setOpenForm(kind); return; }
    setPendingForm(kind);
  };

  // Back from Google sign-in: reopen the form the user asked for (and restore the cart)
  useEffect(() => {
    if (!user) return;
    const kind = sessionStorage.getItem('mesay_pending_form');
    if (!kind) return;
    sessionStorage.removeItem('mesay_pending_form');
    try {
      const saved = JSON.parse(sessionStorage.getItem('mesay_pending_cart') || 'null');
      if (saved && saved.length) setCart(saved);
    } catch (e) {}
    sessionStorage.removeItem('mesay_pending_cart');
    setPendingForm(null);
    setOpenForm(kind);
  }, [user]);

  // Back from admin Google sign-in: reopen the staff login so it can run the admin_users check
  useEffect(() => {
    if (sessionStorage.getItem('mesay_admin_oauth') === '1') setLoginOpen(true);
  }, []);
  
useEffect(() => {
  (async () => {
    try {
      const { migrateRateBook } = await import('./data/ratebook.js');
      const mig = await migrateRateBook();
      if (mig.itemsFixed || mig.categoriesFixed) {
        console.log('Rate book migration:', mig);
      }
      const meta = await getRateBookMeta();
      if (!meta) {
        const res = await seedFromModule();
        console.log('Rate book auto-seeded:', res);
      }
    } catch (e) { console.error('Auto-seed failed:', e); }
  })();
}, []);
  
  // When the user picks a form, scroll to it once it renders
  useEffect(() => {
    if (openForm) {
      requestAnimationFrame(() => {
        const id = openForm === 'materials' ? 'request-materials' : 'request-services';
        const el = document.getElementById(id);
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }
  }, [openForm]);

  if (staff) return <Admin onExit={() => setStaff(false)} />;
  if (loginOpen) return <StaffLogin onSuccess={() => { setLoginOpen(false); setStaff(true); }} onExit={() => setLoginOpen(false)} />;

  // Full-screen solo view: while a quote form is open, nothing else on the home page renders
  if (openForm === 'materials') return (
    <div class="solo-form">
      <RequestMaterials cart={cart} setCart={setCart} user={user} onClose={() => setOpenForm(null)} />
    </div>
  );
  if (openForm === 'services') return (
    <div class="solo-form">
      <RequestServices user={user} onClose={() => setOpenForm(null)} />
    </div>
  );
const handleStaffClick = async () => {
  try {
    if (!supabase) { setLoginOpen(true); return; }
    const { data: s } = await supabase.auth.getSession();
    const u = s.session && s.session.user;
    if (u && (await isAdminUser(u.id))) {
      sessionStorage.setItem('mesay_staff', '1');
      setStaff(true);
      return;
    }
  } catch (e) {}
  setLoginOpen(true);
};
  return (
    <>
      <Nav onStaff={handleStaffClick} onRequestQuote={() => requestForm('materials')} />
      <Hero onOpenForm={requestForm} />
      <TrustStats />
      <Services />
      <Projects onOpen={setActiveProject} />
      <Catalog cart={cart} setCart={setCart} onRequest={() => requestForm('materials')} />

      <Reviews />
      <Footer />
      {activeProject && <ProjectModal project={activeProject} onClose={() => setActiveProject(null)} onRequest={requestForm} />}
      {pendingForm && <LoginModal formKind={pendingForm} cart={cart} onClose={() => setPendingForm(null)} />}
    </>
  );
}
END
cat > src/style.css << 'END'
:root { --primary: #f59e0b; --primary-dark: #d97706; --dark: #1f2937; --darker: #111827; --light: #f9fafb; --gray: #6b7280; --border: #e5e7eb; --success: #10b981; --ethio-green: #078930; --ethio-yellow: #fcdd09; --ethio-red: #da121a; --radius: 10px; --shadow: 0 4px 14px rgba(0,0,0,0.08); }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans Ethiopic", sans-serif; color: var(--dark); background: var(--light); line-height: 1.6; -webkit-font-smoothing: antialiased; }
a { color: inherit; text-decoration: none; }
button { font-family: inherit; cursor: pointer; border: none; background: none; }
img { max-width: 100%; display: block; }

.container{ max-width: 100vw; margin: 0 0; padding: 0 1em; margin-left: -2em; }

.containerm { max-width: 1100px; margin: 0 auto; padding: 0 20px; }
.nav { background: var(--darker); color: white; position: sticky; top: 0; z-index: 100; box-shadow: 0 2px 10px rgba(0,0,0,0.2); }
.nav-inner { display: flex; align-items: center; justify-content: space-between; padding: 14px 20px; max-width: 1100px; margin: 0 auto; }
.logo { font-weight: 800; font-size: 1.1rem; white-space: nowrap; }
.logo span { color: var(--primary); }
.nav-links { display: flex; gap: 16px; align-items: center; }
.nav-links a { font-size: 0.88rem; font-weight: 500; opacity: 0.85; }
.nav-links a:hover { color: var(--primary); opacity: 1; }
.nav-cta { background: var(--primary); color: var(--darker) !important; padding: 8px 12px; border-radius: var(--radius); font-weight: 700; opacity: 1 !important; }
.nav-toggle { display: none; color: white; font-size: 1.5rem; }
@media (max-width: 820px) { .nav-toggle { display: block; } .nav-links { position: absolute; top: 100%; left: 0; right: 0; background: var(--darker); flex-direction: column; padding: 20px; gap: 14px; display: none; } .nav-links.open { display: flex; } }
.hero { background: linear-gradient(135deg, #1f2937 0%, #111827 100%); color: white; padding: 60px 20px 70px; text-align: center; position: relative; overflow: hidden; }
.hero::before { content: ""; position: absolute; inset: 0; background-image: repeating-linear-gradient(45deg, rgba(245,158,11,0.06) 0 20px, transparent 20px 40px); }
.hero::after { content: ""; position: absolute; top: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, var(--ethio-green) 33%, var(--ethio-yellow) 33% 66%, var(--ethio-red) 66%); }
.hero-content { position: relative; max-width: 800px; margin: 0 auto; }
.grade-badge { display: inline-block; background: rgba(245,158,11,0.2); color: var(--primary); padding: 6px 14px; border-radius: 50px; font-size: 0.76rem; font-weight: 700; margin-bottom: 18px; }
.hero h1 { font-size: clamp(1.5rem, 4.2vw, 2.4rem); font-weight: 800; line-height: 1.2; margin-bottom: 14px; }
.hero p { font-size: 0.98rem; opacity: 0.85; margin-bottom: 26px; }
.hero-btns { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }
.hero-badges { display: flex; justify-content: center; gap: 18px; flex-wrap: wrap; margin-top: 26px; font-size: 0.8rem; opacity: 0.75; }
.hero-badges span::before { content: "âœ“ "; color: var(--success); font-weight: bold; }
.hero-contact { display: flex; justify-content: center; gap: 18px; flex-wrap: wrap; margin-top: 18px; font-size: 0.82rem; opacity: 0.85; }
.btn { display: inline-block; padding: 12px 24px; border-radius: var(--radius); font-weight: 700; font-size: 0.9rem; transition: transform 0.15s; }
.btn:hover { transform: translateY(-2px); }
.btn-primary { background: var(--primary); color: var(--darker); }
.btn-primary:hover { background: var(--primary-dark); }
.btn-outline { background: transparent; border: 2px solid white; color: white; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-back { background: var(--border); color: var(--dark); padding: 8px 14px; border-radius: 8px; font-weight: 600; font-size: 0.82rem; }
.section { padding: 55px 20px; }
.section-header { text-align: center; margin-bottom: 36px; }
.section-header h2 { font-size: clamp(1.4rem, 3.8vw, 1.9rem); font-weight: 800; margin-bottom: 8px; }
.section-header p { color: var(--gray); max-width: 560px; margin: 0 auto; font-size: 0.95rem; }
.section.alt { background: white; }
.section.altx {min-width:100vw; margin-left:-4em;min-width:100vw; background: white; }
/* Mobile first: horizontal scroll row */
.trust-grid {
  display: flex;
  gap: 14px;
  overflow-x: auto;
  overflow-y: hidden;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 12px;
  margin: 0 -20px;
  padding-left: 20px;
  padding-right: 20px;
  text-align: center;
}

.trust-grid > .trust-item {
  flex: 0 0 60%;
  scroll-snap-align: center;
  max-width: 220px;
}

.trust-grid::-webkit-scrollbar {
  height: 6px;
}
.trust-grid::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.15);
  border-radius: 3px;
}
.trust-grid::-webkit-scrollbar-track {
  background: transparent;
}

/* Tablet / desktop: revert to grid */
@media (min-width: 820px) {
  .trust-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 16px;
    overflow: visible;
    margin: 0;
    padding: 0;
    scroll-snap-type: none;
  }
  .trust-grid > .trust-item {
    flex: initial;
    max-width: none;
  }
}

.trust-item { background: white; padding: 22px 14px; border-radius: var(--radius); box-shadow: var(--shadow); }
.trust-item .num { font-size: 1.5rem; font-weight: 800; color: var(--primary); display: block; }
.trust-item .lbl { font-size: 0.8rem; color: var(--gray); }
.services-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 18px; }
.service-card { background: white; padding: 24px; border-radius: var(--radius); box-shadow: var(--shadow); }
.service-icon { font-size: 2.2rem; margin-bottom: 10px; }
.service-card h3 { font-size: 1.05rem; margin-bottom: 6px; }
.service-card p { font-size: 0.88rem; color: var(--gray); }
.gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 18px; }
.project-card { background: white; border-radius: var(--radius); overflow: hidden; box-shadow: var(--shadow); cursor: pointer; transition: transform 0.2s; }
.project-card:hover { transform: translateY(-4px); }
.project-img { height: 170px; background: linear-gradient(135deg, #94a3b8, #475569); display: flex; align-items: center; justify-content: center; color: white; font-size: 2.4rem; position: relative; }
.project-tag { position: absolute; top: 12px; left: 12px; background: var(--primary); color: var(--darker); font-size: 0.68rem; font-weight: 700; padding: 3px 10px; border-radius: 50px; text-transform: uppercase; }
.project-info { padding: 14px; }
.project-info h3 { font-size: 1rem; margin-bottom: 4px; }
.project-info p { font-size: 0.84rem; color: var(--gray); }
.project-meta { display: flex; justify-content: space-between; margin-top: 10px; font-size: 0.78rem; color: var(--gray); border-top: 1px solid var(--border); padding-top: 10px; flex-wrap: wrap; gap: 6px; }
.filters { display: flex; gap: 8px; justify-content: center; flex-wrap: wrap; margin-bottom: 24px; }
.filter-btn { padding: 7px 14px; border-radius: 50px; background: white; border: 1px solid var(--border); font-size: 0.82rem; font-weight: 600; color: var(--gray); }
.filter-btn.active { background: var(--dark); color: white; border-color: var(--dark); }
.catalog-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 18px; }
.product-card { background: white; border-radius: var(--radius); overflow: hidden; box-shadow: var(--shadow); display: flex; flex-direction: column; }
.product-img { height: 120px; background: linear-gradient(135deg, #334155, #1f2937); display: flex; align-items: center; justify-content: center; position: relative; }
.product-cat { position: absolute; top: 10px; left: 10px; background: var(--primary); color: var(--darker); font-size: 0.66rem; font-weight: 700; padding: 3px 9px; border-radius: 50px; text-transform: uppercase; }
.product-icon { font-size: 2.6rem; }
.product-info { padding: 14px; flex: 1; display: flex; flex-direction: column; }
.product-info h3 { font-size: 0.95rem; margin-bottom: 6px; }
.product-meta { display: flex; justify-content: space-between; font-size: 0.76rem; color: var(--gray); margin-bottom: 10px; }
.product-actions { display: flex; gap: 6px; margin-top: auto; }
.product-actions input { width: 70px; padding: 8px; border: 1px solid var(--border); border-radius: 6px; font-size: 0.85rem; font-family: inherit; }
.btn-add-cart { flex: 1; background: var(--primary); color: var(--darker); padding: 8px; border-radius: 6px; font-weight: 700; font-size: 0.82rem; }
.cart-summary { background: var(--darker); color: white; padding: 14px 20px; border-radius: var(--radius); margin-top: 20px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; }
/* Mobile first: horizontal scroll row */
.reviews-grid {
  display: flex;
  gap: 16px;
  overflow-x: auto;
  overflow-y: hidden;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 12px;
  margin: 0 -20px;
  padding-left: 20px;
  padding-right: 20px;
}

.reviews-grid > .review-card {
  flex: 0 0 82%;
  scroll-snap-align: center;
  max-width: 320px;
}

.reviews-grid::-webkit-scrollbar {
  height: 6px;
}
.reviews-grid::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.15);
  border-radius: 3px;
}
.reviews-grid::-webkit-scrollbar-track {
  background: transparent;
}

/* Tablet / desktop: revert to grid */
@media (min-width: 820px) {
  .reviews-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 16px;
    overflow: visible;
    margin: 0;
    padding: 0;
    scroll-snap-type: none;
  }
  .reviews-grid > .review-card {
    flex: initial;
    max-width: none;
  }
}
.review-card { background: white; padding: 20px; border-radius: var(--radius); box-shadow: var(--shadow); }
.review-stars { color: var(--primary); margin-bottom: 8px; letter-spacing: 2px; }
.review-card p { font-size: 0.88rem; font-style: italic; color: #374151; margin-bottom: 12px; }
.review-author { font-size: 0.82rem; font-weight: 700; }
.review-loc { font-size: 0.76rem; color: var(--gray); }
footer { background: var(--darker); color: white; padding: 36px 20px 22px; text-align: center; }
footer .license { display: inline-block; background: rgba(245,158,11,0.15); color: var(--primary); padding: 7px 14px; border-radius: 50px; font-size: 0.74rem; font-weight: 600; margin: 12px 0; }
footer p { font-size: 0.82rem; opacity: 0.7; }
footer .foot-links { margin: 14px 0; display: flex; justify-content: center; gap: 18px; flex-wrap: wrap; font-size: 0.84rem; }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.7); display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 1000; }
.modal { background: white; border-radius: var(--radius); max-width: 520px; width: 100%; max-height: 85vh; overflow-y: auto; padding: 26px; position: relative; }
.modal h2 { margin-bottom: 6px; font-size: 1.25rem; }
.modal-close { position: absolute; top: 14px; right: 14px; font-size: 1.5rem; color: var(--gray); }
.modal-meta { display: flex; gap: 14px; font-size: 0.8rem; color: var(--gray); margin: 14px 0; padding: 12px 0; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); flex-wrap: wrap; }
.wizard { background: white; border-radius: var(--radius); padding: 28px; max-width: 560px; margin: 0 auto; box-shadow: var(--shadow); }
.wizard-success { text-align: center; padding: 20px 0; }
.wizard-success .check { font-size: 3.5rem; color: var(--success); margin-bottom: 12px; }
.wizard-options { display: flex; flex-direction: column; gap: 10px; margin-bottom: 20px; }
.wizard-option { padding: 14px 16px; border: 2px solid var(--border); border-radius: 8px; background: white; text-align: left; font-size: 0.92rem; font-weight: 500; }
.wizard-option.selected { border-color: var(--primary); background: #fffbeb; }
.pf-builder { background: white; padding: 10px; border-radius: var(--radius); box-shadow: var(--shadow); max-width: 1000px; min-width:100vw; margin: 0 auto; }
.pf-builder h3 { margin: 20px 0 10px; font-size: 1rem; }
.pf-builder h3:first-child { margin-top: 0; }
.pf-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.pf-grid label { display: flex; align-items: center; font-size: 0.85rem; font-weight: 600; color: var(--gray); }
@media (max-width: 600px) { .pf-grid { grid-template-columns: 1fr; } }
.pf-builder input, .pf-builder select, .pf-builder textarea { width: 100%; padding: 10px; border: 1px solid var(--border); border-radius: 8px; font-family: inherit; font-size: 0.9rem; background: white; margin-bottom: 10px; }
.pf-builder input:focus, .pf-builder select:focus, .pf-builder textarea:focus { outline: none; border-color: var(--primary); }
.pf-add-row { display: grid; grid-template-columns: 1fr 2fr 80px 80px 90px; gap: 8px; align-items: center; }
@media (max-width: 720px) { .pf-add-row { grid-template-columns: 1fr 1fr; } }
.pf-add-row input, .pf-add-row select { margin-bottom: 0; }
.pf-unit { font-size: 0.76rem; color: var(--gray); text-align: center; }
.pf-table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 0.86rem; }
.pf-table th, .pf-table td { padding: 8px 10px; border-bottom: 1px solid var(--border); text-align: left; }
.pf-table th { background: #f9fafb; font-size: 0.74rem; text-transform: uppercase; color: var(--gray); }
.pf-table input { width: 85px; padding: 4px 6px; margin: 0; font-size: 0.85rem; }
.pf-totals { background: #f9fafb; padding: 16px; border-radius: 8px; margin-top: 16px; }
.pf-totals > div { display: flex; justify-content: space-between; padding: 4px 0; font-size: 0.88rem; }
.pf-grand { border-top: 2px solid var(--dark); margin-top: 8px; padding-top: 10px !important; font-weight: 800; font-size: 1rem !important; }
.pf-grand span:last-child { color: var(--primary); }
.pf-lead { color: var(--success); font-size: 0.8rem !important; font-weight: 600; }
.pf-actions { display: flex; gap: 10px; margin-top: 18px; flex-wrap: wrap; }
.pf-actions .btn-primary { flex: 1; min-width: 160px; }
.pf-status { padding: 3px 10px; border-radius: 50px; font-size: 0.7rem; font-weight: 700; text-transform: uppercase; }
.pf-status.draft { background: #e5e7eb; color: #374151; }
.pf-status.sent { background: #fef3c7; color: #92400e; }
.pf-status.accepted, .pf-status.quoted { background: #d1fae5; color: #065f46; }
.pf-status.rejected, .pf-status.expired { background: #fee2e2; color: #991b1b; }
.pf-doc { background: white; padding: 36px; border-radius: var(--radius); box-shadow: var(--shadow); max-width: 900px; margin: 0 auto; }
.pf-doc-header { display: flex; justify-content: space-between; gap: 20px; border-bottom: 2px solid var(--dark); padding-bottom: 18px; margin-bottom: 18px; flex-wrap: wrap; }
.pf-doc-header h1 { font-size: 1.25rem; margin-bottom: 6px; }
.pf-doc-header p { font-size: 0.82rem; color: var(--gray); }
.pf-doc-meta { text-align: right; }
.pf-doc-meta h2 { font-size: 0.95rem; letter-spacing: 3px; color: var(--gray); margin-bottom: 6px; }
.pf-doc-meta strong { font-size: 1.05rem; color: var(--primary); }
.pf-doc-client { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 22px; }
@media (max-width: 600px) { .pf-doc-client { grid-template-columns: 1fr; } }
.pf-doc-client strong { display: block; font-size: 0.72rem; text-transform: uppercase; color: var(--gray); margin-bottom: 6px; }
.pf-doc-client p { font-size: 0.88rem; }
.pf-doc-table { margin: 18px 0; }
.pf-doc-totals { margin-left: auto; max-width: 340px; margin-top: 12px; }
.pf-doc-totals > div { display: flex; justify-content: space-between; padding: 6px 0; font-size: 0.88rem; }
.pf-doc-totals .pf-grand { font-size: 1.05rem; }
.pf-doc-terms { margin-top: 22px; padding-top: 18px; border-top: 1px solid var(--border); font-size: 0.82rem; color: var(--gray); }
.pf-doc-terms strong { display: block; color: var(--dark); margin-bottom: 4px; font-size: 0.85rem; }
.pf-doc-sign { display: flex; justify-content: space-between; margin-top: 50px; font-size: 0.78rem; color: var(--gray); gap: 20px; flex-wrap: wrap; }

/* --- Before & After Slider --- */
.before-after-wrapper {
  position: relative;
  width: 100%;
  max-width: 900px;
  margin: 0 auto;
  aspect-ratio: 16 / 9; /* Adjust to match your images */
  overflow: hidden;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.15);
  user-select: none; /* Prevents text selection while dragging */
}

.ba-image {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  pointer-events: none; /* Prevents images from interfering with the slider */
}

/* The "After" image is inside a container that gets clipped */
.ba-after-clip {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  overflow: hidden;
  border-right: 3px solid #fff; /* The white line of the slider */
  z-index: 2;
}

.ba-after {
  /* Ensure the after image stays the same size as the wrapper, even when clipped */
  width: 100vw; 
  max-width: 900px; /* Must match wrapper max-width */
  height: 100%;
}

/* The vertical slider line and handle */
.ba-slider-line {
  position: absolute;
  top: 0;
  bottom: 0;
  width: 3px;
  background: #fff;
  z-index: 3;
  transform: translateX(-50%);
  pointer-events: none;
}

.ba-slider-handle {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 40px;
  height: 40px;
  background: #fff;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 10px rgba(0,0,0,0.3);
  color: #333;
  font-size: 1.2rem;
  font-weight: bold;
}

/* The invisible range input that covers the whole area to capture dragging */
.ba-range-input {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: ew-resize; /* Shows left-right arrow cursor */
  z-index: 10;
  margin: 0;
}

/* Before/After Text Labels */
.ba-label {
  position: absolute;
  bottom: 1rem;
  background: rgba(0, 0, 0, 0.6);
  color: #fff;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  font-size: 0.85rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  z-index: 4;
  pointer-events: none;
}

.ba-label-before {
  right: 1rem;
}

.ba-label-after {
  left: 1rem;
}

/* Mobile Responsiveness */
@media (max-width: 768px) {
  .before-after-wrapper {
    aspect-ratio: 4 / 3;
  }
  .ba-slider-handle {
    width: 32px;
    height: 32px;
  }
}


.project-img {
  height: 170px;
  background: linear-gradient(135deg, #94a3b8, #475569);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 2.4rem;
  position: relative;
  overflow: hidden;
}

.project-photo {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  transition: transform 0.35s ease;
}

.project-card:hover .project-photo {
  transform: scale(1.06);
}

.project-fallback {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 2.4rem;
}

.project-tag {
  z-index: 2;
}


.gallery-grid {
  display: flex;
  gap: 16px;
  overflow-x: auto;
  overflow-y: hidden;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 12px;
  margin: 0 -20px;          /* bleed past .container padding */
  padding-left: 20px;
  padding-right: 20px;
}

.gallery-grid > .project-card {
  flex: 0 0 82%;            /* each card takes ~82% of viewport */
  scroll-snap-align: center;
  max-width: 320px;         /* cap card width on tablets/desktop */
}

/* Hide the ugly scrollbar but keep scrolling */
.gallery-grid::-webkit-scrollbar {
  height: 6px;
}
.gallery-grid::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.15);
  border-radius: 3px;
}
.gallery-grid::-webkit-scrollbar-track {
  background: transparent;
}

/* Mobile first: horizontal scroll row */
.services-grid {
  display: flex;
  gap: 16px;
  overflow-x: auto;
  overflow-y: hidden;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 12px;
  margin: 0 -20px;
  padding-left: 20px;
  padding-right: 20px;
}

.services-grid > .service-card {
  flex: 0 0 82%;
  scroll-snap-align: center;
  max-width: 320px;
}

.services-grid::-webkit-scrollbar {
  height: 6px;
}
.services-grid::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.15);
  border-radius: 3px;
}
.services-grid::-webkit-scrollbar-track {
  background: transparent;
}

/* Tablet / desktop: revert to grid */
@media (min-width: 820px) {
  .services-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));
    gap: 18px;
    overflow: visible;
    margin: 0;
    padding: 0;
    scroll-snap-type: none;
  }
  .services-grid > .service-card {
    flex: initial;
    max-width: none;
  }
}


/* Mobile first: horizontal scroll row */
.catalog-grid {
  display: flex;
  gap: 16px;
  overflow-x: auto;
  overflow-y: hidden;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 12px;
  margin: 0 -20px;
  padding-left: 20px;
  padding-right: 20px;
}

.catalog-grid > .product-card {
  flex: 0 0 72%;
  scroll-snap-align: center;
  max-width: 280px;
}

.catalog-grid::-webkit-scrollbar {
  height: 6px;
}
.catalog-grid::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.15);
  border-radius: 3px;
}
.catalog-grid::-webkit-scrollbar-track {
  background: transparent;
}

/* Tablet / desktop: revert to grid */
@media (min-width: 820px) {
  .catalog-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 18px;
    overflow: visible;
    margin: 0;
    padding: 0;
    scroll-snap-type: none;
  }
  .catalog-grid > .product-card {
    flex: initial;
    max-width: none;
  }
}
.logo {
  max-width: 8em;
}

.form-close {
  position: absolute;
  top: 0;
  right: 0;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: var(--border);
  color: var(--dark);
  font-size: 1rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.15s;
}
.form-close:hover {
  background: var(--gray);
  color: white;
}

/* Quote form solo view (nothing else on the page renders while a form is open) */
.solo-form { min-height: 100vh; background: var(--light); }

/* Hero quote buttons side by side on desktop */
@media (min-width: 820px) {
  .hero-btns { flex-wrap: nowrap; }
  .hero-btns .btn { flex: 0 0 auto; }
}

/* Login modal */
.login-modal { text-align: center; max-width: 420px; }
.login-modal p { color: var(--gray); font-size: 0.9rem; margin: 8px 0 18px; }
.login-google { display: flex; align-items: center; justify-content: center; gap: 10px; width: 100%; }
.login-err { color: #dc2626; font-size: 0.85rem; margin-top: 12px; }


/* --- Public catalog: product images --- */
.product-img {
  position: relative;
  overflow: hidden;
}
.product-photo {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  z-index: 1;
}
.product-icon {
  position: relative;
  z-index: 0;
  width: 100%;
  height: 100%;
  align-items: center;
  justify-content: center;
  font-size: 2.6rem;
}END
cat > src/print.css << 'END'
@media print { .nav, footer, .no-print, .section-header, .admin-header, .admin-tabs, .pf-actions, .pf-mode-tabs { display: none !important; } body { background: white; } .section { padding: 0; } .container { max-width: 100%; padding: 0; } .pf-doc { box-shadow: none; padding: 0; margin: 0; } .pf-doc-header { border-bottom-color: #000; } }
END
cat > src/admin/admin.css << 'END'
.admin { min-height: 100vh; background: #f3f4f6; }
.admin-header { background: var(--darker); color: white; padding: 14px 20px; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 50; }
.admin-header-actions { display: flex; gap: 8px; }
.admin-header button { padding: 8px 14px; border-radius: 8px; font-weight: 600; font-size: 0.85rem; }
.btn-view { background: var(--primary); color: var(--darker); }
.btn-danger { background: #dc2626; color: white; padding: 8px 14px; border-radius: 8px; font-weight: 700; font-size: 0.85rem; }
.admin-tabs { display: flex; gap: 4px; padding: 12px 20px; background: white; border-bottom: 1px solid var(--border); overflow-x: auto; position: sticky; top: 54px; z-index: 40; }
.admin-tab { padding: 8px 14px; border-radius: 8px; background: transparent; font-weight: 600; font-size: 0.85rem; color: var(--gray); white-space: nowrap; }
.admin-tab.active { background: var(--dark); color: white; }
.admin-body { padding: 20px; max-width: 1000px; margin: 0 auto; }
.admin-panel h2 { margin-bottom: 18px; font-size: 1.2rem; }
.admin-panel-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; gap: 10px; flex-wrap: wrap; }
.admin-field { margin-bottom: 14px; }
.admin-field label { display: block; font-size: 0.8rem; font-weight: 600; margin-bottom: 4px; color: var(--gray); }
.admin-field input, .admin-field textarea, .admin-field select { width: 100%; padding: 10px; border: 1px solid var(--border); border-radius: 8px; font-family: inherit; font-size: 0.9rem; background: white; }
.admin-field input:focus, .admin-field textarea:focus { outline: none; border-color: var(--primary); }
.admin-grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.admin-grid3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; }
@media (max-width: 600px) { .admin-grid2, .admin-grid3 { grid-template-columns: 1fr; } }

.admin-cardx { margin-left:-4em; background: white; border-radius: 10px; padding: 16px; margin-bottom: 14px; box-shadow: 0 1px 4px rgba(0,0,0,0.05); }
.admin-card { background: white; border-radius: 10px; padding: 16px; margin-bottom: 14px; box-shadow: 0 1px 4px rgba(0,0,0,0.05); }
.admin-subcard { background: #f9fafb; border-radius: 8px; padding: 12px; margin-bottom: 8px; border: 1px solid var(--border); }
.admin-card-head { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
.admin-card-title { flex: 1; font-size: 0.95rem; font-weight: 700; border: 1px solid transparent; background: transparent; padding: 6px; border-radius: 6px; font-family: inherit; min-width: 120px; }
.admin-card-title:hover, .admin-card-title:focus { border-color: var(--border); background: white; outline: none; }
.admin-card-icon { width: 48px; text-align: center; font-size: 1.3rem; padding: 6px; border: 1px solid transparent; border-radius: 6px; background: transparent; }
.admin-card-icon:focus { border-color: var(--border); background: white; outline: none; }
.admin-row3 { display: grid; grid-template-columns: 90px 1fr 1fr 40px; gap: 8px; margin-bottom: 8px; align-items: center; }
.admin-row3 input { padding: 8px; border: 1px solid var(--border); border-radius: 6px; font-family: inherit; font-size: 0.88rem; }
.btn-add { background: var(--success); color: white; padding: 8px 14px; border-radius: 8px; font-weight: 700; font-size: 0.85rem; }
.btn-del { background: #fee2e2; color: #dc2626; padding: 6px 12px; border-radius: 6px; font-weight: 600; font-size: 0.8rem; }
.nav-admin { background: transparent; color: white; font-size: 0.95rem; opacity: 0.7; }
.nav-admin:hover { opacity: 1; color: var(--primary); }
.nav-lang { background: rgba(245,158,11,0.2); color: var(--primary); padding: 6px 10px; border-radius: 6px; font-size: 0.8rem; font-weight: 700; }
.admin-msg { background: #fef3c7; color: #92400e; padding: 10px 14px; border-radius: 8px; font-size: 0.85rem; margin-bottom: 14px; font-weight: 600; }
.staff-login { min-height: 100vh; display: flex; align-items: center; justify-content: center; background: var(--darker); padding: 20px; }
.staff-login-card { background: white; padding: 32px; border-radius: var(--radius); width: 100%; max-width: 400px; box-shadow: 0 10px 40px rgba(0,0,0,0.3); }
.staff-login-card h2 { margin-bottom: 8px; font-size: 1.3rem; }
.staff-login-card p { font-size: 0.85rem; color: var(--gray); margin-bottom: 20px; }
.staff-login-card input { width: 100%; padding: 12px; border: 2px solid var(--border); border-radius: 8px; font-size: 1rem; font-family: inherit; margin-bottom: 12px; }
.staff-login-card input:focus { outline: none; border-color: var(--primary); }
.staff-err { color: #dc2626; font-size: 0.85rem; margin-bottom: 12px; }
.staff-login-actions { display: flex; gap: 8px; }
.staff-login-actions .btn-primary { flex: 1; }
.pf-mode-tabs { display: flex; gap: 6px; margin-bottom: 12px; }
.pf-mode { padding: 8px 16px; border-radius: 8px; background: var(--border); color: var(--gray); font-weight: 600; font-size: 0.85rem; }
.pf-mode.active { background: var(--dark); color: white; }
.pf-mode:disabled { opacity: 0.4; cursor: not-allowed; }
.ratebook-row { display: grid; grid-template-columns: 70px 1fr 70px 50px 70px; gap: 4px; align-items: center; padding: 8px; border-bottom: 1px solid var(--border); font-size: 0.82rem; }
.ratebook-row:hover { background: #f9fafb; }
.rb-code { font-family: monospace; color: var(--gray); font-size: 0.75rem; }
.rb-desc { font-size: 0.82rem; }
.rb-unit { color: var(--gray); font-size: 0.75rem; }
.rb-price { font-weight: 700; color: var(--primary); font-size: 0.8rem; text-align: right; }

.admin-body .pf-builder { min-width: 0; max-width: 100%; }
.gadget-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); gap: 14px; }
.gadget { background: white; border-radius: 12px; padding: 18px; text-align: left; box-shadow: 0 1px 4px rgba(0,0,0,0.06); border: 2px solid transparent; display: flex; flex-direction: column; gap: 4px; transition: transform 0.15s, border-color 0.15s; }
.gadget:hover { transform: translateY(-2px); border-color: var(--primary); }
.gadget-icon { font-size: 1.8rem; line-height: 1; }
.gadget-title { font-weight: 800; font-size: 1rem; color: var(--dark); }
.gadget-sub { font-size: 0.78rem; color: var(--gray); }
.gadget-count { margin-top: 8px; font-size: 1.6rem; font-weight: 800; color: var(--primary-dark); line-height: 1; }
.gadget-count small { font-size: 0.72rem; font-weight: 600; color: var(--gray); margin-left: 6px; }
.pf-steps { display: flex; gap: 6px; margin-bottom: 16px; flex-wrap: wrap; }
.pf-step { padding: 6px 14px; border-radius: 50px; background: var(--border); color: var(--gray); font-size: 0.8rem; font-weight: 700; }
.pf-step.active { background: var(--dark); color: white; }
.pf-step.done { background: #d1fae5; color: #065f46; }
.pf-locked { background: #f3f4f6 !important; color: var(--gray); }
.pf-pick-filters { display: grid; grid-template-columns: 2fr 1fr; gap: 10px; }
@media (max-width: 600px) { .pf-pick-filters { grid-template-columns: 1fr; } }
.pf-pick-list { border: 1px solid var(--border); border-radius: 8px; max-height: 320px; overflow-y: auto; margin-bottom: 10px; }
.pf-pick-row { display: grid; grid-template-columns: 70px 1fr 56px 90px 70px; gap: 6px; align-items: center; padding: 8px; border-bottom: 1px solid var(--border); font-size: 0.82rem; }
.pf-pick-row:hover { background: #f9fafb; }
@media (max-width: 600px) { .pf-pick-row { grid-template-columns: 1fr 70px; } .pf-pick-row .rb-code, .pf-pick-row .rb-unit { display: none; } }


/* --- Catalog admin: image row --- */
.admin-image-row {
  display: flex;
  gap: 14px;
  align-items: flex-start;
  margin: 12px 0;
  flex-wrap: wrap;
}
.admin-image-preview {
  width: 120px;
  height: 120px;
  border-radius: 10px;
  background: #f3f4f6;
  border: 1px dashed var(--border);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  flex: 0 0 auto;
}
.admin-image-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.admin-image-empty {
  font-size: 0.75rem;
  color: var(--gray);
  text-align: center;
  padding: 0 6px;
}
.admin-image-controls {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
  min-width: 220px;
}END
cat > src/components/Catalog.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { getProductImageURL } from '../data/images.js';

export function Catalog({ cart, setCart, onRequest }) {
  const [data, lang] = useStore();
  const [active, setActive] = useState('all');
  const [urls, setUrls] = useState({});   // productId -> blob URL

  // Load object URLs for any product that has an imageId
  useEffect(() => {
    let alive = true;
    (async () => {
      const next = {};
      for (const p of data.products) {
        if (!p.imageId) continue;
        const url = await getProductImageURL(p.imageId);
        if (url) next[p.id] = url;
      }
      if (alive) setUrls(next);
    })();
    return () => { alive = false; };
  }, [data.products.map(p => p.imageId || '').join('|')]);

  const list = active === 'all'
    ? data.products
    : data.products.filter(p => p.category === active);

  const inCart = (id) => cart.find(c => c.sku === id);
  const add = (p) => {
    const existing = inCart(p.id);
    if (existing) setCart(cart.map(c => c.sku === p.id ? Object.assign({}, c, { qty: c.qty + 1 }) : c));
    else setCart([...cart, { sku: p.id, name: p.name, unit: p.unit, qty: 1 }]);
  };
  const remove = (id) => setCart(cart.filter(c => c.sku !== id));
  const setQty = (id, q) => setCart(cart.map(c => c.sku === id ? Object.assign({}, c, { qty: Math.max(1, +q || 1) }) : c));

  return (
    <section class="section" id="catalog">
      <div class="container">
        <div class="section-header">
          <h2>{lang === 'am' ? 'የቁሳቁስ ዝርዝር' : 'Materials Catalog'}</h2>
          <p>{lang === 'am' ? 'የሚፈልጉትን ይምረጡ እና ዋጋ ይጠይቁ።' : 'Select items and request a quote.'}</p>
        </div>

        <div class="filters">
          <button
            class={'filter-btn ' + (active === 'all' ? 'active' : '')}
            onClick={() => setActive('all')}
          >
            {lang === 'am' ? 'ሁሉም' : 'All'}
          </button>
          {data.categories.map(c => (
            <button
              class={'filter-btn ' + (active === c.id ? 'active' : '')}
              onClick={() => setActive(c.id)}
            >
              {c.icon} {lang === 'am' ? c.nameAm : c.name}
            </button>
          ))}
        </div>

        <div class="catalog-grid">
          {list.map(p => {
            const added = inCart(p.id);
            const cat = data.categories.find(c => c.id === p.category);
            const url = urls[p.id];
            return (
              <div class="product-card">
                <div class="product-img">
                  <span class="product-cat">
                    {cat ? (lang === 'am' ? cat.nameAm : cat.name) : p.category}
                  </span>

                  {url ? (
                    <img
                      src={url}
                      alt={p.name}
                      class="product-photo"
                      loading="lazy"
                      onError={(e) => {
                        e.currentTarget.style.display = 'none';
                        const fb = e.currentTarget.nextElementSibling;
                        if (fb) fb.style.display = 'flex';
                      }}
                    />
                  ) : null}

                  <span
                    class="product-icon"
                    style={url ? { display: 'none' } : { display: 'flex' }}
                  >
                    {cat ? cat.icon : '📦'}
                  </span>
                </div>

                <div class="product-info">
                  <h3>{p.name}</h3>
                  <div class="product-meta">
                    <span>per {p.unit}</span>
                    <span>Stock: {p.stock}</span>
                  </div>
                  <div class="product-actions">
                    {added ? (
                      <>
                        <input
                          type="number"
                          min="1"
                          value={added.qty}
                          onInput={e => setQty(p.id, e.target.value)}
                        />
                        <button class="btn-add-cart" onClick={() => remove(p.id)}>Remove</button>
                      </>
                    ) : (
                      <button
                        class="btn-add-cart"
                        style="width:100%;"
                        onClick={() => add(p)}
                      >
                        + {lang === 'am' ? 'ወደ ዝርዝር ጨምር' : 'Add to Request List'}
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {cart.length > 0 && (
          <div class="cart-summary">
            <strong>{cart.length} item{cart.length > 1 ? 's' : ''}</strong> in your request list
            <button class="btn btn-primary" style="margin-left: 12px;" onClick={onRequest}>
              Continue to Request →
            </button>
          </div>
        )}
      </div>
    </section>
  );
}END
cat > src/components/Footer.jsx << 'END'
import { useStore } from '../data/store.js';
export function Footer() {
  const [data, lang] = useStore();
  const b = data.business;
  return (
    <footer><div class="container">
      <div class="logo" style="font-size:1.4rem;">Mesay <span>Abebe</span></div>
      <div class="license">{b.fieldOfBusiness} Â· License {b.businessLicenseNo} Â· TIN {b.tin}</div>
      <div class="foot-links">
        <a href="#services">{lang === 'am' ? 'áŠ áŒˆáˆáŒáˆŽá‰¶á‰½' : 'Services'}</a>
        <a href="#projects">{lang === 'am' ? 'á•áˆ®áŒ€áŠ­á‰¶á‰½' : 'Projects'}</a>
        <a href="#catalog">{lang === 'am' ? 'á‰áˆ³á‰áˆ¶á‰½' : 'Materials'}</a>
        <a href={'tel:' + b.cell1.replace(/\s/g, '')}>{b.cell1}</a>
        <a href={'mailto:' + b.email}>{b.email}</a>
      </div>
      <p>{b.addressEn}</p>
      <p style="margin-top:4px;font-size:0.76rem;">Issued by {b.bureau} Â· Renewal {b.renewalDate} Â· Capital {b.capital}</p>
      <p style="margin-top:8px;">Â© 2024 {b.nameEn}. All rights reserved.</p>
    </div></footer>
  );
}
END
cat > src/components/Hero.jsx << 'END'
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
END
cat > src/components/LoginModal.jsx << 'END'
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
END
cat > src/components/Nav.jsx << 'END'
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
END
cat > src/components/ProformaBuilder.jsx << 'END'
import { useState, useEffect, useMemo } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { getRateCategories, getRateItems } from '../data/ratebook.js';
import { saveProforma, getProformas } from '../data/proformas.js';
import { calcLineFromRate, calcProforma, nextProformaNumber, addDays, formatMoney } from '../data/pricing.js';
import { egpAddItems } from '../data/egp.js';

const EMPTY_CLIENT = { name: '', phone: '', email: '', company: '', projectName: '', siteAddress: '', zone: 'addis' };
const STEP_LABELS = ['Client', 'Items', 'Proforma'];

const redo = (l, qty, price) => calcLineFromRate(
  { id: l.sku, description: l.name, unit: l.unit, code: l.code || '', basePrice: l.basePrice, contractorPrice: l.contractorPrice },
  qty, price
);

export function ProformaBuilder({ mode, request, onClose, onSaved }) {
  const [data] = useStore();
  const b = data.business;
  const fromRequest = mode === 'from-request';
  const fromTender = mode === 'from-tender';

  const [step, setStep] = useState(1);
  const [editing, setEditing] = useState(!fromRequest);
  const [client, setClient] = useState(() => {
    if (fromRequest && request) return Object.assign({}, EMPTY_CLIENT, request.client);
    if (fromTender && request) {
      const li = request.detail || {};
      const addr = li.address || {};
      return Object.assign({}, EMPTY_CLIENT, {
        name: li.procuring_entity || request.tender?.procuringEntity || '',
        company: li.procuring_entity || '',
        email: addr.email || '',
        phone: [addr.telephone?.code, addr.telephone?.number].filter(Boolean).join(' '),
        projectName: li.name || request.tender?.lotName || '',
        siteAddress: [addr.town, addr.street].filter(Boolean).join(', '),
      });
    }
    return Object.assign({}, EMPTY_CLIENT);
  });
  const [lines, setLines] = useState(() => {
    if (fromTender && request && Array.isArray(request.items)) {
      return request.items.map((it, i) => ({
        sku: it.lotItemId || ('tender_' + i),
        name: it.description,
        code: '',
        unit: it.unit,
        qty: it.qty,
        basePrice: 0,
        contractorPrice: it.rate || 0,
        lineTotal: (it.rate || 0) * it.qty,
        margin: 0,
        taxable: true,
        leadTimeDays: 0,
        source: 'tender',
      }));
    }
    return [];
  });
  const [cats, setCats] = useState([]);
  const [items, setItems] = useState([]);
  const [search, setSearch] = useState('');
  const [cat, setCat] = useState('all');
  const [discountPct, setDiscountPct] = useState(0);
  const [markupPct, setMarkupPct] = useState(b.markupPct || 0);
  const [contingencyPct, setContingencyPct] = useState(b.contingencyPct || 0);
  const [validDays, setValidDays] = useState(b.validDays || 30);
  const [terms, setTerms] = useState(b.defaultTerms || '');
  const [number, setNumber] = useState('');
  const [pfId] = useState(() => 'pf_' + Math.random().toString(36).slice(2, 9));
  const [today] = useState(() => new Date().toISOString().slice(0, 10));
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [pushMsg, setPushMsg] = useState('');

  useEffect(() => {
    (async () => {
      try {
        setCats(await getRateCategories());
        setItems(await getRateItems());
        setNumber(nextProformaNumber(await getProformas()));
      } catch (e) { console.error('Proforma builder load failed:', e); }
    })();
  }, []);

  const setC = (k, v) => setClient(Object.assign({}, client, { [k]: v }));
  const locked = !editing;

  const results = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter(i =>
      (cat === 'all' || i.categoryId === cat) &&
      (!q || String(i.code).toLowerCase().includes(q) || String(i.description).toLowerCase().includes(q))
    );
  }, [items, search, cat]);

  const addLine = (item) => {
    const existing = lines.find(l => l.sku === item.id);
    if (existing) setLines(lines.map(l => l.sku === item.id ? redo(l, l.qty + 1, l.contractorPrice) : l));
    else setLines([...lines, calcLineFromRate(item, 1)]);
  };
  const setQty = (sku, v) => setLines(lines.map(l => l.sku === sku ? redo(l, Math.max(0, parseFloat(v) || 0), l.contractorPrice) : l));
  const setRate = (sku, v) => setLines(lines.map(l => l.sku === sku ? redo(l, l.qty, Math.max(0, parseFloat(v) || 0)) : l));
  const removeLine = (sku) => setLines(lines.filter(l => l.sku !== sku));

  const totals = calcProforma({
    lines,
    freightZone: client.zone,
    zones: data.freight.zones,
    discountPct: parseFloat(discountPct) || 0,
    vatRate: b.vatRate || 0,
    markupPct: parseFloat(markupPct) || 0,
    contingencyPct: parseFloat(contingencyPct) || 0
  });

  const days = parseInt(validDays, 10) || 0;
  const pf = {
    id: pfId,
    number,
    createdAt: today,
    validDays: days,
    validUntil: addDays(today, days),
    status: 'draft',
    mode,
    sourceRequestId: request && request.id ? request.id : null,
    sourceTenderId: fromTender && request?.tender ? request.tender.id : null,
    quotationRequestId: fromTender && request
      ? (request.detail?.quotationRequestId || request.detail?.quatationRequestId || request.tender?.id || null)
      : null,
    client,
    lines,
    freightZone: client.zone,
    discountPct: parseFloat(discountPct) || 0,
    markupPct: parseFloat(markupPct) || 0,
    contingencyPct: parseFloat(contingencyPct) || 0,
    vatRate: b.vatRate || 0,
    totals,
    terms
  };

  const save = async () => {
    setBusy(true); setErr('');
    try {
      await saveProforma(pf);
      setSaved(true);
      if (onSaved) onSaved(pf);
    } catch (e) { setErr('Could not save: ' + (e.message || e)); }
    setBusy(false);
  };

  const canNext1 = client.name.trim() !== '';
  const canNext2 = lines.length > 0;
  const lockCls = locked ? 'pf-locked' : '';

  return (
    <div class="pf-builder pf-wizard">
      <div class="no-print">
        <div class="admin-panel-head">
          <h2>{fromRequest ? 'Proforma from request' : (fromTender ? 'Proforma from tender' : 'Internal proforma')}</h2>
          <button class="btn btn-back" onClick={onClose}>{saved ? 'Done' : 'Cancel'}</button>
        </div>
        <div class="pf-steps">
          {STEP_LABELS.map((l, i) => (
            <span key={l} class={'pf-step ' + (step === i + 1 ? 'active ' : '') + (step > i + 1 ? 'done' : '')}>{i + 1}. {l}</span>
          ))}
        </div>
      </div>

      {step === 1 && (
        <div>
          <div class="admin-panel-head">
            <h3>Client details</h3>
            {fromRequest && (
              <button type="button" class="btn btn-back" onClick={() => setEditing(!editing)}>{editing ? 'Lock details' : 'Edit details'}</button>
            )}
          </div>
          {fromRequest && !request && <div class="admin-msg">No request attached.</div>}
          {fromTender && !request && <div class="admin-msg">No tender attached.</div>}
          <div class="pf-grid">
            <label>Full name *<input class={lockCls} readOnly={locked} value={client.name} onInput={e => setC('name', e.target.value)} /></label>
            <label>Phone<input class={lockCls} readOnly={locked} value={client.phone} onInput={e => setC('phone', e.target.value)} /></label>
            <label>Email<input class={lockCls} readOnly={locked} value={client.email} onInput={e => setC('email', e.target.value)} /></label>
            <label>Company<input class={lockCls} readOnly={locked} value={client.company} onInput={e => setC('company', e.target.value)} /></label>
            <label>Project name<input class={lockCls} readOnly={locked} value={client.projectName} onInput={e => setC('projectName', e.target.value)} /></label>
            <label>Site address<input class={lockCls} readOnly={locked} value={client.siteAddress} onInput={e => setC('siteAddress', e.target.value)} /></label>
            <label>Delivery zone
              <select class={lockCls} disabled={locked} value={client.zone} onChange={e => setC('zone', e.target.value)}>
                {data.freight.zones.map(z => <option value={z.id}>{z.name}</option>)}
              </select>
            </label>
          </div>
          <div class="pf-actions">
            <button class="btn btn-primary" disabled={!canNext1} onClick={() => setStep(2)}>Next: Items</button>
          </div>
        </div>
      )}

      {step === 2 && (
        <div>
          {!fromTender && (
            <>
              <h3>Pick items from the rate book</h3>
              <div class="pf-pick-filters">
                <input placeholder="Search code or description" value={search} onInput={e => setSearch(e.target.value)} />
                <select value={cat} onChange={e => setCat(e.target.value)}>
                  <option value="all">All categories</option>
                  {cats.map(c => <option value={c.id}>{c.id}. {c.title}</option>)}
                </select>
              </div>
              {items.length === 0 ? (
                <p style="color:var(--gray);font-size:0.9rem;">The rate book is empty. Import it from the Rate Book tab first.</p>
              ) : (
                <div class="pf-pick-list">
                  {results.slice(0, 60).map(i => (
                    <div class="pf-pick-row" key={i.id}>
                      <span class="rb-code">{i.code}</span>
                      <span class="rb-desc">{i.description}</span>
                      <span class="rb-unit">{i.unit}</span>
                      <span class="rb-price">{i.contractorPrice == null ? '-' : formatMoney(i.contractorPrice)}</span>
                      <button type="button" class="btn-add" onClick={() => addLine(i)}>+ Add</button>
                    </div>
                  ))}
                  {results.length === 0 && <div class="pf-pick-row">No matching items.</div>}
                </div>
              )}
              {results.length > 60 && <p style="font-size:0.78rem;color:var(--gray);">Showing the first 60 of {results.length} matches.</p>}
            </>
          )}

          <h3>Selected items ({lines.length})</h3>
          {lines.length === 0 ? <p style="color:var(--gray);font-size:0.9rem;">No items yet.</p> : (
            <table class="pf-table">
              <thead><tr><th>Code</th><th>Description</th><th>Unit</th><th>Qty</th><th>Rate</th><th>Amount</th><th></th></tr></thead>
              <tbody>
                {lines.map(l => (
                  <tr key={l.sku}>
                    <td>{l.code}</td>
                    <td>{l.name}</td>
                    <td>{l.unit}</td>
                    <td><input type="number" min="0" step="any" value={l.qty} onInput={e => setQty(l.sku, e.target.value)} /></td>
                    <td><input type="number" min="0" step="any" value={l.contractorPrice} onInput={e => setRate(l.sku, e.target.value)} /></td>
                    <td>{formatMoney(l.lineTotal)}</td>
                    <td><button type="button" class="btn-del" onClick={() => removeLine(l.sku)}>X</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => setStep(1)}>Back</button>
            <button class="btn btn-primary" disabled={!canNext2} onClick={() => setStep(3)}>Next: Proforma</button>
          </div>
        </div>
      )}

      {step === 3 && (
        <div>
          <div class="no-print">
            <h3>Terms and charges</h3>
            <div class="pf-grid">
              <label>Delivery zone
                <select value={client.zone} disabled={saved} onChange={e => setC('zone', e.target.value)}>
                  {data.freight.zones.map(z => <option value={z.id}>{z.name}</option>)}
                </select>
              </label>
              <label>Discount %<input type="number" min="0" step="any" disabled={saved} value={discountPct} onInput={e => setDiscountPct(e.target.value)} /></label>
              <label>Markup %<input type="number" min="0" step="any" disabled={saved} value={markupPct} onInput={e => setMarkupPct(e.target.value)} /></label>
              <label>Contingency %<input type="number" min="0" step="any" disabled={saved} value={contingencyPct} onInput={e => setContingencyPct(e.target.value)} /></label>
              <label>Valid for (days)<input type="number" min="0" disabled={saved} value={validDays} onInput={e => setValidDays(e.target.value)} /></label>
            </div>
            <textarea rows="3" placeholder="Terms" disabled={saved} value={terms} onInput={e => setTerms(e.target.value)} />
          </div>

          <ProformaDoc pf={pf} />

          {err && <div class="staff-err">{err}</div>}
          {pushMsg && <div class="admin-msg">{pushMsg}</div>}
          <div class="pf-actions no-print">
            {!saved && <button class="btn btn-back" onClick={() => setStep(2)}>Back</button>}
            {!saved && <button class="btn btn-primary" disabled={busy || !number} onClick={save}>{busy ? 'Saving...' : 'Save Proforma'}</button>}
            {saved && <div class="admin-msg" style="flex:1;margin:0;">Saved as {number}</div>}
            {saved && <button class="btn btn-back" onClick={() => window.print()}>Print</button>}
            {saved && fromTender && request?.tender?.sourceApplication === 'Purchasing' && (
              <button class="btn-add" onClick={async () => {
                setPushMsg('');
                const qrid = request.detail?.quotationRequestId || request.detail?.quatationRequestId || request.tender.id;
                const resp = await fetch(`/api/egp/tender/${qrid}/response`).then(r => r.json()).catch(() => null);
                if (!resp?.id) { setPushMsg('Register on eGP first (Tenders tab).'); return; }
                const itemsToPush = lines.filter(l => l.contractorPrice > 0).map(l => ({
                  lotItemId: l.sku, name: l.name, description: l.name,
                  quantity: l.qty, unitMeasure: l.unit,
                }));
                const r = await egpAddItems(resp.id, itemsToPush);
                setPushMsg(r.ok ? `Pushed ${itemsToPush.length} items to eGP.` : 'Push failed: ' + JSON.stringify(r.data));
              }}>Push prices to eGP</button>
            )}
            {saved && <button class="btn btn-primary" onClick={onClose}>Done</button>}
          </div>
        </div>
      )}
    </div>
  );
}

export function ProformaDoc({ pf }) {
  const [data] = useStore();
  const b = data.business;
  const c = pf.client || {};
  const t = pf.totals || {};
  const lines = pf.lines || [];
  const zone = (data.freight.zones.find(z => z.id === pf.freightZone) || {}).name;

  return (
    <div class="pf-doc">
      <div class="pf-doc-header">
        <div>
          <h1>{b.nameEn}</h1>
          <p>{b.addressEn}</p>
          <p>{b.cell1} · {b.cell2} · {b.email}</p>
          <p>TIN {b.tin} · License {b.businessLicenseNo}</p>
        </div>
        <div class="pf-doc-meta">
          <h2>PROFORMA</h2>
          <strong>{pf.number}</strong>
          <p>Date: {pf.createdAt}</p>
          <p>Valid until: {pf.validUntil}</p>
        </div>
      </div>

      <div class="pf-doc-client">
        <div>
          <strong>Client</strong>
          <p>{c.name}</p>
          {c.company && <p>{c.company}</p>}
          {c.phone && <p>{c.phone}</p>}
          {c.email && <p>{c.email}</p>}
        </div>
        <div>
          <strong>Project</strong>
          {c.projectName && <p>{c.projectName}</p>}
          {c.siteAddress && <p>{c.siteAddress}</p>}
          {zone && <p>Delivery: {zone}</p>}
        </div>
      </div>

      <table class="pf-table pf-doc-table">
        <thead><tr><th>#</th><th>Code</th><th>Description</th><th>Unit</th><th>Qty</th><th>Rate</th><th>Amount</th></tr></thead>
        <tbody>
          {lines.map((l, i) => (
            <tr key={l.sku}>
              <td>{i + 1}</td><td>{l.code}</td><td>{l.name}</td><td>{l.unit}</td><td>{l.qty}</td>
              <td>{formatMoney(l.contractorPrice)}</td><td>{formatMoney(l.lineTotal)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div class="pf-doc-totals">
        <div><span>Subtotal</span><span>{formatMoney(t.subtotal)}</span></div>
        {t.markup > 0 && <div><span>Markup ({pf.markupPct}%)</span><span>{formatMoney(t.markup)}</span></div>}
        {t.contingency > 0 && <div><span>Contingency ({pf.contingencyPct}%)</span><span>{formatMoney(t.contingency)}</span></div>}
        {t.discount > 0 && <div><span>Discount ({pf.discountPct}%)</span><span>- {formatMoney(t.discount)}</span></div>}
        <div><span>Freight</span><span>{formatMoney(t.freight)}</span></div>
        <div><span>VAT ({Math.round((pf.vatRate || 0) * 100)}%)</span><span>{formatMoney(t.vat)}</span></div>
        <div class="pf-grand"><span>Grand Total</span><span>{formatMoney(t.grandTotal)}</span></div>
      </div>

      <div class="pf-doc-terms">
        <strong>Terms</strong>
        <p>{pf.terms}</p>
        <p style="margin-top:8px;">{b.disclaimer}</p>
      </div>

      <div class="pf-doc-sign">
        <span>Prepared by: ____________________</span>
        <span>Client acceptance: ____________________</span>
      </div>
    </div>
  );
}END
cat > src/components/ProjectModal.jsx << 'END'
export function ProjectModal({ project, onClose, onRequest }) {
  if (!project) return null;
  return (
    <div class="modal-overlay" onClick={onClose}>
      <div class="modal" onClick={e => e.stopPropagation()}>
        <button class="modal-close" onClick={onClose}>âœ•</button>
        <h2>{project.title}</h2>
        <p style="color: var(--gray); font-size: 0.9rem;">{project.desc}</p>
        <div class="modal-meta">
          <span><strong>Type:</strong> {project.type}</span>
          <span><strong>Budget:</strong> {project.budget}</span>
          <span><strong>Duration:</strong> {project.duration}</span>
          <span><strong>Year:</strong> {project.year}</span>
          <span><strong>Client:</strong> {project.client}</span>
        </div>
        <a href="#request-services" onClick={(e) => { e.preventDefault(); onClose(); if (onRequest) onRequest('services'); }} class="btn btn-primary" style="display:block;text-align:center;margin-top:14px;">Request Similar Project</a>
      </div>
    </div>
  );
}
END
cat > src/components/Projects.jsx << 'END'
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
END
cat > src/components/RequestMaterials.jsx << 'END'
import { useState } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { saveRequest, newRequestId } from '../data/requests.js';
import { pushRequest } from '../data/remote.js';

export function RequestMaterials({ cart, setCart, onClose, user }) {
  const [data, lang] = useStore();
  const [client, setClient] = useState({ name: '', phone: '', email: '', company: '', projectName: '', siteAddress: '', zone: 'addis', requiredBy: '', notes: '' });
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const set = (k, v) => setClient(Object.assign({}, client, { [k]: v }));

  const submit = async () => {
    if (!client.name || !client.phone || cart.length === 0) return;
    setBusy(true);
    const req = { id: newRequestId(), kind: 'materials', createdAt: new Date().toISOString(), status: 'new', client: Object.assign({}, client), cart: cart.slice(), userId: user ? user.id : null, userEmail: user ? user.email : null };
    await saveRequest(req);
    pushRequest(req);
    setBusy(false); setDone(true); setCart([]);
  };

  return (
    <section class="section alt" id="request-materials">
      <div class="container">
        <div class="section-header" style="position:relative;">
          <button
            type="button"
            class="form-close"
            onClick={onClose}
            aria-label="Close"
          >âœ•</button>
          <h2>{lang === 'am' ? 'á‹¨á‰áˆ³á‰áˆµ á‹‹áŒ‹ áŒ á‹­á‰…' : 'Request Materials Quote'}</h2>
          <p>Send us your list.</p>
        </div>

        {done ? (
          <div class="wizard" style="text-align:center;">
            <div class="wizard-success">
              <div class="check">âœ“</div>
              <h2>Request Received!</h2>
              <p style="color: var(--gray); margin-top: 8px;">
                Thanks {client.name}! Our staff will send you a formal quote within 24 hours.
              </p>
              <button class="btn btn-primary" style="margin-top:16px;" onClick={onClose}>
                Close
              </button>
            </div>
          </div>
        ) : (
          <div class="pf-builder">
            <h3>Your List ({cart.length} items)</h3>
            {cart.length === 0 ? (
              <p style="color: var(--gray); font-size:0.9rem;">
                Your list is empty. <a href="#catalog" style="color:var(--primary);" onClick={onClose}>Browse the catalog â†’</a>
              </p>
            ) : (
              <table class="pf-table">
                <thead><tr><th>Item</th><th>Qty</th><th>Unit</th><th></th></tr></thead>
                <tbody>
                  {cart.map(l => (
                    <tr>
                      <td>{l.name}</td>
                      <td><input type="number" min="1" value={l.qty} onInput={e => setCart(cart.map(c => c.sku === l.sku ? Object.assign({}, c, { qty: Math.max(1, +e.target.value || 1) }) : c))} /></td>
                      <td>{l.unit}</td>
                      <td><button class="btn-del" onClick={() => setCart(cart.filter(c => c.sku !== l.sku))}>âœ•</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            <h3>Your Details</h3>
            <div class="pf-grid">
              <input placeholder="Full name *" value={client.name} onInput={e => set('name', e.target.value)} />
              <input placeholder="Phone *" value={client.phone} onInput={e => set('phone', e.target.value)} />
              <input placeholder="Email" value={client.email} onInput={e => set('email', e.target.value)} />
              <input placeholder="Company" value={client.company} onInput={e => set('company', e.target.value)} />
              <input placeholder="Project name" value={client.projectName} onInput={e => set('projectName', e.target.value)} />
              <input placeholder="Site address" value={client.siteAddress} onInput={e => set('siteAddress', e.target.value)} />
              <select value={client.zone} onChange={e => set('zone', e.target.value)}>
                {data.freight.zones.map(z => <option value={z.id}>{z.name}</option>)}
              </select>
              <input type="date" value={client.requiredBy} onInput={e => set('requiredBy', e.target.value)} />
            </div>

            <textarea rows="3" placeholder="Additional notes" value={client.notes} onInput={e => set('notes', e.target.value)} />

            <div class="pf-actions">
              <button class="btn btn-primary" disabled={busy || !client.name || !client.phone || cart.length === 0} onClick={submit}>
                {busy ? 'Sending...' : (lang === 'am' ? 'áŒ¥á‹«á‰„ áˆ‹áŠ­' : 'Submit Request')}
              </button>
              <button type="button" class="btn btn-back" onClick={onClose}>Cancel</button>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
END
cat > src/components/RequestServices.jsx << 'END'
import { useState } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { saveRequest, newRequestId } from '../data/requests.js';
import { pushRequest } from '../data/remote.js';

export function RequestServices({ onClose, user }) {
  const [data, lang] = useStore();
  const [form, setForm] = useState({ serviceType: 'sv1', name: '', phone: '', email: '', company: '', projectName: '', siteAddress: '', description: '', budgetRange: '', timeline: 'planning' });
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const set = (k, v) => setForm(Object.assign({}, form, { [k]: v }));

  const submit = async () => {
    if (!form.name || !form.phone || !form.description) return;
    setBusy(true);
    const req = {
      id: newRequestId(),
      kind: 'services',
      createdAt: new Date().toISOString(),
      status: 'new',
      client: { name: form.name, phone: form.phone, email: form.email, company: form.company, projectName: form.projectName, siteAddress: form.siteAddress },
      serviceType: form.serviceType,
      description: form.description,
      budgetRange: form.budgetRange,
      timeline: form.timeline,
      userId: user ? user.id : null,
      userEmail: user ? user.email : null
    };
    await saveRequest(req);
    pushRequest(req);
    setBusy(false); setDone(true);
  };

  return (
    <section class="section" id="request-services">
      <div class="container">
        <div class="section-header" style="position:relative;">
          <button type="button" class="form-close" onClick={onClose} aria-label="Close">âœ•</button>
          <h2>{lang === 'am' ? 'á‹¨áŠ áŒˆáˆáŒáˆŽá‰µ á‹‹áŒ‹ áŒ á‹­á‰…' : 'Request Service Quote'}</h2>
          <p>Tell us about your project.</p>
        </div>

        {done ? (
          <div class="wizard" style="text-align:center;">
            <div class="wizard-success">
              <div class="check">âœ“</div>
              <h2>Request Received!</h2>
              <p style="color: var(--gray); margin-top: 8px;">
                Thanks {form.name}! Our estimating team will be in touch.
              </p>
              <button class="btn btn-primary" style="margin-top:16px;" onClick={onClose}>Close</button>
            </div>
          </div>
        ) : (
          <div class="pf-builder">
            <h3>Project Type</h3>
            <div class="wizard-options">
              {data.services.map(s => (
                <button
                  class={'wizard-option ' + (form.serviceType === s.id ? 'selected' : '')}
                  onClick={() => set('serviceType', s.id)}
                >
                  {s.icon} {lang === 'am' ? s.titleAm : s.titleEn}
                </button>
              ))}
            </div>

            <h3>Your Details</h3>
            <div class="pf-grid">
              <input placeholder="Full name *" value={form.name} onInput={e => set('name', e.target.value)} />
              <input placeholder="Phone *" value={form.phone} onInput={e => set('phone', e.target.value)} />
              <input placeholder="Email" value={form.email} onInput={e => set('email', e.target.value)} />
              <input placeholder="Company" value={form.company} onInput={e => set('company', e.target.value)} />
              <input placeholder="Project name" value={form.projectName} onInput={e => set('projectName', e.target.value)} />
              <input placeholder="Site address" value={form.siteAddress} onInput={e => set('siteAddress', e.target.value)} />
              <select value={form.budgetRange} onChange={e => set('budgetRange', e.target.value)}>
                <option value="">Estimated budget (optional)</option>
                <option value="lt5m">Under ETB 5M</option>
                <option value="5-20m">ETB 5M â€“ 20M</option>
                <option value="20-100m">ETB 20M â€“ 100M</option>
                <option value="100m+">ETB 100M+</option>
              </select>
              <select value={form.timeline} onChange={e => set('timeline', e.target.value)}>
                <option value="planning">Just planning</option>
                <option value="3-6mo">3â€“6 months</option>
                <option value="1-3mo">1â€“3 months</option>
                <option value="asap">ASAP</option>
              </select>
            </div>

            <textarea rows="4" placeholder="Describe your project *" value={form.description} onInput={e => set('description', e.target.value)} />

            <div class="pf-actions">
              <button class="btn btn-primary" disabled={busy || !form.name || !form.phone || !form.description} onClick={submit}>
                {busy ? 'Sending...' : (lang === 'am' ? 'áŒ¥á‹«á‰„ áˆ‹áŠ­' : 'Submit Request')}
              </button>
              <button type="button" class="btn btn-back" onClick={onClose}>Cancel</button>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
END
cat > src/components/Reviews.jsx << 'END'
import { useState } from 'react';
import { useStore } from '../data/store.js';

// Before/after slider images, with SVG placeholders used when the real image is missing or fails to load
const BA_BEFORE_SRC = 'co/before-project.png';
const BA_AFTER_SRC = 'co/after-project.png';
const BA_BEFORE_PLACEHOLDER = 'co/before-placeholder.png';
const BA_AFTER_PLACEHOLDER = 'co/after-placeholder.png';
const baOnError = (placeholder) => (e) => {
  const img = e.currentTarget;
  if (img.getAttribute('src') !== placeholder) img.setAttribute('src', placeholder);
};

export function Reviews() {
  const [data, lang] = useStore();
  const [sliderPos, setSliderPos] = useState(50); // 50% default position

  return (
    <section class="section alt">
      <div class="container">
        
        {/* --- REVIEWS SECTION (Unchanged) --- */}
        <div class="section-header">
         <h2>{lang === 'am' ? 'የደንበኞች አስተያየት' : 'What Clients Say'}</h2>
         </div>
                <div class="reviews-grid">
          {data.reviews.map(r => (
            <div class="review-card" key={r.name}>
              <div class="review-stars">{'★'.repeat(r.stars)}</div>
              <p>"{r.text}"</p>
              <div class="review-author">{r.name}</div>
              <div class="review-loc">{r.loc}</div>
            </div>
          ))}
        </div>


        {/* --- BEFORE & AFTER SLIDER SECTION --- */}
        <div class="section-header" style={{ marginTop: '4rem' }}>
          
          <h2>{lang === 'am' ? 'የፕሮጀክት ለውጥ' : 'Project Transformations'}</h2>
          <p style={{ color: 'var(--text-muted, #666)', marginTop: '0.5rem' }}>
            {lang === 'am' ? 'በፊት እና በኋላ ያለውን ልዩነት ለማየት መስመሩን ይጎትቱ' : 'Drag the slider to see the before and after'}
          </p>
        </div>

        {/* Replace these with your actual image paths */}
        <div class="before-after-wrapper">
          {/* Before Image (Background) */}
          <img 
            src={BA_BEFORE_SRC || BA_BEFORE_PLACEHOLDER}
            onError={baOnError(BA_BEFORE_PLACEHOLDER)} 
            alt="Before Construction" 
            class="ba-image ba-before" 
          />
          
          {/* After Image (Foreground, clipped by slider) */}
          <div 
            class="ba-after-clip" 
            style={{ width: `${sliderPos}%` }}
          >
            <img 
              src={BA_AFTER_SRC || BA_AFTER_PLACEHOLDER}
              onError={baOnError(BA_AFTER_PLACEHOLDER)} 
              alt="After Construction" 
              class="ba-image ba-after" 
            />
          </div>

          {/* Draggable Slider Line & Handle */}
          <div class="ba-slider-line" style={{ left: `${sliderPos}%` }}>
            <div class="ba-slider-handle">
              <span>↔</span>
            </div>
          </div>

          {/* Invisible Range Input to control the slider */}
          <input 
            type="range" 
            min="0" 
            max="100" 
            value={sliderPos} 
            onChange={(e) => setSliderPos(e.target.value)} 
            class="ba-range-input"
            aria-label="Before and after slider"
          />
          
          {/* Labels */}
          <span class="ba-label ba-label-before">Before</span>
          <span class="ba-label ba-label-after">After</span>
        </div>

      </div>
    </section>
  );
}
END
cat > src/components/Services.jsx << 'END'
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
END
cat > src/components/TrustStats.jsx << 'END'
import { useStore } from '../data/store.js';
export function TrustStats() {
  const [data, lang] = useStore();
  return (
    <section class="section alt"><div class="container"><div class="trust-grid">
      {data.stats.map(s => (<div class="trust-item"><span class="num">{s.num}</span><span class="lbl">{lang === 'am' ? s.lblAm : s.lblEn}</span></div>))}
    </div></div></section>
  );
}
END
cat > src/data/business.js << 'END'
import { put, get, del, getAll } from './db.js';

// --- Business Info ---
export async function saveBusinessInfo(data) {
  return put('business_info', { key: 'business', data });
}

export async function getBusinessInfo() {
  const row = await get('business_info', 'business');
  return row ? row.data : null;
}

// --- Documents ---
export async function saveBusinessDoc(type, file) {
  if (!file) throw new Error('No file provided');
  return put('business_docs', { type, file, name: file.name, updatedAt: Date.now() });
}

export async function getBusinessDoc(type) {
  return get('business_docs', type);
}

export async function deleteBusinessDoc(type) {
  return del('business_docs', type);
}

export async function getAllBusinessDocs() {
  return getAll('business_docs');
}END
cat > src/data/db.js << 'END'
const DB_NAME = 'mesay_db';
const DB_VERSION = 5;
let _db = null;

export function openDB() {
  if (_db) return Promise.resolve(_db);
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (e) => {
      const db = e.target.result;

      if (!db.objectStoreNames.contains('ratebook_categories'))
        db.createObjectStore('ratebook_categories', { keyPath: 'id' });

      if (!db.objectStoreNames.contains('ratebook_items')) {
        const s = db.createObjectStore('ratebook_items', { keyPath: 'id' });
        s.createIndex('by-category', 'categoryId');
        s.createIndex('by-code', 'code');
      }

      if (!db.objectStoreNames.contains('quote_requests')) {
        const s = db.createObjectStore('quote_requests', { keyPath: 'id' });
        s.createIndex('by-status', 'status');
        s.createIndex('by-kind', 'kind');
      }

      if (!db.objectStoreNames.contains('proformas')) {
        const s = db.createObjectStore('proformas', { keyPath: 'id' });
        s.createIndex('by-number', 'number');
        s.createIndex('by-status', 'status');
      }

      if (!db.objectStoreNames.contains('meta'))
        db.createObjectStore('meta', { keyPath: 'key' });

      if (!db.objectStoreNames.contains('product_images'))
        db.createObjectStore('product_images', { keyPath: 'id' });

      if (!db.objectStoreNames.contains('egp_tenders')) {
        const s = db.createObjectStore('egp_tenders', { keyPath: 'id' });
        s.createIndex('by-deadline', 'submissionDeadline');
        s.createIndex('by-entity', 'procuringEntity');
        s.createIndex('by-fetched', 'fetchedAt');
      }
      if (!db.objectStoreNames.contains('egp_tender_details'))
        db.createObjectStore('egp_tender_details', { keyPath: 'lotId' });
      if (!db.objectStoreNames.contains('egp_tender_items'))
        db.createObjectStore('egp_tender_items', { keyPath: 'key' });

      // NEW: Business Info & Docs
      if (!db.objectStoreNames.contains('business_info'))
        db.createObjectStore('business_info', { keyPath: 'key' });
      if (!db.objectStoreNames.contains('business_docs'))
        db.createObjectStore('business_docs', { keyPath: 'type' });
    };
    req.onsuccess = () => { _db = req.result; resolve(_db); };
    req.onerror = () => reject(req.error);
  });
}

function tx(store, mode) {
  return openDB().then(db => db.transaction(store, mode).objectStore(store));
}

export function put(store, value) {
  return tx(store, 'readwrite').then(s => new Promise((res, rej) => {
    const r = s.put(value); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error);
  }));
}
export function putAll(store, values) {
  return openDB().then(db => new Promise((res, rej) => {
    const t = db.transaction(store, 'readwrite');
    const s = t.objectStore(store);
    values.forEach(v => s.put(v));
    t.oncomplete = () => res(values.length);
    t.onerror = () => rej(t.error);
  }));
}
export function get(store, id) {
  return tx(store, 'readonly').then(s => new Promise((res, rej) => {
    const r = s.get(id); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error);
  }));
}
export function getAll(store) {
  return tx(store, 'readonly').then(s => new Promise((res, rej) => {
    const r = s.getAll(); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error);
  }));
}
export function getAllBy(store, indexName, value) {
  return tx(store, 'readonly').then(s => new Promise((res, rej) => {
    const r = s.index(indexName).getAll(value); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error);
  }));
}
export function del(store, id) {
  return tx(store, 'readwrite').then(s => new Promise((res, rej) => {
    const r = s.delete(id); r.onsuccess = () => res(); r.onerror = () => rej(r.error);
  }));
}
export function clearStore(store) {
  return tx(store, 'readwrite').then(s => new Promise((res, rej) => {
    const r = s.clear(); r.onsuccess = () => res(); r.onerror = () => rej(r.error);
  }));
}END
cat > src/data/egp.js << 'END'
export async function egpStatus()  { return (await fetch('/api/egp/status')).json(); }
export async function egpLogin()   { return (await fetch('/api/egp/login', { method:'POST' })).json(); }

export async function fetchTenders({ search='Construction', top=15, skip=0, locale='en' } = {}) {
  const p = new URLSearchParams();
  p.set('type','all'); p.set('skip',skip); p.set('top',top);
  p.set('locale',locale); p.set('search',search);
  ['lotName','sourceApplication','lotReferenceNo','procurementReferenceNo']
    .forEach((f,i)=>p.set(`searchFrom[${i}]`, f));
  p.set('orderBy[0].field','invitationDate');
  p.set('orderBy[0].direction','desc');
  const r = await fetch('/api/egp/tenders?' + p.toString());
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchTenderDetail(tender) {
  const q = tender.sourceApplication === 'Purchasing' ? '?source=purchasing' : '';
  const r = await fetch(`/api/egp/tender/${tender.sourceId || tender.id}${q}`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchQuotationItems(quotationRequestId) {
  const r = await fetch(`/api/egp/tender/${quotationRequestId}/items`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchResponseItems(responseId) {
  const r = await fetch(`/api/egp/tender/${responseId}/response-items`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchSchedule(lotItemId) {
  const r = await fetch(`/api/egp/schedule/${lotItemId}`);
  if (!r.ok) throw new Error('eGP HTTP ' + r.status);
  return r.json();
}

export async function fetchQuotationResponse(quotationRequestId) {
  const r = await fetch(`/api/egp/tender/${quotationRequestId}/response`);
  if (!r.ok) return null;
  return r.json();
}

export async function egpRegister(quotationRequestId, quotationRequestName) {
  const r = await fetch('/api/egp/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ quotationRequestId, quotationRequestName }),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export async function egpPushPriceOne(payload) {
  const r = await fetch('/api/egp/push-price-one', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export async function egpPushSpecOne(payload) {
  const r = await fetch('/api/egp/push-spec-one', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

// Kept for compatibility, hits the deprecated route
export async function egpAddItems(quotationRequestResponseId, items) {
  const r = await fetch('/api/egp/add-items', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ quotationRequestResponseId, items }),
  });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export async function egpSubmit(responseId) {
  const r = await fetch(`/api/egp/submit/${responseId}`, { method: 'POST' });
  return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
}

export function normalizeTenderList(payload) {
  const out = [];
  for (const pkg of payload.items || []) {
    for (const lot of pkg.result || []) {
      const pi = lot.packageInformation || {};
      out.push({
        id: lot.id,
        sourceId: lot.sourceId || null,
        lotName: lot.lotName || pi.packageName || '',
        lotDescription: (lot.lotDescription || pi.packageDescription || '').trim(),
        lotReferenceNo: lot.lotReferenceNo || '',
        procurementReferenceNo: lot.procurementReferenceNo || '',
        procurementCategory: lot.procurementCategory || '',
        procuringEntity: pi.procuringEntity?.en || lot.procuringEntity || '',
        procuringEntityAm: pi.procuringEntity?.am || '',
        sourceApplication: lot.sourceApplication || '',
        marketPlace: lot.marketPlace || '',
        method: lot.method || '',
        submissionDeadline: lot.submissionDeadline || null,
        openingSchedule: lot.openingSchedule || null,
        invitationDate: lot.invitationDate || null,
        address: pi.address || {},
        classification: (lot.procurementClassification || [])
          .map(c => c.title?.en).filter(Boolean),
        origin: lot.origin || '',
        originName: lot.originName?.en || '',
        fetchedAt: Date.now(),
      });
    }
  }
  const seen = new Set();
  return out.filter(t => seen.has(t.id) ? false : (seen.add(t.id), true));
}

// Preserves both tender-level and response-level shapes.
export function normalizeItems(payload) {
  const arr = Array.isArray(payload) ? payload : (payload.items || []);
  return arr.map(it => {
    const rawId = it.id;
    const responseItemId = rawId && rawId !== '00000000-0000-0000-0000-000000000000' ? rawId : null;
    return {
      responseItemId,
      lotItemId: it.lotItemId || (responseItemId ? null : rawId) || null,
      name: it.name || '',
      description: (it.description || '').trim().replace(/\s+/g, ' '),
      unit: it.unitOfMeasure || it.unitMeasure || it.unit || '',
      qty: Number(it.revisedQuantity ?? it.originalQuantity ?? it.quantity ?? it.qty ?? 0),
      rate: Number(it.unitPrice) || 0,
    };
  });
}END
cat > src/data/goods-data.js << 'END'
export const GOODS = { 
  "source": "Table",
  "extractedAt": "2026-10-21T23:03:02.504Z",
  "pageCount": 13,
  "categories": [
    {
      "category": "ENERGY",
      "categoryAm": "ኃይል",
      "items": [
        {"no": 1, "item": "Benzene(Regular)- Gasoline *", "itemAm": "ቤንዚን (መደበኛ) - ነዳጅ *", "unit": "Lit.", "march2026": "142.41", "june2026": "167.50", "change": "+18%"},
        {"no": 2, "item": "Diesel *", "itemAm": "ናፍጣ *", "unit": "Lit.", "march2026": "163.09", "june2026": "180.46", "change": "+11%"}
      ]
    },
    {
      "category": "CEMENT, AGGREGATES & CONCRETE",
      "categoryAm": "ሲሚንቶ፣ ድምር እና ኮንክሪት",
      "items": [
        {"no": 3, "item": "Sika Ceram 105", "itemAm": "ሲካ ሴራም 105", "unit": "Kg", "march2026": "26.22", "june2026": "65.54", "change": "+150%"},
        {"no": 4, "item": "Eucalyptus Dia 6cm", "itemAm": "የባህር ዛፍ ዲያሜትር 6ሴንቲ ሜትር", "unit": "Pcs", "march2026": "96.13", "june2026": "174.78", "change": "+82%"},
        {"no": 5, "item": "Sika Seal-105", "itemAm": "ሲካ ሲል-105", "unit": "lit", "march2026": "174.78", "june2026": "284.02", "change": "+63%"},
        {"no": 6, "item": "C-50 OPC RMC", "itemAm": "C-50 OPC ዝግጁ ድብልቅ ኮንክሪት", "unit": "m3", "march2026": "15,175.50", "june2026": "23,145.59", "change": "+53%"},
        {"no": 7, "item": "C-40 OPC RMC", "itemAm": "C-40 OPC ዝግጁ ድብልቅ ኮንክሪት", "unit": "m3", "march2026": "13,969.50", "june2026": "21,306.00", "change": "+53%"},
        {"no": 8, "item": "Sika Latex for Bonding", "itemAm": "ሲካ ላቴክስ ለማጣበቅ", "unit": "lit", "march2026": "764.67", "june2026": "1,136.09", "change": "+49%"},
        {"no": 9, "item": "C-35 OPC RMC", "itemAm": "C-35 OPC ዝግጁ ድብልቅ ኮንክሪት", "unit": "m3", "march2026": "13,366.50", "june2026": "19,795.00", "change": "+48%"},
        {"no": 10, "item": "C-20 OPC RMC", "itemAm": "C-20 OPC ዝግጁ ድብልቅ ኮንክሪት", "unit": "m3", "march2026": "11,186.09", "june2026": "16,556.28", "change": "+48%"},
        {"no": 11, "item": "Derba", "itemAm": "ደርባ", "unit": "Qts", "march2026": "1,747.83", "june2026": "2,010.00", "change": "+15%"},
        {"no": 12, "item": "National", "itemAm": "ናሽናል", "unit": "Qts", "march2026": "1,835.22", "june2026": "2,010.00", "change": "+10%"},
        {"no": 13, "item": "Gravel 03", "itemAm": "ጠጠር 03", "unit": "m3", "march2026": "3,517.50", "june2026": "5,068.70", "change": "+44%"},
        {"no": 14, "item": "Gravel 00", "itemAm": "ጠጠር 00", "unit": "m3", "march2026": "3,819.00", "june2026": "5,505.65", "change": "+44%"},
        {"no": 15, "item": "C-25 OPC RMC", "itemAm": "C-25 OPC ዝግጁ ድብልቅ ኮንክሪት", "unit": "m3", "march2026": "12,562.50", "june2026": "18,592.50", "change": "+48%"},
        {"no": 16, "item": "Redash", "itemAm": "ቀይ አመድ (ሬዳሽ)", "unit": "m3", "march2026": "419.48", "june2026": "436.96", "change": "+4%"},
        {"no": 17, "item": "Stone Trachethic", "itemAm": "የትራኪቲክ ድንጋይ", "unit": "m3", "march2026": "1,747.83", "june2026": "2,184.78", "change": "+25%"},
        {"no": 18, "item": "Eucalyptus Dia 18cm", "itemAm": "የባህር ዛፍ ዲያሜትር 18ሴንቲ ሜትር", "unit": "Pcs", "march2026": "367.04", "june2026": "436.96", "change": "+19%"}
      ]
    },
    {
      "category": "BLOCKS & BRICKS",
      "categoryAm": "ብሎኮች እና ጡቦች",
      "items": [
        {"no": 19, "item": "Gypsum board Partion / Ceiling work with 60cmx60cm, 4×5 wooden Batton (thickness of Board -9mm)", "itemAm": "የጂፕሰም ቦርድ ክፍልፋይ / ጣሪያ ሥራ ከ60ሴንቲ ሜትርx60ሴንቲ ሜትር፣ 4×5 የእንጨት ባትን ጋር (የቦርዱ ውፍረት -9ሚሜ)", "unit": "M2", "march2026": "436.96", "june2026": "1,704.13", "change": "+290%"},
        {"no": 20, "item": "10cm thick Class-B HCB", "itemAm": "10ሴንቲ ሜትር ውፍረት ያለው ክላስ-B HCB", "unit": "PCS", "march2026": "71.66", "june2026": "131.09", "change": "+83%"},
        {"no": 21, "item": "15cm thick Class-B HCB", "itemAm": "15ሴንቲ ሜትር ውፍረት ያለው ክላስ-B HCB", "unit": "PCS", "march2026": "100.50", "june2026": "139.83", "change": "+39%"},
        {"no": 22, "item": "10cm thick Class-A HCB", "itemAm": "10ሴንቲ ሜትር ውፍረት ያለው ክላስ-A HCB", "unit": "PCS", "march2026": "100.50", "june2026": "139.83", "change": "+39%"},
        {"no": 23, "item": "10cm thick Class-C HCB", "itemAm": "10ሴንቲ ሜትር ውፍረት ያለው ክላስ-C HCB", "unit": "PCS", "march2026": "51.60", "june2026": "69.91", "change": "+35%"},
        {"no": 24, "item": "15cm thick Class-A HCB", "itemAm": "15ሴንቲ ሜትር ውፍረት ያለው ክላስ-A HCB", "unit": "PCS", "march2026": "115.36", "june2026": "157.30", "change": "+36%"},
        {"no": 25, "item": "Engineered Brick (<100,000 pcs)", "itemAm": "ኢንጂነርድ ጡብ (<100,000 pcs)", "unit": "PCS", "march2026": "24.47", "june2026": "23.60", "change": "-4%"},
        {"no": 26, "item": "Magnesium Board Thickness – 6mm (2.4 m × 1.2 m)", "itemAm": "የማግኒዚየም ቦርድ ውፍረት – 6ሚሜ (2.4 ሜ × 1.2 ሜ)", "unit": "PCS", "march2026": "2,184.78", "june2026": "2,796.52", "change": "+28%"},
        {"no": 27, "item": "Soil hydraform (9.5kg) Size 220x220x115mm", "itemAm": "ሶይል ሃይድራፎርም (9.5ኪግ) መጠን 220x220x115ሚሜ", "unit": "Pcs", "march2026": "61.17", "june2026": "69.91", "change": "+14%"}
      ]
    },
    {
      "category": "REINFORCEMENT BAR",
      "categoryAm": "የማጠናከሪያ ብረት",
      "items": [
        {"no": 28, "item": "2.5 mm black wire", "itemAm": "2.5 ሚሜ ጥቁር ሽቦ", "unit": "kg", "march2026": "218.48", "june2026": "271.35", "change": "+24%"},
        {"no": 29, "item": "1.5 mm black wire", "itemAm": "1.5 ሚሜ ጥቁር ሽቦ", "unit": "kg", "march2026": "218.48", "june2026": "241.20", "change": "+10%"},
        {"no": 30, "item": "Dia 6 (0.222kg/m)", "itemAm": "ዲያሜትር 6 (0.222ኪግ/ሜ)", "unit": "kg", "march2026": "205.37", "june2026": "218.48", "change": "+6%"},
        {"no": 31, "item": "Dia 8 (0.395kg/m)", "itemAm": "ዲያሜትር 8 (0.395ኪግ/ሜ)", "unit": "kg", "march2026": "209.74", "june2026": "209.74", "change": "0%"},
        {"no": 32, "item": "Dia 10 (0.617kg/m)", "itemAm": "ዲያሜትር 10 (0.617ኪግ/ሜ)", "unit": "kg", "march2026": "209.74", "june2026": "209.74", "change": "0%"},
        {"no": 33, "item": "Dia 12 (0.888Kg/m)", "itemAm": "ዲያሜትር 12 (0.888ኪግ/ሜ)", "unit": "kg", "march2026": "209.74", "june2026": "209.74", "change": "0%"},
        {"no": 34, "item": "Dia 14 (1.21Kg/m)", "itemAm": "ዲያሜትር 14 (1.21ኪግ/ሜ)", "unit": "kg", "march2026": "209.74", "june2026": "209.74", "change": "0%"},
        {"no": 35, "item": "Dia 16 (1.58kg/m)", "itemAm": "ዲያሜትር 16 (1.58ኪግ/ሜ)", "unit": "kg", "march2026": "209.74", "june2026": "209.74", "change": "0%"},
        {"no": 36, "item": "Dia 20 (2.47kg/m)", "itemAm": "ዲያሜትር 20 (2.47ኪግ/ሜ)", "unit": "kg", "march2026": "209.74", "june2026": "209.74", "change": "0%"},
        {"no": 37, "item": "Dia 24 (3.46kg/m)", "itemAm": "ዲያሜትር 24 (3.46ኪግ/ሜ)", "unit": "kg", "march2026": "209.74", "june2026": "209.74", "change": "0%"}
      ]
    },
    {
      "category": "BITUMEN & ASPHALT",
      "categoryAm": "ቢቱመን እና አስፋልት",
      "items": [
        {"no": 38, "item": "Bitumen 180/200", "itemAm": "ቢቱመን 180/200", "unit": "lit", "march2026": "94.21", "june2026": "97.88", "change": "+4%"},
        {"no": 39, "item": "AC-40/50", "itemAm": "AC-40/50", "unit": "lit", "march2026": "137.64", "june2026": "141.57", "change": "+3%"},
        {"no": 40, "item": "MC-30", "itemAm": "MC-30", "unit": "lit", "march2026": "217.06", "june2026": "222.17", "change": "+2%"},
        {"no": 41, "item": "AC-60/70", "itemAm": "AC-60/70", "unit": "lit", "march2026": "136.23", "june2026": "139.57", "change": "+2%"},
        {"no": 42, "item": "AC-80/100", "itemAm": "AC-80/100", "unit": "lit", "march2026": "136.23", "june2026": "139.57", "change": "+2%"}
      ]
    },
    {
      "category": "STEEL SECTIONS & SHEETS",
      "categoryAm": "የብረት ክፍሎች እና ሉሆች",
      "items": [
        {"no": 43, "item": "RHS120 x120 x 4mm(14.2Kg/ml)", "itemAm": "RHS 120 x 120 x 4ሚሜ (14.2ኪግ/ሜ)", "unit": "pcs", "march2026": "16,142.92", "june2026": "25,256.09", "change": "+56%"},
        {"no": 44, "item": "L-38mm,Thickness-1.5mm(1.755Kg/ml)", "itemAm": "L-38ሚሜ፣ ውፍረት-1.5ሚሜ (1.755ኪግ/ሜ)", "unit": "pcs", "march2026": "1,658.25", "june2026": "2,315.87", "change": "+40%"},
        {"no": 45, "item": "T-38mm,Thickness-1.5mm(2.025Kg/ml)", "itemAm": "T-38ሚሜ፣ ውፍረት-1.5ሚሜ (2.025ኪግ/ሜ)", "unit": "pcs", "march2026": "1,658.25", "june2026": "2,315.87", "change": "+40%"},
        {"no": 46, "item": "Z-38mm,Thickness-1.5mm(2.05Kg/ml)", "itemAm": "Z-38ሚሜ፣ ውፍረት-1.5ሚሜ (2.05ኪግ/ሜ)", "unit": "pcs", "march2026": "1,658.25", "june2026": "2,315.87", "change": "+40%"},
        {"no": 47, "item": "RHS 80x40x2 (3.56Kg/ml)", "itemAm": "RHS 80x40x2 (3.56ኪግ/ሜ)", "unit": "pcs", "march2026": "3,640.02", "june2026": "4,762.83", "change": "+31%"},
        {"no": 48, "item": "CHS Dia 30mmx1.5 (1.05Kg/ml)", "itemAm": "CHS ዲያሜትር 30ሚሜx1.5 (1.05ኪግ/ሜ)", "unit": "pcs", "march2026": "1,136.09", "june2026": "1,398.26", "change": "+23%"},
        {"no": 49, "item": "RHS 60x40x2 (2.93Kg/ml)", "itemAm": "RHS 60x40x2 (2.93ኪግ/ሜ)", "unit": "pcs", "march2026": "3,148.71", "june2026": "3,845.22", "change": "+22%"},
        {"no": 50, "item": "SHS 20x20x1 (0.58kg/m)", "itemAm": "SHS 20x20x1 (0.58ኪግ/ሜ)", "unit": "pcs", "march2026": "742.83", "june2026": "786.52", "change": "+6%"},
        {"no": 51, "item": "SHS 80x80x4 (9.22kg/m)", "itemAm": "SHS 80x80x4 (9.22ኪግ/ሜ)", "unit": "pcs", "march2026": "13,982.61", "june2026": "13,108.70", "change": "-6%"},
        {"no": 52, "item": "RHS 30x20x0.8 (0.6Kg/ml)", "itemAm": "RHS 30x20x0.8 (0.6ኪግ/ሜ)", "unit": "pcs", "march2026": "698.43", "june2026": "786.52", "change": "+13%"},
        {"no": 53, "item": "RHS 100x60x4mm(9.54Kg/ml)", "itemAm": "RHS 100x60x4ሚሜ (9.54ኪግ/ሜ)", "unit": "pcs", "march2026": "9,434.77", "june2026": "11,186.09", "change": "+19%"},
        {"no": 54, "item": "RHS120 x 80x 3mm(9.1Kg/ml)", "itemAm": "RHS 120 x 80 x 3ሚሜ (9.1ኪግ/ሜ)", "unit": "pcs", "march2026": "9,426.03", "june2026": "10,609.30", "change": "+13%"},
        {"no": 55, "item": "CHS Dia 28mmx1.5 (0.97Kg/ml)", "itemAm": "CHS ዲያሜትር 28ሚሜx1.5 (0.97ኪግ/ሜ)", "unit": "pcs", "march2026": "1,153.57", "june2026": "1,249.70", "change": "+8%"},
        {"no": 56, "item": "CHS Dia90mmx2.0 (4.34Kg/ml)", "itemAm": "CHS ዲያሜትር 90ሚሜx2.0 (4.34ኪግ/ሜ)", "unit": "pcs", "march2026": "5,680.43", "june2026": "5,785.30", "change": "+2%"}
      ]
    },
    {
      "category": "BOLTS & FASTENERS",
      "categoryAm": "ቦልቶች እና ማያያዣዎች",
      "items": [
        {"no": 57, "item": "Bolt-M16 Length =5cm", "itemAm": "ቦልት-M16 ርዝመት =5ሴንቲ ሜትር", "unit": "pcs", "march2026": "50.25", "june2026": "57.79", "change": "+15%"},
        {"no": 58, "item": "Blot-J20 Length =50cm", "itemAm": "ቦልት-J20 ርዝመት =50ሴንቲ ሜትር", "unit": "pcs", "march2026": "244.70", "june2026": "281.40", "change": "+15%"},
        {"no": 59, "item": "J bolt dia. 16 mm L 300mm grade 4.8", "itemAm": "J ቦልት ዲያሜትር 16 ሚሜ L 300ሚሜ ግሬድ 4.8", "unit": "Pcs", "march2026": "113.61", "june2026": "130.65", "change": "+15%"},
        {"no": 60, "item": "Bolt-M24 Length =5cm", "itemAm": "ቦልት-M24 ርዝመት =5ሴንቲ ሜትር", "unit": "pcs", "march2026": "70.35", "june2026": "80.90", "change": "+15%"},
        {"no": 61, "item": "Bolt-J16 Length=50cm", "itemAm": "ቦልት-J16 ርዝመት=50ሴንቲ ሜትር", "unit": "pcs", "march2026": "183.52", "june2026": "211.05", "change": "+15%"},
        {"no": 62, "item": "J bolt dia. 16 mm L 450mm grade 4.8", "itemAm": "J ቦልት ዲያሜትር 16 ሚሜ L 450ሚሜ ግሬድ 4.8", "unit": "Pcs", "march2026": "166.04", "june2026": "190.95", "change": "+15%"}
      ]
    },
    {
      "category": "HARDWARE & FASTENERS",
      "categoryAm": "ሃርድዌር እና ማያያዣዎች",
      "items": [
        {"no": 63, "item": "Screw for hinges mm", "itemAm": "የማጠፊያ ብሎን ሚሜ", "unit": "Pc", "march2026": "349.57", "june2026": "830.22", "change": "+138%"},
        {"no": 64, "item": "Nail different size 6cm-12cm", "itemAm": "የተለያየ መጠን ምስማር 6ሴንቲ ሜትር-12ሴንቲ ሜትር", "unit": "kg", "march2026": "157.30", "june2026": "279.65", "change": "+78%"},
        {"no": 65, "item": "Nails 3cm & 4cm.", "itemAm": "ምስማሮች 3ሴንቲ ሜትር እና 4ሴንቲ ሜትር።", "unit": "Kg", "march2026": "400.25", "june2026": "314.61", "change": "-21%"},
        {"no": 66, "item": "Roof Nail", "itemAm": "የጣሪያ ምስማር", "unit": "kg", "march2026": "322.47", "june2026": "367.04", "change": "+14%"},
        {"no": 67, "item": "T-hinges or Strap Hinges (Size 6)", "itemAm": "T-ማጠፊያዎች ወይም ስትራፕ ማጠፊያዎች (መጠን 6)", "unit": "Pcs", "march2026": "231.59", "june2026": "74.28", "change": "-68%"},
        {"no": 68, "item": "Electrode ( 3.2 mm )", "itemAm": "ኤሌክትሮድ (3.2 ሚሜ)", "unit": "Pc", "march2026": "1,502.26", "june2026": "2,010.00", "change": "+34%"}
      ]
    },
    {
      "category": "ALUMINIUM",
      "categoryAm": "አሉሚኒየም",
      "items": [
        {"no": 69, "item": "Hinge (Alloy)", "itemAm": "ማጠፊያ (አሎይ)", "unit": "Psc", "march2026": "119.60", "june2026": "349.57", "change": "+192%"},
        {"no": 70, "item": "Window Handle – Small", "itemAm": "የመስኮት መያዣ – ትንሽ", "unit": "Psc", "march2026": "150.75", "june2026": "305.87", "change": "+103%"},
        {"no": 71, "item": "Sliding Handle – Aluminum", "itemAm": "ተንሸራታች መያዣ – አሉሚኒየም", "unit": "Psc", "march2026": "150.75", "june2026": "262.17", "change": "+74%"},
        {"no": 72, "item": "T-Cross Connector (Cast)", "itemAm": "T-ክሮስ አገናኝ (ካስት)", "unit": "Psc", "march2026": "27.14", "june2026": "39.33", "change": "+45%"},
        {"no": 73, "item": "Equal Angle (L-Profile)", "itemAm": "እኩል አንግል (L-ፕሮፋይል)", "unit": "Bar", "march2026": "5,346.60", "june2026": "6,292.17", "change": "+18%"},
        {"no": 74, "item": "Rectangular Hollow Section (RHS) / Box Profile", "itemAm": "አራት ማዕዘን ባዶ ክፍል (RHS) / ቦክስ ፕሮፋይል", "unit": "Bar", "march2026": "6,612.90", "june2026": "7,297.17", "change": "+10%"},
        {"no": 75, "item": "L & Z Angle Connector", "itemAm": "L እና Z አንግል አገናኝ", "unit": "Psc", "march2026": "57.29", "june2026": "69.91", "change": "+22%"},
        {"no": 76, "item": "Tower Bolt – Long", "itemAm": "ታወር ቦልት – ረዥም", "unit": "Psc", "march2026": "351.75", "june2026": "419.48", "change": "+19%"}
      ]
    },
    {
      "category": "PAINT & FINISHES",
      "categoryAm": "ቀለም እና ማጠናቀቂያዎች",
      "items": [
        {"no": 77, "item": "Thinner (aquarage)", "itemAm": "ማቅለጫ (አኳሬጅ)", "unit": "lit", "march2026": "323.35", "june2026": "648.44", "change": "+101%"},
        {"no": 78, "item": "Gypsum", "itemAm": "ጂፕሰም", "unit": "kg", "march2026": "25.34", "june2026": "39.33", "change": "+55%"},
        {"no": 79, "item": "Varnish", "itemAm": "ቫርኒሽ", "unit": "lit", "march2026": "821.48", "june2026": "1,092.39", "change": "+33%"},
        {"no": 80, "item": "Antirust primer red", "itemAm": "ዝገት መከላከያ ፕራይመር ቀይ", "unit": "lit", "march2026": "448.79", "june2026": "568.04", "change": "+27%"},
        {"no": 81, "item": "Antirust primer grey", "itemAm": "ዝገት መከላከያ ፕራይመር ግራጫ", "unit": "lit", "march2026": "486.89", "june2026": "611.74", "change": "+26%"},
        {"no": 82, "item": "Supper paint plastic", "itemAm": "ሱፐር ፕላስቲክ ቀለም", "unit": "lit", "march2026": "575.91", "june2026": "568.04", "change": "-1%"},
        {"no": 83, "item": "Mica paint", "itemAm": "ሚካ ቀለም", "unit": "lit", "march2026": "530.47", "june2026": "524.35", "change": "-1%"},
        {"no": 84, "item": "Primer", "itemAm": "ፕራይመር", "unit": "lit", "march2026": "192.26", "june2026": "201.00", "change": "+5%"},
        {"no": 85, "item": "Animal glue", "itemAm": "የእንስሳት ሙጫ", "unit": "kg", "march2026": "830.22", "june2026": "856.43", "change": "+3%"},
        {"no": 86, "item": "white putty (25kg)", "itemAm": "ነጭ ፑቲ (25ኪግ)", "unit": "kg", "march2026": "34.17", "june2026": "42.21", "change": "+24%"}
      ]
    },
    {
      "category": "DOORS",
      "categoryAm": "በሮች",
      "items": [
        {"no": 87, "item": "Smooth MDF board made imported wooden door", "itemAm": "ለስላሳ MDF ቦርድ የተሠራ ከውጭ የመጣ የእንጨት በር", "unit": "m²", "march2026": "7,865.22", "june2026": "10,788.46", "change": "+37%"},
        {"no": 88, "item": "Antique smooth MDF board made imported wooden door", "itemAm": "አንቲክ ለስላሳ MDF ቦርድ የተሠራ ከውጭ የመጣ የእንጨት በር", "unit": "m²", "march2026": "10,923.91", "june2026": "13,108.70", "change": "+20%"},
        {"no": 89, "item": "Laminated Kitchen cabinet with out Granite", "itemAm": "ላሚኔትድ የወጥ ቤት ካቢኔት ግራናይት የለም", "unit": "m²", "march2026": "10,923.91", "june2026": "13,108.70", "change": "+20%"},
        {"no": 90, "item": "1.5mm -3mm thick Lead lined Stainless Steel frame door with all work and Accessories Size:-85*260cm (IMPORTED)(0.8mm)", "itemAm": "1.5ሚሜ -3ሚሜ ውፍረት ያለው በእርሳስ የተሸፈነ ስቴንሌስ ስቲል ፍሬም በር ከሁሉም ሥራ እና መለዋወጫዎች ጋር መጠን:-85*260ሴንቲ ሜትር (ከውጭ የመጣ)(0.8ሚሜ)", "unit": "m²", "march2026": "18,094.37", "june2026": "19,226.09", "change": "+6%"},
        {"no": 91, "item": "Steel Framed fire rate door with a rating of 2hr one opening", "itemAm": "የብረት ፍሬም የእሳት መከላከያ በር የ2ሰዓት ደረጃ አንድ መክፈቻ", "unit": "m²", "march2026": "38,917.97", "june2026": "40,462.17", "change": "+4%"},
        {"no": 92, "item": "PVC made Kitchen cabinet with Granite", "itemAm": "PVC የተሠራ የወጥ ቤት ካቢኔት ከግራናይት ጋር", "unit": "m²", "march2026": "16,604.35", "june2026": "19,051.30", "change": "+15%"}
      ]
    },
    {
      "category": "GLASS & GLAZING",
      "categoryAm": "ብርጭቆ እና መስታወት",
      "items": [
        {"no": 93, "item": "4 mm. clear glass", "itemAm": "4 ሚሜ. ግልጽ ብርጭቆ", "unit": "m2", "march2026": "2,010.00", "june2026": "2,796.52", "change": "+39%"},
        {"no": 94, "item": "5 mm. clear glass", "itemAm": "5 ሚሜ. ግልጽ ብርጭቆ", "unit": "m2", "march2026": "2,534.35", "june2026": "3,146.09", "change": "+24%"}
      ]
    },
    {
      "category": "FORMWORK & TIMBER",
      "categoryAm": "ፎርምወርክ እና እንጨት",
      "items": [
        {"no": 95, "item": "Fair Faced Formwork (High Quality Plywood)", "itemAm": "ፌር ፌስድ ፎርምወርክ (ከፍተኛ ጥራት ፕላይዉድ)", "unit": "m2", "march2026": "2,621.74", "june2026": "5,680.43", "change": "+117%"},
        {"no": 96, "item": "Chipwood wall 8mm", "itemAm": "የቺፕዉድ ግድግዳ 8ሚሜ", "unit": "PCS", "march2026": "1,223.48", "june2026": "2,272.17", "change": "+86%"},
        {"no": 97, "item": "Yellow plate Form work", "itemAm": "ቢጫ ሰሌዳ ፎርም ሥራ", "unit": "m2", "march2026": "2,971.30", "june2026": "4,937.61", "change": "+66%"},
        {"no": 98, "item": "Timber 15cm x 4 m", "itemAm": "እንጨት 15ሴንቲ ሜትር x 4 ሜ", "unit": "pcs", "march2026": "1,747.83", "june2026": "2,184.78", "change": "+25%"},
        {"no": 99, "item": "Scaffolding", "itemAm": "ስካፎልዲንግ", "unit": "No", "march2026": "13,720.43", "june2026": "14,419.57", "change": "+5%"},
        {"no": 100, "item": "Chipwood wall 13mm", "itemAm": "የቺፕዉድ ግድግዳ 13ሚሜ", "unit": "PCS", "march2026": "2,184.78", "june2026": "2,534.35", "change": "+16%"}
      ]
    },
    
    {
      "category": "FLOORING & TILES",
      "categoryAm": "ወለል እና ታይሎች",
      "items": [
        {"no": 101, "item": "5kg Filler", "itemAm": "5ኪግ መሙያ", "unit": "bag", "march2026": "480.65", "june2026": "1,267.17", "change": "+164%"},
        {"no": 102, "item": "1 cm thick Black Galaxy Granite, Size:-40cmx40cm-Imported", "itemAm": "1 ሴንቲ ሜትር ውፍረት ያለው ብላክ ጋላክሲ ግራናይት፣ መጠን:-40ሴንቲ ሜትርx40ሴንቲ ሜትር-ከውጭ የመጣ", "unit": "lm", "march2026": "1,223.48", "june2026": "3,076.17", "change": "+151%"},
        {"no": 103, "item": "2kg Filler", "itemAm": "2ኪግ መሙያ", "unit": "bag", "march2026": "480.65", "june2026": "917.61", "change": "+91%"},
        {"no": 104, "item": "Adhesive (25 kg)", "itemAm": "አጣቢ (25 ኪግ)", "unit": "Kg", "march2026": "699.13", "june2026": "1,092.39", "change": "+56%"},
        {"no": 105, "item": "7mm ceramic floor local", "itemAm": "7ሚሜ ሴራሚክ ወለል የአገር ውስጥ", "unit": "m2", "march2026": "1,048.70", "june2026": "1,608.00", "change": "+53%"},
        {"no": 106, "item": "2mm thick PVC flooring", "itemAm": "2ሚሜ ውፍረት ያለው PVC ወለል", "unit": "m2", "march2026": "699.13", "june2026": "1,048.70", "change": "+50%"},
        {"no": 107, "item": "Adhesive", "itemAm": "አጣቢ", "unit": "bag", "march2026": "742.83", "june2026": "1,092.39", "change": "+47%"},
        {"no": 108, "item": "10cm high PVC skirting 2mm thick", "itemAm": "10ሴንቲ ሜትር ከፍታ PVC ስኪርቲንግ 2ሚሜ ውፍረት", "unit": "lm", "march2026": "74.28", "june2026": "104.87", "change": "+41%"},
        {"no": 109, "item": "Terrazzo tile flooring (Colored -Black)Thickness=3.5cm", "itemAm": "የተራዞ ታይል ወለል (ባለቀለም -ጥቁር) ውፍረት=3.5ሴንቲ ሜትር", "unit": "m2", "march2026": "436.96", "june2026": "611.74", "change": "+40%"},
        {"no": 110, "item": "water proofing 5*10", "itemAm": "የውሃ መከላከያ 5*10", "unit": "Kg", "march2026": "5,243.48", "june2026": "4,893.91", "change": "-7%"},
        {"no": 111, "item": "30mm thick Marbel window cill for HCB", "itemAm": "30ሚሜ ውፍረት ያለው የእርስ መስኮት ጠርዝ ለHCB", "unit": "m2", "march2026": "5,680.43", "june2026": "6,991.30", "change": "+23%"},
        {"no": 112, "item": "Ceramic Tile flooring 9mm -Imported (Rack)", "itemAm": "የሴራሚክ ታይል ወለል 9ሚሜ -ከውጭ የመጣ (ራክ)", "unit": "m2", "march2026": "3,626.74", "june2026": "3,679.17", "change": "+1%"},
        {"no": 113, "item": "Thickness- 6mm", "itemAm": "ውፍረት- 6ሚሜ", "unit": "m2", "march2026": "4,020.00", "june2026": "4,194.78", "change": "+4%"},
        {"no": 114, "item": "120cm x 28cmx3cm thick Marble threads-Local", "itemAm": "120ሴንቲ ሜትር x 28ሴንቲ ሜትርx3ሴንቲ ሜትር ውፍረት ያለው የእርስ ተርድ-የአገር ውስጥ", "unit": "m", "march2026": "2,114.17", "june2026": "2,495.90", "change": "+18%"},
        {"no": 115, "item": "120cm x 33cmx3cm thick Granite threads-Imported", "itemAm": "120ሴንቲ ሜትር x 33ሴንቲ ሜትርx3ሴንቲ ሜትር ውፍረት ያለው የግራናይት ተርድ-ከውጭ የመጣ", "unit": "pcs", "march2026": "5,364.08", "june2026": "5,710.15", "change": "+6%"},
        {"no": 116, "item": "200cm x 16cmx2cm thick Marble Riser-Local", "itemAm": "200ሴንቲ ሜትር x 16ሴንቲ ሜትርx2ሴንቲ ሜትር ውፍረት ያለው የእርስ ራይዘር-የአገር ውስጥ", "unit": "m", "march2026": "1,985.53", "june2026": "2,321.11", "change": "+17%"},
        {"no": 117, "item": "120cm x 14cmx2cm thick Terrazo Riser", "itemAm": "120ሴንቲ ሜትር x 14ሴንቲ ሜትርx2ሴንቲ ሜትር ውፍረት ያለው የተራዞ ራይዘር", "unit": "m", "march2026": "286.29", "june2026": "323.00", "change": "+13%"},
        {"no": 118, "item": "20mm thick Terrazo skirting", "itemAm": "20ሚሜ ውፍረት ያለው የተራዞ ስኪርቲንግ", "unit": "lm", "march2026": "170.41", "june2026": "192.26", "change": "+13%"}
      ]
    },
    {
      "category": "CEILING",
      "categoryAm": "ጣሪያ",
      "items": [
        {"no": 119, "item": "Purlin for ceiling", "itemAm": "ፐርላይን ለጣሪያ", "unit": "m2", "march2026": "1,048.70", "june2026": "2,359.57", "change": "+125%"},
        {"no": 120, "item": "Mineral fiber acoustic ceiling With Suspender, all accessories and labour", "itemAm": "ሚኒራል ፋይበር አኮስቲክ ጣሪያ ከሰስፔንደር፣ ሁሉም መለዋወጫዎች እና ጉልበት ጋር", "unit": "m2", "march2026": "1,747.83", "june2026": "3,311.26", "change": "+89%"},
        {"no": 121, "item": "8mm Plywood", "itemAm": "8ሚሜ ፕላይዉድ", "unit": "pcs", "march2026": "2,534.35", "june2026": "4,107.39", "change": "+62%"},
        {"no": 122, "item": "8mm Chip wood Ceiling", "itemAm": "8ሚሜ ቺፕ ዉድ ጣሪያ", "unit": "pcs", "march2026": "1,485.65", "june2026": "2,534.35", "change": "+71%"},
        {"no": 123, "item": "12-15 mm thick Gypsum Ceiling (water proof) with suspender&all accessories", "itemAm": "12-15 ሚሜ ውፍረት ያለው የጂፕሰም ጣሪያ (የውሃ መከላከያ) ከሰስፔንደር እና ሁሉም መለዋወጫዎች ጋር", "unit": "M2", "march2026": "3,408.26", "june2026": "3,182.14", "change": "-7%"}
      ]
    },
    {
      "category": "ROOFING",
      "categoryAm": "የጣሪያ ሥራ",
      "items": [
        {"no": 124, "item": "G-30 CIS Roofing", "itemAm": "G-30 CIS የጣሪያ ሽፋን", "unit": "Pcs", "march2026": "1,293.39", "june2026": "1,597.95", "change": "+24%"},
        {"no": 125, "item": "G-28 CIS Roofing", "itemAm": "G-28 CIS የጣሪያ ሽፋን", "unit": "Pcs", "march2026": "1,573.04", "june2026": "1,909.50", "change": "+21%"},
        {"no": 126, "item": "Acrylic Skylight with 5mm Aluminum frame", "itemAm": "አክሬሊክ ስካይላይት ከ5ሚሜ አሉሚኒየም ፍሬም ጋር", "unit": "Pcs", "march2026": "1,048.70", "june2026": "1,223.48", "change": "+17%"},
        {"no": 127, "item": "G-32 CIS Roofing (Without Truss & Purlin)", "itemAm": "G-32 CIS የጣሪያ ሽፋን (ትረስ እና ፐርላይን የለም)", "unit": "Pcs", "march2026": "1,179.78", "june2026": "1,306.50", "change": "+11%"},
        {"no": 128, "item": "G-35 CIS Roofing (Without Truss & Purlin)", "itemAm": "G-35 CIS የጣሪያ ሽፋን (ትረስ እና ፐርላይን የለም)", "unit": "M2", "march2026": "742.83", "june2026": "786.52", "change": "+6%"},
        {"no": 129, "item": "0.3mm thick (30 Gauge)", "itemAm": "0.3ሚሜ ውፍረት (30 ጌጅ)", "unit": "M2", "march2026": "1,467.30", "june2026": "1,503.65", "change": "+2%"},
        {"no": 130, "item": "Coated EGA 400 with 0.5mm roof cover", "itemAm": "የተሸፈነ EGA 400 ከ0.5ሚሜ ጣሪያ ሽፋን ጋር", "unit": "M2", "march2026": "1,280.28", "june2026": "1,310.87", "change": "+2%"},
        {"no": 131, "item": "G-30 of Devl Length 50cm", "itemAm": "G-30 devl ርዝመት 50ሴንቲ ሜትር", "unit": "ML", "march2026": "589.89", "june2026": "589.89", "change": "0%"},
        {"no": 132, "item": "G-28 of Devl Length 60cm", "itemAm": "G-28 devl ርዝመት 60ሴንቲ ሜትር", "unit": "ML", "march2026": "789.14", "june2026": "789.14", "change": "0%"},
        {"no": 133, "item": "Decra Vally Gutter (Local)", "itemAm": "ዴክራ ቫሊ ገተር (የአገር ውስጥ)", "unit": "Ml", "march2026": "611.74", "june2026": "611.74", "change": "0%"}
      ]
    },
    {
      "category": "SANITARY FITTINGS",
      "categoryAm": "የሳኒቴሪ መለዋወጫዎች",
      "items": [
        {"no": 134, "item": "Turkish WC medium quality", "itemAm": "የቱርክ WC መካከለኛ ጥራት", "unit": "pcs", "march2026": "6,449.48", "june2026": "20,973.91", "change": "+225%"},
        {"no": 135, "item": "Turkish WC high quality", "itemAm": "የቱርክ WC ከፍተኛ ጥራት", "unit": "pcs", "march2026": "7,655.48", "june2026": "24,469.57", "change": "+220%"},
        {"no": 136, "item": "HWB size 45 * 55 cm (Golden dragon sealed)", "itemAm": "HWB መጠን 45 * 55 ሴንቲ ሜትር (ጎልደን ድራጎን ሲልድ)", "unit": "pcs", "march2026": "11,360.87", "june2026": "33,392.22", "change": "+194%"},
        {"no": 137, "item": "HWB size 45 * 55 cm (AQUA)", "itemAm": "HWB መጠን 45 * 55 ሴንቲ ሜትር (AQUA)", "unit": "pcs", "march2026": "10,006.30", "june2026": "27,091.30", "change": "+171%"},
        {"no": 138, "item": "HWB size 45 * 55 cm (RAK)", "itemAm": "HWB መጠን 45 * 55 ሴንቲ ሜትር (RAK)", "unit": "pcs", "march2026": "14,419.57", "june2026": "29,713.04", "change": "+106%"},
        {"no": 139, "item": "Capacity 50 Liter Electric StorageWater Heater", "itemAm": "50 ሊትር አቅም ያለው ኤሌክትሪክ የውሃ ማሞቂያ", "unit": "pcs", "march2026": "27,091.30", "june2026": "38,452.17", "change": "+42%"},
        {"no": 140, "item": "WC low flash (Golden dragon sealed)", "itemAm": "WC ሎው ፍላሽ (ጎልደን ድራጎን ሲልድ)", "unit": "pcs", "march2026": "30,150.00", "june2026": "35,393.48", "change": "+17%"},
        {"no": 141, "item": "Capacity 100 Liter Electric Storage Water Heater", "itemAm": "100 ሊትር አቅም ያለው ኤሌክትሪክ የውሃ ማሞቂያ", "unit": "pcs", "march2026": "60,125.22", "june2026": "62,921.74", "change": "+5%"},
        {"no": 142, "item": "80Lit.water heater", "itemAm": "80 ሊትር የውሃ ማሞቂያ", "unit": "pcs", "march2026": "57,853.04", "june2026": "58,552.17", "change": "+1%"},
        {"no": 143, "item": "Paper Towel Dispenser", "itemAm": "የወረቀት ፎጣ ማውጫ", "unit": "No", "march2026": "3,058.70", "june2026": "2,796.52", "change": "-9%"}
      ]
    },
    {
      "category": "VALVES",
      "categoryAm": "ቫልቮች",
      "items": [
        {"no": 144, "item": "Ø40mm PPR", "itemAm": "Ø40ሚሜ PPR", "unit": "pcs", "march2026": "1,704.13", "june2026": "3,233.48", "change": "+90%"},
        {"no": 145, "item": "Ø65mm PPR", "itemAm": "Ø65ሚሜ PPR", "unit": "pcs", "march2026": "3,626.74", "june2026": "5,856.09", "change": "+61%"},
        {"no": 146, "item": "Ø32mm PPR", "itemAm": "Ø32ሚሜ PPR", "unit": "pcs", "march2026": "1,354.57", "june2026": "2,097.39", "change": "+55%"},
        {"no": 147, "item": "2 1/2″ – 1/2″", "itemAm": "2 1/2″ – 1/2″", "unit": "No", "march2026": "1,179.78", "june2026": "603.00", "change": "-49%"},
        {"no": 148, "item": "Ø20mm chrome service Valve", "itemAm": "Ø20ሚሜ ክሮም ሰርቪስ ቫልቭ", "unit": "pcs", "march2026": "830.22", "june2026": "1,223.48", "change": "+47%"},
        {"no": 149, "item": "Ø25mm Bronze Gate Valve", "itemAm": "Ø25ሚሜ ብሮንዝ ጌት ቫልቭ", "unit": "pcs", "march2026": "2,184.78", "june2026": "2,446.96", "change": "+12%"},
        {"no": 150, "item": "Ø50mm Cast iron Gate Valve", "itemAm": "Ø50ሚሜ የብረት ጌት ቫልቭ", "unit": "pcs", "march2026": "9,613.04", "june2026": "11,535.65", "change": "+20%"},
        {"no": 151, "item": "Ø110mm PPR", "itemAm": "Ø110ሚሜ PPR", "unit": "pcs", "march2026": "10,224.78", "june2026": "11,797.83", "change": "+15%"}
      ]
    },
    {
      "category": "PIPE FITTINGS",
      "categoryAm": "የቧንቧ መገጣጠሚያዎች",
      "items": [
        {"no": 152, "item": "Diameter 3/4″", "itemAm": "ዲያሜትር 3/4″", "unit": "pcs", "march2026": "323.35", "june2026": "480.65", "change": "+49%"},
        {"no": 153, "item": "3/4″", "itemAm": "3/4″", "unit": "no", "march2026": "183.52", "june2026": "253.43", "change": "+38%"},
        {"no": 154, "item": "1 1/2″ PPR", "itemAm": "1 1/2″ PPR", "unit": "No", "march2026": "402.00", "june2026": "524.35", "change": "+30%"},
        {"no": 155, "item": "160 – 110mm", "itemAm": "160 – 110ሚሜ", "unit": "No", "march2026": "1,817.74", "june2026": "2,272.17", "change": "+25%"},
        {"no": 156, "item": "2 1/2″PPR", "itemAm": "2 1/2″ PPR", "unit": "no", "march2026": "1,398.26", "june2026": "1,642.96", "change": "+18%"},
        {"no": 157, "item": "1/2″", "itemAm": "1/2″", "unit": "no", "march2026": "157.30", "june2026": "174.78", "change": "+11%"},
        {"no": 158, "item": "50*45", "itemAm": "50*45", "unit": "No", "march2026": "288.39", "june2026": "323.35", "change": "+12%"},
        {"no": 159, "item": "Diameter 1″", "itemAm": "ዲያሜትር 1″", "unit": "pcs", "march2026": "506.87", "june2026": "585.52", "change": "+16%"},
        {"no": 160, "item": "Diameter 25mm PP-R Male Elbo", "itemAm": "ዲያሜትር 25ሚሜ PP-R ወንድ ክርን", "unit": "pcs", "march2026": "393.26", "june2026": "393.26", "change": "0%"}
      ]
    },
    {
      "category": "PIPES",
      "categoryAm": "ቧንቧዎች",
      "items": [
        {"no": 161, "item": "PN-16 Item but 80mm diameter", "itemAm": "PN-16 80ሚሜ ዲያሜትር", "unit": "ml", "march2026": "830.22", "june2026": "1,441.96", "change": "+74%"},
        {"no": 162, "item": "PN-16 Item but 90mm diameter", "itemAm": "PN-16 90ሚሜ ዲያሜትር", "unit": "ml", "march2026": "838.96", "june2026": "1,441.96", "change": "+72%"},
        {"no": 163, "item": "PN-16 Item but 110mm diameter", "itemAm": "PN-16 110ሚሜ ዲያሜትር", "unit": "ml", "march2026": "1,441.96", "june2026": "2,097.39", "change": "+45%"},
        {"no": 164, "item": "PN-16 Item but 40mm diameter", "itemAm": "PN-16 40ሚሜ ዲያሜትር", "unit": "ml", "march2026": "157.30", "june2026": "218.48", "change": "+39%"},
        {"no": 165, "item": "Upvc Elbow :Dia.250,90 Degree- double ring", "itemAm": "UPVC ክርን ዲያሜትር 250፣ 90 ዲግሪ - ድርብ ቀለበት", "unit": "No", "march2026": "7,865.22", "june2026": "10,923.91", "change": "+39%"},
        {"no": 166, "item": "PN-16 Checkvalve , Diameter 20mm", "itemAm": "PN-16 ቼክ ቫልቭ፣ ዲያሜትር 20ሚሜ", "unit": "No", "march2026": "786.52", "june2026": "1,048.70", "change": "+33%"},
        {"no": 167, "item": "Dai 110mm", "itemAm": "ዲያሜትር 110ሚሜ", "unit": "No", "march2026": "1,136.09", "june2026": "1,267.17", "change": "+12%"},
        {"no": 168, "item": "315mm HDPE PIPE", "itemAm": "315ሚሜ HDPE ቧንቧ", "unit": "ml", "march2026": "6,816.52", "june2026": "6,816.52", "change": "0%"},
        {"no": 169, "item": "uPVC pipe PN-10 500mm. Dia. PVC Pipe", "itemAm": "uPVC ቧንቧ PN-10 500ሚሜ. ዲያሜትር PVC ቧንቧ", "unit": "pcs", "march2026": "20,973.91", "june2026": "21,410.87", "change": "+2%"},
        {"no": 170, "item": "Upvc Elbow :Dia.200,45 Degree- double ring", "itemAm": "UPVC ክርን ዲያሜትር 200፣ 45 ዲግሪ - ድርብ ቀለበት", "unit": "No", "march2026": "6,554.35", "june2026": "4,806.52", "change": "-27%"}
      ]
    },
    {
      "category": "PUMPS & FIRE",
      "categoryAm": "ፓምፖች እና እሳት መከላከያ",
      "items": [
        {"no": 171, "item": "1kg Dry Powder", "itemAm": "1ኪግ ደረቅ ዱቄት", "unit": "No", "march2026": "3,495.65", "june2026": "2,621.74", "change": "-25%"},
        {"no": 172, "item": "6kg Dry Powde", "itemAm": "6ኪግ ደረቅ ዱቄት", "unit": "No", "march2026": "7,865.22", "june2026": "6,117.39", "change": "-22%"},
        {"no": 173, "item": "Fiber glass water tank 500 lt", "itemAm": "ፋይበር ግላስ የውሃ ታንክ 500 lt", "unit": "No", "march2026": "12,933.91", "june2026": "13,108.70", "change": "+1%"},
        {"no": 174, "item": "Fiber glass water tank 15000 lt", "itemAm": "ፋይበር ግላስ የውሃ ታንክ 15000 lt", "unit": "No", "march2026": "147,691.30", "june2026": "148,390.43", "change": "+0%"},
        {"no": 175, "item": "2kg Dry Powder", "itemAm": "2ኪግ ደረቅ ዱቄት", "unit": "No", "march2026": "3,932.61", "june2026": "3,495.65", "change": "-11%"}
      ]
    },
    {
      "category": "WATER PIPES",
      "categoryAm": "የውሃ ቧንቧዎች",
      "items": [
        {"no": 176, "item": "uPVC pipe PN-6 but 110 mm diameter", "itemAm": "uPVC ቧንቧ PN-6 110 ሚሜ ዲያሜትር", "unit": "ml", "march2026": "3,320.87", "june2026": "2,796.52", "change": "-16%"},
        {"no": 177, "item": "uPVC pipe PN-6 but 75 mm diameter", "itemAm": "uPVC ቧንቧ PN-6 75 ሚሜ ዲያሜትር", "unit": "ml", "march2026": "2,010.00", "june2026": "1,704.13", "change": "-15%"},
        {"no": 178, "item": "uPVC pipe PN-6 but 300 mm diameter", "itemAm": "uPVC ቧንቧ PN-6 300 ሚሜ ዲያሜትር", "unit": "ml", "march2026": "26,217.39", "june2026": "29,713.04", "change": "+13%"},
        {"no": 179, "item": "uPVC pipe PN-6 but 50 mm diameter", "itemAm": "uPVC ቧንቧ PN-6 50 ሚሜ ዲያሜትር", "unit": "ml", "march2026": "1,048.70", "june2026": "1,136.09", "change": "+8%"},
        {"no": 180, "item": "uPVC pipe PN-6 but 160 mm diameter", "itemAm": "uPVC ቧንቧ PN-6 160 ሚሜ ዲያሜትር", "unit": "ml", "march2026": "5,680.43", "june2026": "5,593.04", "change": "-2%"},
        {"no": 181, "item": "uPVC pipe PN-6 but 200 mm diameter", "itemAm": "uPVC ቧንቧ PN-6 200 ሚሜ ዲያሜትር", "unit": "ml", "march2026": "8,302.17", "june2026": "7,690.43", "change": "-7%"}
      ]
    },
    {
      "category": "WATER PIPES & VALVES",
      "categoryAm": "የውሃ ቧንቧዎች እና ቫልቮች",
      "items": [
        {"no": 182, "item": "DN80", "itemAm": "DN80", "unit": "no", "march2026": "3,932.61", "june2026": "13,108.70", "change": "+233%"},
        {"no": 183, "item": "DN300", "itemAm": "DN300", "unit": "no", "march2026": "35,306.09", "june2026": "104,869.57", "change": "+197%"},
        {"no": 184, "item": "DN350", "itemAm": "DN350", "unit": "No", "march2026": "41,248.70", "june2026": "117,978.26", "change": "+186%"},
        {"no": 185, "item": "DN100", "itemAm": "DN100", "unit": "m", "march2026": "3,932.61", "june2026": "10,486.96", "change": "+167%"},
        {"no": 186, "item": "DN400", "itemAm": "DN400", "unit": "m", "march2026": "31,023.91", "june2026": "39,326.09", "change": "+27%"},
        {"no": 187, "item": "DN250", "itemAm": "DN250", "unit": "pcs", "march2026": "41,073.91", "june2026": "41,073.91", "change": "0%"}
      ]
    },
    {
      "category": "PUMPS & GENERATORS",
      "categoryAm": "ፓምፖች እና ጄኔሬተሮች",
      "items": [
        {"no": 188, "item": "HP (kW): 10 HP (7 kW), Flow (L/s) 5", "itemAm": "HP (kW): 10 HP (7 kW)፣ ፍሰት (L/s) 5", "unit": "set", "march2026": "112,035.65", "june2026": "239,452.17", "change": "+114%"},
        {"no": 189, "item": "capacity; Q 1L/sat Head of 70m", "itemAm": "አቅም፤ Q 1L/s በ70ሜ ራስ", "unit": "set", "march2026": "2,311,500.00", "june2026": "74,282.61", "change": "-97%"},
        {"no": 190, "item": "HP (kW): 3 HP (2.2 kW), Flow (L/s) 20, Head 18.5", "itemAm": "HP (kW): 3 HP (2.2 kW)፣ ፍሰት (L/s) 20፣ ራስ 18.5", "unit": "set", "march2026": "24,032.61", "june2026": "43,083.91", "change": "+79%"},
        {"no": 191, "item": "520 kW", "itemAm": "520 kW", "unit": "set", "march2026": "18,352,174", "june2026": "19,226,087", "change": "+5%"},
        {"no": 192, "item": "80kv", "itemAm": "80kv", "unit": "set", "march2026": "3,320,869.57", "june2026": "3,320,869.57", "change": "0%"}
      ]
    },
    {
      "category": "MECHANICAL/HVAC",
      "categoryAm": "ሜካኒካል/ኤችቪኤሲ",
      "items": [
        {"no": 193, "item": "Up to 350mm 0.6mm", "itemAm": "እስከ 350ሚሜ 0.6ሚሜ", "unit": "m²", "march2026": "8,389.57", "june2026": "12,562.50", "change": "+50%"},
        {"no": 194, "item": "enclosed perforated cable tray .", "itemAm": "የተዘጋ ቀዳዳ ያለው ኬብል ትሪ።", "unit": "m", "march2026": "8,258.48", "june2026": "6,532.50", "change": "-21%"}
      ]
    },
    {
      "category": "ELECTRICAL CABLES",
      "categoryAm": "የኤሌክትሪክ ኬብሎች",
      "items": [
        {"no": 195, "item": "5*6 sq.mm cable", "itemAm": "5*6 ካሬ ሚሜ ኬብል", "unit": "Mtr", "march2026": "838.96", "june2026": "1,310.87", "change": "+56%"},
        {"no": 196, "item": "TELE 250", "itemAm": "ቴሌ 250", "unit": "Roll", "march2026": "4,325.87", "june2026": "6,466.96", "change": "+49%"},
        {"no": 197, "item": "TELE 100", "itemAm": "ቴሌ 100", "unit": "Roll", "march2026": "1,704.13", "june2026": "2,534.35", "change": "+49%"},
        {"no": 198, "item": "3*70 flat FLEX", "itemAm": "3*70 ጠፍጣፋ ፍሌክስ", "unit": "Mtr", "march2026": "8,214.78", "june2026": "11,186.09", "change": "+36%"},
        {"no": 199, "item": "1.6 FLEX", "itemAm": "1.6 ፍሌክስ", "unit": "Roll", "march2026": "13,283.48", "june2026": "17,653.04", "change": "+33%"},
        {"no": 200, "item": "3*70 FLEX", "itemAm": "3*70 ፍሌክስ", "unit": "Mtr", "march2026": "8,520.65", "june2026": "11,273.48", "change": "+32%"},
        {"no": 201, "item": "HDMI cable ( 10 Meter)", "itemAm": "HDMI ኬብል (10 ሜትር)", "unit": "Pcs", "march2026": "1,441.96", "june2026": "1,441.96", "change": "0%"},
        {"no": 202, "item": "Rigid Conduit 16mm", "itemAm": "ሪጅድ ቱቦ 16ሚሜ", "unit": "Mtr", "march2026": "13.98", "june2026": "13.98", "change": "0%"},
        {"no": 203, "item": "UPVC Pipe 32mm PN-6", "itemAm": "UPVC ቧንቧ 32ሚሜ PN-6", "unit": "Mtr", "march2026": "397.63", "june2026": "397.63", "change": "0%"},
        {"no": 204, "item": "3*50 FLEX", "itemAm": "3*50 ፍሌክስ", "unit": "Mtr", "march2026": "5,855.22", "june2026": "7,603.04", "change": "+30%"},
        {"no": 205, "item": "3*185/95 sq.mm cable", "itemAm": "3*185/95 ካሬ ሚሜ ኬብል", "unit": "Mtr", "march2026": "24,688.04", "june2026": "31,373.48", "change": "+27%"},
        {"no": 206, "item": "4*16 NYY", "itemAm": "4*16 NYY", "unit": "Mtr", "march2026": "2,578.04", "june2026": "3,036.85", "change": "+18%"},
        {"no": 207, "item": "DISH", "itemAm": "ዲሽ", "unit": "Roll", "march2026": "3,932.61", "june2026": "3,932.61", "change": "0%"}
      ]
    },
    {
      "category": "ELECTRICAL CONDUIT & RODS",
      "categoryAm": "የኤሌክትሪክ ቱቦዎች እና ዘንጎች",
      "items": [
        {"no": 208, "item": "Ø 13MM", "itemAm": "Ø 13ሚሜ", "unit": "M", "march2026": "91.76", "june2026": "91.76", "change": "0%"},
        {"no": 209, "item": "Ø 16MM", "itemAm": "Ø 16ሚሜ", "unit": "M", "march2026": "124.97", "june2026": "124.97", "change": "0%"},
        {"no": 210, "item": "Ø 19MM", "itemAm": "Ø 19ሚሜ", "unit": "M", "march2026": "150.31", "june2026": "150.31", "change": "0%"},
        {"no": 211, "item": "Ø 20MM", "itemAm": "Ø 20ሚሜ", "unit": "M", "march2026": "103.12", "june2026": "103.12", "change": "0%"},
        {"no": 212, "item": "GIP Ø3/4″", "itemAm": "GIP Ø3/4″", "unit": "M", "march2026": "305.87", "june2026": "305.87", "change": "0%"}
      ]
    },
    {
      "category": "ELECTRICAL BOARDS & DEVICES",
      "categoryAm": "የኤሌክትሪክ ቦርዶች እና መሣሪያዎች",
      "items": [
        {"no": 213, "item": "3*2.5 sq.mm cable", "itemAm": "3*2.5 ካሬ ሚሜ ኬብል", "unit": "Mtr", "march2026": "183.52", "june2026": "419.48", "change": "+129%"},
        {"no": 214, "item": "3*4 sq.mm cable", "itemAm": "3*4 ካሬ ሚሜ ኬብል", "unit": "Mtr", "march2026": "288.39", "june2026": "629.22", "change": "+118%"},
        {"no": 215, "item": "3 x 185/95mm sq.", "itemAm": "3 x 185/95ሚሜ ካሬ", "unit": "Mtr", "march2026": "14,419.57", "june2026": "31,373.48", "change": "+118%"},
        {"no": 216, "item": "1.5sq.mm cable", "itemAm": "1.5 ካሬ ሚሜ ኬብል", "unit": "Roll", "march2026": "3,823.37", "june2026": "6,707.28", "change": "+75%"},
        {"no": 217, "item": "5*4 sq.mm cable", "itemAm": "5*4 ካሬ ሚሜ ኬብል", "unit": "Mtr", "march2026": "637.96", "june2026": "908.87", "change": "+42%"},
        {"no": 218, "item": "4*10 FLEX", "itemAm": "4*10 ፍሌክስ", "unit": "Mtr", "march2026": "1,171.04", "june2026": "1,835.22", "change": "+57%"}
      ]
    },
    {
      "category": "LIGHTING, BREAKERS & SWITCHES",
      "categoryAm": "መብራት፣ ብሬከሮች እና ስዊቾች",
      "items": [
        {"no": 219, "item": "3M HEIGHT", "itemAm": "3ሜ ከፍታ", "unit": "NO", "march2026": "21,847.83", "june2026": "21,847.83", "change": "0%"},
        {"no": 220, "item": "6M HEIGHT", "itemAm": "6ሜ ከፍታ", "unit": "NO", "march2026": "28,839.13", "june2026": "28,839.13", "change": "0%"},
        {"no": 221, "item": "8M HEIGHT", "itemAm": "8ሜ ከፍታ", "unit": "NO", "march2026": "55,930.43", "june2026": "55,930.43", "change": "0%"},
        {"no": 222, "item": "12M HEIGHT", "itemAm": "12ሜ ከፍታ", "unit": "NO", "march2026": "104,869.57", "june2026": "104,869.57", "change": "0%"},
        {"no": 223, "item": "10-32A/1P ACB ICU= 6KA", "itemAm": "10-32A/1P ACB ICU= 6KA", "unit": "NO", "march2026": "257.80", "june2026": "257.80", "change": "0%"},
        {"no": 224, "item": "125A/3P MCCB “", "itemAm": "125A/3P MCCB “", "unit": "NO", "march2026": "5,658.59", "june2026": "5,658.59", "change": "0%"},
        {"no": 225, "item": "CONTACTOR 25/3P", "itemAm": "ኮንታክተር 25/3P", "unit": "NO", "march2026": "2,971.30", "june2026": "2,971.30", "change": "0%"},
        {"no": 226, "item": "FLUSH MOUNTED SINGLE", "itemAm": "ፍላሽ የሚገጠም ነጠላ", "unit": "NO", "march2026": "305.87", "june2026": "305.87", "change": "0%"}
      ]
    }
 
  ]
};END
cat > src/data/goods.js << 'END'
// src/data/goods.js
import { putAll, getAll, put } from './db.js';
import { GOODS } from './goods-data.js';

function normalizeGoodsItem(catId, item, idx) {
  const raw = String(item.june2026 || '').replace(/,/g, '').trim();
  const price = raw === '' ? null : parseFloat(raw);
  return {
    id: 'goods:' + catId + ':' + (item.no || idx),
    source: 'goods',
    categoryId: 'goods:' + catId,
    code: String(item.no || ''),
    description: item.item || '',
    descriptionAm: item.itemAm || '',
    tenderAliases: [],
    unit: item.unit || '',
    basePrice: price,
    contractorPrice: price,
    page: 0
  };
}

export async function importGoods(json) {
  const src = json || GOODS;
  if (!src || !Array.isArray(src.categories)) throw new Error('Invalid goods data');
  const categories = [];
  const items = [];
  src.categories.forEach(cat => {
    const catId = String(cat.category);
    categories.push({
      id: 'goods:' + catId,
      source: 'goods',
      title: cat.category,
      titleAm: cat.categoryAm || cat.category,
      itemCount: (cat.items || []).length
    });
    (cat.items || []).forEach((item, idx) => items.push(normalizeGoodsItem(catId, item, idx)));
  });
  await putAll('ratebook_categories', categories);
  await putAll('ratebook_items', items);
  await put('meta', {
    key: 'goods_source',
    source: src.source || '',
    importedAt: new Date().toISOString(),
    categoryCount: categories.length,
    itemCount: items.length
  });
  return { categoryCount: categories.length, itemCount: items.length };
}

export async function getGoodsMeta() {
  const rows = await getAll('meta');
  return rows.find(r => r.key === 'goods_source') || null;
}END
cat > src/data/images.js << 'END'
import { put, get, del } from './db.js';

// id -> object URL, so we only create one per blob per session
const urlCache = new Map();

// Save a File/Blob for a product, return nothing (the product stores imageId)
export async function saveProductImage(productId, file) {
  if (!file) throw new Error('No file.');
  await put('product_images', {
    id: productId,
    blob: file,
    type: file.type || 'image/jpeg',
    updatedAt: Date.now()
  });
  // Drop any cached URL so it re-resolves to the new blob
  revokeProductImage(productId);
}

export async function deleteProductImage(productId) {
  revokeProductImage(productId);
  try { await del('product_images', productId); } catch (e) {}
}

function revokeProductImage(productId) {
  const url = urlCache.get(productId);
  if (url) { URL.revokeObjectURL(url); urlCache.delete(productId); }
}

// Get an object URL for a product's image, or null if none
export async function getProductImageURL(productId) {
  if (!productId) return null;
  if (urlCache.has(productId)) return urlCache.get(productId);
  const row = await get('product_images', productId);
  if (!row || !row.blob) return null;
  const url = URL.createObjectURL(row.blob);
  urlCache.set(productId, url);
  return url;
}

// Get every stored image as { productId, url } — used by the public catalog
export async function getAllProductImageURLs(ids) {
  const out = {};
  for (const id of ids) {
    const url = await getProductImageURL(id);
    if (url) out[id] = url;
  }
  return out;
}END
cat > src/data/match.js << 'END'
// Bilingual (English + Amharic) fuzzy matcher for rate-book lookup.
// Aliases (tenderAliases) are treated as extra descriptions on each item.
//
// Anti-false-positive safeguards:
//  - Extended English stop-words cover attribute/shape modifiers (double, thick, coated…)
//  - Substring bonus requires >= 2 hits (one shared word is not enough)
//  - Substring bonus requires tokens >= 4 chars (avoids 3-char collisions like "nut" / "m10")
//  - Cross-category match is refused if token sets share nothing

const STOP_EN = new Set([
  'of','and','the','for','with','to','from','on','in','at','by','or','a','an',
  'pcs','each','unit','no','nos','type','size','dia','mm','cm','m','kg','ton','tone',
  'thick','inch','in',
  // attribute / shape words that appear across categories
  'double','single','thick','thin','long','short','large','small','big','mini',
  'heavy','light','wide','narrow','high','low','new','old','standard','normal',
  'coated','galvanized','painted','polished'
]);

const STOP_AM = new Set([
  'እና','ወይም','ከ','ለ','በ','የ','ላይ','ውስጥ','ጋር','ነው','ና','ም','ን','ኦ','፣','።',
  // shape words that cause cross-category false positives
  'ድርብ','ነጠላ','ትልቅ','ትንሽ','ረዥም','አጭር','ከባድ','ቀላል','ሰፊ','ጠባብ'
]);

const UNIT_SYNONYMS = {
  'pcs': 'each', 'nos': 'each', 'no': 'each',
  'quintal': 'quintal', 'qtl': 'quintal',
  'ton': 'ton', 'tone': 'ton', 't': 'ton',
  'm3': 'm³', 'm³': 'm³', 'cum': 'm³',
  'm2': 'm²', 'm²': 'm²', 'sqm': 'm²',
  'ml': 'ml', 'lm': 'ml',
  'kg': 'kg'
};

// ---------- Tokenizers ----------

function tokenizeEn(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[^a-z0-9.]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .filter(t => t.length > 1 && !STOP_EN.has(t));
}

function tokenizeAm(text) {
  return String(text || '')
    .replace(/[^\u1200-\u137F\s]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .filter(t => t.length > 1 && !STOP_AM.has(t));
}

function normUnit(u) {
  const k = String(u || '').toLowerCase().trim();
  return UNIT_SYNONYMS[k] || k;
}

function scoreTokens(a, b) {
  const aSet = new Set(a), bSet = new Set(b);
  let inter = 0;
  for (const t of aSet) if (bSet.has(t)) inter++;
  if (inter === 0) return 0;
  const union = aSet.size + bSet.size - inter;
  return inter / union;
}

// ---------- Index ----------

export function buildIndex(rateItems) {
  return rateItems.map(r => {
    const aliases = r.tenderAliases || [];
    return {
      item: r,
      tokensEn: tokenizeEn(r.description),
      tokensAm: r.descriptionAm ? tokenizeAm(r.descriptionAm) : [],
      aliasTokensEn: aliases.map(a => tokenizeEn(a)),
      aliasTokensAm: aliases.map(a => tokenizeAm(a)),
      unit: normUnit(r.unit),
      lowerEn: String(r.description || '').toLowerCase(),
      lowerAm: String(r.descriptionAm || '').toLowerCase(),
      lowerAliases: aliases.map(a => String(a).toLowerCase())
    };
  });
}

// Score one pair of token sets with the guarded substring bonus.
// Requires >= 2 substring hits on tokens of length >= 4 to apply the boost.
function scorePair(tTokens, eTokens, eLower, isAmharic) {
  const base = scoreTokens(tTokens, eTokens);

  const minLen = 4;
  let subHits = 0;
  for (const tok of tTokens) {
    if (tok.length < minLen) continue;
    if (eLower.includes(tok)) subHits++;
  }

  let s = base;
  if (subHits >= 2) {
    s = Math.max(s, Math.min(0.9, 0.4 + subHits * 0.1));
  }

  const tStr = tTokens.join(' ');
  if (tStr.length >= (isAmharic ? 4 : 6) && eLower.includes(tStr)) {
    s = Math.min(1, s + 0.35);
  }
  return s;
}

// ---------- Single match ----------

export function matchOne(tenderItem, index, opts = {}) {
  const minScore = opts.minScore ?? 0.35;
  const rawDesc = tenderItem.description || tenderItem.name || '';
  const tEn = tokenizeEn(rawDesc);
  const tAm = tokenizeAm(rawDesc);
  const tUnit = normUnit(tenderItem.unit || tenderItem.unitMeasure);
  const isAmharic = tAm.length > 0 && tEn.length < tAm.length;

  if (tEn.length === 0 && tAm.length === 0) {
    return { rate: 0, matched: false, score: 0 };
  }

  let best = null;
  for (const entry of index) {
    if (!entry.item.contractorPrice) continue;
    if (entry.unit && tUnit && entry.unit !== tUnit) continue;

    // Compute all candidate scores first
    let s = 0;

    if (isAmharic) {
      if (entry.tokensAm.length > 0) {
        s = Math.max(s, scorePair(tAm, entry.tokensAm, entry.lowerAm, true));
      }
      for (let i = 0; i < entry.aliasTokensAm.length; i++) {
        if (entry.aliasTokensAm[i].length === 0) continue;
        s = Math.max(s, scorePair(tAm, entry.aliasTokensAm[i], entry.lowerAliases[i] || '', true));
      }
    } else {
      if (entry.tokensEn.length > 0) {
        s = Math.max(s, scorePair(tEn, entry.tokensEn, entry.lowerEn, false));
      }
      for (let i = 0; i < entry.aliasTokensEn.length; i++) {
        if (entry.aliasTokensEn[i].length === 0) continue;
        s = Math.max(s, scorePair(tEn, entry.aliasTokensEn[i], entry.lowerAliases[i] || '', false));
      }
    }

    // Hard gate: a real match must have either
    //   (a) at least one shared token (Jaccard > 0 on either primary side), or
    //   (b) a substring hit that already cleared the >= 2 threshold.
    // Since scorePair returns 0 when neither applies, this is implicitly enforced.
    // Nothing extra needed here — s stays 0 in that case.

    if (!best || s > best.score) best = { score: s, entry };
  }

  if (!best || best.score < minScore) {
    return { rate: 0, matched: false, score: best ? best.score : 0 };
  }
  return {
    rate: best.entry.item.contractorPrice,
    matched: true,
    score: best.score,
    matchItem: best.entry.item
  };
}

// ---------- Bulk match ----------

export function matchAll(tenderItems, index, opts) {
  return tenderItems.map(it => {
    if (it.rate > 0) return it;
    const m = matchOne(it, index, opts);
    return {
      ...it,
      rate: m.rate,
      _match: {
        matched: m.matched,
        score: m.score,
        source: m.matchItem
      }
    };
  });
}END
cat > src/data/materials.js << 'END'
// Bundled rate book — Addis Ababa Design and Construction Works Bureau
// 2018 4th Quarter, Direct Cost Only, ETB
// PASTE YOUR DATA BELOW, REPLACING THE EXAMPLE CATEGORY
export const MATBOOK = {
  "document": "construction-materials-ratebook.pdf",
  "source": "Addis Ababa Design and Construction Works Bureau",
  "quarter": "2018 4th Quarter (Direct Cost Only)",
  "currency": "ETB",
  "categories": [
    {
      "id": "M1",
      "title": "CEMENT, AGGREGATE & SAND",
      "titleAm": "ሲሚንቶ፣ ድምር እና አሸዋ",
      "items": [
        {"code":"M1.1","description":"Ordinary Portland Cement (OPC) 42.5R — 50kg bag","descriptionAm":"መደበኛ ፖርትላንድ ሲሚንቶ (OPC) 42.5R — 50ኪግ ከረጢት","unit":"bag","price":"1,450.00"},
        {"code":"M1.2","description":"Ordinary Portland Cement (OPC) 32.5N — 50kg bag","descriptionAm":"መደበኛ ፖርትላንድ ሲሚንቶ (OPC) 32.5N — 50ኪግ ከረጢት","unit":"bag","price":"1,320.00"},
        {"code":"M1.3","description":"Pozzolana Portland Cement (PPC) 32.5 — 50kg bag","descriptionAm":"ፖዞላና ፖርትላንድ ሲሚንቶ (PPC) 32.5 — 50ኪግ ከረጢት","unit":"bag","price":"1,250.00"},
        {"code":"M1.4","description":"White cement — 40kg bag","descriptionAm":"ነጭ ሲሚንቶ — 40ኪግ ከረጢት","unit":"bag","price":"2,800.00"},
        {"code":"M1.5","description":"Crushed stone aggregate 10–20mm (01)","descriptionAm":"የተፈጨ የድንጋይ ድምር 10–20ሚሜ (01)","unit":"m³","price":"1,850.00"},
        {"code":"M1.6","description":"Crushed stone aggregate 5–10mm (02)","descriptionAm":"የተፈጨ የድንጋይ ድምር 5–10ሚሜ (02)","unit":"m³","price":"1,780.00"},
        {"code":"M1.7","description":"Crushed stone dust (03)","descriptionAm":"የተፈጨ የድንጋይ ዱቄት (03)","unit":"m³","price":"1,300.00"},
        {"code":"M1.8","description":"Washed river sand","descriptionAm":"የታጠበ የወንዝ አሸዋ","unit":"m³","price":"1,950.00"},
        {"code":"M1.9","description":"Pit sand (unwashed)","descriptionAm":"የጉድጓድ አሸዋ (ያልታጠበ)","unit":"m³","price":"1,250.00"},
        {"code":"M1.10","description":"Selected fill material","descriptionAm":"የተመረጠ የመሙያ ቁሳቁስ","unit":"m³","price":"650.00"},
        {"code":"M1.11","description":"Red ash (pumice)","descriptionAm":"ቀይ አመድ (ፑሚስ)","unit":"m³","price":"1,100.00"},
        {"code":"M1.12","description":"Lime (hydrated) — 25kg bag","descriptionAm":"ኖራ (ሃይድሬትድ) — 25ኪግ ከረጢት","unit":"bag","price":"480.00"}
      ]
    },
    {
      "id": "M2",
      "title": "REINFORCEMENT STEEL & METAL",
      "titleAm": "የማጠናከሪያ ብረት እና ብረታ ብረት",
      "items": [
        {"code":"M2.1","description":"Deformed rebar Grade 60 — dia. 6mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 6ሚሜ","unit":"kg","price":"128.00"},
        {"code":"M2.2","description":"Deformed rebar Grade 60 — dia. 8mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 8ሚሜ","unit":"kg","price":"125.00"},
        {"code":"M2.3","description":"Deformed rebar Grade 60 — dia. 10mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 10ሚሜ","unit":"kg","price":"124.00"},
        {"code":"M2.4","description":"Deformed rebar Grade 60 — dia. 12mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 12ሚሜ","unit":"kg","price":"123.00"},
        {"code":"M2.5","description":"Deformed rebar Grade 60 — dia. 14mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 14ሚሜ","unit":"kg","price":"123.00"},
        {"code":"M2.6","description":"Deformed rebar Grade 60 — dia. 16mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 16ሚሜ","unit":"kg","price":"122.50"},
        {"code":"M2.7","description":"Deformed rebar Grade 60 — dia. 20mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 20ሚሜ","unit":"kg","price":"122.00"},
        {"code":"M2.8","description":"Deformed rebar Grade 60 — dia. 24mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 24ሚሜ","unit":"kg","price":"122.00"},
        {"code":"M2.9","description":"Deformed rebar Grade 60 — dia. 32mm","descriptionAm":"ዲፎርምድ ሪባር ግሬድ 60 — ዲያሜትር 32ሚሜ","unit":"kg","price":"122.00"},
        {"code":"M2.10","description":"Binding wire (soft annealed) 1.2mm","descriptionAm":"የማሰሪያ ሽቦ (ለስላሳ አኒልድ) 1.2ሚሜ","unit":"kg","price":"165.00"},
        {"code":"M2.11","description":"RHS steel section 40x40x2mm","descriptionAm":"RHS የብረት ክፍል 40x40x2ሚሜ","unit":"kg","price":"135.00"},
        {"code":"M2.12","description":"RHS steel section 50x50x2.5mm","descriptionAm":"RHS የብረት ክፍል 50x50x2.5ሚሜ","unit":"kg","price":"132.00"},
        {"code":"M2.13","description":"Angle iron 40x40x3mm","descriptionAm":"አንግል ብረት 40x40x3ሚሜ","unit":"kg","price":"128.00"},
        {"code":"M2.14","description":"Angle iron 50x50x5mm","descriptionAm":"አንግል ብረት 50x50x5ሚሜ","unit":"kg","price":"126.00"},
        {"code":"M2.15","description":"Flat bar 25x3mm","descriptionAm":"ፍላት ባር 25x3ሚሜ","unit":"kg","price":"130.00"},
        {"code":"M2.16","description":"CHS steel pipe dia. 48mm x 2.5mm","descriptionAm":"CHS የብረት ቧንቧ ዲያሜትር 48ሚሜ x 2.5ሚሜ","unit":"kg","price":"138.00"},
        {"code":"M2.17","description":"Galvanized corrugated iron sheet G-28 (0.4mm)","descriptionAm":"ጋልቫናይዝድ ኮርጌትድ ብረት ሉህ G-28 (0.4ሚሜ)","unit":"m²","price":"620.00"},
        {"code":"M2.18","description":"Galvanized corrugated iron sheet G-30 (0.35mm)","descriptionAm":"ጋልቫናይዝድ ኮርጌትድ ብረት ሉህ G-30 (0.35ሚሜ)","unit":"m²","price":"540.00"},
        {"code":"M2.19","description":"Galvanized corrugated iron sheet G-32 (0.3mm)","descriptionAm":"ጋልቫናይዝድ ኮርጌትድ ብረት ሉህ G-32 (0.3ሚሜ)","unit":"m²","price":"470.00"},
        {"code":"M2.20","description":"Lamera sheet 1mm thick","descriptionAm":"ላሜራ ሉህ 1ሚሜ ውፍረት","unit":"m²","price":"1,350.00"}
      ]
    },
    {
      "id": "M3",
      "title": "MASONRY & BLOCK MATERIALS",
      "titleAm": "የግንበኝነት እና የብሎክ ቁሳቁሶች",
      "items": [
        {"code":"M3.1","description":"HCB hollow block 10cm thick (class C)","descriptionAm":"HCB ባዶ ብሎክ 10ሴንቲ ሜትር ውፍረት (ክላስ C)","unit":"pcs","price":"32.00"},
        {"code":"M3.2","description":"HCB hollow block 15cm thick (class C)","descriptionAm":"HCB ባዶ ብሎክ 15ሴንቲ ሜትር ውፍረት (ክላስ C)","unit":"pcs","price":"48.00"},
        {"code":"M3.3","description":"HCB hollow block 20cm thick (class C)","descriptionAm":"HCB ባዶ ብሎክ 20ሴንቲ ሜትር ውፍረት (ክላስ C)","unit":"pcs","price":"62.00"},
        {"code":"M3.4","description":"HCB hollow block 20cm thick (class A)","descriptionAm":"HCB ባዶ ብሎክ 20ሴንቲ ሜትር ውፍረት (ክላስ A)","unit":"pcs","price":"78.00"},
        {"code":"M3.5","description":"Solid concrete block 10cm thick","descriptionAm":"ሶሊድ ኮንክሪት ብሎክ 10ሴንቲ ሜትር ውፍረት","unit":"pcs","price":"42.00"},
        {"code":"M3.6","description":"Solid concrete block 15cm thick","descriptionAm":"ሶሊድ ኮንክሪት ብሎክ 15ሴንቲ ሜትር ውፍረት","unit":"pcs","price":"58.00"},
        {"code":"M3.7","description":"Solid concrete block 20cm thick","descriptionAm":"ሶሊድ ኮንክሪት ብሎክ 20ሴንቲ ሜትር ውፍረት","unit":"pcs","price":"75.00"},
        {"code":"M3.8","description":"Red clay brick (single)","descriptionAm":"ቀይ ሸክላ ጡብ (ነጠላ)","unit":"pcs","price":"18.00"},
        {"code":"M3.9","description":"Red clay brick (double)","descriptionAm":"ቀይ ሸክላ ጡብ (ድርብ)","unit":"pcs","price":"26.00"},
        {"code":"M3.10","description":"Dressed basalt stone (for masonry)","descriptionAm":"የተጠረበ የባዝልት ድንጋይ (ለግንበኝነት)","unit":"m³","price":"2,400.00"},
        {"code":"M3.11","description":"Rough basalt stone (for masonry)","descriptionAm":"ሻካራ የባዝልት ድንጋይ (ለግንበኝነት)","unit":"m³","price":"1,500.00"},
        {"code":"M3.12","description":"Ambo stone (tuff) for cladding","descriptionAm":"የአምቦ ድንጋይ (ቱፍ) ለሽፋን","unit":"m²","price":"850.00"},
        {"code":"M3.13","description":"Chipwood board 8mm thick","descriptionAm":"ቺፕዉድ ቦርድ 8ሚሜ ውፍረት","unit":"m²","price":"420.00"},
        {"code":"M3.14","description":"MDF board 18mm thick (laminated)","descriptionAm":"MDF ቦርድ 18ሚሜ ውፍረት (ላሚኔትድ)","unit":"m²","price":"1,250.00"},
        {"code":"M3.15","description":"Gypsum board 12mm thick","descriptionAm":"ጂፕሰም ቦርድ 12ሚሜ ውፍረት","unit":"m²","price":"380.00"}
      ]
    },
    {
      "id": "M4",
      "title": "TIMBER & WOOD PRODUCTS",
      "titleAm": "እንጨት እና የእንጨት ውጤቶች",
      "items": [
        {"code":"M4.1","description":"Eucalyptus pole dia. 8–10cm","descriptionAm":"የባህር ዛፍ ምሰሶ ዲያሜትር 8–10ሴንቲ ሜትር","unit":"ml","price":"85.00"},
        {"code":"M4.2","description":"Eucalyptus pole dia. 10–12cm","descriptionAm":"የባህር ዛፍ ምሰሶ ዲያሜትር 10–12ሴንቲ ሜትር","unit":"ml","price":"120.00"},
        {"code":"M4.3","description":"Shashemene batten 5x4cm","descriptionAm":"ሻሸመኔ ባትን 5x4ሴንቲ ሜትር","unit":"ml","price":"28.00"},
        {"code":"M4.4","description":"Shashemene batten 5x7cm","descriptionAm":"ሻሸመኔ ባትን 5x7ሴንቲ ሜትር","unit":"ml","price":"48.00"},
        {"code":"M4.5","description":"Zigba purlin 4x5cm","descriptionAm":"ዚግባ ፐርላይን 4x5ሴንቲ ሜትር","unit":"ml","price":"65.00"},
        {"code":"M4.6","description":"Zigba purlin 5x7cm","descriptionAm":"ዚግባ ፐርላይን 5x7ሴንቲ ሜትር","unit":"ml","price":"95.00"},
        {"code":"M4.7","description":"Tsid (Tid) timber 1cm thick","descriptionAm":"ጽድ (ጥድ) እንጨት 1ሴንቲ ሜትር ውፍረት","unit":"m²","price":"680.00"},
        {"code":"M4.8","description":"Plywood 4mm thick","descriptionAm":"ፕላይዉድ 4ሚሜ ውፍረት","unit":"m²","price":"520.00"},
        {"code":"M4.9","description":"Plywood 18mm thick (fair-faced)","descriptionAm":"ፕላይዉድ 18ሚሜ ውፍረት (ፌር-ፌስድ)","unit":"m²","price":"1,450.00"},
        {"code":"M4.10","description":"Mahogany plywood 40mm (door grade)","descriptionAm":"ማሆጋኒ ፕላይዉድ 40ሚሜ (የበር ደረጃ)","unit":"m²","price":"4,200.00"},
        {"code":"M4.11","description":"Kerrero facia board 25cm wide","descriptionAm":"ቄረሮ ፋሺያ ቦርድ 25ሴንቲ ሜትር ስፋት","unit":"ml","price":"380.00"},
        {"code":"M4.12","description":"Kerrero facia board 30cm wide","descriptionAm":"ቄረሮ ፋሺያ ቦርድ 30ሴንቲ ሜትር ስፋት","unit":"ml","price":"450.00"},
        {"code":"M4.13","description":"Wood preservative (anti-termite)","descriptionAm":"የእንጨት መከላከያ (ጸረ-ምስጥ)","unit":"lt","price":"320.00"}
      ]
    },
    {
      "id": "M5",
      "title": "ROOFING MATERIALS",
      "titleAm": "የጣሪያ ቁሳቁሶች",
      "items": [
        {"code":"M5.1","description":"EGA 300 galvanized roof sheet 0.30mm","descriptionAm":"EGA 300 ጋልቫናይዝድ የጣሪያ ሉህ 0.30ሚሜ","unit":"m²","price":"780.00"},
        {"code":"M5.2","description":"EGA 300 galvanized roof sheet 0.40mm","descriptionAm":"EGA 300 ጋልቫናይዝድ የጣሪያ ሉህ 0.40ሚሜ","unit":"m²","price":"980.00"},
        {"code":"M5.3","description":"EGA 400 galvanized roof sheet 0.40mm","descriptionAm":"EGA 400 ጋልቫናይዝድ የጣሪያ ሉህ 0.40ሚሜ","unit":"m²","price":"1,100.00"},
        {"code":"M5.4","description":"EGA 500 galvanized roof sheet 0.50mm","descriptionAm":"EGA 500 ጋልቫናይዝድ የጣሪያ ሉህ 0.50ሚሜ","unit":"m²","price":"1,320.00"},
        {"code":"M5.5","description":"Pre-painted (colour) roof sheet 0.40mm","descriptionAm":"ቅድመ-ቀለም (ባለቀለም) የጣሪያ ሉህ 0.40ሚሜ","unit":"m²","price":"1,450.00"},
        {"code":"M5.6","description":"Pre-painted (colour) roof sheet 0.50mm","descriptionAm":"ቅድመ-ቀለም (ባለቀለም) የጣሪያ ሉህ 0.50ሚሜ","unit":"m²","price":"1,680.00"},
        {"code":"M5.7","description":"Roof ridge (G-28) 33cm dev. length","descriptionAm":"የጣሪያ ሪጅ (G-28) 33ሴንቲ ሜትር dev. ርዝመት","unit":"ml","price":"520.00"},
        {"code":"M5.8","description":"Roof ridge (G-30) 50cm dev. length","descriptionAm":"የጣሪያ ሪጅ (G-30) 50ሴንቲ ሜትር dev. ርዝመት","unit":"ml","price":"610.00"},
        {"code":"M5.9","description":"Galvanized flashing (G-28) 50cm dev. length","descriptionAm":"ጋልቫናይዝድ ፍላሽንግ (G-28) 50ሴንቲ ሜትር dev. ርዝመት","unit":"ml","price":"580.00"},
        {"code":"M5.10","description":"Galvanized copping (G-28) 33cm dev. length","descriptionAm":"ጋልቫናይዝድ ኮፒንግ (G-28) 33ሴንቲ ሜትር dev. ርዝመት","unit":"ml","price":"540.00"},
        {"code":"M5.11","description":"Euro tile roof cover","descriptionAm":"የዩሮ ታይል ጣሪያ ሽፋን","unit":"m²","price":"720.00"},
        {"code":"M5.12","description":"Asbestos roof sheet","descriptionAm":"የአስቤስቶስ የጣሪያ ሉህ","unit":"m²","price":"480.00"},
        {"code":"M5.13","description":"Transparent fiber roof sheet 2mm (corrugated)","descriptionAm":"ግልጽ ፋይበር የጣሪያ ሉህ 2ሚሜ (ኮርጌትድ)","unit":"m²","price":"620.00"},
        {"code":"M5.14","description":"PVC down pipe dia. 75mm","descriptionAm":"PVC የውሃ ማውረጃ ቧንቧ ዲያሜትር 75ሚሜ","unit":"ml","price":"340.00"},
        {"code":"M5.15","description":"PVC down pipe dia. 110mm","descriptionAm":"PVC የውሃ ማውረጃ ቧንቧ ዲያሜትር 110ሚሜ","unit":"ml","price":"420.00"},
        {"code":"M5.16","description":"Roofing nail (umbrella head) 3\"","descriptionAm":"የጣሪያ ምስማር (ጃንጥላ ራስ) 3\"","unit":"kg","price":"185.00"},
        {"code":"M5.17","description":"Roofing screw with washer (self-drilling)","descriptionAm":"የጣሪያ ብሎን ከዋሽር ጋር (ራሱን የሚቆፍር)","unit":"pcs","price":"8.50"}
      ]
    },
    {
      "id": "M6",
      "title": "FASTENERS, NAILS & FIXINGS",
      "titleAm": "ማያያዣዎች፣ ምስማሮች እና መገጣጠሚያዎች",
      "items": [
        {"code":"M6.1","description":"Common wire nail 1\"","descriptionAm":"የተለመደ ሽቦ ምስማር 1\"","unit":"kg","price":"145.00"},
        {"code":"M6.2","description":"Common wire nail 1.5\"","descriptionAm":"የተለመደ ሽቦ ምስማር 1.5\"","unit":"kg","price":"142.00"},
        {"code":"M6.3","description":"Common wire nail 2\"","descriptionAm":"የተለመደ ሽቦ ምስማር 2\"","unit":"kg","price":"140.00"},
        {"code":"M6.4","description":"Common wire nail 3\"","descriptionAm":"የተለመደ ሽቦ ምስማር 3\"","unit":"kg","price":"138.00"},
        {"code":"M6.5","description":"Common wire nail 4\"","descriptionAm":"የተለመደ ሽቦ ምስማር 4\"","unit":"kg","price":"136.00"},
        {"code":"M6.6","description":"Concrete nail 2\"","descriptionAm":"የኮንክሪት ምስማር 2\"","unit":"kg","price":"175.00"},
        {"code":"M6.7","description":"Concrete nail 3\"","descriptionAm":"የኮንክሪት ምስማር 3\"","unit":"kg","price":"172.00"},
        {"code":"M6.8","description":"Galvanized wire nail 2\"","descriptionAm":"ጋልቫናይዝድ ሽቦ ምስማር 2\"","unit":"kg","price":"165.00"},
        {"code":"M6.9","description":"Wood screw 1\" (box)","descriptionAm":"የእንጨት ብሎን 1\" (ሳጥን)","unit":"box","price":"480.00"},
        {"code":"M6.10","description":"Wood screw 2\" (box)","descriptionAm":"የእንጨት ብሎን 2\" (ሳጥን)","unit":"box","price":"620.00"},
        {"code":"M6.11","description":"Self-tapping screw 1\" (box)","descriptionAm":"ራሱን የሚቆፍር ብሎን 1\" (ሳጥን)","unit":"box","price":"550.00"},
        {"code":"M6.12","description":"Anchor bolt dia. 16mm x 400mm (J-bolt)","descriptionAm":"አንከር ቦልት ዲያሜትር 16ሚሜ x 400ሚሜ (J-ቦልት)","unit":"pcs","price":"145.00"},
        {"code":"M6.13","description":"Anchor bolt dia. 20mm x 400mm","descriptionAm":"አንከር ቦልት ዲያሜትር 20ሚሜ x 400ሚሜ","unit":"pcs","price":"210.00"},
        {"code":"M6.14","description":"Rawl plug (plastic) dia. 8mm","descriptionAm":"ራውል ፕላግ (ፕላስቲክ) ዲያሜትር 8ሚሜ","unit":"pcs","price":"2.50"},
        {"code":"M6.15","description":"Rawl plug (plastic) dia. 10mm","descriptionAm":"ራውል ፕላግ (ፕላስቲክ) ዲያሜትር 10ሚሜ","unit":"pcs","price":"3.50"}
      ]
    },
    {
      "id": "M7",
      "title": "PLUMBING MATERIALS",
      "titleAm": "የቧንቧ ቁሳቁሶች",
      "items": [
        {"code":"M7.1","description":"PPR pipe dia. 20mm (1/2\")","descriptionAm":"PPR ቧንቧ ዲያሜትር 20ሚሜ (1/2\")","unit":"ml","price":"145.00"},
        {"code":"M7.2","description":"PPR pipe dia. 25mm (3/4\")","descriptionAm":"PPR ቧንቧ ዲያሜትር 25ሚሜ (3/4\")","unit":"ml","price":"195.00"},
        {"code":"M7.3","description":"PPR pipe dia. 32mm (1\")","descriptionAm":"PPR ቧንቧ ዲያሜትር 32ሚሜ (1\")","unit":"ml","price":"280.00"},
        {"code":"M7.4","description":"PPR pipe dia. 40mm (11/4\")","descriptionAm":"PPR ቧንቧ ዲያሜትር 40ሚሜ (11/4\")","unit":"ml","price":"420.00"},
        {"code":"M7.5","description":"PPR pipe dia. 50mm (11/2\")","descriptionAm":"PPR ቧንቧ ዲያሜትር 50ሚሜ (11/2\")","unit":"ml","price":"620.00"},
        {"code":"M7.6","description":"Galvanized steel pipe 15mm (1/2\")","descriptionAm":"ጋልቫናይዝድ ብረት ቧንቧ 15ሚሜ (1/2\")","unit":"ml","price":"480.00"},
        {"code":"M7.7","description":"Galvanized steel pipe 20mm (3/4\")","descriptionAm":"ጋልቫናይዝድ ብረት ቧንቧ 20ሚሜ (3/4\")","unit":"ml","price":"580.00"},
        {"code":"M7.8","description":"Galvanized steel pipe 25mm (1\")","descriptionAm":"ጋልቫናይዝድ ብረት ቧንቧ 25ሚሜ (1\")","unit":"ml","price":"720.00"},
        {"code":"M7.9","description":"Galvanized steel pipe 50mm (2\")","descriptionAm":"ጋልቫናይዝድ ብረት ቧንቧ 50ሚሜ (2\")","unit":"ml","price":"1,350.00"},
        {"code":"M7.10","description":"UPVC pipe dia. 50mm (waste)","descriptionAm":"UPVC ቧንቧ ዲያሜትር 50ሚሜ (ቆሻሻ)","unit":"ml","price":"185.00"},
        {"code":"M7.11","description":"UPVC pipe dia. 75mm (waste)","descriptionAm":"UPVC ቧንቧ ዲያሜትር 75ሚሜ (ቆሻሻ)","unit":"ml","price":"265.00"},
        {"code":"M7.12","description":"UPVC pipe dia. 110mm (soil)","descriptionAm":"UPVC ቧንቧ ዲያሜትር 110ሚሜ (ሶይል)","unit":"ml","price":"385.00"},
        {"code":"M7.13","description":"UPVC pipe dia. 160mm (soil)","descriptionAm":"UPVC ቧንቧ ዲያሜትር 160ሚሜ (ሶይል)","unit":"ml","price":"680.00"},
        {"code":"M7.14","description":"UPVC pipe dia. 200mm (soil)","descriptionAm":"UPVC ቧንቧ ዲያሜትር 200ሚሜ (ሶይል)","unit":"ml","price":"950.00"},
        {"code":"M7.15","description":"HDPE pipe dia. 25mm","descriptionAm":"HDPE ቧንቧ ዲያሜትር 25ሚሜ","unit":"ml","price":"165.00"},
        {"code":"M7.16","description":"HDPE pipe dia. 32mm","descriptionAm":"HDPE ቧንቧ ዲያሜትር 32ሚሜ","unit":"ml","price":"220.00"},
        {"code":"M7.17","description":"PPR elbow 20mm","descriptionAm":"PPR ክርን 20ሚሜ","unit":"pcs","price":"28.00"},
        {"code":"M7.18","description":"PPR elbow 25mm","descriptionAm":"PPR ክርን 25ሚሜ","unit":"pcs","price":"38.00"},
        {"code":"M7.19","description":"PPR tee 20mm","descriptionAm":"PPR ቲ 20ሚሜ","unit":"pcs","price":"35.00"},
        {"code":"M7.20","description":"PPR coupling 20mm","descriptionAm":"PPR አገናኝ 20ሚሜ","unit":"pcs","price":"22.00"},
        {"code":"M7.21","description":"UPVC elbow 110mm","descriptionAm":"UPVC ክርን 110ሚሜ","unit":"pcs","price":"95.00"},
        {"code":"M7.22","description":"UPVC tee 110mm","descriptionAm":"UPVC ቲ 110ሚሜ","unit":"pcs","price":"120.00"},
        {"code":"M7.23","description":"UPVC coupling 110mm","descriptionAm":"UPVC አገናኝ 110ሚሜ","unit":"pcs","price":"75.00"},
        {"code":"M7.24","description":"PPR welding machine (hot fusion)","descriptionAm":"PPR ብየዳ ማሽን (ሙቅ ውህደት)","unit":"pcs","price":"6,500.00"}
      ]
    },
    {
      "id": "M8",
      "title": "VALVES & FITTINGS",
      "titleAm": "ቫልቮች እና መገጣጠሚያዎች",
      "items": [
        {"code":"M8.1","description":"Brass gate valve PN16 1/2\"","descriptionAm":"የናስ ጌት ቫልቭ PN16 1/2\"","unit":"pcs","price":"720.00"},
        {"code":"M8.2","description":"Brass gate valve PN16 3/4\"","descriptionAm":"የናስ ጌት ቫልቭ PN16 3/4\"","unit":"pcs","price":"980.00"},
        {"code":"M8.3","description":"Brass gate valve PN16 1\"","descriptionAm":"የናስ ጌት ቫልቭ PN16 1\"","unit":"pcs","price":"1,350.00"},
        {"code":"M8.4","description":"Brass gate valve PN16 11/2\"","descriptionAm":"የናስ ጌት ቫልቭ PN16 11/2\"","unit":"pcs","price":"2,250.00"},
        {"code":"M8.5","description":"Brass gate valve PN16 2\"","descriptionAm":"የናስ ጌት ቫልቭ PN16 2\"","unit":"pcs","price":"3,100.00"},
        {"code":"M8.6","description":"Bronze gate valve PN16 2\"","descriptionAm":"የብሮንዝ ጌት ቫልቭ PN16 2\"","unit":"pcs","price":"4,850.00"},
        {"code":"M8.7","description":"Bronze gate valve PN16 3\"","descriptionAm":"የብሮንዝ ጌት ቫልቭ PN16 3\"","unit":"pcs","price":"6,900.00"},
        {"code":"M8.8","description":"Cast iron gate valve PN16 100mm","descriptionAm":"የብረት ጌት ቫልቭ PN16 100ሚሜ","unit":"pcs","price":"18,500.00"},
        {"code":"M8.9","description":"Cast iron gate valve PN16 150mm","descriptionAm":"የብረት ጌት ቫልቭ PN16 150ሚሜ","unit":"pcs","price":"26,400.00"},
        {"code":"M8.10","description":"Float valve 1/2\"","descriptionAm":"ፍሎት ቫልቭ 1/2\"","unit":"pcs","price":"680.00"},
        {"code":"M8.11","description":"Float valve 3/4\"","descriptionAm":"ፍሎት ቫልቭ 3/4\"","unit":"pcs","price":"920.00"},
        {"code":"M8.12","description":"Check valve (non-return) 1\"","descriptionAm":"ቼክ ቫልቭ (የማይመለስ) 1\"","unit":"pcs","price":"1,450.00"},
        {"code":"M8.13","description":"Check valve (non-return) 2\"","descriptionAm":"ቼክ ቫልቭ (የማይመለስ) 2\"","unit":"pcs","price":"3,200.00"},
        {"code":"M8.14","description":"Water meter dia. 25mm","descriptionAm":"የውሃ ሜትር ዲያሜትር 25ሚሜ","unit":"pcs","price":"1,850.00"},
        {"code":"M8.15","description":"Water meter dia. 50mm","descriptionAm":"የውሃ ሜትር ዲያሜትር 50ሚሜ","unit":"pcs","price":"4,200.00"},
        {"code":"M8.16","description":"Floor drain 50mm (chrome plated)","descriptionAm":"የወለል ፍሳሽ 50ሚሜ (ክሮም የተለበጠ)","unit":"pcs","price":"850.00"},
        {"code":"M8.17","description":"Floor drain 100mm (chrome plated)","descriptionAm":"የወለል ፍሳሽ 100ሚሜ (ክሮም የተለበጠ)","unit":"pcs","price":"1,450.00"},
        {"code":"M8.18","description":"Clean out cover 110mm","descriptionAm":"የማጽጃ ክዳን 110ሚሜ","unit":"pcs","price":"680.00"},
        {"code":"M8.19","description":"Vent cap 100mm","descriptionAm":"የአየር ማስወጫ ክዳን 100ሚሜ","unit":"pcs","price":"220.00"}
      ]
    },
    {
      "id": "M9",
      "title": "SANITARY MATERIALS",
      "titleAm": "የሳኒቴሪ ቁሳቁሶች",
      "items": [
        {"code":"M9.1","description":"Water closet (WC) low flush, white ceramic, complete set","descriptionAm":"የውሃ ሽንኩርት ቤት (WC) ሎው ፍላሽ፣ ነጭ ሴራሚክ፣ ሙሉ ስብስብ","unit":"pcs","price":"12,500.00"},
        {"code":"M9.2","description":"Water closet (WC) low flush, RAK brand","descriptionAm":"የውሃ ሽንኩርት ቤት (WC) ሎው ፍላሽ፣ RAK ብራንድ","unit":"pcs","price":"22,800.00"},
        {"code":"M9.3","description":"Turkish type WC (squat pan), white ceramic","descriptionAm":"የቱርክ ዓይነት WC (ስኳት ፓን)፣ ነጭ ሴራሚክ","unit":"pcs","price":"5,400.00"},
        {"code":"M9.4","description":"Wash hand basin (HWB) 45x55cm, complete set","descriptionAm":"እጅ ማጠቢያ (HWB) 45x55ሴንቲ ሜትር፣ ሙሉ ስብስብ","unit":"pcs","price":"9,800.00"},
        {"code":"M9.5","description":"Wash hand basin (HWB) 45x55cm, RAK brand","descriptionAm":"እጅ ማጠቢያ (HWB) 45x55ሴንቲ ሜትር፣ RAK ብራንድ","unit":"pcs","price":"16,500.00"},
        {"code":"M9.6","description":"Urinal wall-hung, white glazed","descriptionAm":"ሽንት ቤት ግድግዳ ላይ የሚንጠለጠል፣ ነጭ ግሌዝድ","unit":"pcs","price":"8,200.00"},
        {"code":"M9.7","description":"Kitchen sink double bowl (stainless steel)","descriptionAm":"የወጥ ቤት ማጠቢያ ድርብ ጎድጓዳ (ስቴንሌስ ስቲል)","unit":"pcs","price":"7,500.00"},
        {"code":"M9.8","description":"Kitchen sink single bowl (stainless steel)","descriptionAm":"የወጥ ቤት ማጠቢያ ነጠላ ጎድጓዳ (ስቴንሌስ ስቲል)","unit":"pcs","price":"5,800.00"},
        {"code":"M9.9","description":"Shower box 90x90cm","descriptionAm":"የሻወር ሳጥን 90x90ሴንቲ ሜትር","unit":"pcs","price":"32,000.00"},
        {"code":"M9.10","description":"Bath tub 70x170cm (standard)","descriptionAm":"ገላ መታጠቢያ ገንዳ 70x170ሴንቲ ሜትር (መደበኛ)","unit":"pcs","price":"38,500.00"},
        {"code":"M9.11","description":"Bath tub 70x170cm (fiber glass)","descriptionAm":"ገላ መታጠቢያ ገንዳ 70x170ሴንቲ ሜትር (ፋይበር ግላስ)","unit":"pcs","price":"28,000.00"},
        {"code":"M9.12","description":"Water heater 50lt (electric)","descriptionAm":"የውሃ ማሞቂያ 50lt (ኤሌክትሪክ)","unit":"pcs","price":"26,500.00"},
        {"code":"M9.13","description":"Water heater 80lt (electric)","descriptionAm":"የውሃ ማሞቂያ 80lt (ኤሌክትሪክ)","unit":"pcs","price":"35,800.00"},
        {"code":"M9.14","description":"Water heater 100lt (electric)","descriptionAm":"የውሃ ማሞቂያ 100lt (ኤሌክትሪክ)","unit":"pcs","price":"46,500.00"},
        {"code":"M9.15","description":"Instant water heater","descriptionAm":"ፈጣን የውሃ ማሞቂያ","unit":"pcs","price":"18,500.00"},
        {"code":"M9.16","description":"Mirror 60x80cm (bathroom)","descriptionAm":"መስታወት 60x80ሴንቲ ሜትር (የመታጠቢያ ቤት)","unit":"pcs","price":"2,800.00"},
        {"code":"M9.17","description":"Towel rail (chrome)","descriptionAm":"የፎጣ መወርወሪያ (ክሮም)","unit":"pcs","price":"1,200.00"},
        {"code":"M9.18","description":"Soap dish (ceramic)","descriptionAm":"የሳሙና ሳህን (ሴራሚክ)","unit":"pcs","price":"650.00"}
      ]
    },
    {
      "id": "M10",
      "title": "ELECTRICAL MATERIALS",
      "titleAm": "የኤሌክትሪክ ቁሳቁሶች",
      "items": [
        {"code":"M10.1","description":"PVC insulated cable 2x2.5mm²","descriptionAm":"PVC የተከለለ ኬብል 2x2.5mm²","unit":"ml","price":"185.00"},
        {"code":"M10.2","description":"PVC insulated cable 3x2.5mm²","descriptionAm":"PVC የተከለለ ኬብል 3x2.5mm²","unit":"ml","price":"265.00"},
        {"code":"M10.3","description":"PVC insulated cable 3x4mm²","descriptionAm":"PVC የተከለለ ኬብል 3x4mm²","unit":"ml","price":"380.00"},
        {"code":"M10.4","description":"PVC insulated cable 3x6mm²","descriptionAm":"PVC የተከለለ ኬብል 3x6mm²","unit":"ml","price":"620.00"},
        {"code":"M10.5","description":"PVC insulated cable 5x4mm²","descriptionAm":"PVC የተከለለ ኬብል 5x4mm²","unit":"ml","price":"580.00"},
        {"code":"M10.6","description":"PVC insulated cable 5x6mm²","descriptionAm":"PVC የተከለለ ኬብል 5x6mm²","unit":"ml","price":"980.00"},
        {"code":"M10.7","description":"PVC conduit (rigid) dia. 16mm","descriptionAm":"PVC ቱቦ (ሪጅድ) ዲያሜትር 16ሚሜ","unit":"ml","price":"32.00"},
        {"code":"M10.8","description":"PVC conduit (rigid) dia. 25mm","descriptionAm":"PVC ቱቦ (ሪጅድ) ዲያሜትር 25ሚሜ","unit":"ml","price":"45.00"},
        {"code":"M10.9","description":"PVC conduit (rigid) dia. 32mm","descriptionAm":"PVC ቱቦ (ሪጅድ) ዲያሜትር 32ሚሜ","unit":"ml","price":"65.00"},
        {"code":"M10.10","description":"PVC conduit (rigid) dia. 50mm","descriptionAm":"PVC ቱቦ (ሪጅድ) ዲያሜትር 50ሚሜ","unit":"ml","price":"120.00"},
        {"code":"M10.11","description":"Flexible PVC conduit dia. 16mm","descriptionAm":"ተለዋዋጭ PVC ቱቦ ዲያሜትር 16ሚሜ","unit":"ml","price":"38.00"},
        {"code":"M10.12","description":"Flexible PVC conduit dia. 25mm","descriptionAm":"ተለዋዋጭ PVC ቱቦ ዲያሜትር 25ሚሜ","unit":"ml","price":"55.00"},
        {"code":"M10.13","description":"Junction box (PVC) 100x100mm","descriptionAm":"መገናኛ ሳጥን (PVC) 100x100ሚሜ","unit":"pcs","price":"45.00"},
        {"code":"M10.14","description":"Single switch 10A (flush mounted)","descriptionAm":"ነጠላ ስዊች 10A (ፍላሽ የሚገጠም)","unit":"pcs","price":"120.00"},
        {"code":"M10.15","description":"Double switch 10A (flush mounted)","descriptionAm":"ድርብ ስዊች 10A (ፍላሽ የሚገጠም)","unit":"pcs","price":"185.00"},
        {"code":"M10.16","description":"Single socket 16A (flush mounted)","descriptionAm":"ነጠላ ሶኬት 16A (ፍላሽ የሚገጠም)","unit":"pcs","price":"165.00"},
        {"code":"M10.17","description":"Double socket 16A (flush mounted)","descriptionAm":"ድርብ ሶኬት 16A (ፍላሽ የሚገጠም)","unit":"pcs","price":"245.00"},
        {"code":"M10.18","description":"MCB 16A single pole","descriptionAm":"MCB 16A ነጠላ ፖል","unit":"pcs","price":"280.00"},
        {"code":"M10.19","description":"MCB 32A single pole","descriptionAm":"MCB 32A ነጠላ ፖል","unit":"pcs","price":"350.00"},
        {"code":"M10.20","description":"MCB 63A three pole","descriptionAm":"MCB 63A ሶስት ፖል","unit":"pcs","price":"850.00"},
        {"code":"M10.21","description":"RCD 30mA/2 pole","descriptionAm":"RCD 30mA/2 ፖል","unit":"pcs","price":"2,200.00"},
        {"code":"M10.22","description":"RCD 100mA/4 pole","descriptionAm":"RCD 100mA/4 ፖል","unit":"pcs","price":"4,500.00"},
        {"code":"M10.23","description":"Distribution board (surface) 8-way","descriptionAm":"ማከፋፈያ ቦርድ (ገጽ) 8-መንገድ","unit":"pcs","price":"2,800.00"},
        {"code":"M10.24","description":"Distribution board (surface) 16-way","descriptionAm":"ማከፋፈያ ቦርድ (ገጽ) 16-መንገድ","unit":"pcs","price":"4,500.00"},
        {"code":"M10.25","description":"LED panel light 60x60cm 48W","descriptionAm":"LED ፓነል መብራት 60x60ሴንቲ ሜትር 48W","unit":"pcs","price":"2,850.00"},
        {"code":"M10.26","description":"LED bulb 12W (E27)","descriptionAm":"LED አምፖል 12W (E27)","unit":"pcs","price":"180.00"},
        {"code":"M10.27","description":"LED flood light 100W","descriptionAm":"LED ፍሎድ መብራት 100W","unit":"pcs","price":"3,500.00"},
        {"code":"M10.28","description":"Copper earth rod 16mm x 1500mm","descriptionAm":"የመዳብ የመሬት ዘንግ 16ሚሜ x 1500ሚሜ","unit":"pcs","price":"3,200.00"},
        {"code":"M10.29","description":"Bare copper conductor 70mm²","descriptionAm":"ባዶ መዳብ ኮንዳክተር 70mm²","unit":"ml","price":"1,450.00"},
        {"code":"M10.30","description":"Galvanized steel cable tray 100x50mm","descriptionAm":"ጋልቫናይዝድ ብረት ኬብል ትሪ 100x50ሚሜ","unit":"ml","price":"1,850.00"}
      ]
    },
    {
      "id": "M11",
      "title": "PAINTS & COATINGS",
      "titleAm": "ቀለሞች እና ሽፋኖች",
      "items": [
        {"code":"M11.1","description":"Plastic emulsion paint (interior) — 20lt","descriptionAm":"ፕላስቲክ ኢሙልሽን ቀለም (የውስጥ) — 20lt","unit":"can","price":"3,200.00"},
        {"code":"M11.2","description":"Plastic emulsion paint (exterior) — 20lt","descriptionAm":"ፕላስቲክ ኢሙልሽን ቀለም (የውጭ) — 20lt","unit":"can","price":"3,800.00"},
        {"code":"M11.3","description":"Acrylic emulsion paint (JOTUN) — 20lt","descriptionAm":"አክሬሊክ ኢሙልሽን ቀለም (JOTUN) — 20lt","unit":"can","price":"5,500.00"},
        {"code":"M11.4","description":"Synthetic enamel paint (oil-based) — 20lt","descriptionAm":"ሲንቴቲክ ኢናሜል ቀለም (በዘይት ላይ የተመሠረተ) — 20lt","unit":"can","price":"4,800.00"},
        {"code":"M11.5","description":"Varnish (clear) — 20lt","descriptionAm":"ቫርኒሽ (ግልጽ) — 20lt","unit":"can","price":"4,200.00"},
        {"code":"M11.6","description":"Primer (PVA) — 20lt","descriptionAm":"ፕራይመር (PVA) — 20lt","unit":"can","price":"2,800.00"},
        {"code":"M11.7","description":"Anti-rust paint (red oxide) — 20lt","descriptionAm":"ዝገት መከላከያ ቀለም (ቀይ ኦክሳይድ) — 20lt","unit":"can","price":"3,500.00"},
        {"code":"M11.8","description":"Mica paint — 20lt","descriptionAm":"ሚካ ቀለም — 20lt","unit":"can","price":"4,500.00"},
        {"code":"M11.9","description":"Quartz paint — 20lt","descriptionAm":"ኳርትዝ ቀለም — 20lt","unit":"can","price":"6,800.00"},
        {"code":"M11.10","description":"Lime paint — 20lt","descriptionAm":"የኖራ ቀለም — 20lt","unit":"can","price":"1,800.00"},
        {"code":"M11.11","description":"Cement paint — 20lt","descriptionAm":"የሲሚንቶ ቀለም — 20lt","unit":"can","price":"2,200.00"},
        {"code":"M11.12","description":"Granite paint (textured) — 20lt","descriptionAm":"የግራናይት ቀለም (ቴክስቸርድ) — 20lt","unit":"can","price":"8,500.00"},
        {"code":"M11.13","description":"Texture paint (Texura Sparol) — 20lt","descriptionAm":"ቴክስቸር ቀለም (ቴክሱራ ስፓሮል) — 20lt","unit":"can","price":"7,200.00"},
        {"code":"M11.14","description":"Thinner (paint) — 5lt","descriptionAm":"ቀለም ማቅለጫ — 5lt","unit":"can","price":"850.00"},
        {"code":"M11.15","description":"Paint brush 4\"","descriptionAm":"የቀለም ብሩሽ 4\"","unit":"pcs","price":"180.00"},
        {"code":"M11.16","description":"Paint roller 9\"","descriptionAm":"የቀለም ሮለር 9\"","unit":"pcs","price":"250.00"},
        {"code":"M11.17","description":"Putty (acrylic) — 20kg","descriptionAm":"ፑቲ (አክሬሊክ) — 20ኪግ","unit":"bag","price":"1,200.00"},
        {"code":"M11.18","description":"Waterproof coating (cementitious) — 20kg","descriptionAm":"የውሃ መከላከያ ሽፋን (ሲሚንቶ) — 20ኪግ","unit":"bag","price":"2,400.00"},
        {"code":"M11.19","description":"Polyurethane waterproof coating — 20lt","descriptionAm":"ፖሊዩሪቴን የውሃ መከላከያ ሽፋን — 20lt","unit":"can","price":"6,500.00"},
        {"code":"M11.20","description":"Bitumen waterproof membrane 4mm — 1x10m roll","descriptionAm":"ቢቱመን የውሃ መከላከያ ሽፋን 4ሚሜ — 1x10ሜ ጥቅል","unit":"roll","price":"3,800.00"}
      ]
    },
    {
      "id": "M12",
      "title": "TILES, STONES & FINISHING MATERIALS",
      "titleAm": "ታይሎች፣ ድንጋዮች እና የማጠናቀቂያ ቁሳቁሶች",
      "items": [
        {"code":"M12.1","description":"Ceramic floor tile 40x40cm (local)","descriptionAm":"የሴራሚክ ወለል ታይል 40x40ሴንቲ ሜትር (የአገር ውስጥ)","unit":"m²","price":"850.00"},
        {"code":"M12.2","description":"Ceramic floor tile 60x60cm (local)","descriptionAm":"የሴራሚክ ወለል ታይል 60x60ሴንቲ ሜትር (የአገር ውስጥ)","unit":"m²","price":"1,250.00"},
        {"code":"M12.3","description":"Porcelain floor tile 60x60cm","descriptionAm":"የፖርሴሌን ወለል ታይል 60x60ሴንቲ ሜትር","unit":"m²","price":"1,850.00"},
        {"code":"M12.4","description":"Porcelain floor tile 120x60cm","descriptionAm":"የፖርሴሌን ወለል ታይል 120x60ሴንቲ ሜትር","unit":"m²","price":"2,600.00"},
        {"code":"M12.5","description":"Ceramic wall tile 25x40cm (local)","descriptionAm":"የሴራሚክ ግድግዳ ታይል 25x40ሴንቲ ሜትር (የአገር ውስጥ)","unit":"m²","price":"720.00"},
        {"code":"M12.6","description":"Ceramic wall tile 30x60cm (imported)","descriptionAm":"የሴራሚክ ግድግዳ ታይል 30x60ሴንቲ ሜትር (ከውጭ የመጣ)","unit":"m²","price":"1,450.00"},
        {"code":"M12.7","description":"Terrazzo tile 40x40x4cm","descriptionAm":"የተራዞ ታይል 40x40x4ሴንቲ ሜትር","unit":"m²","price":"1,100.00"},
        {"code":"M12.8","description":"Marble slab 2cm thick (local)","descriptionAm":"የእርስ ሰሌዳ 2ሴንቲ ሜትር ውፍረት (የአገር ውስጥ)","unit":"m²","price":"4,200.00"},
        {"code":"M12.9","description":"Granite slab 2cm thick (local)","descriptionAm":"የግራናይት ሰሌዳ 2ሴንቲ ሜትር ውፍረት (የአገር ውስጥ)","unit":"m²","price":"4,800.00"},
        {"code":"M12.10","description":"Black Galaxy granite 2cm (imported)","descriptionAm":"ብላክ ጋላክሲ ግራናይት 2ሴንቲ ሜትር (ከውጭ የመጣ)","unit":"m²","price":"12,500.00"},
        {"code":"M12.11","description":"PVC floor tile 2mm thick","descriptionAm":"PVC ወለል ታይል 2ሚሜ ውፍረት","unit":"m²","price":"950.00"},
        {"code":"M12.12","description":"SPC flooring 4mm thick","descriptionAm":"SPC ወለል 4ሚሜ ውፍረት","unit":"m²","price":"1,650.00"},
        {"code":"M12.13","description":"Parquet flooring (Tid)","descriptionAm":"የፓርኬት ወለል (ጽድ)","unit":"m²","price":"2,400.00"},
        {"code":"M12.14","description":"Tile adhesive powder — 25kg bag","descriptionAm":"የታይል አጣቢ ዱቄት — 25ኪግ ከረጢት","unit":"bag","price":"950.00"},
        {"code":"M12.15","description":"Tile grout (white cement based) — 5kg","descriptionAm":"የታይል ግሩት (በነጭ ሲሚንቶ ላይ የተመሠረተ) — 5ኪግ","unit":"bag","price":"480.00"},
        {"code":"M12.16","description":"Silicone sealant (clear) — 300ml","descriptionAm":"ሲሊኮን ማሸጊያ (ግልጽ) — 300ml","unit":"cartridge","price":"380.00"},
        {"code":"M12.17","description":"Aluminium cladding panel 4mm (silver)","descriptionAm":"የአሉሚኒየም ሽፋን ፓነል 4ሚሜ (ብርማ)","unit":"m²","price":"2,850.00"},
        {"code":"M12.18","description":"Aluminium cladding panel 4mm (golden)","descriptionAm":"የአሉሚኒየም ሽፋን ፓነል 4ሚሜ (ወርቃማ)","unit":"m²","price":"3,200.00"}
      ]
    },
    {
      "id": "M13",
      "title": "GLASS & GLAZING MATERIALS",
      "titleAm": "ብርጭቆ እና የመስታወት ቁሳቁሶች",
      "items": [
        {"code":"M13.1","description":"Clear glass 3mm thick","descriptionAm":"ግልጽ ብርጭቆ 3ሚሜ ውፍረት","unit":"m²","price":"850.00"},
        {"code":"M13.2","description":"Clear glass 4mm thick","descriptionAm":"ግልጽ ብርጭቆ 4ሚሜ ውፍረት","unit":"m²","price":"1,100.00"},
        {"code":"M13.3","description":"Clear glass 5mm thick","descriptionAm":"ግልጽ ብርጭቆ 5ሚሜ ውፍረት","unit":"m²","price":"1,450.00"},
        {"code":"M13.4","description":"Clear glass 6mm thick","descriptionAm":"ግልጽ ብርጭቆ 6ሚሜ ውፍረት","unit":"m²","price":"1,850.00"},
        {"code":"M13.5","description":"Figured glass 4mm thick","descriptionAm":"ፊገርድ ብርጭቆ 4ሚሜ ውፍረት","unit":"m²","price":"1,650.00"},
        {"code":"M13.6","description":"Frosted glass 5mm thick","descriptionAm":"ፍርስትድ ብርጭቆ 5ሚሜ ውፍረት","unit":"m²","price":"2,100.00"},
        {"code":"M13.7","description":"Tinted glass 6mm thick","descriptionAm":"ቲንትድ ብርጭቆ 6ሚሜ ውፍረት","unit":"m²","price":"2,400.00"},
        {"code":"M13.8","description":"Reflected glass 5mm thick","descriptionAm":"ሪፍሌክትድ ብርጭቆ 5ሚሜ ውፍረት","unit":"m²","price":"2,250.00"},
        {"code":"M13.9","description":"Laminated (security) glass 6mm","descriptionAm":"ላሚኔትድ (ሴኪዩሪቲ) ብርጭቆ 6ሚሜ","unit":"m²","price":"3,400.00"},
        {"code":"M13.10","description":"Tempered glass 10mm thick","descriptionAm":"ተምፐርድ ብርጭቆ 10ሚሜ ውፍረት","unit":"m²","price":"4,500.00"},
        {"code":"M13.11","description":"Wired glass 5mm thick","descriptionAm":"ዋየርድ ብርጭቆ 5ሚሜ ውፍረት","unit":"m²","price":"2,800.00"},
        {"code":"M13.12","description":"Glass putty (glazing) — 1kg","descriptionAm":"የብርጭቆ ፑቲ (ግሌዚንግ) — 1ኪግ","unit":"kg","price":"220.00"}
      ]
    },
    {
      "id": "M14",
      "title": "DOORS, WINDOWS & HARDWARE",
      "titleAm": "በሮች፣ መስኮቶች እና ሃርድዌር",
      "items": [
        {"code":"M14.1","description":"Flush wooden door 40mm (mahogany plywood) — complete","descriptionAm":"ፍላሽ የእንጨት በር 40ሚሜ (ማሆጋኒ ፕላይዉድ) — ሙሉ","unit":"m²","price":"8,500.00"},
        {"code":"M14.2","description":"Wooden door 40mm (MDF, imported) — complete","descriptionAm":"የእንጨት በር 40ሚሜ (MDF፣ ከውጭ የመጣ) — ሙሉ","unit":"m²","price":"9,800.00"},
        {"code":"M14.3","description":"PVC door (interior/exterior) — complete","descriptionAm":"PVC በር (የውስጥ/የውጭ) — ሙሉ","unit":"m²","price":"7,200.00"},
        {"code":"M14.4","description":"HPL door with stainless steel frame — complete","descriptionAm":"HPL በር ከስቴንሌስ ስቲል ፍሬም ጋር — ሙሉ","unit":"m²","price":"11,500.00"},
        {"code":"M14.5","description":"Metal door 38mm LTZ (1.5mm) — fully metal","descriptionAm":"የብረት በር 38ሚሜ LTZ (1.5ሚሜ) — ሙሉ ብረት","unit":"m²","price":"4,200.00"},
        {"code":"M14.6","description":"Metal door 38mm LTZ (1.5mm) — partially glazed","descriptionAm":"የብረት በር 38ሚሜ LTZ (1.5ሚሜ) — በከፊል ብርጭቆ","unit":"m²","price":"4,000.00"},
        {"code":"M14.7","description":"Metal window 38LTZ (1.5mm) — without grill","descriptionAm":"የብረት መስኮት 38LTZ (1.5ሚሜ) — ግሪል የለም","unit":"m²","price":"3,600.00"},
        {"code":"M14.8","description":"Aluminium window 1.6mm frame + 6mm clear glass","descriptionAm":"የአሉሚኒየም መስኮት 1.6ሚሜ ፍሬም + 6ሚሜ ግልጽ ብርጭቆ","unit":"m²","price":"9,500.00"},
        {"code":"M14.9","description":"Aluminium door 1.6mm frame + 6mm clear glass","descriptionAm":"የአሉሚኒየም በር 1.6ሚሜ ፍሬም + 6ሚሜ ግልጽ ብርጭቆ","unit":"m²","price":"10,200.00"},
        {"code":"M14.10","description":"Aluminium curtain wall 1.6mm + 6mm clear glass","descriptionAm":"የአሉሚኒየም መጋረጃ ግድግዳ 1.6ሚሜ + 6ሚሜ ግልጽ ብርጭቆ","unit":"m²","price":"12,800.00"},
        {"code":"M14.11","description":"Door lock (cylindrical, mortise)","descriptionAm":"የበር መቆለፊያ (ሲሊንደሪካል፣ ሞርታይዝ)","unit":"pcs","price":"1,250.00"},
        {"code":"M14.12","description":"Door handle (lever type, chrome)","descriptionAm":"የበር መያዣ (ሊቨር ዓይነት፣ ክሮም)","unit":"pcs","price":"650.00"},
        {"code":"M14.13","description":"Door hinge 4\" (pair)","descriptionAm":"የበር ማጠፊያ 4\" (ጥንድ)","unit":"pair","price":"280.00"},
        {"code":"M14.14","description":"Door stopper","descriptionAm":"የበር ማቆሚያ","unit":"pcs","price":"120.00"},
        {"code":"M14.15","description":"Window handle (aluminium)","descriptionAm":"የመስኮት መያዣ (አሉሚኒየም)","unit":"pcs","price":"180.00"},
        {"code":"M14.16","description":"Tower bolt 6\"","descriptionAm":"ታወር ቦልት 6\"","unit":"pcs","price":"220.00"}
      ]
    },
    {
      "id": "M15",
      "title": "WATERPROOFING & CHEMICALS",
      "titleAm": "የውሃ መከላከያ እና ኬሚካሎች",
      "items": [
        {"code":"M15.1","description":"Cementitious waterproof coating — 20kg","descriptionAm":"ሲሚንቶ የውሃ መከላከያ ሽፋን — 20ኪግ","unit":"bag","price":"2,400.00"},
        {"code":"M15.2","description":"Xypex crystalline waterproof — 25kg","descriptionAm":"Xypex ክሪስታላይን የውሃ መከላከያ — 25ኪግ","unit":"bag","price":"4,800.00"},
        {"code":"M15.3","description":"Polyurethane waterproof coating — 20lt","descriptionAm":"ፖሊዩሪቴን የውሃ መከላከያ ሽፋን — 20lt","unit":"can","price":"6,500.00"},
        {"code":"M15.4","description":"Bitumen waterproof membrane 4mm — roll","descriptionAm":"ቢቱመን የውሃ መከላከያ ሽፋን 4ሚሜ — ጥቅል","unit":"roll","price":"3,800.00"},
        {"code":"M15.5","description":"PVC waterstop 200mm — 25m roll","descriptionAm":"PVC የውሃ ማቆሚያ 200ሚሜ — 25ሜ ጥቅል","unit":"roll","price":"4,500.00"},
        {"code":"M15.6","description":"PVC joint filler 10mm — 50m roll","descriptionAm":"PVC መገጣጠሚያ መሙያ 10ሚሜ — 50ሜ ጥቅል","unit":"roll","price":"2,800.00"},
        {"code":"M15.7","description":"Concrete admixture (plasticizer) — 20lt","descriptionAm":"የኮንክሪት ተጨማሪ (ፕላስቲሳይዘር) — 20lt","unit":"can","price":"3,200.00"},
        {"code":"M15.8","description":"Concrete admixture (waterproof) — 20lt","descriptionAm":"የኮንክሪት ተጨማሪ (የውሃ መከላከያ) — 20lt","unit":"can","price":"3,800.00"},
        {"code":"M15.9","description":"Concrete admixture (accelerator) — 20lt","descriptionAm":"የኮንክሪት ተጨማሪ (አፋጣኝ) — 20lt","unit":"can","price":"3,500.00"},
        {"code":"M15.10","description":"Concrete admixture (retarder) — 20lt","descriptionAm":"የኮንክሪት ተጨማሪ (አዘግይ) — 20lt","unit":"can","price":"3,500.00"},
        {"code":"M15.11","description":"Form release agent (oil) — 20lt","descriptionAm":"የፎርም መለቀቂያ ወኪል (ዘይት) — 20lt","unit":"can","price":"2,200.00"},
        {"code":"M15.12","description":"Curing compound — 20lt","descriptionAm":"የኮንክሪት እርጥበት መጠበቂያ — 20lt","unit":"can","price":"2,800.00"},
        {"code":"M15.13","description":"Epoxy resin (2-part) — 5kg kit","descriptionAm":"ኤፖክሲ ሬዚን (2-ክፍል) — 5ኪግ ኪት","unit":"kit","price":"4,500.00"},
        {"code":"M15.14","description":"Epoxy floor topping — 20kg kit","descriptionAm":"ኤፖክሲ ወለል ሽፋን — 20ኪግ ኪት","unit":"kit","price":"12,500.00"},
        {"code":"M15.15","description":"Anti-termite chemical — 20lt","descriptionAm":"ጸረ-ምስጥ ኬሚካል — 20lt","unit":"can","price":"3,800.00"}
      ]
    }
  ]

};END
cat > src/data/pricing.js << 'END'
const round2 = (n) => Math.round(n * 100) / 100;
export function tierPrice(product, qty) {
  const tiers = (product.tiers || []).filter(t => qty >= t.min).sort((a, b) => b.min - a.min);
  return tiers.length ? tiers[0].price : product.basePrice;
}
export function calcLine(product, qty, opts = {}) {
  const basePrice = opts.basePriceOverride != null ? opts.basePriceOverride : tierPrice(product, qty);
  const contractorPrice = opts.contractorPrice != null ? opts.contractorPrice : basePrice;
  return { sku: product.id, name: product.name || product.description, unit: product.unit, qty, basePrice, contractorPrice, lineTotal: round2(qty * contractorPrice), margin: round2((contractorPrice - basePrice) * qty), taxable: product.taxable !== false, leadTimeDays: product.leadTimeDays || 0 };
}
export function calcLineFromRate(rateItem, qty, contractorPriceOverride) {
  const basePrice = rateItem.basePrice == null ? 0 : rateItem.basePrice;
  const contractorPrice = contractorPriceOverride != null ? contractorPriceOverride : (rateItem.contractorPrice != null ? rateItem.contractorPrice : basePrice);
  return { sku: rateItem.id, name: rateItem.description, unit: rateItem.unit, qty, basePrice, contractorPrice, lineTotal: round2(qty * contractorPrice), margin: round2((contractorPrice - basePrice) * qty), taxable: true, leadTimeDays: 0, code: rateItem.code };
}
export function calcProforma({ lines, freightZone, zones = [], discountPct = 0, vatRate = 0, markupPct = 0, contingencyPct = 0 }) {
  const subtotal = round2(lines.reduce((s, l) => s + l.lineTotal, 0));
  const markup = round2(subtotal * (markupPct / 100));
  const afterMarkup = round2(subtotal + markup);
  const contingency = round2(afterMarkup * (contingencyPct / 100));
  const afterContingency = round2(afterMarkup + contingency);
  const discount = round2(afterContingency * (discountPct / 100));
  const afterDiscount = round2(afterContingency - discount);
  const zone = zones.find(z => z.id === freightZone);
  const totalTons = lines.reduce((s, l) => s + (l.unit === 'ton' ? l.qty : 0), 0);
  const freight = zone ? round2((zone.flat || 0) + (zone.perTon || 0) * totalTons) : 0;
  const vat = round2(afterDiscount * vatRate);
  const grandTotal = round2(afterDiscount + freight + vat);
  const totalMargin = round2(lines.reduce((s, l) => s + (l.margin || 0), 0));
  const maxLead = lines.reduce((m, l) => Math.max(m, l.leadTimeDays || 0), 0);
  return { subtotal, markup, contingency, discount, afterDiscount, freight, vat, grandTotal, totalMargin, maxLead };
}
export function nextProformaNumber(existing = []) {
  const d = new Date();
  const ymd = d.toISOString().slice(0, 10).replace(/-/g, '');
  const todays = existing.filter(p => p.number && p.number.includes(ymd));
  return 'MA-PF-' + ymd + '-' + String(todays.length + 1).padStart(4, '0');
}
export function addDays(dateStr, days) {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}
export function formatMoney(n, currency = 'ETB') {
  const v = Number(n) || 0;
  const s = v.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return currency === 'ETB' ? 'Br ' + s : currency + ' ' + s;
}
END
cat > src/data/proformas.js << 'END'
import { put, get, getAll, del } from './db.js';

export async function saveProforma(pf) { return put('proformas', pf); }
export async function getProforma(id) { return get('proformas', id); }
export async function getProformas() { return getAll('proformas'); }
export async function deleteProforma(id) { return del('proformas', id); }

export async function updateProforma(id, patch) {
  const current = await get('proformas', id);
  if (!current) return null;
  const next = Object.assign({}, current, patch);
  await put('proformas', next);
  return next;
}

export async function updateProformaStatus(id, status) {
  return updateProforma(id, { status });
}

export async function duplicateProforma(id) {
  const src = await get('proformas', id);
  if (!src) return null;
  const all = await getAll('proformas');
  const today = new Date().toISOString().slice(0, 10);
  const ymd = today.replace(/-/g, '');
  const todays = all.filter(p => p.number && p.number.includes(ymd));
  const number = 'MA-PF-' + ymd + '-' + String(todays.length + 1).padStart(4, '0');
  const copy = Object.assign({}, src, {
    id: 'pf_' + Math.random().toString(36).slice(2, 9),
    number,
    createdAt: today,
    status: 'draft'
  });
  await put('proformas', copy);
  return copy;
}
END
cat > src/data/ratebook-data.js << 'END'
// Bundled rate book — Addis Ababa Design and Construction Works Bureau
// 2018 4th Quarter, Direct Cost Only, ETB
// PASTE YOUR DATA BELOW, REPLACING THE EXAMPLE CATEGORY
export const RATEBOOK = {
  "document": "file.pdf",
  "source": "Addis Ababa Design and Construction Works Bureau",
  "quarter": "2018 4th Quarter (Direct Cost Only)",
  "currency": "ETB",
  "categories": [
    {
      "id": "1",
      "title": "DEMOLITION WORK",
      "titleAm": "የማፍረስ ሥራ",
      "items": [
        {"page":6,"code":"1.1.1","description":"Demolishing the lamera wall","descriptionAm":"የላሜራ ግድግዳ ማፍረስ","unit":"m²","price":"172.41"},
        {"page":6,"code":"1.1.2","description":"Demolishing the existing CIS wall","descriptionAm":"ነባሩ የCIS ግድግዳ ማፍረስ","unit":"m²","price":"32.33"},
        {"page":6,"code":"1.1.3","description":"Demolishing of wooden wall","descriptionAm":"የእንጨት ግድግዳ ማፍረስ","unit":"m²","price":"182.53"},
        {"page":6,"code":"1.1.4","description":"Demolishing of gypsum wall","descriptionAm":"የጂፕሰም ግድግዳ ማፍረስ","unit":"m²","price":"91.27"},
        {"page":6,"code":"1.1.5","description":"Demolishing the CIS roof","descriptionAm":"የCIS ጣሪያ ማፍረስ","unit":"m²","price":"51.72"},
        {"page":6,"code":"1.1.6","description":"Demolishing of 7x5 cm zigba purline","descriptionAm":"7x5 ሴንቲ ሜትር ዚግባ ፐርላይን ማፍረስ","unit":"ml","price":"25.86"},
        {"page":6,"code":"1.1.7","description":"Demolishing of eucalyptus upper & lower chords","descriptionAm":"የባህር ዛፍ የላይኛው እና የታችኛው ቾርድ ማፍረስ","unit":"ml","price":"79.91"},
        {"page":6,"code":"1.1.8","description":"Dimolish RHS purline","descriptionAm":"RHS ፐርላይን ማፍረስ","unit":"ml","price":"43.10"},
        {"page":6,"code":"1.1.9","description":"Dimolishing the RHS truss.","descriptionAm":"የRHS ትረስ ማፍረስ።","unit":"ml","price":"103.01"},
        {"page":6,"code":"1.1.10","description":"Desmantling Gutter","descriptionAm":"የውሃ ማስተላለፊያ ቦይ ማፍረስ","unit":"ml","price":"34.30"},
        {"page":6,"code":"1.1.11","description":"Desmantling down pipe","descriptionAm":"የውሃ ማውረጃ ቧንቧ ማፍረስ","unit":"ml","price":"69.82"},
        {"page":6,"code":"1.1.12","description":"Demolishing the chipwood ceiling","descriptionAm":"የቺፕዉድ ጣሪያ ማፍረስ","unit":"m²","price":"119.56"},
        {"page":6,"code":"1.1.13","description":"Demolishing the timber ceiling","descriptionAm":"የእንጨት ጣሪያ ማፍረስ","unit":"m²","price":"166.06"},
        {"page":6,"code":"1.1.14","description":"Demolishing the abujed ceiling","descriptionAm":"የአቡጄድ ጣሪያ ማፍረስ","unit":"m²","price":"41.51"},
        {"page":6,"code":"1.1.15","description":"Dismantle the metal doors from the wall.","descriptionAm":"የብረት በሮችን ከግድግዳ ላይ መፍታት።","unit":"m²","price":"169.07"},
        {"page":6,"code":"1.1.16","description":"Dismantle the metal windows from the wall.","descriptionAm":"የብረት መስኮቶችን ከግድግዳ ላይ መፍታት።","unit":"m²","price":"152.16"},
        {"page":6,"code":"1.1.17","description":"Desmantling fascia board","descriptionAm":"የፋሺያ ቦርድ ማፍረስ","unit":"ml","price":"47.65"},
        {"page":6,"code":"1.1.18","description":"Desmantling ridge & copping","descriptionAm":"የጣሪያ ሪጅ እና ኮፒንግ ማፍረስ","unit":"ml","price":"68.60"},
        {"page":6,"code":"1.1.19","description":"Demolishing the PVC floor tile","descriptionAm":"የPVC ወለል ታይል ማፍረስ","unit":"m²","price":"45.63"},
        {"page":6,"code":"1.1.20","description":"Demolishing kitchen sink","descriptionAm":"የወጥ ቤት ማጠቢያ ማፍረስ","unit":"pcs","price":"70.46"},
        {"page":6,"code":"1.1.21","description":"Demolishing toilet WC,HW,turkish seat","descriptionAm":"የሽንኩርት ቤት WC፣ HW፣ የቱርክ መቀመጫ ማፍረስ","unit":"pcs","price":"211.37"},
        {"page":6,"code":"1.1.22","description":"Desmantling of wooden door & window","descriptionAm":"የእንጨት በር እና መስኮት ማፍረስ","unit":"m²","price":"135.47"},
        {"page":6,"code":"1.2.1","description":"Masonary Structure (BGL)","descriptionAm":"የግንበኝነት መዋቅር (BGL)","unit":"m³","price":"580.90"},
        {"page":6,"code":"1.2.2","description":"Masonary Structure (AGL)","descriptionAm":"የግንበኝነት መዋቅር (AGL)","unit":"m³","price":"774.54"},
        {"page":6,"code":"1.2.3","description":"Demolishing of 25cm thick hardcore","descriptionAm":"25 ሴንቲ ሜትር ውፍረት ያለው ሃርድኮር ማፍረስ","unit":"m²","price":"54.56"},
        {"page":6,"code":"1.2.4","description":"Concrete Structures","descriptionAm":"የኮንክሪት መዋቅሮች","unit":"m³","price":"2,580.74"},
        {"page":6,"code":"1.2.5","description":"10cm thick HCB Structure","descriptionAm":"10 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"55.46"},
        {"page":6,"code":"1.2.6","description":"15cm thick HCB Structure","descriptionAm":"15 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"73.61"},
        {"page":7,"code":"1.2.7","description":"20cm thick HCB Structure","descriptionAm":"20 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"103.06"},
        {"page":7,"code":"1.2.8","description":"Terrazzo floor","descriptionAm":"የተራዞ ወለል","unit":"m²","price":"114.51"},
        {"page":7,"code":"1.2.9","description":"Cement screed floor","descriptionAm":"የሲሚንቶ ስክሪድ ወለል","unit":"m²","price":"25.77"},
        {"page":7,"code":"1.2.10","description":"8cm thick Mass concrete floor","descriptionAm":"8 ሴንቲ ሜትር ውፍረት ያለው ማስ ኮንክሪት ወለል","unit":"m²","price":"34.35"},
        {"page":7,"code":"1.2.11","description":"30x120x3cm thick marble tread","descriptionAm":"30x120x3 ሴንቲ ሜትር ውፍረት ያለው የእርስ ተርድ","unit":"pcs","price":"227.83"},
        {"page":7,"code":"1.2.12","description":"15x120x3cm thick marble riser","descriptionAm":"15x120x3 ሴንቲ ሜትር ውፍረት ያለው የእርስ ራይዘር","unit":"pcs","price":"170.87"},
        {"page":7,"code":"1.2.13","description":"Steel Structure","descriptionAm":"የብረት መዋቅር","unit":"Kg","price":"10.61"},
        {"page":7,"code":"1.2.14","description":"Demolishing the ceramic wall tile","descriptionAm":"የሴራሚክ ግድግዳ ታይል ማፍረስ","unit":"m²","price":"114.51"},
        {"page":7,"code":"1.2.15","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 1st–3rd floor","descriptionAm":"የሴራሚክ ወለል ታይል (6 እና 8 ሚሜ ውፍረት) ማፍረስ — 1ኛ–3ኛ ፎቅ","unit":"m²","price":"128.83"},
        {"page":7,"code":"1.2.16","description":"Concrete Structures","descriptionAm":"የኮንክሪት መዋቅሮች","unit":"m³","price":"3,236.74"},
        {"page":7,"code":"1.2.17","description":"10cm thick HCB Structure","descriptionAm":"10 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"78.23"},
        {"page":7,"code":"1.2.18","description":"15cm thick HCB Structure","descriptionAm":"15 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"100.59"},
        {"page":7,"code":"1.2.19","description":"20cm thick HCB Structure","descriptionAm":"20 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"140.82"},
        {"page":7,"code":"1.2.20","description":"Terrazzo floor","descriptionAm":"የተራዞ ወለል","unit":"m²","price":"150.07"},
        {"page":7,"code":"1.2.21","description":"Cement screed floor","descriptionAm":"የሲሚንቶ ስክሪድ ወለል","unit":"m²","price":"33.77"},
        {"page":7,"code":"1.2.22","description":"30x120x3cm thick marble tread","descriptionAm":"30x120x3 ሴንቲ ሜትር ውፍረት ያለው የእርስ ተርድ","unit":"m²","price":"281.17"},
        {"page":7,"code":"1.2.23","description":"15x120x3cm marble riser","descriptionAm":"15x120x3 ሴንቲ ሜትር የእርስ ራይዘር","unit":"m²","price":"210.87"},
        {"page":7,"code":"1.2.24","description":"Steel Structure","descriptionAm":"የብረት መዋቅር","unit":"kg","price":"13.11"},
        {"page":7,"code":"1.2.25","description":"Demolishing the ceramic wall tile","descriptionAm":"የሴራሚክ ግድግዳ ታይል ማፍረስ","unit":"m²","price":"150.07"},
        {"page":7,"code":"1.2.26","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 4th–7th floor","descriptionAm":"የሴራሚክ ወለል ታይል (6 እና 8 ሚሜ ውፍረት) ማፍረስ — 4ኛ–7ኛ ፎቅ","unit":"m²","price":"168.83"},
        {"page":7,"code":"1.2.27","description":"Concrete Structures","descriptionAm":"የኮንክሪት መዋቅሮች","unit":"m³","price":"4,036.74"},
        {"page":7,"code":"1.2.28","description":"10cm thick HCB Structure","descriptionAm":"10 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"80.82"},
        {"page":7,"code":"1.2.29","description":"15cm thick HCB Structure","descriptionAm":"15 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"103.91"},
        {"page":7,"code":"1.2.30","description":"20cm thick HCB Structure","descriptionAm":"20 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"145.47"},
        {"page":7,"code":"1.2.31","description":"Terrazzo floor","descriptionAm":"የተራዞ ወለል","unit":"m²","price":"161.63"},
        {"page":7,"code":"1.2.32","description":"Cement screed floor","descriptionAm":"የሲሚንቶ ስክሪድ ወለል","unit":"m²","price":"36.37"},
        {"page":7,"code":"1.2.33","description":"30x120x3cm thick marble tread","descriptionAm":"30x120x3 ሴንቲ ሜትር ውፍረት ያለው የእርስ ተርድ","unit":"m²","price":"324.90"},
        {"page":7,"code":"1.2.34","description":"15x120x3cm marble riser","descriptionAm":"15x120x3 ሴንቲ ሜትር የእርስ ራይዘር","unit":"m²","price":"243.67"},
        {"page":7,"code":"1.2.35","description":"Steel Structure","descriptionAm":"የብረት መዋቅር","unit":"kg","price":"19.32"},
        {"page":8,"code":"1.2.36","description":"Demolishing the ceramic wall tile","descriptionAm":"የሴራሚክ ግድግዳ ታይል ማፍረስ","unit":"m²","price":"185.62"},
        {"page":8,"code":"1.2.37","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 8th–12th floor","descriptionAm":"የሴራሚክ ወለል ታይል (6 እና 8 ሚሜ ውፍረት) ማፍረስ — 8ኛ–12ኛ ፎቅ","unit":"m²","price":"208.83"},
        {"page":8,"code":"1.2.38","description":"Concrete Structures","descriptionAm":"የኮንክሪት መዋቅሮች","unit":"m³","price":"4,836.74"},
        {"page":8,"code":"1.2.39","description":"10cm thick HCB Structure","descriptionAm":"10 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"115.36"},
        {"page":8,"code":"1.2.40","description":"15cm thick HCB Structure","descriptionAm":"15 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"126.76"},
        {"page":8,"code":"1.2.41","description":"20cm thick HCB Structure","descriptionAm":"20 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"177.47"},
        {"page":8,"code":"1.2.42","description":"Terrazzo floor","descriptionAm":"የተራዞ ወለል","unit":"m²","price":"197.19"},
        {"page":8,"code":"1.2.43","description":"Cement screed floor","descriptionAm":"የሲሚንቶ ስክሪድ ወለል","unit":"m²","price":"44.37"},
        {"page":8,"code":"1.2.44","description":"30x120x3cm thick marble tread","descriptionAm":"30x120x3 ሴንቲ ሜትር ውፍረት ያለው የእርስ ተርድ","unit":"m²","price":"378.23"},
        {"page":8,"code":"1.2.45","description":"15x120x3cm marble riser","descriptionAm":"15x120x3 ሴንቲ ሜትር የእርስ ራይዘር","unit":"pcs","price":"283.67"},
        {"page":8,"code":"1.2.46","description":"Steel Structure","descriptionAm":"የብረት መዋቅር","unit":"kg","price":"19.01"},
        {"page":8,"code":"1.2.47","description":"Demolishing the ceramic wall tile","descriptionAm":"የሴራሚክ ግድግዳ ታይል ማፍረስ","unit":"m²","price":"221.18"},
        {"page":8,"code":"1.2.48","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 13th–20th floor","descriptionAm":"የሴራሚክ ወለል ታይል (6 እና 8 ሚሜ ውፍረት) ማፍረስ — 13ኛ–20ኛ ፎቅ","unit":"m²","price":"248.83"},
        {"page":8,"code":"1.2.49","description":"Concrete Structures","descriptionAm":"የኮንክሪት መዋቅሮች","unit":"m³","price":"5,636.74"},
        {"page":8,"code":"1.2.50","description":"10cm thick HCB Structure","descriptionAm":"10 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"116.37"},
        {"page":8,"code":"1.2.51","description":"15cm thick HCB Structure","descriptionAm":"15 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"149.62"},
        {"page":8,"code":"1.2.52","description":"20cm thick HCB Structure","descriptionAm":"20 ሴንቲ ሜትር ውፍረት ያለው HCB መዋቅር","unit":"m²","price":"209.47"},
        {"page":8,"code":"1.2.53","description":"Terrazzo floor","descriptionAm":"የተራዞ ወለል","unit":"m²","price":"232.74"},
        {"page":8,"code":"1.2.54","description":"Cement screed floor","descriptionAm":"የሲሚንቶ ስክሪድ ወለል","unit":"m²","price":"52.37"},
        {"page":8,"code":"1.2.55","description":"30x120x3cm thick marble tread","descriptionAm":"30x120x3 ሴንቲ ሜትር ውፍረት ያለው የእርስ ተርድ","unit":"m²","price":"431.57"},
        {"page":8,"code":"1.2.56","description":"15x120x3cm marble riser","descriptionAm":"15x120x3 ሴንቲ ሜትር የእርስ ራይዘር","unit":"pcs","price":"323.67"},
        {"page":8,"code":"1.2.57","description":"Steel Structure","descriptionAm":"የብረት መዋቅር","unit":"kg","price":"21.51"},
        {"page":8,"code":"1.2.58","description":"Demolishing the ceramic wall tile","descriptionAm":"የሴራሚክ ግድግዳ ታይል ማፍረስ","unit":"m²","price":"256.73"}
      ]
    },
    {
      "id": "2",
      "title": "EXCAVATION AND EARTH WORK — MECHANIZED",
      "titleAm": "የቁፋሮ እና የአፈር ሥራ — በማሽን",
      "items": [
        {"page":8,"code":"2.1.1","description":"20cm. Clearing on wet & black soil.","descriptionAm":"20 ሴንቲ ሜትር። እርጥብ እና ጥቁር አፈር ላይ ማጽዳት።","unit":"m²","price":"98.79"},
        {"page":8,"code":"2.2.1","description":"Bulk excavation in loose & dry soil — depth not exceeding 1.5m","descriptionAm":"ልቅ እና ደረቅ አፈር ውስጥ በጅምላ ቁፋሮ — ጥልቀት ከ1.5m የማይበልጥ","unit":"m³","price":"368.92"},
        {"page":8,"code":"2.2.2","description":"Depth 1.50m–3.00m","descriptionAm":"ጥልቀት 1.50m–3.00m","unit":"m³","price":"452.22"},
        {"page":8,"code":"2.2.3","description":"Depth 3.00m–4.50m","descriptionAm":"ጥልቀት 3.00m–4.50m","unit":"m³","price":"547.61"},
        {"page":9,"code":"2.2.4","description":"Depth 4.50m–6.00m","descriptionAm":"ጥልቀት 4.50m–6.00m","unit":"m³","price":"625.84"},
        {"page":9,"code":"2.2.5","description":"Depth 6.00m–7.50m","descriptionAm":"ጥልቀት 6.00m–7.50m","unit":"m³","price":"730.15"},
        {"page":9,"code":"2.2.6","description":"Depth 7.50m–9.00m","descriptionAm":"ጥልቀት 7.50m–9.00m","unit":"m³","price":"876.18"},
        {"page":9,"code":"2.2.7","description":"Depth 9.00m–10.50m","descriptionAm":"ጥልቀት 9.00m–10.50m","unit":"m³","price":"973.53"},
        {"page":9,"code":"2.3.1","description":"Pit excavation in loose & dry soil — depth ≤1500mm","descriptionAm":"ልቅ እና ደረቅ አፈር ውስጥ የጉድጓድ ቁፋሮ — ጥልቀት ≤1500mm","unit":"m³","price":"417.23"},
        {"page":9,"code":"2.3.2","description":"Depth 1500–3000mm","descriptionAm":"ጥልቀት 1500–3000mm","unit":"m³","price":"476.83"},
        {"page":9,"code":"2.3.3","description":"Depth 3000–4500mm","descriptionAm":"ጥልቀት 3000–4500mm","unit":"m³","price":"556.30"},
        {"page":9,"code":"2.3.4","description":"Depth 4500–6000mm","descriptionAm":"ጥልቀት 4500–6000mm","unit":"m³","price":"667.56"},
        {"page":9,"code":"2.3.5","description":"Depth 6000–7500mm","descriptionAm":"ጥልቀት 6000–7500mm","unit":"m³","price":"834.46"},
        {"page":9,"code":"2.3.6","description":"Depth 7500–9000mm","descriptionAm":"ጥልቀት 7500–9000mm","unit":"m³","price":"1,054.05"},
        {"page":9,"code":"2.3.7","description":"Depth 9000–10500mm","descriptionAm":"ጥልቀት 9000–10500mm","unit":"m³","price":"1,430.50"},
        {"page":9,"code":"2.4.1","description":"Bulk excavation in soft rock — depth ≤1.5m","descriptionAm":"ለስላሳ አለት ውስጥ በጅምላ ቁፋሮ — ጥልቀት ≤1.5m","unit":"m³","price":"666.61"},
        {"page":9,"code":"2.4.2","description":"Depth 1.5m–3m","descriptionAm":"ጥልቀት 1.5m–3m","unit":"m³","price":"760.13"},
        {"page":9,"code":"2.4.3","description":"Depth 3.0m–4.5m","descriptionAm":"ጥልቀት 3.0m–4.5m","unit":"m³","price":"922.70"},
        {"page":9,"code":"2.4.4","description":"Depth 4.5m–6.0m","descriptionAm":"ጥልቀት 4.5m–6.0m","unit":"m³","price":"1,318.14"},
        {"page":9,"code":"2.4.5","description":"Depth 6.0m–7.5m","descriptionAm":"ጥልቀት 6.0m–7.5m","unit":"m³","price":"1,883.05"},
        {"page":9,"code":"2.4.6","description":"Depth 7.5m–9.0m","descriptionAm":"ጥልቀት 7.5m–9.0m","unit":"m³","price":"2,690.08"},
        {"page":9,"code":"2.4.7","description":"Depth 9.0m–10.5m","descriptionAm":"ጥልቀት 9.0m–10.5m","unit":"m³","price":"3,842.97"},
        {"page":9,"code":"2.5.1","description":"Pit excavation in soft rock — depth ≤1.5m","descriptionAm":"ለስላሳ አለት ውስጥ የጉድጓድ ቁፋሮ — ጥልቀት ≤1.5m","unit":"m³","price":"829.55"},
        {"page":9,"code":"2.5.2","description":"Depth 1.5m–3m","descriptionAm":"ጥልቀት 1.5m–3m","unit":"m³","price":"911.60"},
        {"page":9,"code":"2.5.3","description":"Depth 3.0m–4.5m","descriptionAm":"ጥልቀት 3.0m–4.5m","unit":"m³","price":"1,128.64"},
        {"page":9,"code":"2.5.4","description":"Depth 4.5m–6m","descriptionAm":"ጥልቀት 4.5m–6m","unit":"m³","price":"1,612.35"},
        {"page":9,"code":"2.5.5","description":"Depth 6m–7.5m","descriptionAm":"ጥልቀት 6m–7.5m","unit":"m³","price":"2,303.36"},
        {"page":9,"code":"2.5.6","description":"Depth 7.5m–9m","descriptionAm":"ጥልቀት 7.5m–9m","unit":"m³","price":"3,290.51"},
        {"page":9,"code":"2.5.7","description":"Depth 9m–10.5m","descriptionAm":"ጥልቀት 9m–10.5m","unit":"m³","price":"4,700.72"},
        {"page":9,"code":"2.6.1","description":"Bulk excavation in hard rock — depth ≤1.50m","descriptionAm":"ጠንካራ አለት ውስጥ በጅምላ ቁፋሮ — ጥልቀት ≤1.50m","unit":"m³","price":"1,368.24"},
        {"page":9,"code":"2.6.2","description":"Depth 1.5m–3m","descriptionAm":"ጥልቀት 1.5m–3m","unit":"m³","price":"1,706.63"},
        {"page":9,"code":"2.6.3","description":"Depth 3.0m–4.5m","descriptionAm":"ጥልቀት 3.0m–4.5m","unit":"m³","price":"2,051.20"},
        {"page":10,"code":"2.6.4","description":"Depth 4.5m–6.0m","descriptionAm":"ጥልቀት 4.5m–6.0m","unit":"m³","price":"2,792.32"},
        {"page":10,"code":"2.6.5","description":"Depth 6.0m–7.5m","descriptionAm":"ጥልቀት 6.0m–7.5m","unit":"m³","price":"3,490.40"},
        {"page":10,"code":"2.6.6","description":"Depth 7.5m–9.0m","descriptionAm":"ጥልቀት 7.5m–9.0m","unit":"m³","price":"4,363.00"},
        {"page":10,"code":"2.6.7","description":"Depth 9.0m–10.5m","descriptionAm":"ጥልቀት 9.0m–10.5m","unit":"m³","price":"5,132.95"},
        {"page":10,"code":"2.7.1","description":"Pit excavation in hard rock — depth ≤1.50m","descriptionAm":"ጠንካራ አለት ውስጥ የጉድጓድ ቁፋሮ — ጥልቀት ≤1.50m","unit":"m³","price":"1,659.11"},
        {"page":10,"code":"2.7.2","description":"Depth 1.5m–3m","descriptionAm":"ጥልቀት 1.5m–3m","unit":"m³","price":"2,051.09"},
        {"page":10,"code":"2.7.3","description":"Depth 3.0m–4.5m","descriptionAm":"ጥልቀት 3.0m–4.5m","unit":"m³","price":"2,666.42"},
        {"page":10,"code":"2.7.4","description":"Depth 4.5m–6m","descriptionAm":"ጥልቀት 4.5m–6m","unit":"m³","price":"3,627.78"},
        {"page":10,"code":"2.7.5","description":"Depth 6.0m–7.5m","descriptionAm":"ጥልቀት 6.0m–7.5m","unit":"m³","price":"5,182.55"},
        {"page":10,"code":"2.7.6","description":"Depth 7.5m–9m","descriptionAm":"ጥልቀት 7.5m–9m","unit":"m³","price":"7,403.64"},
        {"page":10,"code":"2.7.7","description":"Depth 9m–10.5m","descriptionAm":"ጥልቀት 9m–10.5m","unit":"m³","price":"10,576.63"},
        {"page":10,"code":"2.8.1","description":"Back fill selected excavated mats. from the site (mechanized)","descriptionAm":"ከጣቢያው የተመረጡ የተቆፈሩ ቁሳቁሶች መሙላት (በማሽን)","unit":"m³","price":"982.68"},
        {"page":10,"code":"2.8.2","description":"Back fill from outside (Upto 20km) (Mechanized)","descriptionAm":"ከውጭ መሙላት (እስከ 20ኪሜ) (በማሽን)","unit":"m³","price":"3,066.43"},
        {"page":10,"code":"2.8.3","description":"Back fill from outside (Upto 15km) (Mechanized)","descriptionAm":"ከውጭ መሙላት (እስከ 15ኪሜ) (በማሽን)","unit":"m³","price":"2,540.36"},
        {"page":10,"code":"2.8.4","description":"Back fill from outside (Upto 10km) (Mechanized)","descriptionAm":"ከውጭ መሙላት (እስከ 10ኪሜ) (በማሽን)","unit":"m³","price":"2,180.98"},
        {"page":10,"code":"2.8.5","description":"Back fill from outside (Upto 5km) (Mechanized)","descriptionAm":"ከውጭ መሙላት (እስከ 5ኪሜ) (በማሽን)","unit":"m³","price":"1,821.61"},
        {"page":10,"code":"2.8.6","description":"25cm. thick basaltic hard core. (Mechanized)","descriptionAm":"25 ሴንቲ ሜትር። ውፍረት ያለው የባዝልት ሃርድኮር። (በማሽን)","unit":"m²","price":"1,099.89"}
      ]
    }
  ]
  //these are only two catagories out of many
};END
cat > src/data/ratebook.js << 'END'
import { putAll, getAll, clearStore, put, getAllBy } from './db.js';
import { RATEBOOK } from './ratebook-data.js';

function normalizeItem(catId, item, idx) {
  const rawPrice = String(item.price || '').replace(/,/g, '').trim();
  const price = rawPrice === '' || rawPrice === '—' ? null : parseFloat(rawPrice);
  return {
    id: catId + ':' + (item.code || idx) + ':' + idx,
    source: 'works',
    categoryId: catId,
    code: item.code || '',
    description: item.description || '',
    descriptionAm: item.descriptionAm || '',
    tenderAliases: item.tenderAliases || [],
    unit: item.unit || '',
    basePrice: price,
    contractorPrice: price,
    page: item.page || 0
  };
}

export async function importRateBook(json) {
  const src = json || RATEBOOK;
  if (!src || !Array.isArray(src.categories)) throw new Error('Invalid rate book data — missing "categories"');
  const categories = [];
  const items = [];
  src.categories.forEach(cat => {
    const catId = String(cat.id);
    categories.push({
      id: catId,
      source: 'works',
      title: cat.title || 'Untitled',
      titleAm: cat.titleAm || cat.title || 'Untitled',
      itemCount: (cat.items || []).length
    });
    (cat.items || []).forEach((item, idx) => items.push(normalizeItem(catId, item, idx)));
  });
  await clearStore('ratebook_categories');
  await clearStore('ratebook_items');
  await putAll('ratebook_categories', categories);
  await putAll('ratebook_items', items);
  await put('meta', {
    key: 'ratebook_source',
    source: src.source || '',
    document: src.document || '',
    quarter: src.quarter || '',
    currency: src.currency || 'ETB',
    importedAt: new Date().toISOString(),
    categoryCount: categories.length,
    itemCount: items.length
  });
  return { categoryCount: categories.length, itemCount: items.length };
}

export async function seedFromModule() { return importRateBook(RATEBOOK); }

export async function getRateBookMeta() {
  const rows = await getAll('meta');
  return rows.find(r => r.key === 'ratebook_source') || null;
}

export async function getRateCategories(source = null) {
  const all = await getAll('ratebook_categories');
  if (!source) return all;
  return all.filter(c => c.source === source);
}

export async function getRateItems(source = null) {
  const all = await getAll('ratebook_items');
  if (!source) return all;
  return all.filter(i => (i.source || 'works') === source);
}

export async function getRateItemsByCategory(catId) {
  return getAllBy('ratebook_items', 'by-category', catId);
}

export async function updateRateItem(id, patch) {
  const rows = await getAll('ratebook_items');
  const item = rows.find(r => r.id === id);
  if (!item) return null;
  const next = Object.assign({}, item, patch);
  await put('ratebook_items', next);
  return next;
}

export async function applyInflation(factor, alsoContractor = false, source = null) {
  const rows = await getAll('ratebook_items');
  const updated = rows
    .filter(r => !source || (r.source || 'works') === source)
    .map(r => {
      if (r.basePrice == null) return r;
      const next = Object.assign({}, r, { basePrice: Math.round(r.basePrice * factor * 100) / 100 });
      if (alsoContractor) next.contractorPrice = next.basePrice;
      return next;
    });
  await putAll('ratebook_items', updated);
  return updated.length;
}

export async function resetContractorPrices(source = null) {
  const rows = await getAll('ratebook_items');
  const updated = rows
    .filter(r => !source || (r.source || 'works') === source)
    .map(r => Object.assign({}, r, { contractorPrice: r.basePrice }));
  await putAll('ratebook_items', updated);
  return updated.length;
}

export async function clearRateBook(source = null) {
  if (!source) {
    await clearStore('ratebook_categories');
    await clearStore('ratebook_items');
    await clearStore('meta');
    return;
  }
  const allItems = await getAll('ratebook_items');
  const allCats = await getAll('ratebook_categories');
  const keepItems = allItems.filter(i => (i.source || 'works') !== source);
  const keepCats = allCats.filter(c => (c.source || 'works') !== source);
  await clearStore('ratebook_categories');
  await clearStore('ratebook_items');
  await putAll('ratebook_categories', keepCats);
  await putAll('ratebook_items', keepItems);
}

export async function migrateRateBook() {
  const items = await getAll('ratebook_items');
  const itemsToFix = items.filter(i =>
    i.descriptionAm === undefined ||
    i.tenderAliases === undefined ||
    i.source === undefined
  );
  if (itemsToFix.length > 0) {
    await putAll('ratebook_items', itemsToFix.map(i => ({
      ...i,
      descriptionAm: i.descriptionAm ?? '',
      tenderAliases: i.tenderAliases ?? [],
      source: i.source ?? 'works'
    })));
  }
  const cats = await getAll('ratebook_categories');
  const catsToFix = cats.filter(c => c.titleAm === undefined || c.source === undefined);
  if (catsToFix.length > 0) {
    await putAll('ratebook_categories', catsToFix.map(c => ({
      ...c,
      titleAm: c.titleAm ?? c.title,
      source: c.source ?? 'works'
    })));
  }
  return { itemsFixed: itemsToFix.length, categoriesFixed: catsToFix.length };
}

export async function addTenderAlias(rateItemId, tenderDescription) {
  const alias = String(tenderDescription || '').trim().replace(/\s+/g, ' ');
  if (alias.length < 3) return null;
  const rows = await getAll('ratebook_items');
  const item = rows.find(r => r.id === rateItemId);
  if (!item) return null;
  const existing = item.tenderAliases || [];
  const lower = alias.toLowerCase();
  if (existing.some(a => a.toLowerCase() === lower)) return item;
  const next = { ...item, tenderAliases: [...existing, alias] };
  await put('ratebook_items', next);
  return next;
}

export async function removeTenderAlias(rateItemId, alias) {
  const rows = await getAll('ratebook_items');
  const item = rows.find(r => r.id === rateItemId);
  if (!item) return null;
  const next = { ...item, tenderAliases: (item.tenderAliases || []).filter(a => a !== alias) };
  await put('ratebook_items', next);
  return next;
}

export async function createRateItem({ description, descriptionAm = '', unit, rate, categoryId = 'custom', source = 'works' }) {
  const clean = String(description || '').trim().replace(/\s+/g, ' ');
  if (!clean) throw new Error('Description required');
  const id = source + ':custom:' + Date.now().toString(36) + ':' + Math.random().toString(36).slice(2, 6);
  const next = {
    id,
    source,
    categoryId,
    code: '',
    description: clean,
    descriptionAm: String(descriptionAm || '').trim(),
    tenderAliases: [clean],
    unit: String(unit || ''),
    basePrice: Number(rate) || 0,
    contractorPrice: Number(rate) || 0,
    page: 0
  };
  await put('ratebook_items', next);

  const cats = await getAll('ratebook_categories');
  const catId = source + ':custom';
  if (!cats.some(c => c.id === catId)) {
    await put('ratebook_categories', {
      id: catId,
      source,
      title: source === 'goods' ? 'Custom goods' : 'Custom items',
      titleAm: source === 'goods' ? 'ብጁ ዕቃዎች' : 'ብጁ ዕቃዎች (ከጨረታ የተጨመሩ)',
      itemCount: 0
    });
  }
  return next;
}END
cat > src/data/rbd.js << 'END'
END
cat > src/data/remote.js << 'END'
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
END
cat > src/data/requests.js << 'END'
import { put, getAll, del } from './db.js';
export async function saveRequest(req) { return put('quote_requests', req); }
export async function getRequests() { return getAll('quote_requests'); }
export async function deleteRequest(id) { return del('quote_requests', id); }
export async function updateRequestStatus(id, status) {
  const all = await getAll('quote_requests');
  const r = all.find(x => x.id === id);
  if (!r) return null;
  const next = Object.assign({}, r, { status });
  await put('quote_requests', next);
  return next;
}
export function newRequestId() { return 'req_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 6); }
END
cat > src/data/store.js << 'END'
import { useState, useEffect } from 'preact/hooks';
import { saveBusinessInfo, getBusinessInfo } from './business.js';

const KEY = 'mesay_data_v2';

export const DEFAULT_DATA = {
  business: {
    nameEn: 'Mesay Abebe General Contractor',
    nameAm: 'መሳይ አበበ አጠቃላይ ተቋራጭ G5',
    taglineEn: 'General Contractor G5 · Building, Road & Renovation',
    taglineAm: 'አጠቃላይ ተቋራጭ (511114) · ህንፃ፣ መንገድ እና ማሻሻያ',
    subtitleEn: 'Building construction, road works, renovation — plus construction materials delivered to your site.',
    subtitleAm: 'በአዲስ አበባ ጉለሌ ክፍለ ከተማ የተመዘገበ አጠቃላይ ተቋራጭ።',
    ownerName: 'Mr. MESAY ABEBE BAHIRE',
    fieldOfBusiness: 'General Contractor Except water work',
    businessLicenseNo: 'GU/AA/14/668/717216/2010',
    principalRegNo: 'GU/AA/1/0006440/2009',
    previousLicenseNo: '980/2016',
    tin: '0054073141',
    capital: 'ETB 500,000.00',
    dateOfIssuance: '18/4/2010',
    renewalDate: '3/10/2018',
    businessLicenseIssued: '6/10/2026',
    bureau: 'Addis Ababa City Administration Trade Bureau',
    cell1: '+251 911 891 851',
    cell2: '+251 912 175 984',
    cell3: '+251 911 891 888',
    phone: '+251 911 891 851',
    tel: '0926803092',
    email: 'info@mesayabebe.et',
    region: 'Addis Ababa',
    zoneSubCity: 'Gulele',
    woreda: '08',
    houseNo: '185',
    addressEn: 'Gulele Sub-city, Woreda 08, House No. 185, Addis Ababa',
    addressAm: 'ጉለሌ ክፍለ ከተማ ወረዳ 08 ቤት ቁጥር 185 አዲስ አበባ',
    currency: 'ETB', vatRate: 0.15, validDays: 30,
    markupPct: 15, contingencyPct: 5, inflationFactor: 1.0,
    staffPassword: 'mesay2024',
    disclaimer: 'Rates based on Addis Ababa Design and Construction Works Bureau, 2018 4th Quarter, Direct Cost Only. Actual rates subject to site conditions and current market.',
    defaultTerms: '50% advance with order, balance on delivery. Prices valid 30 days. Subject to stock and site availability.'
  },
  services: [
    { id: 'sv1', icon: '🏢', titleEn: 'Building Construction', titleAm: 'የህንፃ ግንባታ', descEn: 'Residential, commercial and institutional buildings.' },
    { id: 'sv2', icon: '🛣️', titleEn: 'Road Works', titleAm: 'የመንገድ ስራ', descEn: 'Urban and rural roads, drainage, culverts, and asphalt.' },
    { id: 'sv3', icon: '🏗️', titleEn: 'Renovation & Fit-out', titleAm: 'ማሻሻያ እና ማስተካከያ', descEn: 'Interior fit-outs, structural retrofits, and finishing.' },
    { id: 'sv4', icon: '📦', titleEn: 'General material Supply', titleAm: 'አጠቃላይ አቅርቦት', descEn: 'Construction materials, fixtures, and equipment supply.' }
  ],
  projects: [
    { id: 'p1', title: 'Network Tower and compound fence', type: 'Telecom', icon: '🏢', image: 'img/messe/1.jpg', desc: 'Telecom infrastructure for safaricom.', budget: 'ETB 85,000,000', duration: '24 months', year: 2024, client: 'Safaricom Ethiopia' },
    { id: 'p2', title: 'solar panel array', type: 'Telecom', icon: '🛣️', image: 'img/messe/2.jpg', desc: 'solar power supply for network tower installation', budget: 'ETB 42,000,000', duration: '14 months', year: 2023, client: 'Safaricom-ethiopia' },
    { id: 'p3', title: 'Commercial Office Fit-out', type: 'building', icon: '🏢', image: 'img/messe/3.jpg', desc: '1,800 m² office interior fit-out.', budget: 'ETB 28,000,000', duration: '8 months', year: 2023, client: 'Private client' }
  ],
  reviews: [
    { id: 'r1', name: 'Ato Bekele T.', loc: 'Addis Ababa', stars: 5, text: 'Delivered our residential building on schedule. Professional site management.' },
    { id: 'r2', name: 'Ato Dawit M.', loc: 'Gulele', stars: 5, text: 'Road quality met every spec. Good communication with our engineers.' },
    { id: 'r3', name: 'W/ro Hana G.', loc: 'Addis Ababa', stars: 5, text: 'Office fit-out finished on time and on budget.' }
  ],
  categories: [
    { id: 'cement', name: 'Cement & Binders', nameAm: 'ሲሚንቶ', icon: '🧱' },
    { id: 'steel', name: 'Steel & Rebar', nameAm: 'ብረት', icon: '🔩' },
    { id: 'lumber', name: 'Lumber & Timber', nameAm: 'እንጨት', icon: '🪵' },
    { id: 'aggregate', name: 'Aggregates', nameAm: 'ጠጠር እና አሸዋ', icon: '⛰️' },
    { id: 'fixtures', name: 'Fixtures & Pipes', nameAm: 'ቧንቧ እና መለዋወጫ', icon: '🚰' }
  ],
  products: [
    { id: 'sku_cem_425', category: 'cement', name: 'Dangote / Mugher OPC 42.5N', unit: 'quintal (100 kg)', basePrice: 1050, contractorPrice: 1050, stock: 24000, leadTimeDays: 2, taxable: true, tiers: [ { min: 1, price: 1050 }, { min: 20, price: 1020 }, { min: 100, price: 990 } ] },
    { id: 'sku_cem_325', category: 'cement', name: 'PPC 32.5N Cement', unit: 'quintal (100 kg)', basePrice: 940, contractorPrice: 940, stock: 32000, leadTimeDays: 2, taxable: true, tiers: [ { min: 1, price: 940 }, { min: 20, price: 910 }, { min: 100, price: 880 } ] },
    { id: 'sku_reb_8',  category: 'steel', name: 'Rebar Ø8 mm — Deformed', unit: 'ton', basePrice: 132000, contractorPrice: 132000, stock: 180, leadTimeDays: 4, taxable: true, tiers: [ { min: 1, price: 132000 }, { min: 5, price: 129500 }, { min: 20, price: 126000 } ] },
    { id: 'sku_reb_12', category: 'steel', name: 'Rebar Ø12 mm — Deformed', unit: 'ton', basePrice: 130500, contractorPrice: 130500, stock: 240, leadTimeDays: 4, taxable: true, tiers: [ { min: 1, price: 130500 }, { min: 5, price: 128000 }, { min: 20, price: 124500 } ] },
    { id: 'sku_reb_16', category: 'steel', name: 'Rebar Ø16 mm — Deformed', unit: 'ton', basePrice: 129000, contractorPrice: 129000, stock: 160, leadTimeDays: 4, taxable: true, tiers: [ { min: 1, price: 129000 }, { min: 5, price: 126500 }, { min: 20, price: 123000 } ] },
    { id: 'sku_lum_pine', category: 'lumber', name: 'Pine Timber 2x4x4m', unit: 'piece', basePrice: 380, contractorPrice: 380, stock: 3200, leadTimeDays: 3, taxable: true, tiers: [ { min: 1, price: 380 }, { min: 50, price: 360 }, { min: 200, price: 340 } ] },
    { id: 'sku_agg_crushed', category: 'aggregate', name: 'Crushed Stone 20 mm', unit: 'm³', basePrice: 950, contractorPrice: 950, stock: 1800, leadTimeDays: 3, taxable: true, tiers: [ { min: 1, price: 950 }, { min: 10, price: 900 }, { min: 50, price: 850 } ] },
    { id: 'sku_agg_sand', category: 'aggregate', name: 'Washed River Sand', unit: 'm³', basePrice: 850, contractorPrice: 850, stock: 2200, leadTimeDays: 3, taxable: true, tiers: [ { min: 1, price: 850 }, { min: 10, price: 800 }, { min: 50, price: 750 } ] },
    { id: 'sku_fix_pvc110', category: 'fixtures', name: 'PVC Pipe Ø110 mm x 6 m', unit: 'piece', basePrice: 1650, contractorPrice: 1650, stock: 900, leadTimeDays: 2, taxable: true, tiers: [ { min: 1, price: 1650 }, { min: 20, price: 1580 }, { min: 100, price: 1500 } ] },
    { id: 'sku_fix_pvc63', category: 'fixtures', name: 'PVC Pipe Ø63 mm x 6 m', unit: 'piece', basePrice: 780, contractorPrice: 780, stock: 1400, leadTimeDays: 2, taxable: true, tiers: [ { min: 1, price: 780 }, { min: 20, price: 740 }, { min: 100, price: 700 } ] }
  ],
  freight: { zones: [ { id: 'addis', name: 'Addis Ababa', flat: 800, perTon: 40 }, { id: 'nearby', name: 'Within 100 km', flat: 1800, perTon: 75 }, { id: 'regional', name: 'Regional (100-400)', flat: 4500, perTon: 140 }, { id: 'far', name: 'Remote (> 400 km)', flat: 9000, perTon: 220 } ] },
  hero: { badge1En: 'General Contractor G5', badge1Am: 'አጠቃላይ ተቋራጭ 511114', badge2En: 'Trusted', badge2Am: 'ma', badge3En: '10+ Years', badge3Am: '18+ ዓመታት' },
  stats: [ { id: 's1', num: '120+', lblEn: 'Projects Delivered', lblAm: 'የተጠናቀቁ ፕሮጀክቶች' }, { id: 's2', num: '18+',  lblEn: 'Years in Business',  lblAm: 'የንግድ ዓመታት' }, { id: 's3', num: '511114', lblEn: 'License Code',     lblAm: 'የፈቃድ ኮድ' }, { id: 's4', num: '100%', lblEn: 'VAT Registered',     lblAm: 'ተ.እ.ታ ተመዝጋቢ' } ]
};

let _state = DEFAULT_DATA;
const subs = new Set();

// Sync state to components
export function getData() { return _state; }
export function subscribe(fn) { subs.add(fn); return () => subs.delete(fn); }
export function setData(next) {
  _state = next;
  // Save "business" to IndexedDB
  if (next.business) saveBusinessInfo(next.business).catch(e => console.warn('Save business failed', e));
  subs.forEach(fn => fn(next));
}
export function resetData() { setData(DEFAULT_DATA); }

export function useStore() {
  const [d, setD] = useState(_state);
  
  useEffect(() => {
    let alive = true;
    
    // Load from IndexedDB (with migration from localStorage if needed)
    (async () => {
      try {
        const idbBiz = await getBusinessInfo();
        if (idbBiz) {
          _state = { ..._state, business: idbBiz };
          if (alive) setD(_state);
        } else {
          // Migration: load from localStorage once
          const raw = localStorage.getItem(KEY);
          if (raw) {
            const parsed = JSON.parse(raw);
            if (parsed.business) {
              await saveBusinessInfo(parsed.business);
              _state = { ..._state, business: parsed.business };
              if (alive) setD(_state);
              console.log('Migrated business to IndexedDB');
            }
          }
        }
      } catch (e) { console.warn('DB load error:', e); }
    })();
    
    return subscribe(d => { if (alive) setD(d); });
  }, []);
  
  return [d, setData];
}

export function uid() { return 'id_' + Math.random().toString(36).slice(2, 9); }END
cat > src/data/tenders.js << 'END'
import { putAll, getAll, get, put, del } from './db.js';

export const saveTenders      = (list)    => putAll('egp_tenders', list);
export const getTenders       = ()        => getAll('egp_tenders');
export const deleteTender     = (id)      => del('egp_tenders', id);

export const saveTenderDetail = (d)       => put('egp_tender_details', d);
export const getTenderDetail  = (lotId)   => get('egp_tender_details', lotId);

export const saveTenderItems  = (rec)     => put('egp_tender_items', rec);
export const getTenderItems   = (key)     => get('egp_tender_items', key);END
cat > src/admin/Admin.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { supabase } from '../lib/supabase.js';
import { signOut, isAdminUser } from '../lib/auth.js';
import { AdminHome, ADMIN_TOOLS } from './AdminHome.jsx';
import { RequestsTab } from './RequestsTab.jsx';
import { ProformasTab } from './ProformasTab.jsx';
import { RateBookTab } from './RateBookTab.jsx';
import { TendersTab } from './TendersTab.jsx';
import { CatalogTab, ProjectsTab, ReviewsTab, BusinessTab, UsersTab, SettingsTab } from './Tabs.jsx';
import { ProformaBuilder } from '../components/ProformaBuilder.jsx';

export function Admin({ onExit }) {
  const [data] = useStore();
  const [tab, setTab] = useState('home');
  const [builder, setBuilder] = useState(null);

  const viewSite = () => { sessionStorage.removeItem('mesay_staff'); onExit(); };
  const leave = async () => { sessionStorage.removeItem('mesay_staff'); await signOut(); onExit(); };

  useEffect(() => {
    (async () => {
      if (!supabase) { viewSite(); return; }
      const { data: s } = await supabase.auth.getSession();
      const u = s.session && s.session.user;
      if (!u || !(await isAdminUser(u.id))) leave();
    })();
  }, []);

  const openBuilder = (mode, request) => { setBuilder({ mode, request: request || null }); setTab('proformas'); };
  const go = (id) => { setBuilder(null); setTab(id); };

  let body;
  if (builder) {
    body = <ProformaBuilder key={builder.mode + (builder.request ? (builder.request.id || builder.request.tender?.id || '') : '')} mode={builder.mode} request={builder.request} onClose={() => setBuilder(null)} />;
  } else if (tab === 'home') body = <AdminHome onOpen={go} />;
  else if (tab === 'requests') body = <RequestsTab onBuildProforma={(r) => openBuilder('from-request', r)} />;
  else if (tab === 'tenders') body = <TendersTab onCreateProforma={(payload) => openBuilder('from-tender', payload)} />;
  else if (tab === 'proformas') body = <ProformasTab onNew={(mode) => openBuilder(mode)} onGoRequests={() => go('requests')} onGoTenders={() => go('tenders')} />;
  else if (tab === 'ratebook') body = <RateBookTab />;
  else if (tab === 'catalog') body = <CatalogTab />;
  else if (tab === 'projects') body = <ProjectsTab />;
  else if (tab === 'reviews') body = <ReviewsTab />;
  else if (tab === 'business') body = <BusinessTab />;
  else if (tab === 'users') body = <UsersTab />;
  else if (tab === 'settings') body = <SettingsTab />;

  return (
    <div class="admin">
      <div class="admin-header">
        <strong>{data.business.nameEn} · Admin</strong>
        <div class="admin-header-actions">
          <button class="btn-view" onClick={viewSite}>View Site</button>
          <button class="btn-danger" onClick={leave}>Sign out</button>
        </div>
      </div>
      <div class="admin-tabs">
        <button class={'admin-tab ' + (tab === 'home' && !builder ? 'active' : '')} onClick={() => go('home')}>Home</button>
        {ADMIN_TOOLS.map(t => (
          <button class={'admin-tab ' + (tab === t.id ? 'active' : '')} key={t.id} onClick={() => go(t.id)}>{t.icon} {t.title}</button>
        ))}
      </div>
      <div class="admin-body">{body}</div>
    </div>
  );
}END
cat > src/admin/AdminHome.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { getRequests } from '../data/requests.js';
import { getProformas } from '../data/proformas.js';
import { getRateItems } from '../data/ratebook.js';
import { getTenders } from '../data/tenders.js';
import { supabase } from '../lib/supabase.js';
import { BUSINESS_FIELDS } from './fields.js';



export const ADMIN_TOOLS = [
  { id: 'requests',  icon: 'Inbox',     title: 'Quote Requests',   subtitle: 'Service and material requests from clients', unit: 'requests' },
  { id: 'tenders',   icon: 'Tenders',   title: 'Tenders',          subtitle: 'eGP construction bids',                      unit: 'tenders' },
  { id: 'proformas', icon: 'Proforma',  title: 'Proformas',        subtitle: 'Build, track and print quotations',          unit: 'proformas' },
  { id: 'ratebook',  icon: 'Rate Book', title: 'Rate Book',        subtitle: 'Bureau unit rates and contractor prices',    unit: 'items' },
  { id: 'catalog',   icon: 'Catalog',   title: 'Materials Catalog',subtitle: 'Products shown to customers',                unit: 'products' },
  { id: 'projects',  icon: 'Projects',  title: 'Projects',         subtitle: 'Recent projects gallery',                    unit: 'projects' },
  { id: 'reviews',   icon: 'Reviews',   title: 'Reviews',          subtitle: 'Client testimonials',                        unit: 'reviews' },
  { id: 'business',  icon: 'Business',  title: 'Business Info',    subtitle: 'License, contacts and address',              unit: 'fields set' },
  { id: 'users',     icon: 'Users',     title: 'Users/Roles',      subtitle: 'Who can sign in to admin',                   unit: 'admins' },
  { id: 'settings',  icon: 'Settings',  title: 'Settings',         subtitle: 'VAT, terms, markup and freight',             unit: 'freight zones' }
];

export function AdminHome({ onOpen }) {
  const [data] = useStore();
  const [counts, setCounts] = useState({});
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    let alive = true;
    (async () => {
      const next = {};
      try { next.requests = (await getRequests()).length; } catch (e) {}
      try { next.tenders = (await getTenders()).length; } catch (e) {}
      try { next.proformas = (await getProformas()).length; } catch (e) {}
      try { next.ratebook = (await getRateItems()).length; } catch (e) {}
      if (supabase) {
        try {
          const r = await supabase.from('admin_users').select('user_id', { count: 'exact', head: true });
          if (!r.error) next.users = r.count;
        } catch (e) {}
      }
      if (alive) { setCounts(next); setLoaded(true); }
    })();
    return () => { alive = false; };
  }, []);

  const live = {
    requests: counts.requests,
    tenders: counts.tenders,
    proformas: counts.proformas,
    ratebook: counts.ratebook,
    catalog: data.products.length,
    projects: data.projects.length,
    reviews: data.reviews.length,
    business: BUSINESS_FIELDS.filter(([k]) => data.business[k] !== '' && data.business[k] != null).length,
    users: counts.users,
    settings: data.freight.zones.length
  };
  const show = (id) => live[id] != null ? live[id] : (loaded ? '0' : '...');

  return (
    <div class="admin-panel">
      <h2>Dashboard</h2>
      <div class="gadget-grid">
        {ADMIN_TOOLS.map(t => (
          <button type="button" class="gadget" key={t.id} onClick={() => onOpen(t.id)}>
            <span class="gadget-icon">{t.icon}</span>
            <span class="gadget-title">{t.title}</span>
            <span class="gadget-sub">{t.subtitle}</span>
            <span class="gadget-count">{show(t.id)}<small>{t.unit}</small></span>
          </button>
        ))}
      </div>
    </div>
  );
}END
cat > src/admin/ProformasTab.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { getProformas, deleteProforma, duplicateProforma, updateProformaStatus } from '../data/proformas.js';
import { formatMoney } from '../data/pricing.js';
import { ProformaDoc } from '../components/ProformaBuilder.jsx';

const STATUSES = ['draft', 'sent', 'accepted', 'rejected', 'expired'];

export function ProformasTab({ onNew, onGoRequests, onGoTenders }) {
  const [rows, setRows] = useState(null);
  const [chooser, setChooser] = useState(false);
  const [viewing, setViewing] = useState(null);

  const load = async () => {
    const all = await getProformas();
    setRows(all.sort((a, b) => String(b.number).localeCompare(String(a.number))));
  };
  useEffect(() => { load(); }, []);

  const setStatus = async (p, status) => { await updateProformaStatus(p.id, status); load(); };
  const dup = async (p) => { await duplicateProforma(p.id); load(); };
  const remove = async (p) => { if (confirm('Delete proforma ' + p.number + '?')) { await deleteProforma(p.id); load(); } };

  if (viewing) {
    return (
      <div class="admin-panel">
        <div class="pf-actions no-print">
          <button class="btn btn-back" onClick={() => setViewing(null)}>Back</button>
          <button class="btn btn-primary" onClick={() => window.print()}>Print</button>
        </div>
        <ProformaDoc pf={viewing} />
      </div>
    );
  }
  if (!rows) return <div class="admin-panel"><h2>Proformas</h2><p>Loading...</p></div>;

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Proformas ({rows.length})</h2>
        <button class="btn-add" onClick={() => setChooser(!chooser)}>+ New Proforma</button>
      </div>
      {chooser && (
        <div class="admin-card">
          <strong>Start a proforma</strong>
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => { setChooser(false); onGoRequests && onGoRequests(); }}>
              From a request
            </button>
            <button class="btn btn-primary" onClick={() => { setChooser(false); onNew('internal'); }}>
              Internal / open bidding
            </button>
            <button class="btn btn-back" onClick={() => { setChooser(false); onGoTenders && onGoTenders(); }}>
              From eGP tender
            </button>
          </div>
        </div>
      )}
      {rows.length === 0 && <div class="admin-card">No proformas yet.</div>}
      {rows.map(p => (
        <div class="admin-card" key={p.id}>
          <div class="admin-card-head">
            <strong style="flex:1;min-width:160px;">{p.number}</strong>
            <span class={'pf-status ' + p.status}>{p.status}</span>
            <select value={p.status} onChange={e => setStatus(p, e.target.value)}>
              {STATUSES.map(s => <option value={s}>{s}</option>)}
            </select>
          </div>
          <div style="font-size:0.85rem;color:var(--gray);">
            {(p.client && p.client.name) || '-'} · {p.createdAt} · {p.mode === 'internal' ? 'Internal' : (p.mode === 'from-tender' ? 'From tender' : 'From request')} · <strong>{formatMoney(p.totals && p.totals.grandTotal)}</strong>
          </div>
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => setViewing(p)}>View</button>
            <button class="btn btn-back" onClick={() => dup(p)}>Duplicate</button>
            <button class="btn-del" onClick={() => remove(p)}>Delete</button>
          </div>
        </div>
      ))}
    </div>
  );
}END
cat > src/admin/RateBookTab.jsx << 'END'
import { useState, useEffect, useMemo } from 'preact/hooks';
import { useStore } from '../data/store.js';
import {
  getRateBookMeta, getRateCategories, getRateItems, updateRateItem,
  applyInflation, resetContractorPrices, seedFromModule,
} from '../data/ratebook.js';
import { importGoods, getGoodsMeta } from '../data/goods.js';
import { GOODS } from '../data/goods-data.js';

export function RateBookTab() {
  const [data] = useStore();
  const [source, setSource] = useState('works');
  const [meta, setMeta] = useState(null);
  const [goodsMeta, setGoodsMeta] = useState(null);
  const [cats, setCats] = useState([]);
  const [items, setItems] = useState([]);
  const [cat, setCat] = useState('all');
  const [q, setQ] = useState('');
  const [factor, setFactor] = useState(String(data.business.inflationFactor || 1));
  const [alsoContractor, setAlsoContractor] = useState(false);
  const [msg, setMsg] = useState('');
  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkText, setBulkText] = useState('');

  const load = async () => {
    const [m, gm, c, i] = await Promise.all([
      getRateBookMeta(),
      getGoodsMeta(),
      getRateCategories(),
      getRateItems(),
    ]);
    setMeta(m); setGoodsMeta(gm); setCats(c); setItems(i);
  };

  useEffect(() => { load(); }, []);
  useEffect(() => { load(); }, [source]);

  const activeMeta = source === 'goods' ? goodsMeta : meta;
  const activeCats = useMemo(() => cats.filter(c => (c.source || 'works') === source), [cats, source]);

  const results = useMemo(() => {
    const s = q.trim().toLowerCase();
    return items.filter(i => {
      if ((i.source || 'works') !== source) return false;
      if (cat !== 'all' && i.categoryId !== cat) return false;
      if (!s) return true;
      return (
        String(i.code).toLowerCase().includes(s) ||
        String(i.description).toLowerCase().includes(s) ||
        String(i.descriptionAm || '').includes(s) ||
        (i.tenderAliases || []).some(a => a.toLowerCase().includes(s))
      );
    });
  }, [items, cat, q, source]);

  const savePrice = async (item, raw) => {
    const v = raw === '' ? null : parseFloat(raw);
    await updateRateItem(item.id, { contractorPrice: v });
    setItems(items.map(i => i.id === item.id ? Object.assign({}, i, { contractorPrice: v }) : i));
  };

  const saveAmharic = async (item, v) => {
    await updateRateItem(item.id, { descriptionAm: v });
    setItems(items.map(i => i.id === item.id ? Object.assign({}, i, { descriptionAm: v }) : i));
  };

  const inflate = async () => {
    const f = parseFloat(factor);
    if (!f || f <= 0) { setMsg('Enter a valid factor, e.g. 1.05'); return; }
    if (!confirm(`Multiply all ${source} base prices by ${f}?`)) return;
    const n = await applyInflation(f, alsoContractor, source);
    setMsg('Updated ' + n + ' items.'); load();
  };

  const resetPrices = async () => {
    if (!confirm(`Reset every ${source} contractor price to its base price?`)) return;
    const n = await resetContractorPrices(source);
    setMsg('Reset ' + n + ' items.'); load();
  };

  const reseedWorks = async () => {
    if (!confirm('Reload the civil-works rate book? This replaces all civil-works items.')) return;
    const r = await seedFromModule();
    setMsg('Loaded ' + r.itemCount + ' works items.'); load();
  };

  const loadGoods = async () => {
    if (!confirm('Load the goods catalog? Existing goods items will be replaced.')) return;
    const r = await importGoods(GOODS);
    setMsg('Loaded ' + r.itemCount + ' goods items.'); load();
  };

  const applyBulk = async () => {
    const lines = bulkText.split('\n').map(l => l.trim()).filter(Boolean);
    if (lines.length === 0) { setMsg('Nothing to import.'); return; }
    let updated = 0, missed = 0;
    for (const line of lines) {
      const parts = line.split(/\t|,(?=[\u1200-\u137F])/);
      if (parts.length < 2) { missed++; continue; }
      const code = parts[0].trim();
      const am = parts.slice(1).join(',').trim();
      if (!code || !am) { missed++; continue; }
      const target = items.find(i => (i.source || 'works') === source && i.code === code);
      if (!target) { missed++; continue; }
      await updateRateItem(target.id, { descriptionAm: am });
      updated++;
    }
    await load();
    setMsg(`Bulk import: ${updated} updated, ${missed} skipped.`);
    setBulkText('');
    setBulkOpen(false);
  };

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Rate Book — {source === 'goods' ? 'Goods' : 'Civil works'} ({results.length} items)</h2>
        <div class="pf-actions" style="margin:0;">
          <select value={source} onChange={e => { setSource(e.target.value); setCat('all'); }}>
            <option value="works">Civil works</option>
            <option value="goods">Goods</option>
          </select>
          <button class="btn btn-back" onClick={load}>Refresh</button>
          <button class="btn btn-back" onClick={() => setBulkOpen(!bulkOpen)}>
            {bulkOpen ? 'Close bulk' : 'Bulk paste Amharic'}
          </button>
          {source === 'works'
            ? <button class="btn-add" onClick={reseedWorks}>Reload works</button>
            : <button class="btn-add" onClick={loadGoods}>Load goods catalog</button>}
        </div>
      </div>

      {activeMeta && (
        <div class="admin-card" style="font-size:0.85rem;color:var(--gray);">
          {activeMeta.source || ''} {activeMeta.quarter || ''} · imported {String(activeMeta.importedAt || '').slice(0, 10)}
        </div>
      )}
      {msg && <div class="admin-msg">{msg}</div>}

      {bulkOpen && (
        <div class="admin-card">
          <strong>Bulk Amharic import ({source})</strong>
          <p style="font-size:0.8rem;color:var(--gray);margin:4px 0 8px;">
            One line per item: <code>code&lt;TAB&gt;amharic description</code>.
          </p>
          <textarea
            rows="6"
            style="width:100%;font-family:monospace;font-size:0.82rem;padding:8px;border:1px solid var(--border);border-radius:6px;"
            value={bulkText}
            onInput={e => setBulkText(e.target.value)}
          />
          <div class="pf-actions">
            <button class="btn-add" onClick={applyBulk}>Apply</button>
            <button class="btn btn-back" onClick={() => { setBulkText(''); setBulkOpen(false); }}>Cancel</button>
          </div>
        </div>
      )}

      <div class="admin-card">
        <div class="admin-grid3">
          <div class="admin-field"><label>Inflation factor</label>
            <input type="number" step="any" value={factor} onInput={e => setFactor(e.target.value)} /></div>
          <div class="admin-field"><label>Also set contractor price</label>
            <select value={alsoContractor ? 'yes' : 'no'} onChange={e => setAlsoContractor(e.target.value === 'yes')}>
              <option value="no">No</option><option value="yes">Yes</option>
            </select></div>
          <div class="admin-field"><label>&nbsp;</label>
            <button class="btn-add" onClick={inflate}>Apply</button></div>
        </div>
        <button class="btn-del" onClick={resetPrices}>Reset contractor prices</button>
      </div>

      <div class="admin-grid2">
        <div class="admin-field"><label>Search (English or Amharic)</label>
          <input value={q} onInput={e => setQ(e.target.value)} placeholder="Code, description, or አማርኛ" /></div>
        <div class="admin-field"><label>Category</label>
          <select value={cat} onChange={e => setCat(e.target.value)}>
            <option value="all">All categories</option>
            {activeCats.map(c => (
              <option value={c.id}>{c.titleAm || c.title}</option>
            ))}
          </select>
        </div>
      </div>

      <div class="admin-card">
        {results.slice(0, 100).map(i => (
          <div class="ratebook-row" key={i.id} style="grid-template-columns: 70px 1fr 70px 50px 70px;">
            <span class="rb-code">{i.code}</span>
            <div style="display:flex;flex-direction:column;gap:4px;">
              <span class="rb-desc">{i.description}</span>
              <input
                placeholder="Amharic description (optional)"
                value={i.descriptionAm || ''}
                onInput={e => saveAmharic(i, e.target.value)}
                style="font-size:0.78rem;padding:2px 6px;border:1px solid var(--border);border-radius:4px;direction:auto;"
              />
            </div>
            <span class="rb-price">{i.basePrice == null ? '—' : i.basePrice}</span>
            <span class="rb-unit">{i.unit}</span>
            <input
              type="number" step="any"
              value={i.contractorPrice == null ? '' : i.contractorPrice}
              onChange={e => savePrice(i, e.target.value)}
            />
          </div>
        ))}
        {results.length === 0 && (
          <div>
            No items yet.
            {source === 'goods' && ' Click "Load goods catalog".'}
            {source === 'works' && ' Click "Reload works".'}
          </div>
        )}
        {results.length > 100 && (
          <p style="font-size:0.78rem;color:var(--gray);margin-top:8px;">
            Showing the first 100 of {results.length} matches.
          </p>
        )}
      </div>
    </div>
  );
}END
cat > src/admin/RequestsTab.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { getRequests, saveRequest, deleteRequest } from '../data/requests.js';
import { fetchRemoteRequests, updateRemoteRequestStatus, deleteRemoteRequest } from '../data/remote.js';

const STATUSES = ['new', 'quoted', 'closed'];

export function RequestsTab({ onBuildProforma }) {
  const [rows, setRows] = useState(null);
  const [kind, setKind] = useState('all');
  const [openId, setOpenId] = useState(null);

  const load = async () => {
    const local = await getRequests();
    let remote = [];
    try { remote = await fetchRemoteRequests(); } catch (e) {}
    const map = new Map();
    remote.forEach(r => map.set(r.id, r));
    local.forEach(r => map.set(r.id, Object.assign({}, map.get(r.id) || {}, r)));
    setRows(Array.from(map.values()).sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt))));
  };
  useEffect(() => { load(); }, []);

  const setStatus = async (r, status) => {
    await saveRequest(Object.assign({}, r, { status }));
    updateRemoteRequestStatus(r.id, status);
    setRows(rows.map(x => x.id === r.id ? Object.assign({}, x, { status }) : x));
  };
  const remove = async (r) => {
    if (!confirm('Delete this request?')) return;
    await deleteRequest(r.id);
    deleteRemoteRequest(r.id);
    setRows(rows.filter(x => x.id !== r.id));
  };

  if (!rows) return <div class="admin-panel"><h2>Quote Requests</h2><p>Loadingâ€¦</p></div>;
  const list = kind === 'all' ? rows : rows.filter(r => r.kind === kind);

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Quote Requests ({list.length})</h2>
        <div class="pf-mode-tabs">
          {['all', 'services', 'materials'].map(k => (
            <button class={'pf-mode ' + (kind === k ? 'active' : '')} key={k} onClick={() => setKind(k)}>{k}</button>
          ))}
        </div>
      </div>
      {list.length === 0 && <div class="admin-card">No requests yet.</div>}
      {list.map(r => {
        const c = r.client || {};
        const isOpen = openId === r.id;
        return (
          <div class="admin-card" key={r.id}>
            <div class="admin-card-head">
              <strong style="flex:1;min-width:160px;">{c.name || '(no name)'} Â· {c.phone}</strong>
              <span class={'pf-status ' + (r.status === 'new' ? 'draft' : r.status)}>{r.kind}</span>
              <select value={r.status} onChange={e => setStatus(r, e.target.value)}>
                {STATUSES.map(s => <option value={s}>{s}</option>)}
              </select>
            </div>
            <div style="font-size:0.8rem;color:var(--gray);">
              {String(r.createdAt || '').slice(0, 10)}{c.projectName ? ' Â· ' + c.projectName : ''}{r.userEmail ? ' Â· ' + r.userEmail : ''}
            </div>
            {isOpen && (
              <div class="admin-subcard" style="margin-top:10px;">
                <div>{[c.company, c.email, c.siteAddress].filter(Boolean).join(' Â· ')}</div>
                {r.description && <p style="margin-top:6px;">{r.description}</p>}
                {r.serviceType && <div>Service: {r.serviceType} Â· Budget: {r.budgetRange || 'â€”'} Â· Timeline: {r.timeline || 'â€”'}</div>}
                {c.notes && <p style="margin-top:6px;">Notes: {c.notes}</p>}
                {r.cart && r.cart.length > 0 && (
                  <table class="pf-table">
                    <thead><tr><th>Item</th><th>Qty</th><th>Unit</th></tr></thead>
                    <tbody>{r.cart.map(l => <tr><td>{l.name}</td><td>{l.qty}</td><td>{l.unit}</td></tr>)}</tbody>
                  </table>
                )}
              </div>
            )}
            <div class="pf-actions">
              <button class="btn btn-back" onClick={() => setOpenId(isOpen ? null : r.id)}>{isOpen ? 'Hide details' : 'View details'}</button>
              <button class="btn btn-primary" onClick={() => onBuildProforma(r)}>Build Proforma</button>
              <button class="btn-del" onClick={() => remove(r)}>Delete</button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
END
cat > src/admin/StaffLogin.jsx << 'END'
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
END
cat > src/admin/Tabs.jsx << 'END'
import { useState, useEffect, useMemo } from 'preact/hooks';
import { useStore, setData, uid } from '../data/store.js';
import { supabase } from '../lib/supabase.js';
import { getRateCategories, getRateItems } from '../data/ratebook.js';
import { saveProductImage, deleteProductImage, getProductImageURL } from '../data/images.js';
import { BUSINESS_FIELDS } from './fields.js';

const save = (data, key, value) => setData(Object.assign({}, data, { [key]: value }));
const upd = (list, id, k, v) => list.map(x => x.id === id ? Object.assign({}, x, { [k]: v }) : x);

function Field({ label, value, onInput, type = 'text', step }) {
  return (
    <div class="admin-field">
      <label>{label}</label>
      <input type={type} step={step} value={value == null ? '' : value}
        onInput={e => onInput(type === 'number' ? (e.target.value === '' ? '' : +e.target.value) : e.target.value)} />
    </div>
  );
}
function Area({ label, value, onInput, rows = 3 }) {
  return (
    <div class="admin-field">
      <label>{label}</label>
      <textarea rows={rows} value={value || ''} onInput={e => onInput(e.target.value)} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// MATERIALS CATALOG — products from the rate book, images from IndexedDB
// ---------------------------------------------------------------------------
export function CatalogTab() {
  const [data] = useStore();
  const list = data.products;
  const [cats, setCats] = useState([]);
  const [items, setItems] = useState([]);
  const [q, setQ] = useState('');
  const [cat, setCat] = useState('all');
  const [picking, setPicking] = useState(false);
  const [busyId, setBusyId] = useState(null);
  const [urls, setUrls] = useState({});      // productId -> objectURL
  const [err, setErr] = useState('');

  useEffect(() => {
    (async () => {
      try {
        setCats(await getRateCategories());
        setItems(await getRateItems());
      } catch (e) { console.error('Catalog ratebook load failed:', e); }
    })();
  }, []);

  // Load object URLs for every product that has an image
  useEffect(() => {
    let alive = true;
    (async () => {
      const next = {};
      for (const p of list) {
        if (!p.imageId) continue;
        const url = await getProductImageURL(p.imageId);
        if (url) next[p.id] = url;
      }
      if (alive) setUrls(next);
    })();
    return () => { alive = false; };
  }, [list.map(p => p.imageId).join('|')]);

  const results = useMemo(() => {
    const s = q.trim().toLowerCase();
    return items.filter(i =>
      (cat === 'all' || i.categoryId === cat) &&
      (!s || String(i.code).toLowerCase().includes(s) ||
              String(i.description).toLowerCase().includes(s))
    );
  }, [items, q, cat]);

  const set = (id, k, v) => save(data, 'products', upd(list, id, k, v));
  const setPrice = (id, v) => save(data, 'products',
    list.map(p => p.id === id
      ? Object.assign({}, p, { basePrice: v, contractorPrice: v })
      : p));

  const ensureCategory = (rateCatId) => {
    const rateCat = cats.find(c => String(c.id) === String(rateCatId));
    const title = rateCat ? rateCat.title : String(rateCatId);
    const existing = data.categories.find(c => c.id === String(rateCatId));
    if (existing) return existing.id;
    const newCat = { id: String(rateCatId), name: title, nameAm: title, icon: '📦' };
    setData(Object.assign({}, data, { categories: [...data.categories, newCat] }));
    return newCat.id;
  };

  const addFromRate = (rate) => {
    if (list.some(p => p.rateId === rate.id)) return;
    const catId = ensureCategory(rate.categoryId);
    const product = {
      id: uid(),
      rateId: rate.id,
      category: catId,
      name: rate.description,
      code: rate.code,
      unit: rate.unit,
      basePrice: rate.contractorPrice != null ? rate.contractorPrice : 0,
      contractorPrice: rate.contractorPrice != null ? rate.contractorPrice : 0,
      stock: 0,
      leadTimeDays: 0,
      taxable: true,
      imageId: null,        // key into product_images store
      tiers: []
    };
    save(data, 'products', [...list, product]);
  };

  const addBlank = () => save(data, 'products', [...list, {
    id: uid(), rateId: null,
    category: data.categories[0] ? data.categories[0].id : '',
    name: 'New product', code: '', unit: 'piece',
    basePrice: 0, contractorPrice: 0, stock: 0, leadTimeDays: 0,
    taxable: true, imageId: null, tiers: []
  }]);

  const remove = async (p) => {
    if (!confirm('Delete this product?')) return;
    if (p.imageId) await deleteProductImage(p.imageId);
    save(data, 'products', list.filter(x => x.id !== p.id));
  };

  // Upload a File into IndexedDB for this product
  const onImageFile = async (p, file) => {
    if (!file) return;
    setErr('');
    setBusyId(p.id);
    try {
      if (!file.type.startsWith('image/')) throw new Error('Not an image file.');
      if (file.size > 5 * 1024 * 1024) throw new Error('Image is larger than 5 MB.');
      const imageId = p.imageId || ('img_' + p.id);
      await saveProductImage(imageId, file);
      // Re-read to force the object URL effect to run
      set(p.id, 'imageId', imageId);
      const url = await getProductImageURL(imageId);
      if (url) setUrls(u => Object.assign({}, u, { [p.id]: url }));
    } catch (e) {
      setErr(e.message || String(e));
    }
    setBusyId(null);
  };

  const clearImage = async (p) => {
    if (!p.imageId) return;
    if (!confirm('Remove this image?')) return;
    await deleteProductImage(p.imageId);
    set(p.id, 'imageId', null);
    setUrls(u => { const n = Object.assign({}, u); delete n[p.id]; return n; });
  };

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Materials Catalog ({list.length})</h2>
        <div class="pf-actions" style="margin:0;">
          <button class="btn-add" onClick={() => setPicking(!picking)}>
            {picking ? 'Close rate book' : '+ Add from Rate Book'}
          </button>
          <button class="btn btn-back" onClick={addBlank}>+ Blank product</button>
        </div>
      </div>

      {err && <div class="staff-err" style="margin-bottom:10px;">{err}</div>}

      {picking && (
        <div class="admin-card">
          <strong>Pick items from the rate book</strong>
          <div class="pf-pick-filters" style="margin-top:10px;">
            <input placeholder="Search code or description"
                   value={q} onInput={e => setQ(e.target.value)} />
            <select value={cat} onChange={e => setCat(e.target.value)}>
              <option value="all">All categories</option>
              {cats.map(c => <option value={c.id}>{c.id}. {c.title}</option>)}
            </select>
          </div>
          {items.length === 0 ? (
            <p style="color:var(--gray);font-size:0.9rem;">
              The rate book is empty. Import it from the Rate Book tab first.
            </p>
          ) : (
            <div class="pf-pick-list">
              {results.slice(0, 60).map(i => {
                const already = list.some(p => p.rateId === i.id);
                return (
                  <div class="pf-pick-row" key={i.id}>
                    <span class="rb-code">{i.code}</span>
                    <span class="rb-desc">{i.description}</span>
                    <span class="rb-unit">{i.unit}</span>
                    <span class="rb-price">{i.contractorPrice == null ? '—' : i.contractorPrice}</span>
                    <button type="button" class="btn-add" disabled={already}
                            onClick={() => addFromRate(i)}>
                      {already ? '✓ Added' : '+ Add'}
                    </button>
                  </div>
                );
              })}
              {results.length === 0 && <div class="pf-pick-row">No matching items.</div>}
            </div>
          )}
          {results.length > 60 &&
            <p style="font-size:0.78rem;color:var(--gray);">
              Showing first 60 of {results.length}. Refine the search.
            </p>}
        </div>
      )}

      {list.map(p => {
        const url = urls[p.id];
        return (
          <div class="admin-card" key={p.id}>
            <div class="admin-grid2">
              <Field label="Name" value={p.name} onInput={v => set(p.id, 'name', v)} />
              <Field label="Code (optional)" value={p.code || ''} onInput={v => set(p.id, 'code', v)} />
            </div>

            {/* Image row */}
            <div class="admin-image-row">
              <div class="admin-image-preview">
                {url
                  ? <img src={url} alt={p.name}
                         onError={e => { e.currentTarget.style.display = 'none'; }} />
                  : <span class="admin-image-empty">
                      {busyId === p.id ? 'Saving…' : 'No image'}
                    </span>}
              </div>
              <div class="admin-image-controls">
                <label class="btn-add" style="cursor:pointer;">
                  {url ? 'Replace image' : 'Upload image'}
                  <input type="file" accept="image/*" style="display:none;"
                         disabled={busyId === p.id}
                         onChange={e => {
                           const f = e.target.files && e.target.files[0];
                           e.target.value = '';
                           if (f) onImageFile(p, f);
                         }} />
                </label>
                {url && (
                  <button class="btn-del" onClick={() => clearImage(p)}>Remove image</button>
                )}
              </div>
            </div>

            <div class="admin-grid3">
              <div class="admin-field">
                <label>Category</label>
                <select value={p.category} onChange={e => set(p.id, 'category', e.target.value)}>
                  {data.categories.map(c => <option value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <Field label="Unit" value={p.unit} onInput={v => set(p.id, 'unit', v)} />
              <Field label="Price" type="number" step="any" value={p.basePrice}
                     onInput={v => setPrice(p.id, v)} />
              <Field label="Stock" type="number" value={p.stock}
                     onInput={v => set(p.id, 'stock', v)} />
              <Field label="Lead time (days)" type="number" value={p.leadTimeDays}
                     onInput={v => set(p.id, 'leadTimeDays', v)} />
            </div>

            <button class="btn-del" onClick={() => remove(p)}>Delete</button>
          </div>
        );
      })}

      {list.length === 0 && (
        <div class="admin-card">
          No products yet. Click <strong>+ Add from Rate Book</strong> to pick items.
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// PROJECTS
// ---------------------------------------------------------------------------
export function ProjectsTab() {
  const [data] = useStore();
  const list = data.projects;
  const set = (id, k, v) => save(data, 'projects', upd(list, id, k, v));
  const add = () => save(data, 'projects', [...list, { id: uid(), title: 'New project', type: '', icon: '🏢', image: '', desc: '', budget: '', duration: '', year: new Date().getFullYear(), client: '' }]);
  const remove = (id) => { if (confirm('Delete this project?')) save(data, 'projects', list.filter(p => p.id !== id)); };
  return (
    <div class="admin-panel">
      <div class="admin-panel-head"><h2>Projects ({list.length})</h2><button class="btn-add" onClick={add}>+ Add project</button></div>
      {list.map(p => (
        <div class="admin-card" key={p.id}>
          <div class="admin-grid2">
            <Field label="Title" value={p.title} onInput={v => set(p.id, 'title', v)} />
            <Field label="Type" value={p.type} onInput={v => set(p.id, 'type', v)} />
            <Field label="Icon" value={p.icon} onInput={v => set(p.id, 'icon', v)} />
            <Field label="Image path" value={p.image} onInput={v => set(p.id, 'image', v)} />
            <Field label="Budget" value={p.budget} onInput={v => set(p.id, 'budget', v)} />
            <Field label="Duration" value={p.duration} onInput={v => set(p.id, 'duration', v)} />
            <Field label="Year" type="number" value={p.year} onInput={v => set(p.id, 'year', v)} />
            <Field label="Client" value={p.client} onInput={v => set(p.id, 'client', v)} />
          </div>
          <Area label="Description" value={p.desc} onInput={v => set(p.id, 'desc', v)} />
          <button class="btn-del" onClick={() => remove(p.id)}>Delete</button>
        </div>
      ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// REVIEWS
// ---------------------------------------------------------------------------
export function ReviewsTab() {
  const [data] = useStore();
  const list = data.reviews;
  const set = (id, k, v) => save(data, 'reviews', upd(list, id, k, v));
  const add = () => save(data, 'reviews', [...list, { id: uid(), name: 'New client', loc: '', stars: 5, text: '' }]);
  const remove = (id) => { if (confirm('Delete this review?')) save(data, 'reviews', list.filter(r => r.id !== id)); };
  return (
    <div class="admin-panel">
      <div class="admin-panel-head"><h2>Reviews ({list.length})</h2><button class="btn-add" onClick={add}>+ Add review</button></div>
      {list.map(r => (
        <div class="admin-card" key={r.id}>
          <div class="admin-grid3">
            <Field label="Name" value={r.name} onInput={v => set(r.id, 'name', v)} />
            <Field label="Location" value={r.loc} onInput={v => set(r.id, 'loc', v)} />
            <Field label="Stars (1-5)" type="number" value={r.stars} onInput={v => set(r.id, 'stars', Math.min(5, Math.max(1, v || 1)))} />
          </div>
          <Area label="Review" value={r.text} onInput={v => set(r.id, 'text', v)} />
          <button class="btn-del" onClick={() => remove(r.id)}>Delete</button>
        </div>
      ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// BUSINESS INFO
// ---------------------------------------------------------------------------
export function BusinessTab() {
  const [data] = useStore();
  const b = data.business;
  const set = (k, v) => save(data, 'business', Object.assign({}, b, { [k]: v }));
  return (
    <div class="admin-panel">
      <h2>Business Info</h2>
      <div class="admin-card">
        <div class="admin-grid2">
          {BUSINESS_FIELDS.map(([k, label]) => <Field key={k} label={label} value={b[k]} onInput={v => set(k, v)} />)}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// SETTINGS
// ---------------------------------------------------------------------------
export function SettingsTab() {
  const [data] = useStore();
  const b = data.business;
  const set = (k, v) => save(data, 'business', Object.assign({}, b, { [k]: v }));
  const zones = data.freight.zones;
  const setZone = (id, k, v) => setData(Object.assign({}, data, { freight: Object.assign({}, data.freight, { zones: upd(zones, id, k, v) }) }));
  return (
    <div class="admin-panel">
      <h2>Settings</h2>
      <div class="admin-card">
        <div class="admin-grid3">
          <Field label="Currency" value={b.currency} onInput={v => set('currency', v)} />
          <Field label="VAT rate (0.15 = 15%)" type="number" step="any" value={b.vatRate} onInput={v => set('vatRate', v)} />
          <Field label="Proforma valid (days)" type="number" value={b.validDays} onInput={v => set('validDays', v)} />
          <Field label="Markup %" type="number" step="any" value={b.markupPct} onInput={v => set('markupPct', v)} />
          <Field label="Contingency %" type="number" step="any" value={b.contingencyPct} onInput={v => set('contingencyPct', v)} />
          <Field label="Inflation factor" type="number" step="any" value={b.inflationFactor} onInput={v => set('inflationFactor', v)} />
        </div>
        <Area label="Disclaimer" value={b.disclaimer} onInput={v => set('disclaimer', v)} />
        <Area label="Default terms" value={b.defaultTerms} onInput={v => set('defaultTerms', v)} />
      </div>
      <div class="admin-card">
        <strong>Freight zones</strong>
        {zones.map(z => (
          <div class="admin-grid3" key={z.id} style="margin-top:10px;">
            <Field label="Zone name" value={z.name} onInput={v => setZone(z.id, 'name', v)} />
            <Field label="Flat" type="number" step="any" value={z.flat} onInput={v => setZone(z.id, 'flat', v)} />
            <Field label="Per ton" type="number" step="any" value={z.perTon} onInput={v => setZone(z.id, 'perTon', v)} />
          </div>
        ))}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// USERS / ROLES
// ---------------------------------------------------------------------------
export function UsersTab() {
  const [rows, setRows] = useState(null);
  const [newId, setNewId] = useState('');
  const [role, setRole] = useState('admin');
  const [msg, setMsg] = useState('');
  const [me, setMe] = useState('');

  const load = async () => {
    if (!supabase) { setRows([]); return; }
    const { data: s } = await supabase.auth.getSession();
    setMe(s.session ? s.session.user.id : '');
    const { data, error } = await supabase.from('admin_users').select('user_id, role, created_at').order('created_at');
    if (error) setMsg(error.message);
    setRows(data || []);
  };
  useEffect(() => { load(); }, []);

  const add = async () => {
    if (!newId.trim()) return;
    const { error } = await supabase.from('admin_users').insert({ user_id: newId.trim(), role });
    setMsg(error ? error.message : 'Added.');
    if (!error) setNewId('');
    load();
  };
  const remove = async (r) => {
    if (r.user_id === me) { setMsg('You cannot remove your own admin access.'); return; }
    if (!confirm('Remove this admin?')) return;
    const { error } = await supabase.from('admin_users').delete().eq('user_id', r.user_id);
    setMsg(error ? error.message : 'Removed.');
    load();
  };
  const changeRole = async (r, v) => {
    const { error } = await supabase.from('admin_users').update({ role: v }).eq('user_id', r.user_id);
    setMsg(error ? error.message : 'Role updated.');
    load();
  };

  if (!supabase) return <div class="admin-panel"><h2>Users/Roles</h2><div class="admin-msg">Supabase is not configured.</div></div>;
  return (
    <div class="admin-panel">
      <h2>Users/Roles</h2>
      {msg && <div class="admin-msg">{msg}</div>}
      <div class="admin-card">
        <strong>Add an admin</strong>
        <p style="font-size:0.8rem;color:var(--gray);margin:4px 0 10px;">Paste the user's id from Supabase → Authentication → Users. They must have signed in at least once.</p>
        <div class="admin-grid3">
          <div class="admin-field"><label>User id</label><input value={newId} onInput={e => setNewId(e.target.value)} placeholder="uuid" /></div>
          <div class="admin-field"><label>Role</label>
            <select value={role} onChange={e => setRole(e.target.value)}><option value="admin">admin</option><option value="staff">staff</option></select>
          </div>
          <div class="admin-field"><label>&nbsp;</label><button class="btn-add" onClick={add}>Add</button></div>
        </div>
      </div>
      {(rows || []).map(r => (
        <div class="admin-card" key={r.user_id}>
          <div class="admin-card-head">
            <span style="flex:1;font-family:monospace;font-size:0.8rem;word-break:break-all;">{r.user_id}{r.user_id === me ? ' (you)' : ''}</span>
            <select value={r.role} onChange={e => changeRole(r, e.target.value)}><option value="admin">admin</option><option value="staff">staff</option></select>
            <button class="btn-del" onClick={() => remove(r)}>Remove</button>
          </div>
        </div>
      ))}
      {rows && rows.length === 0 && <div class="admin-card">No admins listed.</div>}
    </div>
  );
}END
cat > src/admin/TendersTab.jsx << 'END'
import { useState, useEffect, useMemo } from 'preact/hooks';
import {
  egpStatus, egpLogin, fetchTenders, normalizeTenderList, normalizeItems,
  fetchTenderDetail, fetchQuotationItems, fetchResponseItems,
  fetchQuotationResponse, egpRegister, egpPushPriceOne, egpPushSpecOne,
} from '../data/egp.js';
import {
  saveTenders, getTenders, deleteTender,
  saveTenderDetail,
  saveTenderItems,
} from '../data/tenders.js';
import {
  getRateItems, addTenderAlias, createRateItem, getRateCategories,
} from '../data/ratebook.js';
import { buildIndex, matchAll } from '../data/match.js';

export function TendersTab({ onCreateProforma }) {
  const [status, setStatus]   = useState({ isAuthenticated: false, loading: true });
  const [rows, setRows]       = useState([]);
  const [search, setSearch]   = useState('Construction');
  const [top, setTop]         = useState(15);
  const [busy, setBusy]       = useState(false);
  const [msg, setMsg]         = useState('');
  const [error, setError]     = useState('');
  const [filter, setFilter]   = useState('');
  const [detail, setDetail]   = useState(null);
  const [loadingDetail, setLoadingDetail] = useState(false);

  const loadStored = async () => {
    try {
      const all = await getTenders();
      setRows(all.sort((a,b)=>String(b.invitationDate).localeCompare(String(a.invitationDate))));
    } catch (e) { setError('DB read failed: ' + e.message); }
  };

  const refreshStatus = async () => {
    try {
      const s = await egpStatus();
      setStatus({ ...s, loading: false });
    } catch (e) {
      setStatus({ isAuthenticated: false, loading: false, error: e.message });
      setError('Cannot reach /api/egp/status: ' + e.message);
    }
  };

  useEffect(() => {
    refreshStatus();
    loadStored();
    const t = setInterval(refreshStatus, 30_000);
    return () => clearInterval(t);
  }, []);

  const login = async () => {
    setBusy(true); setError('');
    try {
      const r = await egpLogin();
      if (!r.success) setError('Login failed: ' + JSON.stringify(r));
      await refreshStatus();
    } catch (e) { setError('Login request failed: ' + e.message); }
    setBusy(false);
  };

  const doFetch = async () => {
    setBusy(true); setMsg(''); setError('');
    try {
      const raw = await fetchTenders({ search, top });
      const norm = normalizeTenderList(raw);
      await saveTenders(norm);
      await loadStored();
      setMsg(`Fetched ${raw.total ?? '?'} total · ${norm.length} normalized · saved.`);
    } catch (e) { setError('Fetch failed: ' + e.message); }
    setBusy(false);
  };

  const openTender = async (t) => {
    setLoadingDetail(true); setError('');
    try {
      const d = await fetchTenderDetail(t);
      const qrid = d.quotationRequestId || d.quatationRequestId || null;
      let items = [], response = null;

      if (t.sourceApplication === 'Purchasing' && qrid) {
        try { response = await fetchQuotationResponse(qrid); } catch (e) { console.warn(e); }
        if (response?.id) {
          try { items = normalizeItems(await fetchResponseItems(response.id)); } catch (e) { console.warn(e); }
        }
        if (items.length === 0) {
          try { items = normalizeItems(await fetchQuotationItems(qrid)); } catch (e) { console.warn(e); }
        }
      }

      await saveTenderDetail({ lotId: t.id, quotationRequestId: qrid, detail: d, items, response, fetchedAt: Date.now() });
      if (qrid) await saveTenderItems({ key: qrid, lotId: t.id, items, response, fetchedAt: Date.now() });
      setDetail({ tender: t, detail: d, items, response });
    } catch (e) { setError('Detail failed: ' + e.message); }
    setLoadingDetail(false);
  };

  const removeTender = async (id) => {
    if (!confirm('Remove this tender from your list?')) return;
    try { await deleteTender(id); loadStored(); } catch (e) { setError(e.message); }
  };

  const filtered = useMemo(() => {
    const s = filter.trim().toLowerCase();
    if (!s) return rows;
    return rows.filter(t =>
      (t.lotName || '').toLowerCase().includes(s) ||
      (t.procuringEntity || '').toLowerCase().includes(s) ||
      (t.procurementReferenceNo || '').toLowerCase().includes(s)
    );
  }, [rows, filter]);

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Tenders ({rows.length})</h2>
        <div class="pf-actions" style="margin:0;">
          {status.loading
            ? <span class="pf-status draft">Checking session...</span>
            : status.isAuthenticated
              ? <span class="pf-status accepted">{status.name || 'Signed in'} · {Math.round((status.expiresInSeconds||0)/60)}m left</span>
              : <button class="btn-add" disabled={busy} onClick={login}>{busy ? 'Logging in...' : 'Login to eGP'}</button>}
        </div>
      </div>

      {error && <div class="staff-err" style="margin-bottom:12px;">{error}</div>}

      <div class="admin-card">
        <div class="admin-grid3">
          <div class="admin-field"><label>Search keyword</label>
            <input value={search} onInput={e=>setSearch(e.target.value)} /></div>
          <div class="admin-field"><label>Fetch top N</label>
            <input type="number" value={top} onInput={e=>setTop(+e.target.value||15)} /></div>
          <div class="admin-field"><label>&nbsp;</label>
            <button class="btn-add" disabled={busy || !status.isAuthenticated} onClick={doFetch}>
              {busy ? 'Fetching...' : 'Fetch from eGP'}
            </button>
          </div>
        </div>
        {msg && <div class="admin-msg">{msg}</div>}
      </div>

      <div class="admin-field" style="margin-bottom:12px;">
        <input placeholder="Filter stored tenders..." value={filter} onInput={e=>setFilter(e.target.value)} />
      </div>

      {filtered.length === 0 && <div class="admin-card">No tenders yet. Log in, then click <strong>Fetch from eGP</strong>.</div>}

      {filtered.map(t => (
        <div class="admin-card" key={t.id}>
          <div class="admin-card-head">
            <strong style="flex:1;min-width:200px;">{t.lotName}</strong>
            <span class="pf-status draft">{t.procurementCategory || t.sourceApplication}</span>
          </div>
          <div style="font-size:0.84rem;color:var(--gray);">
            {t.procuringEntity} · Ref {t.procurementReferenceNo}
            {t.submissionDeadline && ` · Deadline ${String(t.submissionDeadline).slice(0,10)}`}
          </div>
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => openTender(t)}>
              {loadingDetail ? '...' : 'View detail'}
            </button>
            <button class="btn-del" onClick={() => removeTender(t.id)}>Remove</button>
          </div>
        </div>
      ))}

      {detail && (
        <TenderDetailModal
          data={detail}
          onClose={() => setDetail(null)}
          onCreateProforma={(payload) => { setDetail(null); onCreateProforma(payload); }}
        />
      )}
    </div>
  );
}

function TenderDetailModal({ data, onClose, onCreateProforma }) {
  const { tender, detail, items: initialItems, response: initialResponse } = data;
  const li = detail.lotInformation || {};
  const addr = li.address || {};
  const qrid = detail.quotationRequestId || detail.quatationRequestId || tender.id;

  const [working, setWorking] = useState(false);
  const [response, setResponse] = useState(initialResponse);
  const [items, setItems] = useState(initialItems);
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const [matchSummary, setMatchSummary] = useState(null);
  const [rateIndex, setRateIndex] = useState(null);
  const [rateCats, setRateCats] = useState([]);

  const [pickerFor, setPickerFor] = useState(null);
  const [pickerQuery, setPickerQuery] = useState('');
  const [pickerAm, setPickerAm] = useState('');
  const [pickerPrice, setPickerPrice] = useState('');

  const isGoodsTender = String(tender.procurementCategory || '').toLowerCase().includes('good');
  const source = isGoodsTender ? 'goods' : 'works';

  const ensureIndex = async () => {
    if (rateIndex) return rateIndex;
    const [ri, rc] = await Promise.all([getRateItems(source), getRateCategories(source)]);
    const idx = buildIndex(ri);
    setRateIndex(idx);
    setRateCats(rc);
    return idx;
  };

  const reloadResponse = async () => {
    try { const r = await fetchQuotationResponse(qrid); setResponse(r); return r; }
    catch { return null; }
  };

  const reloadItems = async (responseId) => {
    if (responseId) {
      try {
        const raw = await fetchResponseItems(responseId);
        const norm = normalizeItems(raw);
        if (norm.length > 0) { setItems(norm); return norm; }
      } catch (e) { console.warn(e); }
    }
    try {
      const raw = await fetchQuotationItems(qrid);
      const norm = normalizeItems(raw);
      setItems(norm);
      return norm;
    } catch { return null; }
  };

  const doRegister = async () => {
    setWorking(true); setMsg(''); setErr('');
    try {
      const r = await egpRegister(qrid, li.name || tender.lotName);
      if (r.ok) {
        setMsg('Registered. Loading items…');
        const resp = await reloadResponse();
        let list = await reloadItems(resp?.id);
        for (let i = 0; i < 3 && (!list || list.length === 0); i++) {
          await new Promise(res => setTimeout(res, 2000));
          list = await reloadItems(resp?.id);
        }
        setMsg(list && list.length > 0
          ? `Registered. Loaded ${list.length} items.`
          : 'Registered. Items not populated yet — try Refresh.');
      } else {
        setErr('Register failed: ' + JSON.stringify(r.data));
      }
    } catch (e) { setErr('Register error: ' + e.message); }
    setWorking(false);
  };

  const refreshItems = async () => {
    setWorking(true); setMsg(''); setErr('');
    const list = await reloadItems(response?.id);
    if (list && list.length > 0) setMsg(`Refreshed: ${list.length} items.`);
    else setErr('No items returned.');
    setWorking(false);
  };

  // ---- Push prices (financial offer) ----
  const doPushPrices = async () => {
    if (!response?.id) { setErr('Register first.'); return; }
    setWorking(true); setMsg(''); setErr('');

    let ok = 0, fail = 0, skip = 0;
    const failures = [];

    for (const it of items) {
      if (!it.rate || it.rate <= 0) { skip++; continue; }
      if (!it.responseItemId) { skip++; continue; }

      const r = await egpPushPriceOne({
        id: it.responseItemId,
        quotationRequestResponseId: response.id,
        quotationRequestId: qrid,
        lotItemId: it.lotItemId,
        name: it.name || '',
        description: it.description || '',
        quantity: it.qty,
        currency: 'ETB',
        unitMeasure: it.unit,
        unitPrice: it.rate,
        deliveryTime: null,
        taxAmount: null,
        tax: 'VAT',
      });
      if (r.ok) ok++;
      else { fail++; failures.push({ lotItemId: it.lotItemId, status: r.status, body: r.data }); }
    }

    setMsg(`Prices pushed: ${ok} ok, ${fail} failed, ${skip} skipped.`);
    if (fail) setErr('Failures: ' + JSON.stringify(failures.slice(0, 2)));
    setWorking(false);
  };

  // ---- Push specs (technical offer) ----
  const doPushSpecs = async () => {
    if (!response?.id) { setErr('Register first.'); return; }
    setWorking(true); setMsg(''); setErr('');

    let ok = 0, fail = 0, skip = 0;
    const failures = [];

    for (const it of items) {
      if (!it.lotItemId) { skip++; continue; }
      if (!it.offeredSpecification || !it.offeredSpecification.trim()) { skip++; continue; }

      const r = await egpPushSpecOne({
        quotationRequestResponseId: response.id,
        lotItemId: it.lotItemId,
        offeredSpecification: it.offeredSpecification.trim(),
      });
      if (r.ok) ok++;
      else { fail++; failures.push({ lotItemId: it.lotItemId, status: r.status, body: r.data }); }
    }

    setMsg(`Specs pushed: ${ok} ok, ${fail} failed, ${skip} skipped.`);
    if (fail) setErr('Failures: ' + JSON.stringify(failures.slice(0, 2)));
    setWorking(false);
  };

  const setRate = (idx, v) => {
    setItems(items.map((it, i) => i === idx ? { ...it, rate: Math.max(0, parseFloat(v) || 0) } : it));
  };
  const setSpec = (idx, v) => {
    setItems(items.map((it, i) => i === idx ? { ...it, offeredSpecification: v } : it));
  };

  const fillFromRateBook = async () => {
    setWorking(true); setMsg(''); setErr(''); setMatchSummary(null);
    try {
      setRateIndex(null);
      const idx = await ensureIndex();
      if (!idx || idx.length === 0) {
        setErr(
          source === 'goods'
            ? 'Goods catalog is empty. Open Rate Book → Goods → "Load goods catalog" first.'
            : 'Civil works rate book is empty. Open Rate Book → Works → "Reload works" first.'
        );
        setWorking(false); return;
      }
      const fresh = items.map(it => ({ ...it, rate: 0, _match: null }));
      const filled = matchAll(fresh, idx, { minScore: 0.25 });
      setItems(filled);
      const matched = filled.filter(x => x._match?.matched).length;
      const needsManual = filled.filter(x => !x.rate || x.rate === 0).length;
      setMatchSummary({ matched, total: filled.length, needsManual, source });
      setMsg(`Matched ${matched} of ${filled.length} items against ${source === 'goods' ? 'Goods' : 'Works'} catalog.`);
    } catch (e) { setErr('Match failed: ' + e.message); }
    setWorking(false);
  };

  const clearRates = () => {
    setItems(items.map(it => ({ ...it, rate: 0, _match: null })));
    setMatchSummary(null);
    setMsg('Cleared all rates.');
  };

  const openLinkPicker = async (idx) => {
    await ensureIndex();
    setPickerFor({ idx, mode: 'link' });
    setPickerQuery('');
  };
  const confirmLink = async (rateItem) => {
    const row = items[pickerFor.idx];
    if (!row || !rateItem) { setPickerFor(null); return; }
    setItems(items.map((it, i) => i === pickerFor.idx
      ? { ...it, rate: rateItem.contractorPrice || 0, _match: { matched: true, score: 1, source: rateItem, manual: true } }
      : it));
    try { await addTenderAlias(rateItem.id, row.description); } catch {}
    setMsg(`Linked "${row.description.slice(0,40)}…" → ${rateItem.description.slice(0,40)}…`);
    setRateIndex(null);
    setPickerFor(null);
  };

  const openAddPicker = (idx) => {
    const row = items[idx];
    setPickerFor({ idx, mode: 'add' });
    setPickerAm('');
    setPickerQuery(row?.description || '');
    setPickerPrice(row?.rate > 0 ? String(row.rate) : '');
  };
  const confirmAdd = async () => {
    const row = items[pickerFor.idx];
    if (!row) { setPickerFor(null); return; }
    const desc = pickerQuery.trim() || row.description;
    const rate = parseFloat(pickerPrice) || 0;
    if (!desc) { setErr('Description required.'); return; }
    if (rate <= 0) { setErr('Enter a base price greater than 0.'); return; }
    try {
      const created = await createRateItem({
        description: desc,
        descriptionAm: pickerAm.trim(),
        unit: row.unit,
        rate,
        categoryId: (isGoodsTender ? 'goods:' : 'works:') + 'custom',
        source: isGoodsTender ? 'goods' : 'works'
      });
      setItems(items.map((it, i) => i === pickerFor.idx
        ? { ...it, rate, _match: { matched: true, score: 1, source: created, manual: true } }
        : it));
      setMsg(`Added "${desc.slice(0,40)}…" @ ${rate}.`);
      setRateIndex(null);
      setPickerPrice('');
    } catch (e) { setErr('Add failed: ' + e.message); }
    setPickerFor(null);
  };

  const pickerRow = pickerFor ? items[pickerFor.idx] : null;
  const pickerResults = useMemo(() => {
    if (!rateIndex || !pickerFor) return [];
    const q = pickerQuery.trim().toLowerCase();
    if (!q) return rateIndex.slice(0, 30);
    return rateIndex
      .filter(e =>
        String(e.item.code).toLowerCase().includes(q) ||
        String(e.item.description).toLowerCase().includes(q) ||
        String(e.item.descriptionAm || '').includes(q) ||
        (e.item.tenderAliases || []).some(a => a.toLowerCase().includes(q))
      )
      .slice(0, 30);
  }, [rateIndex, pickerFor, pickerQuery]);

  const missingResponseItemId = items.some(it => !it.responseItemId && it.rate > 0);

  return (
    <div class="modal-overlay" onClick={onClose}>
      <div class="modal" style="max-width:1100px;" onClick={e=>e.stopPropagation()}>
        <button class="modal-close" onClick={onClose}>X</button>
        <h2>{li.name || tender.lotName}</h2>
        <p style="color:var(--gray);font-size:0.88rem;">{li.description}</p>
        <div class="modal-meta">
          <span><strong>Entity:</strong> {li.procuring_entity || tender.procuringEntity}</span>
          <span><strong>Ref:</strong> {li.reference_no || tender.procurementReferenceNo}</span>
          <span><strong>Deadline:</strong> {li.submission_deadline || tender.submissionDeadline}</span>
          <span><strong>Town:</strong> {addr.town || '-'}</span>
          <span><strong>Catalog:</strong> {isGoodsTender ? 'Goods' : 'Works'}</span>
        </div>

        {response && (
          <div class="admin-msg" style="margin-top:12px;">
            Response: <strong>{response.status}</strong> · id <code style="font-size:0.75rem;">{response.id}</code>
          </div>
        )}

        <div class="pf-actions" style="margin-top:12px;">
          <button class="btn-add" disabled={working || items.length === 0} onClick={fillFromRateBook}>
            {working ? 'Matching...' : 'Match to rate book'}
          </button>
          <button class="btn btn-back" disabled={working || items.length === 0} onClick={clearRates}>
            Clear rates
          </button>
          <button class="btn btn-back" disabled={working || !response?.id} onClick={refreshItems}>
            Refresh items
          </button>
          {matchSummary && (
            <span style="font-size:0.82rem;color:var(--gray);align-self:center;">
              {matchSummary.matched} matched · {matchSummary.needsManual} need manual entry
            </span>
          )}
        </div>

        {missingResponseItemId && (
          <div class="admin-msg" style="margin-top:8px;background:#fef3c7;">
            Some items have no <code>responseItemId</code> — prices can't be pushed for those. Register first, then click <strong>Refresh items</strong>.
          </div>
        )}

        <h3 style="margin-top:14px;">Items ({items.length})</h3>
        {items.length === 0 && <p style="color:var(--gray);font-size:0.85rem;">No items.</p>}
        {items.length > 0 && (
          <table class="pf-table">
            <thead>
              <tr>
                <th>Description</th>
                <th>Unit</th>
                <th>Qty</th>
                <th>Offered spec</th>
                <th>Rate</th>
                <th>Match</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => (
                <tr key={it.responseItemId || it.lotItemId || i}>
                  <td>{it.description}</td>
                  <td>{it.unit}</td>
                  <td>{it.qty}</td>
                  <td>
                    <input type="text"
                      placeholder="Compliant"
                      value={it.offeredSpecification || ''}
                      onInput={e => setSpec(i, e.target.value)}
                      style="width:130px;font-size:0.78rem;" />
                  </td>
                  <td>
                    <input type="number" min="0" step="any" value={it.rate || ''}
                      onInput={e => setRate(i, e.target.value)}
                      placeholder="0"
                      style={{
                        width: '100px',
                        background: it._match?.matched ? '#f0fdf4' : (it.rate > 0 ? '#fff' : '#fef3c7')
                      }} />
                  </td>
                  <td style="font-size:0.72rem;color:var(--gray);max-width:180px;">
                    {it._match?.matched
                      ? <>
                          <span title={it._match.source?.description}>
                            {it._match.manual ? 'manual' : `✓ ${Math.round(it._match.score * 100)}%`}
                          </span>
                          <br />
                          <span style="font-size:0.68rem;" title={it._match.source?.description}>
                            {(it._match.source?.description || '').slice(0, 40)}
                            {(it._match.source?.description || '').length > 40 ? '…' : ''}
                          </span>
                        </>
                      : it.rate > 0
                        ? <span style="color:#92400e;">manual</span>
                        : <span style="color:#dc2626;">no match</span>}
                  </td>
                  <td style="white-space:nowrap;">
                    <button type="button" class="btn btn-back" style="font-size:0.72rem;padding:3px 8px;"
                      onClick={() => openLinkPicker(i)}>
                      Link
                    </button>
                    {' '}
                    <button type="button" class="btn btn-back" style="font-size:0.72rem;padding:3px 8px;"
                      onClick={() => openAddPicker(i)}>
                      +New
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {pickerFor && (
          <div class="admin-card" style="margin-top:14px;border:2px solid var(--primary);">
            <div class="admin-panel-head" style="margin-bottom:8px;">
              <strong>
                {pickerFor.mode === 'link'
                  ? `Link to ${source === 'goods' ? 'Goods' : 'Works'} catalog`
                  : `Add new ${source === 'goods' ? 'Goods' : 'Works'} item`}
              </strong>
              <button class="btn btn-back" onClick={() => setPickerFor(null)}>Cancel</button>
            </div>
            <div style="font-size:0.82rem;color:var(--gray);margin-bottom:8px;">
              Tender item: <strong>{pickerRow?.description}</strong> · {pickerRow?.unit} · qty {pickerRow?.qty}
            </div>

            {pickerFor.mode === 'link' && (
              <>
                <div class="admin-field">
                  <label>Search catalog (code, EN, AM, or alias)</label>
                  <input value={pickerQuery} onInput={e => setPickerQuery(e.target.value)} placeholder="e.g. cement, ሲሚንቶ, 12" />
                </div>
                <div style="max-height:260px;overflow-y:auto;border:1px solid var(--border);border-radius:6px;">
                  {pickerResults.length === 0 && <div style="padding:10px;color:var(--gray);font-size:0.85rem;">No matches.</div>}
                  {pickerResults.map(e => (
                    <div key={e.item.id}
                      style="padding:8px 10px;border-bottom:1px solid var(--border);cursor:pointer;font-size:0.85rem;"
                      onClick={() => confirmLink(e.item)}
                      onMouseEnter={ev => ev.currentTarget.style.background = '#f9fafb'}
                      onMouseLeave={ev => ev.currentTarget.style.background = 'transparent'}
                    >
                      <div><strong>{e.item.code || e.item.id}</strong> · {e.item.description}</div>
                      {e.item.descriptionAm && <div style="color:var(--gray);font-size:0.78rem;">{e.item.descriptionAm}</div>}
                      <div style="color:var(--gray);font-size:0.74rem;">
                        {e.item.contractorPrice != null ? e.item.contractorPrice + ' ETB' : '—'} / {e.item.unit}
                        {e.item.tenderAliases && e.item.tenderAliases.length > 0 && ` · ${e.item.tenderAliases.length} aliases`}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}

            {pickerFor.mode === 'add' && (
              <>
                <div class="admin-field">
                  <label>Description (English)</label>
                  <input value={pickerQuery} onInput={e => setPickerQuery(e.target.value)} />
                </div>
                <div class="admin-field">
                  <label>Description (Amharic, optional)</label>
                  <input value={pickerAm} onInput={e => setPickerAm(e.target.value)} />
                </div>
                <div class="admin-field">
                  <label>Base price (ETB) *</label>
                  <input type="number" min="0" step="any"
                    value={pickerPrice} onInput={e => setPickerPrice(e.target.value)}
                    placeholder="e.g. 1050" />
                </div>
                <div style="font-size:0.82rem;color:var(--gray);margin-bottom:8px;">
                  Unit: <strong>{pickerRow?.unit}</strong> · Catalog: <strong>{isGoodsTender ? 'Goods' : 'Works'}</strong>
                </div>
                <button class="btn-add" onClick={confirmAdd}>Create in Custom category</button>
              </>
            )}
          </div>
        )}

        {msg && <div class="admin-msg" style="margin-top:8px;">{msg}</div>}
        {err && <div class="staff-err" style="margin-top:8px;">{err}</div>}

        <div class="pf-actions" style="margin-top:14px;">
          {!response && tender.sourceApplication === 'Purchasing' && (
            <button class="btn-add" disabled={working} onClick={doRegister}>
              {working ? 'Registering...' : 'Register on eGP'}
            </button>
          )}

          {response && (
            <>
              <button class="btn-add" disabled={working || items.length === 0} onClick={doPushSpecs}>
                {working ? '...' : 'Push specs (technical)'}
              </button>
              <button class="btn-add" disabled={working || items.length === 0} onClick={doPushPrices}>
                {working ? '...' : 'Push prices (financial)'}
              </button>
            </>
          )}

          <button class="btn btn-primary" disabled={items.length === 0}
            onClick={() => onCreateProforma({
              tender,
              detail: li,
              items: items.map(it => ({
                lotItemId: it.lotItemId,
                name: it.name,
                description: it.description,
                unit: it.unit,
                qty: it.qty,
                rate: it.rate || 0,
              })),
            })}>
            Create Proforma
          </button>

          <button class="btn btn-back" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}END
cat > src/admin/fields.js << 'END'
// Field lists used by the Business Info and Settings admin tabs (and the dashboard counts)
export const BUSINESS_FIELDS = [
  ['nameEn', 'Business name (EN)'], ['nameAm', 'Business name (AM)'],
  ['taglineEn', 'Tagline (EN)'], ['taglineAm', 'Tagline (AM)'],
  ['subtitleEn', 'Subtitle (EN)'], ['subtitleAm', 'Subtitle (AM)'],
  ['ownerName', 'Owner'], ['fieldOfBusiness', 'Field of business'],
  ['businessLicenseNo', 'Business license no.'], ['principalRegNo', 'Principal registration no.'],
  ['previousLicenseNo', 'Previous license no.'], ['tin', 'TIN'],
  ['capital', 'Capital'], ['dateOfIssuance', 'Date of issuance'],
  ['renewalDate', 'Renewal date'], ['businessLicenseIssued', 'License issued'],
  ['bureau', 'Issuing bureau'], ['cell1', 'Cell 1'],
  ['cell2', 'Cell 2'], ['cell3', 'Cell 3'],
  ['phone', 'Phone'], ['tel', 'Tel'],
  ['email', 'Email'], ['region', 'Region'],
  ['zoneSubCity', 'Zone / Sub-city'], ['woreda', 'Woreda'],
  ['houseNo', 'House no.'], ['addressEn', 'Address (EN)'],
  ['addressAm', 'Address (AM)']
];
END
npm install
echo 'Done! Run npm start'
