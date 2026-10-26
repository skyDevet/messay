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
export default defineConfig(
  
  { plugins: [preact()], 
    server: 
          { 
     host: '0.0.0.0',
     port: 5173
                              
             }
                            
        });
END
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

  return (
    <>
      <Nav onStaff={() => setLoginOpen(true)} onRequestQuote={() => requestForm('materials')} />
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

const EMPTY_CLIENT = { name: '', phone: '', email: '', company: '', projectName: '', siteAddress: '', zone: 'addis' };
const STEP_LABELS = ['Client', 'Items', 'Proforma'];

// Recompute a line after the qty or rate changes
const redo = (l, qty, price) => calcLineFromRate(
  { id: l.sku, description: l.name, unit: l.unit, code: l.code, basePrice: l.basePrice, contractorPrice: l.contractorPrice },
  qty, price
);

// mode: 'from-request' (client auto-filled from a quote request) | 'internal' (empty client form)
export function ProformaBuilder({ mode, request, onClose, onSaved }) {
  const [data] = useStore();
  const b = data.business;
  const fromRequest = mode === 'from-request';

  const [step, setStep] = useState(1);
  const [editing, setEditing] = useState(!fromRequest);
  const [client, setClient] = useState(() => Object.assign({}, EMPTY_CLIENT, fromRequest && request ? request.client : {}));
  const [lines, setLines] = useState([]);
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
    sourceRequestId: request ? request.id : null,
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
          <h2>{fromRequest ? 'Proforma from request' : 'Internal proforma'}</h2>
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
              <button type="button" class="btn btn-back" onClick={() => setEditing(!editing)}>{editing ? 'Lock details' : 'âœŽ Edit details'}</button>
            )}
          </div>
          {fromRequest && !request && <div class="admin-msg">No request attached.</div>}
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
            <button class="btn btn-primary" disabled={!canNext1} onClick={() => setStep(2)}>Next: Items â†’</button>
          </div>
        </div>
      )}

      {step === 2 && (
        <div>
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
                  <span class="rb-price">{i.contractorPrice == null ? 'â€”' : formatMoney(i.contractorPrice)}</span>
                  <button type="button" class="btn-add" onClick={() => addLine(i)}>+ Add</button>
                </div>
              ))}
              {results.length === 0 && <div class="pf-pick-row">No matching items.</div>}
            </div>
          )}
          {results.length > 60 && <p style="font-size:0.78rem;color:var(--gray);">Showing the first 60 of {results.length} matches. Refine the search to narrow down.</p>}

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
                    <td><button type="button" class="btn-del" onClick={() => removeLine(l.sku)}>âœ•</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <div class="pf-actions">
            <button class="btn btn-back" onClick={() => setStep(1)}>â† Back</button>
            <button class="btn btn-primary" disabled={!canNext2} onClick={() => setStep(3)}>Next: Proforma â†’</button>
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
          <div class="pf-actions no-print">
            {!saved && <button class="btn btn-back" onClick={() => setStep(2)}>â† Back</button>}
            {!saved && <button class="btn btn-primary" disabled={busy || !number} onClick={save}>{busy ? 'Saving...' : 'Save Proforma'}</button>}
            {saved && <div class="admin-msg" style="flex:1;margin:0;">Saved as {number}</div>}
            {saved && <button class="btn btn-back" onClick={() => window.print()}>Print</button>}
            {saved && <button class="btn btn-primary" onClick={onClose}>Done</button>}
          </div>
        </div>
      )}
    </div>
  );
}

