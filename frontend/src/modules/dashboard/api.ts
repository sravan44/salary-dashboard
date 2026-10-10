import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { graphqlRequest } from '../../shared/graphql-client'
import { DASHBOARD_CURRENCY_DETAIL, DASHBOARD_OVERVIEW } from './queries'
import type { CurrencyDetailData, DashboardFiltersInput, OverviewData } from './types'

export function useDashboardOverview(filters: DashboardFiltersInput) {
  return useQuery({
    queryKey: ['dashboard-overview', filters],
    queryFn: () => graphqlRequest<OverviewData>(DASHBOARD_OVERVIEW, { filters }),
    placeholderData: keepPreviousData,
  })
}

export function useCurrencyDetail(filters: DashboardFiltersInput, currency: string | undefined) {
  return useQuery({
    queryKey: ['dashboard-currency-detail', filters, currency],
    queryFn: () => graphqlRequest<CurrencyDetailData>(DASHBOARD_CURRENCY_DETAIL, { filters, currency }),
    enabled: currency !== undefined,
    placeholderData: keepPreviousData,
  })
}
