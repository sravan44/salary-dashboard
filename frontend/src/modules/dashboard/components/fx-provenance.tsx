import { Text } from '@mantine/core'
import type { Converted } from '../types'

/** Rates are exact on the server; shown with 6 significant digits (the exact value is in the tooltip). */
const shortRate = (rate: string) => String(Number(Number(rate).toPrecision(6)))

/**
 * Shown beside every converted figure: which rates, of which date, from which source.
 * Converted analytics are indicative; stored salaries are never changed.
 */
export function FxProvenance({ converted }: { converted: Converted }) {
  const to = converted.reportingCurrency
  return (
    <Text role="note" aria-label="Conversion details" size="xs" c="dimmed" mt="sm">
      {`Converted to ${to} at ${converted.source}, rates of ${converted.rateDate}: `}
      {converted.rates.map((r, i) => (
        <span key={r.currency} title={`1 ${r.currency} = ${r.rate} ${to} (exact)`}>
          {`${i > 0 ? ' · ' : ''}1 ${r.currency} = ${shortRate(r.rate)} ${to}`}
        </span>
      ))}
      {'. Indicative only; stored salaries are not changed.'}
    </Text>
  )
}