// The printable proforma document (also used to view saved proformas)
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
          <p>{b.cell1} Â· {b.cell2} Â· {b.email}</p>
          <p>TIN {b.tin} Â· License {b.businessLicenseNo}</p>
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
        {t.discount > 0 && <div><span>Discount ({pf.discountPct}%)</span><span>âˆ’ {formatMoney(t.discount)}</span></div>}
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
}
END
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
cat > src/data/db.js << 'END'
const DB_NAME = 'mesay_db';
const DB_VERSION = 2;
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

      // NEW: blobs for product images
      if (!db.objectStoreNames.contains('product_images'))
        db.createObjectStore('product_images', { keyPath: 'id' });
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
      "items": [
        {"page":6,"code":"1.1.1","description":"Demolishing the lamera wall","unit":"m²","price":"172.41"},
        {"page":6,"code":"1.1.2","description":"Demolishing the existing CIS wall","unit":"m²","price":"32.33"},
        {"page":6,"code":"1.1.3","description":"Demolishing of wooden wall","unit":"m²","price":"182.53"},
        {"page":6,"code":"1.1.4","description":"Demolishing of gypsum wall","unit":"m²","price":"91.27"},
        {"page":6,"code":"1.1.5","description":"Demolishing the CIS roof","unit":"m²","price":"51.72"},
        {"page":6,"code":"1.1.6","description":"Demolishing of 7x5 cm zigba purline","unit":"ml","price":"25.86"},
        {"page":6,"code":"1.1.7","description":"Demolishing of eucalyptus upper & lower chords","unit":"ml","price":"79.91"},
        {"page":6,"code":"1.1.8","description":"Dimolish RHS purline","unit":"ml","price":"43.10"},
        {"page":6,"code":"1.1.9","description":"Dimolishing the RHS truss.","unit":"ml","price":"103.01"},
        {"page":6,"code":"1.1.10","description":"Desmantling Gutter","unit":"ml","price":"34.30"},
        {"page":6,"code":"1.1.11","description":"Desmantling down pipe","unit":"ml","price":"69.82"},
        {"page":6,"code":"1.1.12","description":"Demolishing the chipwood ceiling","unit":"m²","price":"119.56"},
        {"page":6,"code":"1.1.13","description":"Demolishing the timber ceiling","unit":"m²","price":"166.06"},
        {"page":6,"code":"1.1.14","description":"Demolishing the abujed ceiling","unit":"m²","price":"41.51"},
        {"page":6,"code":"1.1.15","description":"Dismantle the metal doors from the wall.","unit":"m²","price":"169.07"},
        {"page":6,"code":"1.1.16","description":"Dismantle the metal windows from the wall.","unit":"m²","price":"152.16"},
        {"page":6,"code":"1.1.17","description":"Desmantling fascia board","unit":"ml","price":"47.65"},
        {"page":6,"code":"1.1.18","description":"Desmantling ridge & copping","unit":"ml","price":"68.60"},
        {"page":6,"code":"1.1.19","description":"Demolishing the PVC floor tile","unit":"m²","price":"45.63"},
        {"page":6,"code":"1.1.20","description":"Demolishing kitchen sink","unit":"pcs","price":"70.46"},
        {"page":6,"code":"1.1.21","description":"Demolishing toilet WC,HW,turkish seat","unit":"pcs","price":"211.37"},
        {"page":6,"code":"1.1.22","description":"Desmantling of wooden door & window","unit":"m²","price":"135.47"},
        {"page":6,"code":"1.2.1","description":"Masonary Structure (BGL)","unit":"m³","price":"580.90"},
        {"page":6,"code":"1.2.2","description":"Masonary Structure (AGL)","unit":"m³","price":"774.54"},
        {"page":6,"code":"1.2.3","description":"Demolishing of 25cm thick hardcore","unit":"m²","price":"54.56"},
        {"page":6,"code":"1.2.4","description":"Concrete Structures","unit":"m³","price":"2,580.74"},
        {"page":6,"code":"1.2.5","description":"10cm thick HCB Structure","unit":"m²","price":"55.46"},
        {"page":6,"code":"1.2.6","description":"15cm thick HCB Structure","unit":"m²","price":"73.61"},
        {"page":7,"code":"1.2.7","description":"20cm thick HCB Structure","unit":"m²","price":"103.06"},
        {"page":7,"code":"1.2.8","description":"Terrazzo floor","unit":"m²","price":"114.51"},
        {"page":7,"code":"1.2.9","description":"Cement screed floor","unit":"m²","price":"25.77"},
        {"page":7,"code":"1.2.10","description":"8cm thick Mass concrete floor","unit":"m²","price":"34.35"},
        {"page":7,"code":"1.2.11","description":"30x120x3cm thick marble tread","unit":"pcs","price":"227.83"},
        {"page":7,"code":"1.2.12","description":"15x120x3cm thick marble riser","unit":"pcs","price":"170.87"},
        {"page":7,"code":"1.2.13","description":"Steel Structure","unit":"Kg","price":"10.61"},
        {"page":7,"code":"1.2.14","description":"Demolishing the ceramic wall tile","unit":"m²","price":"114.51"},
        {"page":7,"code":"1.2.15","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 1st–3rd floor","unit":"m²","price":"128.83"},
        {"page":7,"code":"1.2.16","description":"Concrete Structures","unit":"m³","price":"3,236.74"},
        {"page":7,"code":"1.2.17","description":"10cm thick HCB Structure","unit":"m²","price":"78.23"},
        {"page":7,"code":"1.2.18","description":"15cm thick HCB Structure","unit":"m²","price":"100.59"},
        {"page":7,"code":"1.2.19","description":"20cm thick HCB Structure","unit":"m²","price":"140.82"},
        {"page":7,"code":"1.2.20","description":"Terrazzo floor","unit":"m²","price":"150.07"},
        {"page":7,"code":"1.2.21","description":"Cement screed floor","unit":"m²","price":"33.77"},
        {"page":7,"code":"1.2.22","description":"30x120x3cm thick marble tread","unit":"m²","price":"281.17"},
        {"page":7,"code":"1.2.23","description":"15x120x3cm marble riser","unit":"m²","price":"210.87"},
        {"page":7,"code":"1.2.24","description":"Steel Structure","unit":"kg","price":"13.11"},
        {"page":7,"code":"1.2.25","description":"Demolishing the ceramic wall tile","unit":"m²","price":"150.07"},
        {"page":7,"code":"1.2.26","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 4th–7th floor","unit":"m²","price":"168.83"},
        {"page":7,"code":"1.2.27","description":"Concrete Structures","unit":"m³","price":"4,036.74"},
        {"page":7,"code":"1.2.28","description":"10cm thick HCB Structure","unit":"m²","price":"80.82"},
        {"page":7,"code":"1.2.29","description":"15cm thick HCB Structure","unit":"m²","price":"103.91"},
        {"page":7,"code":"1.2.30","description":"20cm thick HCB Structure","unit":"m²","price":"145.47"},
        {"page":7,"code":"1.2.31","description":"Terrazzo floor","unit":"m²","price":"161.63"},
        {"page":7,"code":"1.2.32","description":"Cement screed floor","unit":"m²","price":"36.37"},
        {"page":7,"code":"1.2.33","description":"30x120x3cm thick marble tread","unit":"m²","price":"324.90"},
        {"page":7,"code":"1.2.34","description":"15x120x3cm marble riser","unit":"m²","price":"243.67"},
        {"page":7,"code":"1.2.35","description":"Steel Structure","unit":"kg","price":"19.32"},
        {"page":8,"code":"1.2.36","description":"Demolishing the ceramic wall tile","unit":"m²","price":"185.62"},
        {"page":8,"code":"1.2.37","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 8th–12th floor","unit":"m²","price":"208.83"},
        {"page":8,"code":"1.2.38","description":"Concrete Structures","unit":"m³","price":"4,836.74"},
        {"page":8,"code":"1.2.39","description":"10cm thick HCB Structure","unit":"m²","price":"115.36"},
        {"page":8,"code":"1.2.40","description":"15cm thick HCB Structure","unit":"m²","price":"126.76"},
        {"page":8,"code":"1.2.41","description":"20cm thick HCB Structure","unit":"m²","price":"177.47"},
        {"page":8,"code":"1.2.42","description":"Terrazzo floor","unit":"m²","price":"197.19"},
        {"page":8,"code":"1.2.43","description":"Cement screed floor","unit":"m²","price":"44.37"},
        {"page":8,"code":"1.2.44","description":"30x120x3cm thick marble tread","unit":"m²","price":"378.23"},
        {"page":8,"code":"1.2.45","description":"15x120x3cm marble riser","unit":"pcs","price":"283.67"},
        {"page":8,"code":"1.2.46","description":"Steel Structure","unit":"kg","price":"19.01"},
        {"page":8,"code":"1.2.47","description":"Demolishing the ceramic wall tile","unit":"m²","price":"221.18"},
        {"page":8,"code":"1.2.48","description":"Demolishing the ceramic floor tile (6 & 8 mm thick) — 13th–20th floor","unit":"m²","price":"248.83"},
        {"page":8,"code":"1.2.49","description":"Concrete Structures","unit":"m³","price":"5,636.74"},
        {"page":8,"code":"1.2.50","description":"10cm thick HCB Structure","unit":"m²","price":"116.37"},
        {"page":8,"code":"1.2.51","description":"15cm thick HCB Structure","unit":"m²","price":"149.62"},
        {"page":8,"code":"1.2.52","description":"20cm thick HCB Structure","unit":"m²","price":"209.47"},
        {"page":8,"code":"1.2.53","description":"Terrazzo floor","unit":"m²","price":"232.74"},
        {"page":8,"code":"1.2.54","description":"Cement screed floor","unit":"m²","price":"52.37"},
        {"page":8,"code":"1.2.55","description":"30x120x3cm thick marble tread","unit":"m²","price":"431.57"},
        {"page":8,"code":"1.2.56","description":"15x120x3cm marble riser","unit":"pcs","price":"323.67"},
        {"page":8,"code":"1.2.57","description":"Steel Structure","unit":"kg","price":"21.51"},
        {"page":8,"code":"1.2.58","description":"Demolishing the ceramic wall tile","unit":"m²","price":"256.73"}
      ]
    },
    {
      "id": "2",
      "title": "EXCAVATION AND EARTH WORK — MECHANIZED",
      "items": [
        {"page":8,"code":"2.1.1","description":"20cm. Clearing on wet & black soil.","unit":"m²","price":"98.79"},
        {"page":8,"code":"2.2.1","description":"Bulk excavation in loose & dry soil — depth not exceeding 1.5m","unit":"m³","price":"368.92"},
        {"page":8,"code":"2.2.2","description":"Depth 1.50m–3.00m","unit":"m³","price":"452.22"},
        {"page":8,"code":"2.2.3","description":"Depth 3.00m–4.50m","unit":"m³","price":"547.61"},
        {"page":9,"code":"2.2.4","description":"Depth 4.50m–6.00m","unit":"m³","price":"625.84"},
        {"page":9,"code":"2.2.5","description":"Depth 6.00m–7.50m","unit":"m³","price":"730.15"},
        {"page":9,"code":"2.2.6","description":"Depth 7.50m–9.00m","unit":"m³","price":"876.18"},
        {"page":9,"code":"2.2.7","description":"Depth 9.00m–10.50m","unit":"m³","price":"973.53"},
        {"page":9,"code":"2.3.1","description":"Pit excavation in loose & dry soil — depth ≤1500mm","unit":"m³","price":"417.23"},
        {"page":9,"code":"2.3.2","description":"Depth 1500–3000mm","unit":"m³","price":"476.83"},
        {"page":9,"code":"2.3.3","description":"Depth 3000–4500mm","unit":"m³","price":"556.30"},
        {"page":9,"code":"2.3.4","description":"Depth 4500–6000mm","unit":"m³","price":"667.56"},
        {"page":9,"code":"2.3.5","description":"Depth 6000–7500mm","unit":"m³","price":"834.46"},
        {"page":9,"code":"2.3.6","description":"Depth 7500–9000mm","unit":"m³","price":"1,054.05"},
        {"page":9,"code":"2.3.7","description":"Depth 9000–10500mm","unit":"m³","price":"1,430.50"},
        {"page":9,"code":"2.4.1","description":"Bulk excavation in soft rock — depth ≤1.5m","unit":"m³","price":"666.61"},
        {"page":9,"code":"2.4.2","description":"Depth 1.5m–3m","unit":"m³","price":"760.13"},
        {"page":9,"code":"2.4.3","description":"Depth 3.0m–4.5m","unit":"m³","price":"922.70"},
        {"page":9,"code":"2.4.4","description":"Depth 4.5m–6.0m","unit":"m³","price":"1,318.14"},
        {"page":9,"code":"2.4.5","description":"Depth 6.0m–7.5m","unit":"m³","price":"1,883.05"},
        {"page":9,"code":"2.4.6","description":"Depth 7.5m–9.0m","unit":"m³","price":"2,690.08"},
        {"page":9,"code":"2.4.7","description":"Depth 9.0m–10.5m","unit":"m³","price":"3,842.97"},
        {"page":9,"code":"2.5.1","description":"Pit excavation in soft rock — depth ≤1.5m","unit":"m³","price":"829.55"},
        {"page":9,"code":"2.5.2","description":"Depth 1.5m–3m","unit":"m³","price":"911.60"},
        {"page":9,"code":"2.5.3","description":"Depth 3.0m–4.5m","unit":"m³","price":"1,128.64"},
        {"page":9,"code":"2.5.4","description":"Depth 4.5m–6m","unit":"m³","price":"1,612.35"},
        {"page":9,"code":"2.5.5","description":"Depth 6m–7.5m","unit":"m³","price":"2,303.36"},
        {"page":9,"code":"2.5.6","description":"Depth 7.5m–9m","unit":"m³","price":"3,290.51"},
        {"page":9,"code":"2.5.7","description":"Depth 9m–10.5m","unit":"m³","price":"4,700.72"},
        {"page":9,"code":"2.6.1","description":"Bulk excavation in hard rock — depth ≤1.50m","unit":"m³","price":"1,368.24"},
        {"page":9,"code":"2.6.2","description":"Depth 1.5m–3m","unit":"m³","price":"1,706.63"},
        {"page":9,"code":"2.6.3","description":"Depth 3.0m–4.5m","unit":"m³","price":"2,051.20"},
        {"page":10,"code":"2.6.4","description":"Depth 4.5m–6.0m","unit":"m³","price":"2,792.32"},
        {"page":10,"code":"2.6.5","description":"Depth 6.0m–7.5m","unit":"m³","price":"3,490.40"},
        {"page":10,"code":"2.6.6","description":"Depth 7.5m–9.0m","unit":"m³","price":"4,363.00"},
        {"page":10,"code":"2.6.7","description":"Depth 9.0m–10.5m","unit":"m³","price":"5,132.95"},
        {"page":10,"code":"2.7.1","description":"Pit excavation in hard rock — depth ≤1.50m","unit":"m³","price":"1,659.11"},
        {"page":10,"code":"2.7.2","description":"Depth 1.5m–3m","unit":"m³","price":"2,051.09"},
        {"page":10,"code":"2.7.3","description":"Depth 3.0m–4.5m","unit":"m³","price":"2,666.42"},
        {"page":10,"code":"2.7.4","description":"Depth 4.5m–6m","unit":"m³","price":"3,627.78"},
        {"page":10,"code":"2.7.5","description":"Depth 6.0m–7.5m","unit":"m³","price":"5,182.55"},
        {"page":10,"code":"2.7.6","description":"Depth 7.5m–9m","unit":"m³","price":"7,403.64"},
        {"page":10,"code":"2.7.7","description":"Depth 9m–10.5m","unit":"m³","price":"10,576.63"},
        {"page":10,"code":"2.8.1","description":"Back fill selected excavated mats. from the site (mechanized)","unit":"m³","price":"982.68"},
        {"page":10,"code":"2.8.2","description":"Back fill from outside (Upto 20km) (Mechanized)","unit":"m³","price":"3,066.43"},
        {"page":10,"code":"2.8.3","description":"Back fill from outside (Upto 15km) (Mechanized)","unit":"m³","price":"2,540.36"},
        {"page":10,"code":"2.8.4","description":"Back fill from outside (Upto 10km) (Mechanized)","unit":"m³","price":"2,180.98"},
        {"page":10,"code":"2.8.5","description":"Back fill from outside (Upto 5km) (Mechanized)","unit":"m³","price":"1,821.61"},
        {"page":10,"code":"2.8.6","description":"25cm. thick basaltic hard core. (Mechanized)","unit":"m²","price":"1,099.89"}
      ]
      
// the catagories items are over 1500 lines this is just dample
    }]
};END
cat > src/data/ratebook.js << 'END'
import { putAll, getAll, clearStore, put, getAllBy } from './db.js';
import { RATEBOOK } from './ratebook-data.js';

