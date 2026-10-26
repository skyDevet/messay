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
}