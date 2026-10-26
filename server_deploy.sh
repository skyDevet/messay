#!/bin/bash
set -e
echo "Extracting server files..."
mkdir -p "server"
mkdir -p "server/lib"
mkdir -p "server/middleware"
mkdir -p "server/routes"
mkdir -p "server/supabase"
mkdir -p "server/supabase/migrations"
cat > "server/egpAuth.js" << __EOF_79f26e976311__
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const CONFIG = {
  USERNAME: process.env.EGP_USERNAME || 'Mesaya496@gmail.com',
  PASSWORD: process.env.EGP_PASSWORD || 'Mesay@123',
  TOKEN_URL: 'https://production.egp.gov.et/auth/connect/token',
  API_BASE: 'https://production.egp.gov.et',
  SCOPE: 'openid profile email offline_access erp_api',
  CLIENT_ID: 'skoruba_identity_admin',
  CLIENT_SECRET: 'skoruba_admin_client_secret',
  VISITOR_ID: process.env.EGP_VISITOR_ID || 'ce01e0a13c0cf55d99d8710d8b941c85',
  HMAC_SECRET: 'xlpJ2QI0pvOtZkBN5WlL',
  SESSION_FILE: path.resolve('server/egp_session.json'),
  REFRESH_MARGIN: 120,
  REFRESH_CHECK_MS: 30_000,
  REQUEST_TIMEOUT_MS: 15_000,
  MAX_RETRIES: 2,
  RETRY_DELAY_MS: 1_000,
};

const session = {
  access_token: null, refresh_token: null, id_token: null,
  token_type: null, expires_in: null, expires_at: null, scope: null,
  profile: null, org: null, isAuthenticated: false,
  capturedAt: null, lastRefresh: null, refreshCount: 0,
};

const now = () => Math.floor(Date.now() / 1000);

function decodeJwt(t) {
  try {
    const p = t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(p, 'base64').toString('utf8'));
  } catch { return null; }
}

function saveSession() {
  try { fs.writeFileSync(CONFIG.SESSION_FILE, JSON.stringify(session, null, 2)); }
  catch (e) { console.warn('[egp] save fail:', e.message); }
}
function loadSession() {
  try {
    if (fs.existsSync(CONFIG.SESSION_FILE))
      Object.assign(session, JSON.parse(fs.readFileSync(CONFIG.SESSION_FILE, 'utf8')));
  } catch {}
}

function applyToken(body) {
  session.access_token = body.access_token;
  session.refresh_token = body.refresh_token || session.refresh_token;
  session.id_token = body.id_token;
  session.token_type = body.token_type;
  session.expires_in = body.expires_in;
  session.scope = body.scope;
  session.expires_at = now() + Number(body.expires_in || 0);
  session.isAuthenticated = true;

  const p = decodeJwt(session.access_token) || {};
  const prof = p.profile || {};
  session.profile = {
    sub: p.sub, name: p.name, email: prof.email,
    firstName: prof.firstName?.en, lastName: prof.lastName?.en,
  };
}

const formHeaders = () => ({
  'Content-Type': 'application/x-www-form-urlencoded',
  Accept: 'application/json, text/plain, */*',
  'X-Application-Key': 'landing',
});

// Fetch with timeout + retry; throws only after all retries exhausted
async function robustFetch(url, init = {}) {
  let lastErr = null;
  for (let attempt = 0; attempt < CONFIG.MAX_RETRIES; attempt++) {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), CONFIG.REQUEST_TIMEOUT_MS);
    try {
      const res = await fetch(url, { ...init, signal: ctl.signal });
      clearTimeout(timer);
      return res;
    } catch (e) {
      clearTimeout(timer);
      lastErr = e;
      const code = e?.cause?.code || e?.name || e?.message || 'error';
      console.warn(`[egp] fetch attempt ${attempt + 1}/${CONFIG.MAX_RETRIES} failed: ${code}`);
      if (attempt < CONFIG.MAX_RETRIES - 1) {
        await new Promise(r => setTimeout(r, CONFIG.RETRY_DELAY_MS));
      }
    }
  }
  throw lastErr;
}

function errMessage(e) {
  return e?.cause?.code || e?.cause?.message || e?.name || e?.message || 'network error';
}

export async function doPasswordLogin() {
  const body = new URLSearchParams({
    grant_type: 'password', scope: CONFIG.SCOPE,
    username: CONFIG.USERNAME, password: CONFIG.PASSWORD,
    client_id: CONFIG.CLIENT_ID, client_secret: CONFIG.CLIENT_SECRET,
  });
  try {
    const r = await robustFetch(CONFIG.TOKEN_URL, { method: 'POST', headers: formHeaders(), body });
    const json = await r.json().catch(() => ({}));
    if (r.status !== 200 || !json.access_token) {
      console.warn('[egp] login failed', r.status, json);
      return false;
    }
    applyToken(json);
    session.capturedAt = new Date().toISOString();
    saveSession();
    console.log('[egp] login ok, expires_in', session.expires_in);
    return true;
  } catch (e) { console.warn('[egp] login exc:', errMessage(e)); return false; }
}

export async function doRefresh() {
  if (!session.refresh_token) return false;
  const body = new URLSearchParams({
    grant_type: 'refresh_token', refresh_token: session.refresh_token,
    client_id: CONFIG.CLIENT_ID, client_secret: CONFIG.CLIENT_SECRET,
    scope: CONFIG.SCOPE,
  });
  try {
    const r = await robustFetch(CONFIG.TOKEN_URL, { method: 'POST', headers: formHeaders(), body });
    const json = await r.json().catch(() => ({}));
    if (r.status !== 200 || !json.access_token) {
      console.warn('[egp] refresh failed', r.status, json);
      return false;
    }
    applyToken(json);
    session.lastRefresh = new Date().toISOString();
    session.refreshCount += 1;
    saveSession();
    console.log('[egp] refreshed, count', session.refreshCount);
    return true;
  } catch (e) { console.warn('[egp] refresh exc:', errMessage(e)); return false; }
}

export function status() {
  const rem = (session.expires_at || 0) - now();
  return {
    isAuthenticated: session.isAuthenticated,
    hasToken: !!session.access_token,
    expiresAt: session.expires_at,
    expiresInSeconds: Math.max(rem, 0),
    refreshCount: session.refreshCount,
    lastRefresh: session.lastRefresh,
    capturedAt: session.capturedAt,
    name: session.profile?.name || null,
    org: session.org,
  };
}

function signingPath(pathname) {
  const i = pathname.indexOf('/api');
  return i === -1 ? pathname : pathname.slice(i);
}

function buildHmac(method, fullUrl) {
  const u = new URL(fullUrl);
  const m  = (method || 'POST').toUpperCase();
  const p  = signingPath(u.pathname);
  const q  = u.search.startsWith('?') ? u.search.slice(1) : u.search;
  const q_ = q ? '?' + q : '';
  const ts = String(Math.floor(Date.now() / 1000));
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const canonical = [m, p, q_, ts, nonce].join('\n');
  const sig = crypto.createHmac('sha256', CONFIG.HMAC_SECRET).update(canonical).digest('base64');
  return {
    'X-Hmac-Signature': sig,
    'X-Hmac-Timestamp': ts,
    'X-Hmac-Nonce':     nonce,
  };
}

function baseHeaders() {
  return {
    Authorization: `Bearer ${session.access_token}`,
    Accept: 'application/json, text/plain, */*',
    'X-Application-Key': 'landing',
    'X-Visitor-Id': CONFIG.VISITOR_ID,
    'X-Organization-Id': '5b861f3c-e466-4453-8980-43d8dd05f5c7',
    'X-Personnel-Id':    'c5fcfc56-4538-4bfe-ba0d-940134288a33',
    'X-Placement-Id':    'e846dd88-20bb-4e6c-b4b5-d20e83b7765e',
    'X-Unit-Id':         '5b861f3c-e466-4453-8980-43d8dd05f5c7',
  };
}

export async function egpGet(pathname) {
  if (!session.access_token) {
    if (!(await doPasswordLogin())) return { status: 401, body: { error: 'not authenticated' } };
  }
  const url = CONFIG.API_BASE + pathname;

  const doFetch = () => robustFetch(url, { headers: baseHeaders() });

  try {
    let r = await doFetch();
    if (r.status === 401 && (await doRefresh())) r = await doFetch();

    const text = await r.text();
    let parsed; try { parsed = JSON.parse(text); } catch { parsed = { _raw: text.slice(0, 2000) }; }
    return { status: r.status, body: parsed };
  } catch (e) {
    const msg = errMessage(e);
    console.warn('[egp] egpGet failed:', msg);
    return { status: 0, body: { error: 'eGP unreachable: ' + msg } };
  }
}

export async function egpRequest(method, pathname, body) {
  if (!session.access_token) {
    if (!(await doPasswordLogin())) return { status: 401, body: { error: 'not authenticated' } };
  }
  const url = CONFIG.API_BASE + pathname;
  const m = method.toUpperCase();

  const doFetch = () => {
    const headers = baseHeaders();
    headers['Content-Type'] = 'application/json';
    if (m !== 'GET') Object.assign(headers, buildHmac(m, url));
    return robustFetch(url, {
      method: m,
      headers,
      body: body != null ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
    });
  };

  try {
    let r = await doFetch();
    if (r.status === 401 && (await doRefresh())) r = await doFetch();

    const text = await r.text();
    let parsed; try { parsed = JSON.parse(text); } catch { parsed = { _raw: text.slice(0, 2000) }; }
    return { status: r.status, body: parsed };
  } catch (e) {
    const msg = errMessage(e);
    console.warn(`[egp] egpRequest ${m} ${pathname} failed:`, msg);
    return { status: 0, body: { error: 'eGP unreachable: ' + msg } };
  }
}

export function startRefreshWorker() {
  setInterval(async () => {
    if (!session.isAuthenticated) return;
    const rem = (session.expires_at || 0) - now();
    if (rem <= CONFIG.REFRESH_MARGIN) {
      console.log(`[egp] token expires in ${rem}s, refreshing`);
      if (!(await doRefresh()) && !(await doPasswordLogin())) {
        console.warn('[egp] refresh + login both failed');
      }
    }
  }, CONFIG.REFRESH_CHECK_MS).unref?.();
}

export async function bootstrap() {
  loadSession();
  if (session.refresh_token) {
    console.log('[egp] bootstrapping from stored refresh_token');
    if (!(await doRefresh())) await doPasswordLogin();
  } else {
    console.log('[egp] no stored session, will log in on first call');
  }
  startRefreshWorker();
}
__EOF_79f26e976311__
cat > "server/egpAuth.js (2)" << __EOF_dc0d79b2b551__
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const CONFIG = {
  USERNAME: process.env.EGP_USERNAME || 'Mesaya496@gmail.com',
  PASSWORD: process.env.EGP_PASSWORD || 'Mesay@123',
  TOKEN_URL: 'https://production.egp.gov.et/auth/connect/token',
  API_BASE: 'https://production.egp.gov.et',
  SCOPE: 'openid profile email offline_access erp_api',
  CLIENT_ID: 'skoruba_identity_admin',
  CLIENT_SECRET: 'skoruba_admin_client_secret',
  VISITOR_ID: process.env.EGP_VISITOR_ID || 'ce01e0a13c0cf55d99d8710d8b941c85',
  HMAC_SECRET: 'xlpJ2QI0pvOtZkBN5WlL',
  SESSION_FILE: path.resolve('server/egp_session.json'),
  REFRESH_MARGIN: 120,
  REFRESH_CHECK_MS: 30_000,
};