function normalizeItem(catId, item, idx) {
  const rawPrice = String(item.price || '').replace(/,/g, '').trim();
  const price = rawPrice === '' || rawPrice === 'â€”' ? null : parseFloat(rawPrice);
  return {
    id: catId + ':' + (item.code || idx) + ':' + idx,
    categoryId: catId,
    code: item.code || '',
    description: item.description || '',
    unit: item.unit || '',
    basePrice: price,
    contractorPrice: price,
    page: item.page || 0
  };
}

export async function importRateBook(json) {
  const src = json || RATEBOOK;
  if (!src || !Array.isArray(src.categories)) throw new Error('Invalid rate book data â€” missing "categories"');
  const categories = [];
  const items = [];
  src.categories.forEach(cat => {
    const catId = String(cat.id);
    categories.push({ id: catId, title: cat.title || 'Untitled', itemCount: (cat.items || []).length });
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
export async function getRateCategories() { return getAll('ratebook_categories'); }
export async function getRateItemsByCategory(catId) { return getAllBy('ratebook_items', 'by-category', catId); }
export async function getRateItems() { return getAll('ratebook_items'); }
export async function updateRateItem(id, patch) {
  const rows = await getAll('ratebook_items');
  const item = rows.find(r => r.id === id);
  if (!item) return null;
  const next = Object.assign({}, item, patch);
  await put('ratebook_items', next);
  return next;
}
export async function applyInflation(factor, alsoContractor = false) {
  const rows = await getAll('ratebook_items');
  const updated = rows.map(r => {
    if (r.basePrice == null) return r;
    const next = Object.assign({}, r, { basePrice: Math.round(r.basePrice * factor * 100) / 100 });
    if (alsoContractor) next.contractorPrice = next.basePrice;
    return next;
  });
  await putAll('ratebook_items', updated);
  return updated.length;
}
export async function resetContractorPrices() {
  const rows = await getAll('ratebook_items');
  const updated = rows.map(r => Object.assign({}, r, { contractorPrice: r.basePrice }));
  await putAll('ratebook_items', updated);
  return updated.length;
}
export async function clearRateBook() {
  await clearStore('ratebook_categories');
  await clearStore('ratebook_items');
  await clearStore('meta');
}
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
    {
      id: 'p1',
      title: 'Network Tower and compound fence',
      type: 'Telecom',
      icon: '🏢',
      image: 'img/messe/1.jpg',
      desc: 'Telecom infrastructure for safaricom.',
      budget: 'ETB 85,000,000',
      duration: '24 months',
      year: 2024,
      client: 'Safaricom Ethiopia'
    },
    {
      id: 'p2',
      title: 'solar panel array',
      type: 'Telecom',
      icon: '🛣️',
      image: 'img/messe/2.jpg',
      desc: 'solar power supply for network tower installation',
      budget: 'ETB 42,000,000',
      duration: '14 months',
      year: 2023,
      client: 'Safaricom-ethiopia'
    },
    {
      id: 'p3',
      title: 'Commercial Office Fit-out',
      type: 'building',
      icon: '🏢',
      image: 'img/messe/3.jpg',
      desc: '1,800 m² office interior fit-out.',
      budget: 'ETB 28,000,000',
      duration: '8 months',
      year: 2023,
      client: 'Private client'
    }
  ],
  reviews: [
    { id: 'r1', name: 'Ato Bekele T.', loc: 'Addis Ababa', stars: 5, text: 'Delivered our residential building on schedule. Professional site management.' },
    { id: 'r2', name: 'Ato Dawit M.', loc: 'Gulele', stars: 5, text: 'Road quality met every spec. Good communication with our engineers.' },
    { id: 'r3', name: 'W/ro Hana G.', loc: 'Addis Ababa', stars: 5, text: 'Office fit-out finished on time and on budget.' }
  ],
  categories: [
    { id: 'cement',    name: 'Cement & Binders', nameAm: 'ሲሚንቶ', icon: '🧱' },
    { id: 'steel',     name: 'Steel & Rebar',    nameAm: 'ብረት', icon: '🔩' },
    { id: 'lumber',    name: 'Lumber & Timber',  nameAm: 'እንጨት', icon: '🪵' },
    { id: 'aggregate', name: 'Aggregates',       nameAm: 'ጠጠር እና አሸዋ', icon: '⛰️' },
    { id: 'fixtures',  name: 'Fixtures & Pipes', nameAm: 'ቧንቧ እና መለዋወጫ', icon: '🚰' }
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
  freight: {
    zones: [
      { id: 'addis',    name: 'Addis Ababa',        flat: 800,  perTon: 40 },
      { id: 'nearby',   name: 'Within 100 km',      flat: 1800, perTon: 75 },
      { id: 'regional', name: 'Regional (100-400)', flat: 4500, perTon: 140 },
      { id: 'far',      name: 'Remote (> 400 km)',  flat: 9000, perTon: 220 }
    ]
  },
  hero: {
    badge1En: 'General Contractor G5', badge1Am: 'አጠቃላይ ተቋራጭ 511114',
    badge2En: 'Trusted', badge2Am: 'ma',
    badge3En: '10+ Years', badge3Am: '18+ ዓመታት'
  },
  stats: [
    { id: 's1', num: '120+', lblEn: 'Projects Delivered', lblAm: 'የተጠናቀቁ ፕሮጀክቶች' },
    { id: 's2', num: '18+',  lblEn: 'Years in Business',  lblAm: 'የንግድ ዓመታት' },
    { id: 's3', num: '511114', lblEn: 'License Code',     lblAm: 'የፈቃድ ኮድ' },
    { id: 's4', num: '100%', lblEn: 'VAT Registered',     lblAm: 'ተ.እ.ታ ተመዝጋቢ' }
  ]
};

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return DEFAULT_DATA;
    return Object.assign({}, DEFAULT_DATA, JSON.parse(raw));
  } catch (e) { return DEFAULT_DATA; }
}

