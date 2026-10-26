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
}