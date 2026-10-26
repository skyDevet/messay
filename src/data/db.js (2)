const DB_NAME = 'mesay_db';
const DB_VERSION = 1;
let _db = null;
export function openDB() {
  if (_db) return Promise.resolve(_db);
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (e) => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains('ratebook_categories')) db.createObjectStore('ratebook_categories', { keyPath: 'id' });
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
      if (!db.objectStoreNames.contains('meta')) db.createObjectStore('meta', { keyPath: 'key' });
    };
    req.onsuccess = () => { _db = req.result; resolve(_db); };
    req.onerror = () => reject(req.error);
  });
}
function tx(store, mode) { return openDB().then(db => db.transaction(store, mode).objectStore(store)); }
export function put(store, value) { return tx(store, 'readwrite').then(s => new Promise((res, rej) => { const r = s.put(value); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); })); }
export function putAll(store, values) { return openDB().then(db => new Promise((res, rej) => { const t = db.transaction(store, 'readwrite'); const s = t.objectStore(store); values.forEach(v => s.put(v)); t.oncomplete = () => res(values.length); t.onerror = () => rej(t.error); })); }
export function get(store, id) { return tx(store, 'readonly').then(s => new Promise((res, rej) => { const r = s.get(id); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); })); }
export function getAll(store) { return tx(store, 'readonly').then(s => new Promise((res, rej) => { const r = s.getAll(); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); })); }
export function getAllBy(store, indexName, value) { return tx(store, 'readonly').then(s => new Promise((res, rej) => { const r = s.index(indexName).getAll(value); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); })); }
export function del(store, id) { return tx(store, 'readwrite').then(s => new Promise((res, rej) => { const r = s.delete(id); r.onsuccess = () => res(); r.onerror = () => rej(r.error); })); }
export function clearStore(store) { return tx(store, 'readwrite').then(s => new Promise((res, rej) => { const r = s.clear(); r.onsuccess = () => res(); r.onerror = () => rej(r.error); })); }