let _state = load();
const subs = new Set();
export function getData() { return _state; }
export function subscribe(fn) { subs.add(fn); return () => subs.delete(fn); }
export function setData(next) {
  _state = next;
  try { localStorage.setItem(KEY, JSON.stringify(next)); } catch (e) {}
  subs.forEach(fn => fn(next));
}
export function resetData() { setData(DEFAULT_DATA); }
export function useStore() {
  const [d, setD] = useState(_state);
  useEffect(() => subscribe(setD), []);
  return [d, setData];
}
export function uid() { return 'id_' + Math.random().toString(36).slice(2, 9); }END
cat > src/admin/Admin.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { supabase } from '../lib/supabase.js';
import { signOut, isAdminUser } from '../lib/auth.js';
import { AdminHome, ADMIN_TOOLS } from './AdminHome.jsx';
import { RequestsTab } from './RequestsTab.jsx';
import { ProformasTab } from './ProformasTab.jsx';
import { RateBookTab } from './RateBookTab.jsx';
import { CatalogTab, ProjectsTab, ReviewsTab, BusinessTab, UsersTab, SettingsTab } from './Tabs.jsx';
import { ProformaBuilder } from '../components/ProformaBuilder.jsx';


export function Admin({ onExit }) {
  const [data] = useStore();
  const [tab, setTab] = useState('home');
  const [builder, setBuilder] = useState(null); // { mode: 'from-request' | 'internal', request }

  const viewSite = () => { sessionStorage.removeItem('mesay_staff'); onExit(); };
  const leave = async () => { sessionStorage.removeItem('mesay_staff'); await signOut(); onExit(); };

  // The sessionStorage flag is only a client hint: confirm there is still an admin session
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
    body = <ProformaBuilder key={builder.mode + (builder.request ? builder.request.id : '')} mode={builder.mode} request={builder.request} onClose={() => setBuilder(null)} />;
  } else if (tab === 'home') body = <AdminHome onOpen={go} />;
  else if (tab === 'requests') body = <RequestsTab onBuildProforma={(r) => openBuilder('from-request', r)} />;
  else if (tab === 'proformas') body = <ProformasTab onNew={(mode) => openBuilder(mode)} onGoRequests={() => go('requests')} />;
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
        <strong>{data.business.nameEn} Â· Admin</strong>
        <div class="admin-header-actions">
          <button class="btn-view" onClick={viewSite}>View Site</button>
          <button class="btn-danger" onClick={leave}>Sign out</button>
        </div>
      </div>
      <div class="admin-tabs">
        <button class={'admin-tab ' + (tab === 'home' && !builder ? 'active' : '')} onClick={() => go('home')}>ðŸ  Home</button>
        {ADMIN_TOOLS.map(t => (
          <button class={'admin-tab ' + (tab === t.id ? 'active' : '')} key={t.id} onClick={() => go(t.id)}>{t.icon} {t.title}</button>
        ))}
      </div>
      <div class="admin-body">{body}</div>
    </div>
  );
}
END
cat > src/admin/AdminHome.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { useStore } from '../data/store.js';
import { getRequests } from '../data/requests.js';
import { getProformas } from '../data/proformas.js';
import { getRateItems } from '../data/ratebook.js';
import { supabase } from '../lib/supabase.js';
import { BUSINESS_FIELDS } from './fields.js';

