/**
 * Display an exact API amount (e.g. "120000.50") in its own currency.
 * Display only: amounts are never added up across currencies in the UI.
 */
export function formatMoney(amount: string, currency: string): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    currencyDisplay: 'symbol', // 'symbol' keeps CA$, A$, SGD distinct from US $; 'narrowSymbol' shows them all as $
    minimumFractionDigits: amount.endsWith('.00') ? 0 : 2,
    maximumFractionDigits: 2,
  }).format(Number(amount))
}