const session = {
  access_token: null, refresh_token: null, id_token: null,
  token_type: null, expires_in: null, expires_at: null, scope: null,
  profile: null, org: null, isAuthenticated: false,
  capturedAt: null, lastRefresh: null, refreshCount: 0,
};

const now = () => Math.floor(Date.now() / 1000);

function decodeJwt(t) {
  try {
    const p = t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(p, 'base64').toString('utf8'));
  } catch { return null; }
}

function saveSession() {
  try { fs.writeFileSync(CONFIG.SESSION_FILE, JSON.stringify(session, null, 2)); }
  catch (e) { console.warn('[egp] save fail:', e.message); }
}
function loadSession() {
  try {
    if (fs.existsSync(CONFIG.SESSION_FILE))
      Object.assign(session, JSON.parse(fs.readFileSync(CONFIG.SESSION_FILE, 'utf8')));
  } catch {}
}

function applyToken(body) {
  session.access_token = body.access_token;
  session.refresh_token = body.refresh_token || session.refresh_token;
  session.id_token = body.id_token;
  session.token_type = body.token_type;
  session.expires_in = body.expires_in;
  session.scope = body.scope;
  session.expires_at = now() + Number(body.expires_in || 0);
  session.isAuthenticated = true;

  const p = decodeJwt(session.access_token) || {};
  const prof = p.profile || {};
  session.profile = {
    sub: p.sub, name: p.name, email: prof.email,
    firstName: prof.firstName?.en, lastName: prof.lastName?.en,
  };
  const org = (prof.organizations || []).find(o => o.applications?.length) || prof.organizations?.[0];
  if (org) {
    const unit = org.units?.[0] || {};
    session.org = {
      organizationId: org.id,
      personnelId: org.personnelId,
      placementId: unit.placementId,
      unitId: unit.id,
    };
  }
}

const formHeaders = () => ({
  'Content-Type': 'application/x-www-form-urlencoded',
  Accept: 'application/json, text/plain, */*',
  'X-Application-Key': 'landing',
});

export async function doPasswordLogin() {
  const body = new URLSearchParams({
    grant_type: 'password', scope: CONFIG.SCOPE,
    username: CONFIG.USERNAME, password: CONFIG.PASSWORD,
    client_id: CONFIG.CLIENT_ID, client_secret: CONFIG.CLIENT_SECRET,
  });
  try {
    const r = await fetch(CONFIG.TOKEN_URL, { method: 'POST', headers: formHeaders(), body });
    const json = await r.json().catch(() => ({}));
    if (r.status !== 200 || !json.access_token) {
      console.warn('[egp] login failed', r.status, json);
      return false;
    }
    applyToken(json);
    session.capturedAt = new Date().toISOString();
    saveSession();
    console.log('[egp] ✅ login ok, expires_in', session.expires_in);
    return true;
  } catch (e) { console.warn('[egp] login exc:', e.message); return false; }
}

export async function doRefresh() {
  if (!session.refresh_token) return false;
  const body = new URLSearchParams({
    grant_type: 'refresh_token', refresh_token: session.refresh_token,
    client_id: CONFIG.CLIENT_ID, client_secret: CONFIG.CLIENT_SECRET,
    scope: CONFIG.SCOPE,
  });
  try {
    const r = await fetch(CONFIG.TOKEN_URL, { method: 'POST', headers: formHeaders(), body });
    const json = await r.json().catch(() => ({}));
    if (r.status !== 200 || !json.access_token) {
      console.warn('[egp] refresh failed', r.status, json);
      return false;
    }
    applyToken(json);
    session.lastRefresh = new Date().toISOString();
    session.refreshCount += 1;
    saveSession();
    console.log('[egp] ✅ refreshed, count', session.refreshCount);
    return true;
  } catch (e) { console.warn('[egp] refresh exc:', e.message); return false; }
}

export function status() {
  const rem = (session.expires_at || 0) - now();
  return {
    isAuthenticated: session.isAuthenticated,
    hasToken: !!session.access_token,
    expiresAt: session.expires_at,
    expiresInSeconds: Math.max(rem, 0),
    refreshCount: session.refreshCount,
    lastRefresh: session.lastRefresh,
    capturedAt: session.capturedAt,
    name: session.profile?.name || null,
    org: session.org,
  };
}

// Mirrors signingPath() from main-es2015 — strip everything before "/api"
function signingPath(pathname) {
  const i = pathname.indexOf('/api');
  return i === -1 ? pathname : pathname.slice(i);
}

// Mirrors signRequest(): canonical = METHOD\nPATH\nQUERY\nTS\nNONCE
function buildHmac(method, fullUrl) {
  const u = new URL(fullUrl);
  const m  = (method || 'POST').toUpperCase();
  const p  = signingPath(u.pathname);
  const q  = u.search.startsWith('?') ? u.search.slice(1) : u.search;
  const q_ = q ? '?' + q : '';
  const ts = String(Math.floor(Date.now() / 1000));
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const canonical = [m, p, q_, ts, nonce].join('\n');
  const sig = crypto.createHmac('sha256', CONFIG.HMAC_SECRET).update(canonical).digest('base64');
  return {
    'X-Hmac-Signature': sig,
    'X-Hmac-Timestamp': ts,
    'X-Hmac-Nonce':     nonce,
  };
}

/*function baseHeaders() {
  return {
    Authorization: `Bearer ${session.access_token}`,
    Accept: 'application/json, text/plain, /*',
    'X-Application-Key': 'landing',
    'X-Visitor-Id': CONFIG.VISITOR_ID,
    ...(session.org ? {
      'X-Organization-Id': session.org.organizationId,
      'X-Personnel-Id':    session.org.personnelId,
      'X-Placement-Id':    session.org.placementId,
      'X-Unit-Id':         session.org.unitId,
    } : {}),
  };
} */

function baseHeaders() {
  return {
    Authorization: `Bearer ${session.access_token}`,
    Accept: 'application/json, text/plain, */*',
    'X-Application-Key': 'landing',
    'X-Visitor-Id': CONFIG.VISITOR_ID,
    'X-Organization-Id': '5b861f3c-e466-4453-8980-43d8dd05f5c7',
    'X-Personnel-Id':    'c5fcfc56-4538-4bfe-ba0d-940134288a33',
    'X-Placement-Id':    'e846dd88-20bb-4e6c-b4b5-d20e83b7765e',
    'X-Unit-Id':         '5b861f3c-e466-4453-8980-43d8dd05f5c7',
  };
}

export async function egpGet(pathname) {
  if (!session.access_token) {
    if (!(await doPasswordLogin())) return { status: 401, body: { error: 'not authenticated' } };
  }
  const url = CONFIG.API_BASE + pathname;

  const doFetch = async () => fetch(url, { headers: baseHeaders() });
  let r = await doFetch();
  if (r.status === 401 && (await doRefresh())) r = await doFetch();

  const text = await r.text();
  let parsed; try { parsed = JSON.parse(text); } catch { parsed = { _raw: text.slice(0, 2000) }; }
  return { status: r.status, body: parsed };
}

export async function egpRequest(method, pathname, body) {
  if (!session.access_token) {
    if (!(await doPasswordLogin())) return { status: 401, body: { error: 'not authenticated' } };
  }
  const url = CONFIG.API_BASE + pathname;
  const m = method.toUpperCase();

  const doFetch = async () => {
    const headers = baseHeaders();
    headers['Content-Type'] = 'application/json';
    if (m !== 'GET') Object.assign(headers, buildHmac(m, url));
    return fetch(url, {
      method: m,
      headers,
      body: body != null ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
    });
  };

  let r = await doFetch();
  if (r.status === 401 && (await doRefresh())) r = await doFetch();

  const text = await r.text();
  let parsed; try { parsed = JSON.parse(text); } catch { parsed = { _raw: text.slice(0, 2000) }; }
  return { status: r.status, body: parsed };
}

export function startRefreshWorker() {
  setInterval(async () => {
    if (!session.isAuthenticated) return;
    const rem = (session.expires_at || 0) - now();
    if (rem <= CONFIG.REFRESH_MARGIN) {
      console.log(`[egp] token expires in ${rem}s → refreshing`);
      if (!(await doRefresh()) && !(await doPasswordLogin())) {
        console.warn('[egp] refresh + login both failed');
      }
    }
  }, CONFIG.REFRESH_CHECK_MS).unref?.();
}