export const ADMIN_TOOLS = [
  { id: 'requests', icon: 'ðŸ“¥', title: 'Quote Requests', subtitle: 'Service and material requests from clients', unit: 'requests' },
  { id: 'proformas', icon: 'ðŸ§¾', title: 'Proformas', subtitle: 'Build, track and print quotations', unit: 'proformas' },
  { id: 'ratebook', icon: 'ðŸ“–', title: 'Rate Book', subtitle: 'Bureau unit rates and contractor prices', unit: 'items' },
  { id: 'catalog', icon: 'ðŸ§±', title: 'Materials Catalog', subtitle: 'Products shown to customers', unit: 'products' },
  { id: 'projects', icon: 'ðŸ—ï¸', title: 'Projects', subtitle: 'Recent projects gallery', unit: 'projects' },
  { id: 'reviews', icon: 'â­', title: 'Reviews', subtitle: 'Client testimonials', unit: 'reviews' },
  { id: 'business', icon: 'ðŸ¢', title: 'Business Info', subtitle: 'License, contacts and address', unit: 'fields set' },
  { id: 'users', icon: 'ðŸ‘¥', title: 'Users/Roles', subtitle: 'Who can sign in to admin', unit: 'admins' },
  { id: 'settings', icon: 'âš™ï¸', title: 'Settings', subtitle: 'VAT, terms, markup and freight', unit: 'freight zones' }
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
    proformas: counts.proformas,
    ratebook: counts.ratebook,
    catalog: data.products.length,
    projects: data.projects.length,
    reviews: data.reviews.length,
    business: BUSINESS_FIELDS.filter(([k]) => data.business[k] !== '' && data.business[k] != null).length,
    users: counts.users,
    settings: data.freight.zones.length
  };
  const show = (id) => live[id] != null ? live[id] : (loaded ? 'â€”' : 'â€¦');

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
}
END
cat > src/admin/ProformasTab.jsx << 'END'
import { useState, useEffect } from 'preact/hooks';
import { getProformas, deleteProforma, duplicateProforma, updateProformaStatus } from '../data/proformas.js';
import { formatMoney } from '../data/pricing.js';
import { ProformaDoc } from '../components/ProformaBuilder.jsx';

