import { putAll, getAll, get, put, del } from './db.js';

export const saveTenders      = (list)    => putAll('egp_tenders', list);
export const getTenders       = ()        => getAll('egp_tenders');
export const deleteTender     = (id)      => del('egp_tenders', id);

export const saveTenderDetail = (d)       => put('egp_tender_details', d);
export const getTenderDetail  = (lotId)   => get('egp_tender_details', lotId);

export const saveTenderItems  = (rec)     => put('egp_tender_items', rec);
export const getTenderItems   = (key)     => get('egp_tender_items', key);