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
}