export async function bootstrap() {
  loadSession();
  if (session.refresh_token) {
    console.log('[egp] bootstrapping from stored refresh_token…');
    if (!(await doRefresh())) await doPasswordLogin();
  } else {
    console.log('[egp] no stored session — will log in on first call');
  }
  startRefreshWorker();
}
__EOF_dc0d79b2b551__
cat > "server/egp_session.json" << __EOF_068a9a033a21__
{
  "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IkZFQzk3QzJDRTNFQTQ0QjZCNEMyMEZFMjk0ODk1RkQ0MEIyMDA1MjUiLCJ4NXQiOiJfc2w4TE9QcVJMYTB3Z19pbElsZjFBc2dCU1UiLCJ0eXAiOiJhdCtqd3QifQ.eyJpc3MiOiJodHRwczovL3Byb2R1Y3Rpb24uZWdwLmdvdi5ldC9hdXRoIiwiZXhwIjoxNzkyOTcwMzIwLCJpYXQiOjE3OTI5NjY3MjAsImF1ZCI6ImVycF9hcGkiLCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIG9mZmxpbmVfYWNjZXNzIGVycF9hcGkiLCJqdGkiOiI5ZjNkZDM5YS1hMDFhLTRhNDQtYjg1My01ODgzNjc3M2FiODMiLCJzdWIiOiJhMWZkOWRiNy1kNDQ0LTRkNTAtYjc4OC04OTYzNDlmNDJiOWMiLCJuYW1lIjoibWVzYXlhNDk2QGdtYWlsLmNvbSIsInByZWZlcnJlZF91c2VybmFtZSI6Im1lc2F5YTQ5NkBnbWFpbC5jb20iLCJvaV9wcnN0Ijoic2tvcnViYV9pZGVudGl0eV9hZG1pbiIsIm9pX2F1X2lkIjoiNzA2ZWNjMWYtMjQ3Yi00ODA5LWJkYjYtYjQyMDU2NzEwMzVkIiwiaXNGaXJzdExvZ2luIjpmYWxzZSwiaXNQYXNzd29yZEV4cGlyZWQiOmZhbHNlLCJvcmlnaW4iOiJmZWRlcmFsIiwiaXNGYW5WZXJpZmllZCI6dHJ1ZSwidHdvRmFjdG9yRW5hYmxlZCI6ZmFsc2UsInJlcXVpcmVzTWZhU2V0dXAiOmZhbHNlLCJwcm9maWxlIjp7ImlkIjoiYTFmZDlkYjctZDQ0NC00ZDUwLWI3ODgtODk2MzQ5ZjQyYjljIiwiZW1haWwiOiJtZXNheWE0OTZAZ21haWwuY29tIiwiZmlyc3ROYW1lIjp7ImVuIjoiTUVTQVkifSwibGFzdE5hbWUiOnsiZW4iOiJBQkVCRSJ9fSwib3JnYW5pemF0aW9ucyI6W3siaWQiOiI1Yjg2MWYzYy1lNDY2LTQ0NTMtODk4MC00M2Q4ZGQwNWY1YzciLCJuYW1lIjp7ImFtIjoiIOGImOGIs-GLrSDhiqDhiaDhiaAg4Ymj4YiF4YioIiwiZW4iOiJNRVNBWSBBQkVCRSBCQUhJUkUifSwic2hvcnROYW1lIjp7ImFtIjoiIOGImOGIs-GLrSDhiqDhiaDhiaAg4Ymj4YiF4YioIiwiZW4iOiJNRVNBWSBBQkVCRSBCQUhJUkUifSwicGVyc29ubmVsSWQiOiJjNWZjZmM1Ni00NTM4LTRiZmUtYmEwZC05NDAxMzQyODhhMzMiLCJoYXNCcmFuY2giOmZhbHNlLCJ1bml0cyI6W3siaWQiOiI1Yjg2MWYzYy1lNDY2LTQ0NTMtODk4MC00M2Q4ZGQwNWY1YzciLCJuYW1lIjp7ImFtIjoiIOGImOGIs-GLrSDhiqDhiaDhiaAg4Ymj4YiF4YioIiwiZW4iOiJNRVNBWSBBQkVCRSBCQUhJUkUifSwiaXNBY3RpdmUiOmZhbHNlLCJpc0xlYWYiOnRydWUsImxldmVsIjowLCJvcmdhbml6YXRpb25JZCI6IjViODYxZjNjLWU0NjYtNDQ1My04OTgwLTQzZDhkZDA1ZjVjNyIsInBsYWNlbWVudElkIjoiZTg0NmRkODgtMjBiYi00ZTZjLWI0YjUtZDIwZTgzYjc3NjVlIiwiaXNNYW5hZ2VyIjpmYWxzZSwiaXNEZXRlbGVkIjpmYWxzZSwiaXNCcmFuY2giOmZhbHNlLCJiZWhhdmlvciI6bnVsbCwiYnJhbmNoSWQiOm51bGx9XSwiZ3JvdXBzIjpbXSwibWFuZGF0ZXMiOltdLCJhcHBsaWNhdGlvbnMiOltdLCJwZXJtaXNzaW9ucyI6W119LHsiaWQiOiJkOTcyNWM0NC1lZDA5LTQ2MjEtYTg3YS03Mzk3OTRhNjJkNDciLCJuYW1lIjp7ImFtIjoiIiwiZW4iOiJDdXN0b21lciBPcmdhbml6YXRpb24ifSwic2hvcnROYW1lIjp7ImFtIjoiIiwiZW4iOiJDdXN0b21lciBPcmdhbml6YXRpb24ifSwicGVyc29ubmVsSWQiOiJjYjBkMDc1Zi1iMGE2LTQ4MGMtOWRlYi1lZDU3YWU2MjlhZjAiLCJoYXNCcmFuY2giOmZhbHNlLCJ1bml0cyI6W3siaWQiOiI2YTQyNTg2Zi1jN2Q5LTQ1MTItYjM2OC1jZDU5OGYyOTEzZTciLCJuYW1lIjp7ImFtIjoiIiwiZW4iOiJDdXN0b21lciBTdHJ1Y3R1cmUifSwiaXNBY3RpdmUiOnRydWUsImlzTGVhZiI6dHJ1ZSwibGV2ZWwiOjAsIm9yZ2FuaXphdGlvbklkIjoiZDk3MjVjNDQtZWQwOS00NjIxLWE4N2EtNzM5Nzk0YTYyZDQ3IiwicGxhY2VtZW50SWQiOiJiMTBiZWMyOC03MjA4LTQ5MzAtOTU2Ny1jYzJiOTYyZjVjNjEiLCJpc01hbmFnZXIiOmZhbHNlLCJpc0RldGVsZWQiOmZhbHNlLCJpc0JyYW5jaCI6ZmFsc2UsImJlaGF2aW9yIjpudWxsLCJicmFuY2hJZCI6bnVsbH1dLCJncm91cHMiOltdLCJtYW5kYXRlcyI6W10sImFwcGxpY2F0aW9ucyI6W3siaWQiOiI1YzhjZWExOS00ZDMxLTRlOTAtYmY4OS1lMzY0YmVjMDUwNjYiLCJwbGF0Zm9ybUlkIjoiZTc0Mjk3Y2QtNjIwMS00NTMzLWEyZGUtM2RlOTVmOWYyYzVjIiwia2V5IjoiZWdwLXBvcnRhbCIsIm5hbWUiOnsiYW0iOiIiLCJlbiI6ImVHUCBQb3J0YWwifSwiaXNBY3RpdmUiOnRydWUsInJvbGVzIjpbeyJpZCI6ImQ4NGQxMTQyLTMxYTctNDAzZC1iZjc2LTcxY2ZjYmU5NzhmOSIsImFwcGxpY2F0aW9uSWQiOiI1YzhjZWExOS00ZDMxLTRlOTAtYmY4OS1lMzY0YmVjMDUwNjYiLCJrZXkiOiJjdXN0b21lciIsIm5hbWUiOnsiYW0iOiIiLCJlbiI6IkN1c3RvbWVyIn0sImlzU3lzdGVtQWNjb3VudCI6ZmFsc2UsInR5cGUiOm51bGwsImNvZGUiOiJlZ3AtcG9ydGFsX2N1c3RvbWVyIiwiY2FzdGluZ1ZvdGUiOmZhbHNlfV19XSwicGVybWlzc2lvbnMiOltdfV0sInNlc3Npb24iOiI4YTlmYzllOC0wOTlhLTQxYTYtYTYxYy1iZjFlYjZkYzA0NDQiLCJjbGllbnRfaWQiOiJza29ydWJhX2lkZW50aXR5X2FkbWluIiwib2lfdGtuX2lkIjoiZTAwMDZlOTUtYmFkNi00YWNjLThiOWQtYWMzZDkzMTNmY2VhIn0.SiKyY6M0xJHAFNdB95GaUfga-I6pOnEhoCSI0-ceewMHWhB71Y5cHxpkZJT4ukysB78pVo4g_GKDP6mU0dh14AR_mdBW96llcWAHGnlzngZXFExMX2BRCav5Pq4q0qm-KE-VFlElC15-dDKP9z1KXHcxmWesA1jWVgou-boh8wp_q4eSMOTHrNXGaMebfVPxH4kvByX1Sjr3BS2cRw_taEN08Vh_GhUXAcDqx1cwaEQnhmXeThrkXKhceJammSHSlOBALlYOJaagc856QmQuit2OtJYlKTjAehvbYPdaAuIud30oWmNFu-dnDnjQ7ycRSLl9vmgsq2I9YfxvEy980aoefEsViZWL1kCuHpmwFDJ8WzcLYD6fDxnflTQu-tCwnSij6RMB8164Yzbl1lNc1SKDIhCNeAbd-x58CZqihXe0-L_6_DkcAwnZ7w-pJ3iWISnlcpa8lzCXVl0YAgf2WTz1FG_g8mlm48dx2lFxO1KeMUKVQs4ZjxCPqrraLchm71MLXY7osVJ1-cSQTlx_4061KriSpxs6wJoT4KHUAXd7J0lzCynyuzPx6x9HsOofrASB13LUctRQUjbwJ12vJipyYBC0FZQebjOIq-hjGOSIIggCGlrMcGxtK5Tp1962Ct8_qvpyBETFoy7x2jMrLOw09o6Z9FV-5Duk3-5XBYg",
  "refresh_token": "eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZDQkMtSFM1MTIiLCJraWQiOiIzQzkyMjNFQzcwNjVFOUMwNTJCNUVDQkE5QjVDN0I5QjdGMEJGMUM2IiwidHlwIjoib2lfcmVmdCtqd3QiLCJjdHkiOiJKV1QifQ.uKjhZCFl9ZCfMUTEY7zPzDmh3ggPbiWxeBvMtfYB1aqaoZ05XsulKUzgCrpb-K0llaUqPS7Hp-nbW14ZUBj5PcuePptQnQfq7s9L9EpnqRzn_Zq2DXppCQxmsMqcMcnabulGABxRtbylQL7eV-B3Fmq5rppn14IA4pkl2MtOE4CRSy3qMUwIoLT-T2iE2LPVBRv0RUN3njiQO0pXs9Pk0PqWV63Cyr9Aur-eEDNRsev8fB0jaoKXLz8akG7vDUgTmZMwNOtf7APy4lhTW1g-WfLZwDayj6tM_Id5_Rh54o6AnDoU-PPYYqLzhf6QRX1XGgvS8de5NSh_gXMxIOT8WbfATp1c33611vAaGGK6G3i0QORWYak1GazNxgS2ULdOOAHCfbJWfmefxnnd2r_sXQ1t4PYV5hYjnvxPJMgvfpTIx8hwSQ7OYN7HXRSL3gLC-pOMnsY3uPVyNGwhi0QtDOSfC4IZlwtOzqDcBn6g2IJbse7ND3UetlNAXOYq0Wvz9HhTK5RJzfa9avejN786phiHn_5-y3ZW9dyBsrCWCg-ujNbrSLNK3Ixsf-als7NMo6bpgPDfqbtqay_mcVKNS-cwVBAleTayz_MkhdJBvn2O_ILXo50dueyQF8P6zrsmAeSu10bQd7zaePYfkq_-wdn-mzfLSdPUGJ7yLZHcmsA.dPrlqYH77syeT_FZSy6ogA.oXjDdTyZ8Y0GFWCy7INICBw0fjA4Izhrvvx37pWAKVmh0r75EP2k6Q75wPN7RnJl3PGyXqL_2WUH1BENkWiL4T4k2pfw7tamqhUwL9hdVwa3n8QBaVpHYjckfUAU4xVA3QS_YhA8F23TFyF7-VcfV-2TTCCl1I6XH-Fyt63vnEX8_XdLgU6YXd4GuCE2bkGubvhrh771M1688QmBTgiTmNk-euFz4Yj0ULUYXPthVv7Z13m2DMrWgDhLqpjepvnxPrrZ1Km6E3zlP0JfLAtLV09-rLs1u3IPEDj8SfiBiOnQXPRp7KOaLN7jw7gvX1UkPqGLPu4ziAD5UjZJpkv1bUDneR90pc5Dv6TgA1ki-vlN-d452kXIO3pqJPdu_wQEqlnM10zymi93sv9jeOedxScbPsS2zAnFcb7p9vvILsJ9t_wrXL6yragFu1A2Cz8t2aItJgIQCYXj-kRASsVL7fnHid_FqzGMnhWQNBIwXfBn_15ncgsTU7-eUhBMo0GEpVvf5NXnMz2i9GYxIqfK0NiWVyvUo8hUSM4WH0PeXZwy4JeGE2UNto_bnV7fgOFTu5G4u6FM6ft34LKL9aS7A_DKzMk_zx0SFcPZdbCzAcuYmAtKqbjSdKH1h10-6JkF9g7Ke36SIOyPl-tNNHT25NbyNz3BXLRlCbfdHoyfLwQMOKowDlqgmQ3dJ93hlcXMSOq__iNiIoONtmgRLj3NYBdWdMBv2OIovaX6uIYfZDsr36zL8stkd4hdvOoYfsOchOl7OkK9nUP2EpijxOxAOJUgkVdr9tZ4-pg84JjmyPN-SZanCN23lH5vYjSoyIQhZ1Wce5KWwczfJadpj349KKO8hL1OBHvOBiuet2r5slm_e66tjcNDKp6EwWjeeKQBmFPyi-v5vxBsWwpHSAdGhrOlfXFL0ZMRgqMZmYVY84VCouDk2Vg_36LZE_vtqKn0SlFI163kfzEvChLunWK14gTX-VrBtHrBuQYF2UF0qMGS75j_EJlhhp-Yui7yBVuREv989AEVOETp8AMsI5eYPpzSu0aGLshm2xRyIjg5TtSsPRebCs4ykjbOTx521ICkTCbKCQ7-R8BXDFJzGPVBKAkVDo4sxmb3vONjBLAVyYUWNfHosk8mKT3MgfhKqHM1QEMyFyv7auyuXpnsjOZDUh9ka3G3iS1BoIL1B_iejXdbzLnqHYvbPhre29giufzoA_N0TqH_WzDUejetKUhZSvvi1CL70X5E6YrWus-_8jbtG5Oxfz_hkliNtYzVpqra6xZv7QKmWT9cbGy2vGLbuUmweElI8KIB_hPL-nrPFw6Z6G2xFST45zhCVlvPfc_BuTTWHUBurrozVQ-yO-_PomeVjd_ZMUs4-4GJbrzNH8fYcB4GPnrHnxKQMt1Tvj4OI5ydnA6qVRnWqB2AIOhHbybhAToxjzW7NCxWZzqYO6Elv0aHoDxrq1XbcNUK3zUUzxMWiZ-9gTV0qCn86j5LGFTxm2E0gQAnKNupubb7XUNEh2eVx3IjUya-wrPDGh-EY1eY2aiONAmwG27gl6kn87P4-rBskHFXmtHIU4bcs6n1Kw0LIkRSUl4YOSlkhj5NS5R1BAB1dW53FvGGhxxoQx-6dIAGON9m3k7dNJUerDzFI-RyCZ1O3jzRNuHEuPeCnsoWgdxI2dc90A-ditjq_h8WZjNNPKgRemXPVr83K1GoPoMrUWOCPjmNloiNhyXVyTNSlEOcNlOuomv_upsamQznrg8DCtTrwT1ay34631V6EQW_WH3A3gOwUK8EQ6dCvQeJ58fUbFm_vndDVLpyt2wh5Mjl8J0VmKoMjMIon0QPwVqKuMtrJe1BmPHLS0X8Pf9r7Ui0MMMN3PHXOkIwcZkVPu_9sJdVgCqclnO-k4u3kTph4EW4GnKcxBsVjHW3DdZT8h0rRfCbgTgpW_gdtElMj2mU2cfDNge8UQxpzKq_FaTOEpmCDL3Ol4jLSIuzPIWaUmezJKsxEoWrNB10ZI52zpq6QvGKWN4OdZzc0L4LJYRRfjf2QYQXgueOFmgo2VSjbgZy4wEbhUWz7EG808dNiT8OovfZMZIEp_R056rb_sQobkF9Z1kS835Efj6_KFI3DnpzCGwktUZD1toKxFJH_8exQmRgiR2mWX-OBBGSLVlknKy6moLi5owtdHfcpqHqLhwPvA75i9zmLfk7kP0h_FgEbS0gfqiGvUUEw44OXayvexwuUPSp3SIQ5IoIbN73kXJvvWOAlB959n8znF775y8FT9nTb47V5fHEIDXSeCdpY6UXnmbcgtJFh5MAjdn_wx5JDPT2xTyvOf7KV6HDItgTYDVW23i73NuFvRmSCAiRbMopAHVa0bYhWsGuLgFpcCY357fhoEWaA2hVTwKK8V_6i9Gefiutj-iWyJjolyY_BVvpWR1NFhfxfX-8WrbQgwR9UVwF1-cXLx_0aQLlg3w26qxcI-pd9gRuuIjUbEOYIkWrDySfr0BAvXaxDdM_N3OpF1rfTmIDcFlsKliuwGUdN6HEB8l2nsp8oTAL7nRgUCRCPnlF-2FDR0V8BjQHRSvIe_balqNKxZvdOIwbdZVbJ5NI-2c8ii1DylvtTgs7vUKobr3ohUMiA4FfHdVq4OwEXBLkKk6cn9bX9qFvZ8BVv2qJV1tsrPNmy4Ad02-xL9W6HBdQwibUPc-_WS7faPkHKpXVPDjssS5EyOUkGVoj1ERQtRYPVXhyLb9RSoFQmP4Cr9M_Q1zDYYUjGMxDfhz4S8DznVg3c7-uoolLzUhI_GBdM3vF_NUGDf2FmdQUcXwaIvU4Y-HkIlAOOggcGwCHPMg1eix0kb6B8viU7yqH1OASXWqFUjDAYApUFpwoOle_bw11-UgfPQIz5B_g8uULFy3eRuX87_3BBT3UtugSMPU3s0Z1u3DyZ8uutzAwtNA8I8WU9MabByDzkZat1ImrOoTbFG_eFSyBI6g3tq0FHpQQp-2k9L7iioA7U56BwVyIJ_rrP4A7zSu7AKoPPhQruM7r8EEgk-pT8hqF6NvdcNXjKp9waeh0mvXm8bXiYmlUZfFwjRG2B6RjQ4Jx3tY9JYvSmkNzl5Q0wgCOtoTq7HjPmRfuxpkoNJN9Grj2jtQ0ehY_F1JE_2Z1zFlI6lmO0PjBcIrxgQjSg0D5uBUDsix6rGJ5iAEIfQI3uNCpTCgCeK1pDIS6MmXOwS_yus3bvC69rWNa5pX-SOHffLEnWAwU61QSDDdBFvdfsNOtJUjWxIPig1WVIOxf865eql8KCqwNgkhAjoSSSSOX0P6G_DwvnLl79gMbG752eqYQcmmSg3yLImwDF5dlz4OktE8lxii_YjyFT3PxgPtcSNi2qk-CyIsNp8qQld9i2HAwuGC2cb4-NtDUPAwNyFAdPpxze3hp8EBHY5ma0q3MxqurpTG9rfTfbrM61Gt_Xvud1xZCSZ2T8uOF6b-oWV_r1Esuyw9c4Y01q1y6t187YQc5_bTNUKJWAr3vahHWjsTEsvBpyGS7GoeAEgnhNTyyUYLxJzni8c4V8ipPnZnuDfkHpg8xlTELweCUnjxryohZS0LMZRPIWser6cwH50yI5OqJz0MvE-99cYd5HB0wVLYolW9OoEP0tEOXL4i8NzVLmJgAvntdzEaV4hvcj_yK8qKsz1VOP2211fvyD5seOQdnNQrboB5jwSrGJEUPCxyR5l1V9Rpd8NrYVeLfE1ce_F8iVow1i-1CYcsY2fLNA2lnxaVtKdoPmTYnPWu-uDzXVGgeIqzLU1mMcjR3UpoUxDRaRGaX0TBYVcJv0uP-1Ny3Ee-5q99Hv_7-aQXj8qGzG6MLLrV68jxuNW6JqLH8sxjIoV0gn6cbVi1CaVPvUs1AsPlNxCFMubj6lSWmjLRSJPUYQdyk6V5ocfXxMP7J4HQ2IYShmsDLJQ0wefXwiZcGsz8ztScFbp2aRlFKGmFpEQEpNel6xSC1pbN_oRdvnIIYrTvg8Xg-ejkM2uLXJ3Vj2yUU5_o43CreyardcEl4vdu13Tj2OhkrTeim3V21NLBDrKJue17quu9dLcbV5HSj8z6bNF56Wmh9a_Pk0Ehne3hamUK922QN0dgmHpWk1jCVn6Ih2YnyEQvtfFDKt1V9ZvvgSrXjPBhjeZR8z3X6R7BGxfQE5jlzFGZ8PkbDU2MwixMiGrrT19_TvahkW6bx1rBOa5YxoBECyrtRggf-S6I5xed3_kHPsjoqqQQATNCSCnuRaE4M6fh3r822kDdMDL1dKzDLFa29KUo6Jk34lBj3P2r1lv3Ykja4SWPyRvU27JvsWpEloi89Ny5nABk2ap31FfpIAb94Vqjrp0ic5hfdPLMlTKsmXge7HTabjHvkiViEbW4kqJVf0PKZx1uEYsoBdyVFSImZqxEmk4N0BANbC0JTMHoN8KlmKyyBYeXEqiST6iBJ0cB3GdOPzHsRDOEtmgeHEHoE5d-CG6gsVbm7-MAGGnS1Ir9_SGm7UgVqoJ6XGvatKyQe-7328iLe-ZVrbsnTJFvi5pl5P4dzFR63W-GF3GGQlwgMughCLir7wTMt9IWHtICgu5UvSeLq5eau9McOdWjyfkHar_z0zGB2wPjbLDBTjaguAQDO8GQKwzrhkmfBTz5SFEiBtjgWJ7v8Iqr7SqyBOy_bRkbvXFFkcTVZCKD8fbKsGXbtX7vubsTfrx2cD4_1s3UxD7wDCtAgdX7QRUa_6w98kB5dHVdNn0VZRHy8cj-nl_mL2169_oW2-6iVfGsylIzJATFOPKvuCMtT9SZOVJEu5a7iLfGMpxQeZDjib6ykXWEZO2WnppKHTRhCtJwgs8ft_LwdynrWjn25JvZkzRuthS6g3TwEJiWzNiw8rBZ7kE9uYHFZVgmAbrgOtjHRcW9CXG8BBiBkVxEWGTE9Hb3k6fayIzENX4yoFh50hYSa-1oOn1MycJfMssGjCvBVE1zyv0QqBu8XY719VZqeYodVVfHrM2lzz2pdb9pxWC49Z4LTuN2xewFEWXBiMOTh96N8v4g_YCIdGKI2bIf9tBKGNw71Qc7LQrke2yWB5h9GOCfGeVXrrQh53lFfndgDA14-cK1PbmlXiIExLRrKdkZUi_B3W22oJKclxGOkx5ZDe4-krRQDkRlZONDHHSGcQ3ZqxfUn7Rkh5bdpKRR17_QMWW6MS6ixgECs7tfh458RZlVG-WlYZ5CPE1S8wxkV0Ag8pVmuqQhGhuoLfkMQWIy5RqP3oaLMp13kvr14GIuxxe2etnSKUxV7HtgEz6nPJKLSCSSLB8UcCZ3XEG7UsWQMACS7lufb1DtQZKVhVxznehedTHTSgZwTWEtvNGKRqwJRaGg2zEnEDXuKfgfYoO9gGtzRoJrR9uvPACf5P5AYTIIvuZwaIien5nfhshjuz4b-WtjEtc2Z2BYSXxYq4u5G7dDEEXpo5ZStyt3sr_GfLJQV-JN7o92c144j_XGL0h-Xlkd5CUrRt0pl6Ve0ZN0fzak6WZb9u3C5GYkd1HgkLgR56yVyuACFg9e3o5MmaXLgB2-4Eh48jEitxbC2c-zShVNEGUz-VWloXVuoKSHr1dG81dGNZ7C9t7efoXvbKYm4IMeTlka-ao-tfVFDDBgTV8ej9gBq5BIKapizHH8-AjYduddSmwd2ZJtM7v0v8Dgxfb8j2__z1RLuXe9nkUjI0Yw_46F2d_QPH7tdx_Xi7JJ529MXt34uauBje79xqymYoKmRJPcFED3iLkBRGw8IQMdIMxZtHG1QYXM4_ZlX3-mgJh2Gd9e61EuGCr5MynNr3S3PuWd1-UobiPpOFul2__IqA5G4YUIEWnL43QP1XytcKzuf65ZBNu4kRY8M85e9VHX9yVR-0obMmfdOsv9_HnwvJ9AgANHJeWCj04vyyya9LTS3yrfaa8-f3ppEx3IL_Po2kZQ9UWRc8285BeiXC8BfwJIBnPL52aoyPxekchfV3hZ_boeiBGtYJCL-WZbetijHqSFgzJWPmdeLYmBNUxVaNf9zv4cIlyQVy0X37FDOx3MC-xPYcwmJJXqWtWPkHiKbpERDUg1vr97ugGFt79BNCa9LPQex9CoxDdJtKFaOWn8_l9aCUfebl9pMCFVZ_3AOLrxWS3Y3dtOkaGpZflNXu_fNHWFdNeo3_oRXU9_eA6gdCkgDl7QxwzPnVC4z_FY0mlqEEf70kavrDfhCFoL8vHRl4rOWgU7kbs5GXoJkS4HFtA0NX3gHB0HncYmnKnMnz2GACVGAEgv1u1rGnp2M7c4oNbFVitn7UHgO3EwyoRJCrI8jN8Cy1pPwra96i_KwjAniIib0KhMQIElR6QOCuc4kWgshaFVM2-F0fJqHmpX6i2nviiOQ1izX1MS16R74CBchGjvGznAAlqgQ-1LlELLAtR0JWkYbBXWVJir_4Jfmf1gceZOFcC2V2YfGeq9gKqzjr4L6HPiqBKGjkS-xlkzpS5CWoouNfHE5AwObuZXwb0PN_BASwvS6loQAOLewhqCB0kLjEcYPKWSwqRyskKaG55x4tzoToY4agasXz6D223EooyE8FyBjXc8hcZwDuu8xU6BBo0fH2alQjrKWyHJQ4aK2UT8qPLSLZeumoXWGLsfr_LGGqMqLng1Gw6bwyyngG62O5Mov6OUijlN4YIJ1AbzEcAPzdATmkpXn63qCf74vhQtbUDa3e7U-3vn8WDX6MUWGdAEE3kslUnQsZYqUETo1fRAYOf_deN4OUYuGPxWVFholTfERpEFuHR__xQNwnDpRz2vna2zN7EkEwN3cRxIaluDqIPYLTljOMOgqIbKUUC5tgfEiyNuIp9Fg12ng6LGdDPF_3mTrO8uWLgnSsh0FX1flocBzynPRubgw7hihwSfaZ3DBgRsn4epUpP1EiynK_m0gZCy_65YuTlp6kzUQu75hXbOD.tFddowCBgvJLJ7uHJKb7YNhSiUn68-z8hkmfi27h8uE",
  "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IkZFQzk3QzJDRTNFQTQ0QjZCNEMyMEZFMjk0ODk1RkQ0MEIyMDA1MjUiLCJ4NXQiOiJfc2w4TE9QcVJMYTB3Z19pbElsZjFBc2dCU1UiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3Byb2R1Y3Rpb24uZWdwLmdvdi5ldC9hdXRoIiwiZXhwIjoxNzkyOTY3OTIwLCJpYXQiOjE3OTI5NjY3MjAsImF1ZCI6InNrb3J1YmFfaWRlbnRpdHlfYWRtaW4iLCJzdWIiOiJhMWZkOWRiNy1kNDQ0LTRkNTAtYjc4OC04OTYzNDlmNDJiOWMiLCJuYW1lIjoibWVzYXlhNDk2QGdtYWlsLmNvbSIsInByZWZlcnJlZF91c2VybmFtZSI6Im1lc2F5YTQ5NkBnbWFpbC5jb20iLCJvaV9hdV9pZCI6IjcwNmVjYzFmLTI0N2ItNDgwOS1iZGI2LWI0MjA1NjcxMDM1ZCIsImlzRmlyc3RMb2dpbiI6ZmFsc2UsImlzUGFzc3dvcmRFeHBpcmVkIjpmYWxzZSwib3JpZ2luIjoiZmVkZXJhbCIsImlzRmFuVmVyaWZpZWQiOnRydWUsInR3b0ZhY3RvckVuYWJsZWQiOmZhbHNlLCJyZXF1aXJlc01mYVNldHVwIjpmYWxzZSwicHJvZmlsZSI6eyJpZCI6ImExZmQ5ZGI3LWQ0NDQtNGQ1MC1iNzg4LTg5NjM0OWY0MmI5YyIsImVtYWlsIjoibWVzYXlhNDk2QGdtYWlsLmNvbSIsImZpcnN0TmFtZSI6eyJlbiI6Ik1FU0FZIn0sImxhc3ROYW1lIjp7ImVuIjoiQUJFQkUifX0sIm9yZ2FuaXphdGlvbnMiOlt7ImlkIjoiNWI4NjFmM2MtZTQ2Ni00NDUzLTg5ODAtNDNkOGRkMDVmNWM3IiwibmFtZSI6eyJhbSI6IiDhiJjhiLPhi60g4Yqg4Ymg4YmgIOGJo-GIheGIqCIsImVuIjoiTUVTQVkgQUJFQkUgQkFISVJFIn0sInNob3J0TmFtZSI6eyJhbSI6IiDhiJjhiLPhi60g4Yqg4Ymg4YmgIOGJo-GIheGIqCIsImVuIjoiTUVTQVkgQUJFQkUgQkFISVJFIn0sInBlcnNvbm5lbElkIjoiYzVmY2ZjNTYtNDUzOC00YmZlLWJhMGQtOTQwMTM0Mjg4YTMzIiwiaGFzQnJhbmNoIjpmYWxzZSwidW5pdHMiOlt7ImlkIjoiNWI4NjFmM2MtZTQ2Ni00NDUzLTg5ODAtNDNkOGRkMDVmNWM3IiwibmFtZSI6eyJhbSI6IiDhiJjhiLPhi60g4Yqg4Ymg4YmgIOGJo-GIheGIqCIsImVuIjoiTUVTQVkgQUJFQkUgQkFISVJFIn0sImlzQWN0aXZlIjpmYWxzZSwiaXNMZWFmIjp0cnVlLCJsZXZlbCI6MCwib3JnYW5pemF0aW9uSWQiOiI1Yjg2MWYzYy1lNDY2LTQ0NTMtODk4MC00M2Q4ZGQwNWY1YzciLCJwbGFjZW1lbnRJZCI6ImU4NDZkZDg4LTIwYmItNGU2Yy1iNGI1LWQyMGU4M2I3NzY1ZSIsImlzTWFuYWdlciI6ZmFsc2UsImlzRGV0ZWxlZCI6ZmFsc2UsImlzQnJhbmNoIjpmYWxzZSwiYmVoYXZpb3IiOm51bGwsImJyYW5jaElkIjpudWxsfV0sImdyb3VwcyI6W10sIm1hbmRhdGVzIjpbXSwiYXBwbGljYXRpb25zIjpbXSwicGVybWlzc2lvbnMiOltdfSx7ImlkIjoiZDk3MjVjNDQtZWQwOS00NjIxLWE4N2EtNzM5Nzk0YTYyZDQ3IiwibmFtZSI6eyJhbSI6IiIsImVuIjoiQ3VzdG9tZXIgT3JnYW5pemF0aW9uIn0sInNob3J0TmFtZSI6eyJhbSI6IiIsImVuIjoiQ3VzdG9tZXIgT3JnYW5pemF0aW9uIn0sInBlcnNvbm5lbElkIjoiY2IwZDA3NWYtYjBhNi00ODBjLTlkZWItZWQ1N2FlNjI5YWYwIiwiaGFzQnJhbmNoIjpmYWxzZSwidW5pdHMiOlt7ImlkIjoiNmE0MjU4NmYtYzdkOS00NTEyLWIzNjgtY2Q1OThmMjkxM2U3IiwibmFtZSI6eyJhbSI6IiIsImVuIjoiQ3VzdG9tZXIgU3RydWN0dXJlIn0sImlzQWN0aXZlIjp0cnVlLCJpc0xlYWYiOnRydWUsImxldmVsIjowLCJvcmdhbml6YXRpb25JZCI6ImQ5NzI1YzQ0LWVkMDktNDYyMS1hODdhLTczOTc5NGE2MmQ0NyIsInBsYWNlbWVudElkIjoiYjEwYmVjMjgtNzIwOC00OTMwLTk1NjctY2MyYjk2MmY1YzYxIiwiaXNNYW5hZ2VyIjpmYWxzZSwiaXNEZXRlbGVkIjpmYWxzZSwiaXNCcmFuY2giOmZhbHNlLCJiZWhhdmlvciI6bnVsbCwiYnJhbmNoSWQiOm51bGx9XSwiZ3JvdXBzIjpbXSwibWFuZGF0ZXMiOltdLCJhcHBsaWNhdGlvbnMiOlt7ImlkIjoiNWM4Y2VhMTktNGQzMS00ZTkwLWJmODktZTM2NGJlYzA1MDY2IiwicGxhdGZvcm1JZCI6ImU3NDI5N2NkLTYyMDEtNDUzMy1hMmRlLTNkZTk1ZjlmMmM1YyIsImtleSI6ImVncC1wb3J0YWwiLCJuYW1lIjp7ImFtIjoiIiwiZW4iOiJlR1AgUG9ydGFsIn0sImlzQWN0aXZlIjp0cnVlLCJyb2xlcyI6W3siaWQiOiJkODRkMTE0Mi0zMWE3LTQwM2QtYmY3Ni03MWNmY2JlOTc4ZjkiLCJhcHBsaWNhdGlvbklkIjoiNWM4Y2VhMTktNGQzMS00ZTkwLWJmODktZTM2NGJlYzA1MDY2Iiwia2V5IjoiY3VzdG9tZXIiLCJuYW1lIjp7ImFtIjoiIiwiZW4iOiJDdXN0b21lciJ9LCJpc1N5c3RlbUFjY291bnQiOmZhbHNlLCJ0eXBlIjpudWxsLCJjb2RlIjoiZWdwLXBvcnRhbF9jdXN0b21lciIsImNhc3RpbmdWb3RlIjpmYWxzZX1dfV0sInBlcm1pc3Npb25zIjpbXX1dLCJhenAiOiJza29ydWJhX2lkZW50aXR5X2FkbWluIiwiYXRfaGFzaCI6IldSdzAtdVFpZ05zWURLZTJ2TFhfVHciLCJvaV90a25faWQiOiI4Y2E2MWJkMi1jOTFhLTRkNmMtOTc0My1lZDQxNzNiZjEzNmUifQ.NSFZ1_Iw2DSj0GMTVHjYWc2hSv8D63r6W5_fy3A7OYNTIjZSkm5Cvr4_5MoyWywSZjMmlx4_s9QvK0XyaF_toEsogvDLCkB2Bb2Nz7atg87sAd1zm1ou4wzs3peTicCO8bSe4yJsSLuY6skT187yqic4peEzyEdHHZOra_O0Yaok7WcIXj_s7mWQ99CGcc-GgWgu645j1TH1lORG7U-IkoWVOUXjrWNBdsummQnYH-Wl7FFpqZ-S_ohD2mPgu87uQv1pKq8F8V6wZImnSIGChDM5UbMW4pc1Klr6Ll-9o1MRxtahsabyzXDcGDAIFr98vkfeF0a4O0MugJ3geo5L6OywxLlvjKMCdeRT5b1NlfCoElWkbOXD604CIYcxgafL91VKIgmnhwEVyRriYIgQAY0afumDb3TgehZ6xoQ2LTfUtN1qwT8Kh9df0gbCua-Ibm9tXeNhIVNiYgqq4VLjrMrLs0LJ8RxG-3sAmKb0BYfp68ikfTVj0KMC4EmJ3uh8q2dkjlQ1L7mkyrMqiDHKgfzDwV_pL9LGmClsmFcvJKQI6ZQhqFPvlxYH9ZUMfN8rhL-J_ClaHGd00wAimfZXZjO8fQMCDhkvwrN_rFUYpehlY7HRKzLlsvwfacW_59fLF_PYKbS0eJlikNiBpeJRSiTc7_2mnLpUQi2LMK6Viz4",
  "token_type": "Bearer",
  "expires_in": 3600,
  "expires_at": 1792970320,
  "profile": {
    "sub": "a1fd9db7-d444-4d50-b788-896349f42b9c",
    "name": "mesaya496@gmail.com",
    "email": "mesaya496@gmail.com",
    "firstName": "MESAY",
    "lastName": "ABEBE"
  },
  "org": null,
  "isAuthenticated": true,
  "capturedAt": "2026-10-23T21:54:52.921Z",
  "lastRefresh": "2026-10-25T22:18:40.515Z",
  "refreshCount": 41
}
__EOF_068a9a033a21__
cat > "server/index.js" << __EOF_0861d6d6b50d__
import './lib/env.js';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { requireDb } from './middleware/auth.js';
import quotes from './routes/quotes.js';
import proformas from './routes/proformas.js';
import projects from './routes/projects.js';
import reviews from './routes/reviews.js';
import business from './routes/business.js';
import uploads from './routes/uploads.js';
import egp from './routes/egp.js';
import { bootstrap as egpBootstrap } from './egpAuth.js';

