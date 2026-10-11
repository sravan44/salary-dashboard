import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getJson, sendJson } from '../../shared/api-client'

/** The latest cached snapshot: 1 `base` (EUR) = `rate` of each currency. All null until the first fetch. */
export type RatesSnapshot = {
  base: string
  rate_date: string | null
  source: string | null
  fetched_at: string | null
  stale: boolean
  rates: { currency: string; rate: string }[]
}

const RATES_KEY = ['exchange-rates'] as const

export function useExchangeRates() {
  return useQuery({ queryKey: RATES_KEY, queryFn: async () => (await getJson<{ data: RatesSnapshot }>('/api/v1/exchange_rates')).data })
}

/** Fetches fresh rates from the provider now; on failure the server keeps the cached ones. */
export function useSyncExchangeRates() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async () => (await sendJson<{ data: RatesSnapshot & { stored: number } }>('POST', '/api/v1/exchange_rates/sync', {})).data,
    // The answer is the new snapshot (plus how many rates were stored), so the table updates without a refetch.
    onSuccess: ({ base, rate_date, source, fetched_at, stale, rates }) =>
      queryClient.setQueryData<RatesSnapshot>(RATES_KEY, { base, rate_date, source, fetched_at, stale, rates }),
  })
}
