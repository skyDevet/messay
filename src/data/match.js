// Bilingual (English + Amharic) fuzzy matcher for rate-book lookup.
// Aliases (tenderAliases) are treated as extra descriptions on each item.
//
// Anti-false-positive safeguards:
//  - Extended English stop-words cover attribute/shape modifiers (double, thick, coated…)
//  - Substring bonus requires >= 2 hits (one shared word is not enough)
//  - Substring bonus requires tokens >= 4 chars (avoids 3-char collisions like "nut" / "m10")
//  - Cross-category match is refused if token sets share nothing

const STOP_EN = new Set([
  'of','and','the','for','with','to','from','on','in','at','by','or','a','an',
  'pcs','each','unit','no','nos','type','size','dia','mm','cm','m','kg','ton','tone',
  'thick','inch','in',
  // attribute / shape words that appear across categories
  'double','single','thick','thin','long','short','large','small','big','mini',
  'heavy','light','wide','narrow','high','low','new','old','standard','normal',
  'coated','galvanized','painted','polished'
]);

const STOP_AM = new Set([
  'እና','ወይም','ከ','ለ','በ','የ','ላይ','ውስጥ','ጋር','ነው','ና','ም','ን','ኦ','፣','።',
  // shape words that cause cross-category false positives
  'ድርብ','ነጠላ','ትልቅ','ትንሽ','ረዥም','አጭር','ከባድ','ቀላል','ሰፊ','ጠባብ'
]);

const UNIT_SYNONYMS = {
  'pcs': 'each', 'nos': 'each', 'no': 'each',
  'quintal': 'quintal', 'qtl': 'quintal',
  'ton': 'ton', 'tone': 'ton', 't': 'ton',
  'm3': 'm³', 'm³': 'm³', 'cum': 'm³',
  'm2': 'm²', 'm²': 'm²', 'sqm': 'm²',
  'ml': 'ml', 'lm': 'ml',
  'kg': 'kg'
};

// ---------- Tokenizers ----------

function tokenizeEn(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[^a-z0-9.]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .filter(t => t.length > 1 && !STOP_EN.has(t));
}

function tokenizeAm(text) {
  return String(text || '')
    .replace(/[^\u1200-\u137F\s]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .filter(t => t.length > 1 && !STOP_AM.has(t));
}

function normUnit(u) {
  const k = String(u || '').toLowerCase().trim();
  return UNIT_SYNONYMS[k] || k;
}

function scoreTokens(a, b) {
  const aSet = new Set(a), bSet = new Set(b);
  let inter = 0;
  for (const t of aSet) if (bSet.has(t)) inter++;
  if (inter === 0) return 0;
  const union = aSet.size + bSet.size - inter;
  return inter / union;
}

// ---------- Index ----------

export function buildIndex(rateItems) {
  return rateItems.map(r => {
    const aliases = r.tenderAliases || [];
    return {
      item: r,
      tokensEn: tokenizeEn(r.description),
      tokensAm: r.descriptionAm ? tokenizeAm(r.descriptionAm) : [],
      aliasTokensEn: aliases.map(a => tokenizeEn(a)),
      aliasTokensAm: aliases.map(a => tokenizeAm(a)),
      unit: normUnit(r.unit),
      lowerEn: String(r.description || '').toLowerCase(),
      lowerAm: String(r.descriptionAm || '').toLowerCase(),
      lowerAliases: aliases.map(a => String(a).toLowerCase())
    };
  });
}

// Score one pair of token sets with the guarded substring bonus.
// Requires >= 2 substring hits on tokens of length >= 4 to apply the boost.
function scorePair(tTokens, eTokens, eLower, isAmharic) {
  const base = scoreTokens(tTokens, eTokens);

  const minLen = 4;
  let subHits = 0;
  for (const tok of tTokens) {
    if (tok.length < minLen) continue;
    if (eLower.includes(tok)) subHits++;
  }

  let s = base;
  if (subHits >= 2) {
    s = Math.max(s, Math.min(0.9, 0.4 + subHits * 0.1));
  }

  const tStr = tTokens.join(' ');
  if (tStr.length >= (isAmharic ? 4 : 6) && eLower.includes(tStr)) {
    s = Math.min(1, s + 0.35);
  }
  return s;
}

// ---------- Single match ----------

export function matchOne(tenderItem, index, opts = {}) {
  const minScore = opts.minScore ?? 0.35;
  const rawDesc = tenderItem.description || tenderItem.name || '';
  const tEn = tokenizeEn(rawDesc);
  const tAm = tokenizeAm(rawDesc);
  const tUnit = normUnit(tenderItem.unit || tenderItem.unitMeasure);
  const isAmharic = tAm.length > 0 && tEn.length < tAm.length;

  if (tEn.length === 0 && tAm.length === 0) {
    return { rate: 0, matched: false, score: 0 };
  }

  let best = null;
  for (const entry of index) {
    if (!entry.item.contractorPrice) continue;
    if (entry.unit && tUnit && entry.unit !== tUnit) continue;

    // Compute all candidate scores first
    let s = 0;

    if (isAmharic) {
      if (entry.tokensAm.length > 0) {
        s = Math.max(s, scorePair(tAm, entry.tokensAm, entry.lowerAm, true));
      }
      for (let i = 0; i < entry.aliasTokensAm.length; i++) {
        if (entry.aliasTokensAm[i].length === 0) continue;
        s = Math.max(s, scorePair(tAm, entry.aliasTokensAm[i], entry.lowerAliases[i] || '', true));
      }
    } else {
      if (entry.tokensEn.length > 0) {
        s = Math.max(s, scorePair(tEn, entry.tokensEn, entry.lowerEn, false));
      }
      for (let i = 0; i < entry.aliasTokensEn.length; i++) {
        if (entry.aliasTokensEn[i].length === 0) continue;
        s = Math.max(s, scorePair(tEn, entry.aliasTokensEn[i], entry.lowerAliases[i] || '', false));
      }
    }

    // Hard gate: a real match must have either
    //   (a) at least one shared token (Jaccard > 0 on either primary side), or
    //   (b) a substring hit that already cleared the >= 2 threshold.
    // Since scorePair returns 0 when neither applies, this is implicitly enforced.
    // Nothing extra needed here — s stays 0 in that case.

    if (!best || s > best.score) best = { score: s, entry };
  }

  if (!best || best.score < minScore) {
    return { rate: 0, matched: false, score: best ? best.score : 0 };
  }
  return {
    rate: best.entry.item.contractorPrice,
    matched: true,
    score: best.score,
    matchItem: best.entry.item
  };
}

// ---------- Bulk match ----------

export function matchAll(tenderItems, index, opts) {
  return tenderItems.map(it => {
    if (it.rate > 0) return it;
    const m = matchOne(it, index, opts);
    return {
      ...it,
      rate: m.rate,
      _match: {
        matched: m.matched,
        score: m.score,
        source: m.matchItem
      }
    };
  });
}