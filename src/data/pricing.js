const round2 = (n) => Math.round(n * 100) / 100;
export function tierPrice(product, qty) {
  const tiers = (product.tiers || []).filter(t => qty >= t.min).sort((a, b) => b.min - a.min);
  return tiers.length ? tiers[0].price : product.basePrice;
}
export function calcLine(product, qty, opts = {}) {
  const basePrice = opts.basePriceOverride != null ? opts.basePriceOverride : tierPrice(product, qty);
  const contractorPrice = opts.contractorPrice != null ? opts.contractorPrice : basePrice;
  return { sku: product.id, name: product.name || product.description, unit: product.unit, qty, basePrice, contractorPrice, lineTotal: round2(qty * contractorPrice), margin: round2((contractorPrice - basePrice) * qty), taxable: product.taxable !== false, leadTimeDays: product.leadTimeDays || 0 };
}
export function calcLineFromRate(rateItem, qty, contractorPriceOverride) {
  const basePrice = rateItem.basePrice == null ? 0 : rateItem.basePrice;
  const contractorPrice = contractorPriceOverride != null ? contractorPriceOverride : (rateItem.contractorPrice != null ? rateItem.contractorPrice : basePrice);
  return { sku: rateItem.id, name: rateItem.description, unit: rateItem.unit, qty, basePrice, contractorPrice, lineTotal: round2(qty * contractorPrice), margin: round2((contractorPrice - basePrice) * qty), taxable: true, leadTimeDays: 0, code: rateItem.code };
}
export function calcProforma({ lines, freightZone, zones = [], discountPct = 0, vatRate = 0, markupPct = 0, contingencyPct = 0 }) {
  const subtotal = round2(lines.reduce((s, l) => s + l.lineTotal, 0));
  const markup = round2(subtotal * (markupPct / 100));
  const afterMarkup = round2(subtotal + markup);
  const contingency = round2(afterMarkup * (contingencyPct / 100));
  const afterContingency = round2(afterMarkup + contingency);
  const discount = round2(afterContingency * (discountPct / 100));
  const afterDiscount = round2(afterContingency - discount);
  const zone = zones.find(z => z.id === freightZone);
  const totalTons = lines.reduce((s, l) => s + (l.unit === 'ton' ? l.qty : 0), 0);
  const freight = zone ? round2((zone.flat || 0) + (zone.perTon || 0) * totalTons) : 0;
  const vat = round2(afterDiscount * vatRate);
  const grandTotal = round2(afterDiscount + freight + vat);
  const totalMargin = round2(lines.reduce((s, l) => s + (l.margin || 0), 0));
  const maxLead = lines.reduce((m, l) => Math.max(m, l.leadTimeDays || 0), 0);
  return { subtotal, markup, contingency, discount, afterDiscount, freight, vat, grandTotal, totalMargin, maxLead };
}
export function nextProformaNumber(existing = []) {
  const d = new Date();
  const ymd = d.toISOString().slice(0, 10).replace(/-/g, '');
  const todays = existing.filter(p => p.number && p.number.includes(ymd));
  return 'MA-PF-' + ymd + '-' + String(todays.length + 1).padStart(4, '0');
}
export function addDays(dateStr, days) {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}
export function formatMoney(n, currency = 'ETB') {
  const v = Number(n) || 0;
  const s = v.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return currency === 'ETB' ? 'Br ' + s : currency + ' ' + s;
}
