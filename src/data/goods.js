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
}