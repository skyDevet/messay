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
}