// Global safety nets: a failed eGP request must never kill the API
process.on('unhandledRejection', (err) => {
  console.error('[api] unhandled rejection:', err?.message || err);
});
process.on('uncaughtException', (err) => {
  console.error('[api] uncaught exception:', err?.message || err);
});

const app = express();
const PORT = process.env.PORT || 3001;
const origins = (process.env.CORS_ORIGIN || 'http://localhost:5173').split(',').map(s => s.trim()).filter(Boolean);

app.use(helmet());
app.use(cors({ origin: origins, credentials: true }));
app.use(morgan('dev'));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (req, res) => res.json({ ok: true }));

// eGP routes mount BEFORE requireDb so they skip DB auth middleware
app.use('/api/egp', egp);

app.use('/api', requireDb);
app.use('/api/quotes', quotes);
app.use('/api/proformas', proformas);
app.use('/api/projects', projects);
app.use('/api/reviews', reviews);
app.use('/api/business', business);
app.use('/api/uploads', uploads);

app.use('/api', (req, res) => res.status(404).json({ error: 'Not found.' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[api] route error:', err?.message || err);
  if (res.headersSent) return next(err);
  res.status(500).json({ error: 'Server error: ' + (err?.message || 'unknown') });
});

egpBootstrap().then(() => {
  app.listen(PORT, () => console.log('API listening on http://localhost:' + PORT));
}).catch((e) => {
  console.error('[api] bootstrap failed:', e?.message || e);
  // Still start the server — eGP will log in on first call
  app.listen(PORT, () => console.log('API listening on http://localhost:' + PORT));
});
__EOF_0861d6d6b50d__
cat > "server/index.js (2)" << __EOF_acddde83313d__
import './lib/env.js';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { requireDb } from './middleware/auth.js';
import quotes from './routes/quotes.js';
import proformas from './routes/proformas.js';
import projects from './routes/projects.js';
import reviews from './routes/reviews.js';
import business from './routes/business.js';
import uploads from './routes/uploads.js';

const app = express();
const PORT = process.env.PORT || 3001;
const origins = (process.env.CORS_ORIGIN || 'http://localhost:5173').split(',').map(s => s.trim()).filter(Boolean);

app.use(helmet());
app.use(cors({ origin: origins, credentials: true }));
app.use(morgan('dev'));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (req, res) => res.json({ ok: true }));

