/** Rates are exact on the server (10 dp); shown with 6 significant digits, e.g. "0.0119048", "1.1". */
export const shortRate = (rate: string) => String(Number(Number(rate).toPrecision(6)))