const STATUSES = ['draft', 'sent', 'accepted', 'rejected', 'expired'];

export function ProformasTab({ onNew, onGoRequests }) {
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
          <button class="btn btn-back" onClick={() => setViewing(null)}>â† Back</button>
          <button class="btn btn-primary" onClick={() => window.print()}>Print</button>
        </div>
        <ProformaDoc pf={viewing} />
      </div>
    );
  }
  if (!rows) return <div class="admin-panel"><h2>Proformas</h2><p>Loadingâ€¦</p></div>;

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
            <button class="btn btn-back" onClick={onGoRequests}>From a request (pick one in Quote Requests)</button>
            <button class="btn btn-primary" onClick={() => onNew('internal')}>Internal / open bidding</button>
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
            {(p.client && p.client.name) || 'â€”'} Â· {p.createdAt} Â· {p.mode === 'internal' ? 'Internal' : 'From request'} Â· <strong>{formatMoney(p.totals && p.totals.grandTotal)}</strong>
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
}
END
cat > src/admin/RateBookTab.jsx << 'END'
import { useState, useEffect, useMemo } from 'preact/hooks';
import { useStore } from '../data/store.js';
import {
  getRateBookMeta, getRateCategories, getRateItems, updateRateItem,
  applyInflation, resetContractorPrices, seedFromModule
} from '../data/ratebook.js';

