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
}