app.use('/api', requireDb);
app.use('/api/quotes', quotes);
app.use('/api/proformas', proformas);
app.use('/api/projects', projects);
app.use('/api/reviews', reviews);
app.use('/api/business', business);
app.use('/api/uploads', uploads);

app.use('/api', (req, res) => res.status(404).json({ error: 'Not found.' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Server error.' });
});

app.listen(PORT, () => console.log('API listening on http://localhost:' + PORT));
__EOF_acddde83313d__
cat > "server/index.js (3)" << __EOF_6660caba7ee3__
import './lib/env.js';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { requireDb } from './middleware/auth.js';
import quotes from './routes/quotes.js';
import proformas from './routes/proformas.js';
import projects from './routes/projects.js';
import reviews from './routes/reviews.js';
import business from './routes/business.js';
import uploads from './routes/uploads.js';
import egp from './routes/egp.js';
import { bootstrap as egpBootstrap } from './egpAuth.js';

const app = express();
const PORT = process.env.PORT || 3001;
const origins = (process.env.CORS_ORIGIN || 'http://localhost:5173').split(',').map(s => s.trim()).filter(Boolean);

app.use(helmet());
app.use(cors({ origin: origins, credentials: true }));
app.use(morgan('dev'));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (req, res) => res.json({ ok: true }));