export function RateBookTab() {
  const [data] = useStore();
  const [meta, setMeta] = useState(null);
  const [cats, setCats] = useState([]);
  const [items, setItems] = useState([]);
  const [cat, setCat] = useState('all');
  const [q, setQ] = useState('');
  const [factor, setFactor] = useState(String(data.business.inflationFactor || 1));
  const [alsoContractor, setAlsoContractor] = useState(false);
  const [msg, setMsg] = useState('');

  const load = async () => {
    setMeta(await getRateBookMeta());
    setCats(await getRateCategories());
    setItems(await getRateItems());
  };
  useEffect(() => { load(); }, []);

  const results = useMemo(() => {
    const s = q.trim().toLowerCase();
    return items.filter(i =>
      (cat === 'all' || i.categoryId === cat) &&
      (!s || String(i.code).toLowerCase().includes(s) || String(i.description).toLowerCase().includes(s))
    );
  }, [items, cat, q]);

  const savePrice = async (item, raw) => {
    const v = raw === '' ? null : parseFloat(raw);
    await updateRateItem(item.id, { contractorPrice: v });
    setItems(items.map(i => i.id === item.id ? Object.assign({}, i, { contractorPrice: v }) : i));
  };
  const inflate = async () => {
    const f = parseFloat(factor);
    if (!f || f <= 0) { setMsg('Enter a valid factor, e.g. 1.05'); return; }
    if (!confirm('Multiply all base prices by ' + f + '?')) return;
    const n = await applyInflation(f, alsoContractor);
    setMsg('Updated ' + n + ' items.'); load();
  };
  const resetPrices = async () => {
    if (!confirm('Reset every contractor price to its base price?')) return;
    const n = await resetContractorPrices();
    setMsg('Reset ' + n + ' items.'); load();
  };
  const reseed = async () => {
    if (!confirm('Reload the bundled rate book? This replaces all rate book items and edits.')) return;
    const r = await seedFromModule();
    setMsg('Loaded ' + r.itemCount + ' items in ' + r.categoryCount + ' categories.'); load();
  };

  return (
    <div class="admin-panel">
      <div class="admin-panel-head">
        <h2>Rate Book ({items.length} items)</h2>
        <button class="btn-add" onClick={reseed}>Reload bundled rate book</button>
      </div>
      {meta && <div class="admin-card" style="font-size:0.85rem;color:var(--gray);">{meta.document || meta.source} {meta.quarter} Â· {meta.currency} Â· imported {String(meta.importedAt).slice(0, 10)}</div>}
      {msg && <div class="admin-msg">{msg}</div>}

      <div class="admin-card">
        <div class="admin-grid3">
          <div class="admin-field"><label>Inflation factor</label><input type="number" step="any" value={factor} onInput={e => setFactor(e.target.value)} /></div>
          <div class="admin-field"><label>Also set contractor price</label><select value={alsoContractor ? 'yes' : 'no'} onChange={e => setAlsoContractor(e.target.value === 'yes')}><option value="no">No</option><option value="yes">Yes</option></select></div>
          <div class="admin-field"><label>&nbsp;</label><button class="btn-add" onClick={inflate}>Apply</button></div>
        </div>
        <button class="btn-del" onClick={resetPrices}>Reset contractor prices</button>
      </div>

      <div class="admin-grid2">
        <div class="admin-field"><label>Search</label><input value={q} onInput={e => setQ(e.target.value)} placeholder="Code or description" /></div>
        <div class="admin-field"><label>Category</label>
          <select value={cat} onChange={e => setCat(e.target.value)}>
            <option value="all">All categories</option>
            {cats.map(c => <option value={c.id}>{c.id}. {c.title}</option>)}
          </select>
        </div>
      </div>

      <div class="admin-card">
        {results.slice(0, 100).map(i => (
          <div class="ratebook-row" key={i.id}>
            <span class="rb-code">{i.code}</span>
            <span class="rb-desc">{i.description}</span>
            <span class="rb-price">{i.basePrice == null ? 'â€”' : i.basePrice}</span>
            <span class="rb-unit">{i.unit}</span>
            <input type="number" step="any" value={i.contractorPrice == null ? '' : i.contractorPrice} onChange={e => savePrice(i, e.target.value)} />
          </div>
        ))}
        {results.length === 0 && <div>No items.</div>}
        {results.length > 100 && <p style="font-size:0.78rem;color:var(--gray);margin-top:8px;">Showing the first 100 of {results.length} matches.</p>}
      </div>
    </div>
  );
}
END
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