// eGP routes mount BEFORE requireDb — they talk to eGP, not your DB
app.use('/api/egp', egp);

app.use('/api', requireDb);
app.use('/api/quotes', quotes);
app.use('/api/proformas', proformas);
app.use('/api/projects', projects);
app.use('/api/reviews', reviews);
app.use('/api/business', business);
app.use('/api/uploads', uploads);

app.use('/api', (req, res) => res.status(404).json({ error: 'Not found.' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Server error.' });
});

egpBootstrap().then(() => {
  app.listen(PORT, () => console.log('API listening on http://localhost:' + PORT));
});
__EOF_6660caba7ee3__
cat > "server/lib/env.js" << __EOF_8a8811b03773__
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const here = path.dirname(fileURLToPath(import.meta.url));
// Single .env at the project root (shared with Vite, which only exposes VITE_ keys to the browser)
dotenv.config({ path: path.resolve(here, '../../.env') });
__EOF_8a8811b03773__
cat > "server/lib/supabase.js" << __EOF_ffb8204d1b29__
import './env.js';
import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  console.warn('[server] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are missing in .env. API routes will answer 503.');
}

// Service role key: bypasses RLS. Server only, never ship it to the browser.
export const supabaseAdmin = url && serviceKey
  ? createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } })
  : null;
__EOF_ffb8204d1b29__
cat > "server/middleware/auth.js" << __EOF_48fa68c18a48__
import { supabaseAdmin } from '../lib/supabase.js';

// Wrap async handlers so errors reach the error middleware
export const ah = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

export function requireDb(req, res, next) {
  if (!supabaseAdmin) return res.status(503).json({ error: 'Supabase is not configured on the server.' });
  next();
}

async function userFromRequest(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return null;
  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data || !data.user) return null;
  return data.user;
}

export async function isAdmin(userId) {
  const { data } = await supabaseAdmin.from('admin_users').select('user_id').eq('user_id', userId).maybeSingle();
  return !!data;
}

export const requireUser = ah(async (req, res, next) => {
  const user = await userFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Sign in required.' });
  req.user = user;
  next();
});

export const requireAdmin = ah(async (req, res, next) => {
  const user = await userFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Sign in required.' });
  if (!(await isAdmin(user.id))) return res.status(403).json({ error: 'Not authorized.' });
  req.user = user;
  next();
});

export function pick(obj, keys) {
  const out = {};
  keys.forEach(k => { if (obj && obj[k] !== undefined) out[k] = obj[k]; });
  return out;
}
__EOF_48fa68c18a48__
cat > "server/routes/business.js" << __EOF_670b012d9548__
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin } from '../middleware/auth.js';

const router = Router();

// Public
router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('business_info').select('data').eq('id', 1).maybeSingle();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data ? data.data : {});
}));

// Admin: replace the single business_info row
router.put('/', requireAdmin, ah(async (req, res) => {
  const row = { id: 1, data: req.body || {}, updated_at: new Date().toISOString() };
  const { data, error } = await supabaseAdmin.from('business_info').upsert(row).select('data').single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data.data);
}));

export default router;
__EOF_670b012d9548__
cat > "server/routes/egp.js" << __EOF_a4c1114a9608__
import { Router } from 'express';
import {
  doPasswordLogin, doRefresh, status, egpGet, egpRequest,
} from '../egpAuth.js';

const r = Router();

// ---- Auth ----
r.post('/login',   async (_req, res) => res.json({ success: await doPasswordLogin(), ...status() }));
r.post('/refresh', async (_req, res) => res.json({ success: await doRefresh(), ...status() }));
r.get ('/status',  (_req, res) => res.json(status()));

// ---- Tender list ----
r.get('/tenders', async (req, res) => {
  const qs = req.originalUrl.split('?')[1] || '';
  const p = '/po-gw/cms-v2/api/sourcing/get-grouped-sourcing' + (qs ? '?' + qs : '');
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Tender detail ----
r.get('/tender/:id', async (req, res) => {
  const { id } = req.params;
  const source = String(req.query.source || '').toLowerCase();
  const p = source === 'purchasing'
    ? `/po-gw/federal/purchasing/api/quotation-invitations/get-quotation-invitation/${id}`
    : `/po-gw/cms-v2/api/sourcing/get-lot/${id}`;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Tender-level items ----
r.get('/tender/:quotationRequestId/items', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-requests/get-quotation-request-items-by-quotation-request-id/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Response-level items (has responseItemId) ----
r.get('/tender/:responseId/response-items', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-request-responses/get-quotation-request-response-items-v2'
          + '?quatationRequestResponseId=' + encodeURIComponent(req.params.responseId);
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Schedule of requirements per lotItemId ----
r.get('/schedule/:lotItemId', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-requests/get-schedule-of-requirement-by-quotation-request-id-v2/'
          + req.params.lotItemId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Registered response ----
r.get('/tender/:quotationRequestId/response', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-request-responses/get-public-quotation-request-response-v2/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Register ----
r.post('/register', async (req, res) => {
  const { quotationRequestId, quotationRequestName } = req.body || {};
  if (!quotationRequestId || !quotationRequestName) {
    return res.status(400).json({ error: 'quotationRequestId + quotationRequestName required' });
  }
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-registrations/create-quotation-request-registration',
    { quatationRequestId: quotationRequestId, quatationRequestName: quotationRequestName }
  );
  res.status(s).json(body);
});

// ---- Push ONE price (financial offer) ----
// The client sends the full payload that eGP's own UI sends.
r.post('/push-price-one', async (req, res) => {
  const p = req.body || {};
  if (!p.id || !p.quotationRequestResponseId || !p.quotationRequestId || !p.lotItemId || p.unitPrice == null) {
    return res.status(400).json({
      error: 'id, quotationRequestResponseId, quotationRequestId, lotItemId, unitPrice required'
    });
  }
  const payload = {
    id: p.id,
    quotationRequestResponseId: p.quotationRequestResponseId,
    quotationRequestId: p.quotationRequestId,
    lotItemId: p.lotItemId,
    name: p.name || '',
    description: p.description || '',
    quantity: Number(p.quantity) || 0,
    currency: p.currency || 'ETB',
    unitMeasure: p.unitMeasure || '',
    unitPrice: Number(p.unitPrice),
    deliveryTime: p.deliveryTime ?? null,
    taxAmount: p.taxAmount ?? null,
    tax: p.tax ?? 'VAT',
  };
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-responses/update-quotation-request-response-item',
    payload
  );
  res.status(s).json({ ok: s >= 200 && s < 300, status: s, body });
});

// ---- Push ONE spec (technical offer) ----
// Needs: responseId, lotItemId. Server looks up responseItemId + schedule internally.
r.post('/push-spec-one', async (req, res) => {
  const { quotationRequestResponseId, lotItemId, offeredSpecification } = req.body || {};
  if (!quotationRequestResponseId || !lotItemId) {
    return res.status(400).json({ error: 'quotationRequestResponseId + lotItemId required' });
  }

  // 1. Fetch schedule of requirements
  const schedPath = '/po-gw/federal/purchasing/api/quotation-requests/get-schedule-of-requirement-by-quotation-request-id-v2/' + lotItemId;
  const sched = await egpGet(schedPath);
  const scheduleItems = (sched.body?.items || []).filter(x => !x.isCancelled);
  if (scheduleItems.length === 0) {
    return res.status(400).json({ error: 'no schedule requirements for this lotItemId' });
  }

  // 2. Look up responseItemId from response-items list
  const respPath = '/po-gw/federal/purchasing/api/quotation-request-responses/get-quotation-request-response-items-v2'
                 + '?quatationRequestResponseId=' + encodeURIComponent(quotationRequestResponseId);
  const respItems = await egpGet(respPath);
  const matching = (respItems.body?.items || []).find(x => x.lotItemId === lotItemId);
  if (!matching?.id) {
    return res.status(400).json({ error: 'response item not found for this lotItemId' });
  }

  // 3. Build payload and push
  const payload = {
    quotationRequestResponseId,
    quotationRequestResponseItemId: matching.id,
    quotationRequestResponseItemDetails: scheduleItems.map(s => ({
      quotationRequestResponseId,
      quotationRequestResponseItemId: matching.id,
      lotItemId,
      scheduleofRequirementId: s.id,
      offeredSpecification: offeredSpecification || s.requirement || 'Compliant',
      attribute: s.reqAttribute || 'Technical Detail',
    })),
  };
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-responses/add-quotation-request-response-item-details',
    payload
  );
  res.status(s).json({ ok: s >= 200 && s < 300, status: s, body });
});

// ---- Deprecated (kept harmless) ----
r.post('/add-items', async (_req, res) => {
  res.status(410).json({ error: 'Deprecated. Use /push-price-one and /push-spec-one.' });
});

// ---- Submit (path still unconfirmed; left as-is) ----
r.post('/submit/:responseId', async (req, res) => {
  const { status: s, body } = await egpRequest(
    'POST',
    `/po-gw/federal/purchasing/api/quotation-request-responses/submit-quotation-request-response/${req.params.responseId}`,
    {}
  );
  res.status(s).json(body);
});

export default r;
__EOF_a4c1114a9608__
cat > "server/routes/egp.js (2)" << __EOF_c13d32222beb__
import { Router } from 'express';
import {
  doPasswordLogin, doRefresh, status, egpGet, egpRequest,
} from '../egpAuth.js';

const r = Router();

// ---- Auth ----
r.post('/login',   async (_req, res) => res.json({ success: await doPasswordLogin(), ...status() }));
r.post('/refresh', async (_req, res) => res.json({ success: await doRefresh(), ...status() }));
r.get ('/status',  (_req, res) => res.json(status()));

// ---- Tender list (raw query passthrough) ----
r.get('/tenders', async (req, res) => {
  const qs = req.originalUrl.split('?')[1] || '';
  const p = '/po-gw/cms-v2/api/sourcing/get-grouped-sourcing' + (qs ? '?' + qs : '');
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Tender detail (branch by ?source=purchasing|tendering) ----
r.get('/tender/:id', async (req, res) => {
  const { id } = req.params;
  const source = String(req.query.source || '').toLowerCase();
  const p = source === 'purchasing'
    ? `/po-gw/federal/purchasing/api/quotation-invitations/get-quotation-invitation/${id}`
    : `/po-gw/cms-v2/api/sourcing/get-lot/${id}`;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Items for a quotation ----
r.get('/tender/:quotationRequestId/items', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-requests/get-quotation-request-items-by-quotation-request-id/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Registered response ----
r.get('/tender/:quotationRequestId/response', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-request-responses/get-public-quotation-request-response-v2/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Register ----
r.post('/register', async (req, res) => {
  const { quotationRequestId, quotationRequestName } = req.body || {};
  if (!quotationRequestId || !quotationRequestName) {
    return res.status(400).json({ error: 'quotationRequestId + quotationRequestName required' });
  }
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-registrations/create-quotation-request-registration',
    { quatationRequestId: quotationRequestId, quatationRequestName: quotationRequestName }
  );
  res.status(s).json(body);
});

// ---- Add items to response ----
r.post('/add-items', async (req, res) => {
  const { quotationRequestResponseId, items } = req.body || {};
  if (!quotationRequestResponseId || !Array.isArray(items)) {
    return res.status(400).json({ error: 'quotationRequestResponseId + items[] required' });
  }
  const payload = {
    quotationRequestResponseId,
    quotationRequestResponseItems: items.map(it => ({
      quotationRequestResponseId,
      lotItemId:   it.lotItemId,
      name:        it.name || '',
      description: it.description || '',
      quantity:    it.quantity ?? it.qty ?? 0,
      unitMeasure: it.unitMeasure || it.unit || '',
    })),
  };
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-responses/add-quotation-request-response-item',
    payload
  );
  res.status(s).json(body);
});

// ---- Submit ----
r.post('/submit/:responseId', async (req, res) => {
  const { status: s, body } = await egpRequest(
    'POST',
    `/po-gw/federal/purchasing/api/quotation-request-responses/submit-quotation-request-response/${req.params.responseId}`,
    {}
  );
  res.status(s).json(body);
});

export default r;
__EOF_c13d32222beb__
cat > "server/routes/egp.js (3)" << __EOF_8ac8b5ec4dee__
import { Router } from 'express';
import {
  doPasswordLogin, doRefresh, status, egpGet, egpRequest,
} from '../egpAuth.js';

const r = Router();

// ---- Auth ----
r.post('/login',   async (_req, res) => res.json({ success: await doPasswordLogin(), ...status() }));
r.post('/refresh', async (_req, res) => res.json({ success: await doRefresh(), ...status() }));
r.get ('/status',  (_req, res) => res.json(status()));

// ---- Tender list (raw query passthrough) ----
r.get('/tenders', async (req, res) => {
  const qs = req.originalUrl.split('?')[1] || '';
  const p = '/po-gw/cms-v2/api/sourcing/get-grouped-sourcing' + (qs ? '?' + qs : '');
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Tender detail (branch by ?source=purchasing|tendering) ----
r.get('/tender/:id', async (req, res) => {
  const { id } = req.params;
  const source = String(req.query.source || '').toLowerCase();
  const p = source === 'purchasing'
    ? `/po-gw/federal/purchasing/api/quotation-invitations/get-quotation-invitation/${id}`
    : `/po-gw/cms-v2/api/sourcing/get-lot/${id}`;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Items for a quotation ----
r.get('/tender/:quotationRequestId/items', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-requests/get-quotation-request-items-by-quotation-request-id/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Registered response ----
r.get('/tender/:quotationRequestId/response', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-request-responses/get-public-quotation-request-response-v2/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Register ----
r.post('/register', async (req, res) => {
  const { quotationRequestId, quotationRequestName } = req.body || {};
  if (!quotationRequestId || !quotationRequestName) {
    return res.status(400).json({ error: 'quotationRequestId + quotationRequestName required' });
  }
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-registrations/create-quotation-request-registration',
    { quatationRequestId: quotationRequestId, quatationRequestName: quotationRequestName }
  );
  res.status(s).json(body);
});

// ---- Add items to response ----
r.post('/add-items', async (req, res) => {
  const { quotationRequestResponseId, items } = req.body || {};
  if (!quotationRequestResponseId || !Array.isArray(items)) {
    return res.status(400).json({ error: 'quotationRequestResponseId + items[] required' });
  }
  const payload = {
    quotationRequestResponseId,
    quotationRequestResponseItems: items.map(it => ({
      quotationRequestResponseId,
      lotItemId:   it.lotItemId,
      name:        it.name || '',
      description: it.description || '',
      quantity:    it.quantity ?? it.qty ?? 0,
      unitMeasure: it.unitMeasure || it.unit || '',
    })),
  };
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-responses/add-quotation-request-response-item',
    payload
  );
  res.status(s).json(body);
});

// ---- Submit ----
r.post('/submit/:responseId', async (req, res) => {
  const { status: s, body } = await egpRequest(
    'POST',
    `/po-gw/federal/purchasing/api/quotation-request-responses/submit-quotation-request-response/${req.params.responseId}`,
    {}
  );
  res.status(s).json(body);
});

export default r;
__EOF_8ac8b5ec4dee__
cat > "server/routes/egp.js.WORKING" << __EOF_456f1c38acad__
import { Router } from 'express';
import {
  doPasswordLogin, doRefresh, status, egpGet, egpRequest,
} from '../egpAuth.js';

const r = Router();

// ---- Auth ----
r.post('/login',   async (_req, res) => res.json({ success: await doPasswordLogin(), ...status() }));
r.post('/refresh', async (_req, res) => res.json({ success: await doRefresh(), ...status() }));
r.get ('/status',  (_req, res) => res.json(status()));

// ---- Tender list (raw query passthrough) ----
r.get('/tenders', async (req, res) => {
  const qs = req.originalUrl.split('?')[1] || '';
  const p = '/po-gw/cms-v2/api/sourcing/get-grouped-sourcing' + (qs ? '?' + qs : '');
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Tender detail (branch by ?source=purchasing|tendering) ----
r.get('/tender/:id', async (req, res) => {
  const { id } = req.params;
  const source = String(req.query.source || '').toLowerCase();
  const p = source === 'purchasing'
    ? `/po-gw/federal/purchasing/api/quotation-invitations/get-quotation-invitation/${id}`
    : `/po-gw/cms-v2/api/sourcing/get-lot/${id}`;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Items for a quotation ----
r.get('/tender/:quotationRequestId/items', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-requests/get-quotation-request-items-by-quotation-request-id/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Registered response ----
r.get('/tender/:quotationRequestId/response', async (req, res) => {
  const p = '/po-gw/federal/purchasing/api/quotation-request-responses/get-public-quotation-request-response-v2/'
          + req.params.quotationRequestId;
  const { status: s, body } = await egpGet(p);
  res.status(s).json(body);
});

// ---- Register ----
r.post('/register', async (req, res) => {
  const { quotationRequestId, quotationRequestName } = req.body || {};
  if (!quotationRequestId || !quotationRequestName) {
    return res.status(400).json({ error: 'quotationRequestId + quotationRequestName required' });
  }
  const { status: s, body } = await egpRequest(
    'POST',
    '/po-gw/federal/purchasing/api/quotation-request-registrations/create-quotation-request-registration',
    { quatationRequestId: quotationRequestId, quatationRequestName: quotationRequestName }
  );
  res.status(s).json(body);
});

// ---- Add items to response ----
r.post('/add-items', async (req, res) => {
  const { quotationRequestResponseId, items } = req.body || {};
  if (!quotationRequestResponseId || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'quotationRequestResponseId + items[] required' });
  }

  const results = [];
  for (const it of items) {
    if (!it.lotItemId || !it.quantity || !it.unitMeasure) {
      results.push({ lotItemId: it.lotItemId, ok: false, error: 'missing lotItemId/quantity/unitMeasure' });
      continue;
    }
    const payload = {
      quotationRequestResponseId,
      quotationRequestResponseItems: [{
        quotationRequestResponseId,
        lotItemId:   it.lotItemId,
        name:        it.name || '',
        description: it.description || '',
        quantity:    Number(it.quantity) || 0,
        unitMeasure: it.unitMeasure,
      }],
    };
    const { status: s, body } = await egpRequest(
      'POST',
      '/po-gw/federal/purchasing/api/quotation-request-responses/add-quotation-request-response-item',
      payload
    );
    results.push({ lotItemId: it.lotItemId, ok: s === 200 || s === 201, status: s, body });
  }

  const failed = results.filter(x => !x.ok);
  res.json({ pushed: results.length - failed.length, failed });
});
// ---- Submit ----
r.post('/submit/:responseId', async (req, res) => {
  const { status: s, body } = await egpRequest(
    'POST',
    `/po-gw/federal/purchasing/api/quotation-request-responses/submit-quotation-request-response/${req.params.responseId}`,
    {}
  );
  res.status(s).json(body);
});

export default r;
__EOF_456f1c38acad__
cat > "server/routes/proformas.js" << __EOF_9818e0287fa2__
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin, pick } from '../middleware/auth.js';

const router = Router();
const FIELDS = ['number', 'status', 'source_request_id', 'client', 'lines', 'totals', 'terms', 'valid_days'];

router.use(requireAdmin);

router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('proformas').select('*').order('created_at', { ascending: false });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.get('/:id', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('proformas').select('*').eq('id', req.params.id).maybeSingle();
  if (error) return res.status(400).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Not found.' });
  res.json(data);
}));

router.post('/', ah(async (req, res) => {
  const row = Object.assign(pick(req.body, FIELDS), { created_by: req.user.id });
  const { data, error } = await supabaseAdmin.from('proformas').insert(row).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

router.put('/:id', ah(async (req, res) => {
  const patch = Object.assign(pick(req.body, FIELDS), { updated_at: new Date().toISOString() });
  const { data, error } = await supabaseAdmin.from('proformas').update(patch).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('proformas').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
__EOF_9818e0287fa2__
cat > "server/routes/projects.js" << __EOF_8d382b542d0d__
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin, pick } from '../middleware/auth.js';

const router = Router();
const FIELDS = ['title', 'type', 'icon', 'image', 'description', 'budget', 'duration', 'year', 'client'];

// Public
router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('projects').select('*').order('created_at', { ascending: true });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.post('/', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('projects').insert(pick(req.body, ['id'].concat(FIELDS))).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

router.put('/:id', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('projects').update(pick(req.body, FIELDS)).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', requireAdmin, ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('projects').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
__EOF_8d382b542d0d__
cat > "server/routes/quotes.js" << __EOF_a4353c5c0611__
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireUser, requireAdmin, isAdmin, pick } from '../middleware/auth.js';

const router = Router();

// Signed-in user creates a quote request (user_id/email come from the token, never the body)
router.post('/', requireUser, ah(async (req, res) => {
  const body = pick(req.body, ['id', 'kind', 'client', 'cart', 'description', 'service_type', 'budget_range', 'timeline']);
  if (!['materials', 'services'].includes(body.kind)) return res.status(400).json({ error: 'kind must be "materials" or "services".' });
  const row = Object.assign({}, body, { user_id: req.user.id, user_email: req.user.email || null, status: 'new' });
  const { data, error } = await supabaseAdmin.from('quote_requests').insert(row).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

// Admins see every request, other users only their own
router.get('/', requireUser, ah(async (req, res) => {
  let q = supabaseAdmin.from('quote_requests').select('*').order('created_at', { ascending: false });
  if (!(await isAdmin(req.user.id))) q = q.eq('user_id', req.user.id);
  if (req.query.status) q = q.eq('status', String(req.query.status));
  const { data, error } = await q;
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.patch('/:id', requireAdmin, ah(async (req, res) => {
  const patch = pick(req.body, ['status']);
  const { data, error } = await supabaseAdmin.from('quote_requests').update(patch).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', requireAdmin, ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('quote_requests').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
__EOF_a4353c5c0611__
cat > "server/routes/reviews.js" << __EOF_63bdfa1399bf__
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireUser, requireAdmin, pick } from '../middleware/auth.js';

const router = Router();

// Public: approved reviews only
router.get('/', ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('reviews').select('*').eq('approved', true).order('created_at', { ascending: false });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

// Admin: every review, including pending ones
router.get('/all', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('reviews').select('*').order('created_at', { ascending: false });
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

// Signed-in users submit a review; it stays hidden until an admin approves it
router.post('/', requireUser, ah(async (req, res) => {
  const row = Object.assign(pick(req.body, ['name', 'loc', 'stars', 'text']), { approved: false });
  const { data, error } = await supabaseAdmin.from('reviews').insert(row).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
}));

router.patch('/:id', requireAdmin, ah(async (req, res) => {
  const { data, error } = await supabaseAdmin.from('reviews').update(pick(req.body, ['name', 'loc', 'stars', 'text', 'approved'])).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
}));

router.delete('/:id', requireAdmin, ah(async (req, res) => {
  const { error } = await supabaseAdmin.from('reviews').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).end();
}));

export default router;
__EOF_63bdfa1399bf__
cat > "server/routes/uploads.js" << __EOF_45b51016e034__
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { ah, requireAdmin } from '../middleware/auth.js';

const router = Router();
const BUCKET = process.env.SUPABASE_STORAGE_BUCKET || 'uploads';

// Admin: get a signed upload URL, then PUT the file straight to Supabase Storage from the browser.
// Body: { filename: "site.jpg", folder?: "projects" }
router.post('/', requireAdmin, ah(async (req, res) => {
  const filename = String((req.body && req.body.filename) || '').trim();
  if (!filename) return res.status(400).json({ error: 'filename is required.' });
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
  const folder = String((req.body && req.body.folder) || 'misc').replace(/[^a-zA-Z0-9_-]/g, '');
  const path = folder + '/' + Date.now() + '-' + safe;

  const { data, error } = await supabaseAdmin.storage.from(BUCKET).createSignedUploadUrl(path);
  if (error) return res.status(400).json({ error: error.message });
  const pub = supabaseAdmin.storage.from(BUCKET).getPublicUrl(path);
  res.status(201).json({ bucket: BUCKET, path: data.path, token: data.token, signedUrl: data.signedUrl, publicUrl: pub.data.publicUrl });
}));

export default router;
__EOF_45b51016e034__
cat > "server/supabase/migrations/0001_tables.sql" << __EOF_ed697e7e7650__
-- 0001: tables

create table if not exists public.business_info (
  id int primary key default 1 check (id = 1),          -- single row
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into public.business_info (id, data) values (1, '{}'::jsonb) on conflict (id) do nothing;

create table if not exists public.projects (
  id text primary key default gen_random_uuid()::text,
  title text not null,
  type text,
  icon text,
  image text,
  description text,
  budget text,
  duration text,
  year int,
  client text,
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id text primary key default gen_random_uuid()::text,
  name text not null,
  loc text,
  stars int not null default 5 check (stars between 1 and 5),
  text text,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.quote_requests (
  id text primary key default gen_random_uuid()::text,
  user_id uuid references auth.users (id) on delete set null,
  user_email text,
  kind text not null check (kind in ('materials', 'services')),
  status text not null default 'new',
  client jsonb not null default '{}'::jsonb,
  cart jsonb,
  description text,
  service_type text,
  budget_range text,
  timeline text,
  created_at timestamptz not null default now()
);

create table if not exists public.proformas (
  id text primary key default gen_random_uuid()::text,
  number text unique,
  status text not null default 'draft',
  source_request_id text references public.quote_requests (id) on delete set null,
  client jsonb not null default '{}'::jsonb,
  lines jsonb not null default '[]'::jsonb,
  totals jsonb not null default '{}'::jsonb,
  terms text,
  valid_days int not null default 30,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'admin',
  created_at timestamptz not null default now()
);

create index if not exists quote_requests_user_idx on public.quote_requests (user_id);
create index if not exists quote_requests_status_idx on public.quote_requests (status);
create index if not exists proformas_request_idx on public.proformas (source_request_id);
__EOF_ed697e7e7650__
cat > "server/supabase/migrations/0002_rls.sql" << __EOF_9c085a9832e5__
-- 0002: row level security + policies

-- SECURITY DEFINER avoids policy recursion when admin_users is checked from its own policies
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

alter table public.business_info  enable row level security;
alter table public.projects       enable row level security;
alter table public.reviews        enable row level security;
alter table public.quote_requests enable row level security;
alter table public.proformas      enable row level security;
alter table public.admin_users    enable row level security;

-- Public read
drop policy if exists "business_info public read" on public.business_info;
create policy "business_info public read" on public.business_info
  for select to anon, authenticated using (true);

drop policy if exists "projects public read" on public.projects;
create policy "projects public read" on public.projects
  for select to anon, authenticated using (true);

drop policy if exists "reviews public read approved" on public.reviews;
create policy "reviews public read approved" on public.reviews
  for select to anon, authenticated using (approved = true);

-- Signed-in users can create their own quote requests
drop policy if exists "quote_requests insert own" on public.quote_requests;
create policy "quote_requests insert own" on public.quote_requests
  for insert to authenticated with check (auth.uid() = user_id);

-- Admins (anyone listed in admin_users) get full access everywhere
drop policy if exists "business_info admin all" on public.business_info;
create policy "business_info admin all" on public.business_info
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "projects admin all" on public.projects;
create policy "projects admin all" on public.projects
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "reviews admin all" on public.reviews;
create policy "reviews admin all" on public.reviews
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "quote_requests admin all" on public.quote_requests;
create policy "quote_requests admin all" on public.quote_requests
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "proformas admin all" on public.proformas;
create policy "proformas admin all" on public.proformas
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin_users admin all" on public.admin_users;
create policy "admin_users admin all" on public.admin_users
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- A signed-in user can read their own admin_users row (used by the login check)
drop policy if exists "admin_users read self" on public.admin_users;
create policy "admin_users read self" on public.admin_users
  for select to authenticated using (user_id = auth.uid());

-- Bootstrap your first admin (run once in the SQL editor, with your auth user id):
-- insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-000000000000', 'admin');
__EOF_9c085a9832e5__
cat > "server/supabase/migrations/0003_storage.sql" << __EOF_5bedca7c14ea__
-- 0003: storage bucket used by /api/uploads (signed upload URLs)
insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do nothing;
__EOF_5bedca7c14ea__
echo 'Done! Server files extracted.'
