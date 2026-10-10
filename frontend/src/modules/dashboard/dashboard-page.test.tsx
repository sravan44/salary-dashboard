import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { dashboardReference, graphqlCalls, lastGraphqlCall, overview, respondToCurrencyDetail, respondToOverview } from '../../test/api-mock'
import { currentSearchParams, renderApp } from '../../test/render-app'

async function renderDashboard(path = '/') {
  renderApp(path)
  // The dashboard is lazy-loaded with Highcharts; the first test pays the cold import.
  await screen.findByText('9,227', {}, { timeout: 5000 })
}

const card = (title: string) => screen.getByRole('region', { name: title })

async function showTable(title: string) {
  await userEvent.click(within(card(title)).getByRole('radio', { name: 'Table' }))
  return within(card(title)).getByRole('table')
}

describe('Dashboard', () => {
  describe('headline numbers', () => {
    it('shows active headcount, countries and currencies as tiles', async () => {
      await renderDashboard()

      const tiles = screen.getByRole('region', { name: 'Headline numbers' })
      expect(within(tiles).getByText('Active employees')).toBeInTheDocument()
      expect(within(tiles).getByText('9,227')).toBeInTheDocument()
      expect(within(tiles).getByText('8')).toBeInTheDocument()
      expect(within(tiles).getByText('2')).toBeInTheDocument()
    })
  })

  describe('charts', () => {
    it('draws headcount by country and offers the same numbers as a table', async () => {
      await renderDashboard()
      expect(within(card('Headcount by country')).getByRole('figure', { name: /Headcount by country/ })).toBeInTheDocument()

      const table = await showTable('Headcount by country')

      expect(within(table).getByRole('row', { name: 'United States 2,700' })).toBeInTheDocument()
      expect(within(table).getByRole('row', { name: 'India 2,300' })).toBeInTheDocument()
    })

    it('defaults the salary charts to the most common currency and asks for that currency only', async () => {
      await renderDashboard()

      await waitFor(() => expect(lastGraphqlCall('DashboardCurrencyDetail')?.variables.currency).toBe('USD'))
      expect(screen.getByLabelText('Salary currency')).toHaveValue('USD')
    })

    it('shows the salary distribution buckets in the chosen currency', async () => {
      await renderDashboard()
      await screen.findByRole('figure', { name: /Salary distribution/ })

      const table = await showTable('Salary distribution (USD)')

      expect(within(table).getByRole('row', { name: '$40,000 – $60,000 1,200' })).toBeInTheDocument()
    })

    it('shows median and range by department in the chosen currency', async () => {
      await renderDashboard()
      await screen.findByRole('figure', { name: /Median and range by department/ })

      const table = await showTable('Median and range by department (USD)')

      expect(within(table).getByRole('row', { name: 'Engineering 900 $50,000 $115,500.50 $238,300' })).toBeInTheDocument()
    })

    it('shows headcount by department, hires by year and median pay by job title as their own charts', async () => {
      await renderDashboard()
      await screen.findByRole('figure', { name: /Median salary by job title/ })

      expect(within(await showTable('Headcount by department')).getByRole('row', { name: 'Engineering 2,800' })).toBeInTheDocument()
      expect(within(await showTable('Hires by year (current employees)')).getByRole('row', { name: '2025 1,100' })).toBeInTheDocument()
      expect(within(await showTable('Median salary by job title (USD)')).getByRole('row', { name: 'Staff Engineer 120 $188,000' })).toBeInTheDocument()
    })

    it('switches the salary charts to another currency', async () => {
      await renderDashboard()

      await userEvent.selectOptions(await screen.findByLabelText('Salary currency'), 'INR')

      await waitFor(() => expect(lastGraphqlCall('DashboardCurrencyDetail')?.variables.currency).toBe('INR'))
      expect(currentSearchParams().get('currency')).toBe('INR')
    })

    it('says so when nobody in the selection is paid in the chosen currency', async () => {
      respondToCurrencyDetail(() => ({ data: { dashboard: { distribution: [], byDepartment: [], byJobTitle: [] } } }))
      await renderDashboard()

      const distribution = await screen.findByRole('region', { name: 'Salary distribution (USD)' }, { timeout: 3000 })
      expect(within(distribution).getByText('No salaries in USD for this selection.')).toBeInTheDocument()
      expect(within(card('Median and range by department (USD)')).getByText('No salaries in USD for this selection.')).toBeInTheDocument()
      expect(within(card('Median salary by job title (USD)')).getByText('No salaries in USD for this selection.')).toBeInTheDocument()
    })
  })

  describe('chart types', () => {
    const seriesTypes = (title: string) =>
      Array.from(card(title).querySelectorAll('.highcharts-series'))
        .flatMap((el) => Array.from(el.classList))
        .filter((c) => /^highcharts-[a-z]+-series$/.test(c))

    async function choose(title: string, type: string) {
      await userEvent.click(within(card(title)).getByRole('radio', { name: type }))
    }

    it('switches headcount by country between bar, column and pie', async () => {
      await renderDashboard()
      expect(seriesTypes('Headcount by country')).toEqual(['highcharts-bar-series'])

      await choose('Headcount by country', 'Column')
      expect(seriesTypes('Headcount by country')).toEqual(['highcharts-column-series'])

      await choose('Headcount by country', 'Pie')
      expect(seriesTypes('Headcount by country')).toEqual(['highcharts-pie-series'])
    })

    it('switches the salary distribution between column, line and area', async () => {
      await renderDashboard()
      const title = 'Salary distribution (USD)'
      await screen.findByRole('figure', { name: /Salary distribution/ })
      expect(seriesTypes(title)).toEqual(['highcharts-column-series'])

      await choose(title, 'Line')
      expect(seriesTypes(title)).toEqual(['highcharts-line-series'])

      await choose(title, 'Area')
      expect(seriesTypes(title)).toEqual(['highcharts-area-series'])
    })

    it('shows department pay as a min–max range with a median dot, or as median columns', async () => {
      await renderDashboard()
      const title = 'Median and range by department (USD)'
      await screen.findByRole('figure', { name: /Median and range by department/ })
      expect(seriesTypes(title)).toEqual(['highcharts-columnrange-series', 'highcharts-scatter-series'])

      await choose(title, 'Median')
      expect(seriesTypes(title)).toEqual(['highcharts-column-series'])
    })
  })

  describe('more chart types', () => {
    const types = (title: string) =>
      Array.from(card(title).querySelectorAll('.highcharts-series'))
        .flatMap((el) => Array.from(el.classList))
        .filter((c) => /^highcharts-[a-z]+-series$/.test(c))
    const choose = (title: string, type: string) => userEvent.click(within(card(title)).getByRole('radio', { name: type }))

    it('draws departments as a donut by default, switchable to pie or bar', async () => {
      await renderDashboard()
      expect(types('Headcount by department')).toEqual(['highcharts-pie-series'])
      expect(card('Headcount by department').querySelector('.highcharts-pie-series')).not.toBeNull()

      await choose('Headcount by department', 'Bar')
      expect(types('Headcount by department')).toEqual(['highcharts-bar-series'])
    })

    it('draws hires by year as a line, switchable to column or area', async () => {
      await renderDashboard()
      expect(types('Hires by year (current employees)')).toEqual(['highcharts-line-series'])

      await choose('Hires by year (current employees)', 'Area')
      expect(types('Hires by year (current employees)')).toEqual(['highcharts-area-series'])
    })

    it('draws median pay by job title as bars, switchable to columns', async () => {
      await renderDashboard()
      await screen.findByRole('figure', { name: /Median salary by job title/ })
      expect(types('Median salary by job title (USD)')).toEqual(['highcharts-bar-series'])

      await choose('Median salary by job title (USD)', 'Column')
      expect(types('Median salary by job title (USD)')).toEqual(['highcharts-column-series'])
    })
  })

  describe('filters', () => {
    it('sends every filter to both requests, using the schema’s enum names, and keeps them in the URL', async () => {
      await renderDashboard()

      await userEvent.selectOptions(screen.getByLabelText('Country'), 'IN')
      await userEvent.selectOptions(screen.getByLabelText('Department'), 'Customer Support')
      await userEvent.selectOptions(screen.getByLabelText('Job title'), 'Support Lead')

      const expected = { country: 'IN', department: 'CUSTOMER_SUPPORT', jobTitle: 'Support Lead' }
      await waitFor(() => expect(lastGraphqlCall('DashboardOverview')?.variables.filters).toEqual(expected))
      await waitFor(() => expect(lastGraphqlCall('DashboardCurrencyDetail')?.variables.filters).toEqual(expected))
      expect(currentSearchParams().get('department')).toBe('Customer Support')
    })

    it('never asks for salary charts in the previous selection’s currency while new numbers load', async () => {
      respondToOverview((variables) => {
        const india = (variables.filters as { country?: string })?.country === 'IN'
        const currencies = india ? [{ currency: 'INR', headcount: 2300 }] : [{ currency: 'USD', headcount: 2700 }, { currency: 'INR', headcount: 2300 }]
        return { data: { dashboard: { ...overview, currencies }, reference: dashboardReference } }
      })
      await renderDashboard()
      await waitFor(() => expect(lastGraphqlCall('DashboardCurrencyDetail')?.variables.currency).toBe('USD'))

      await userEvent.selectOptions(screen.getByLabelText('Country'), 'IN')

      await waitFor(() => expect(lastGraphqlCall('DashboardCurrencyDetail')?.variables).toMatchObject({ currency: 'INR', filters: { country: 'IN' } }))
      const indiaRequests = graphqlCalls.filter((c) => c.operation === 'DashboardCurrencyDetail' && (c.variables.filters as { country?: string }).country === 'IN')
      expect(indiaRequests.map((c) => c.variables.currency)).toEqual(['INR'])
    })

    it('restores filters from a bookmarked URL', async () => {
      await renderDashboard('/?country=US&currency=INR')

      expect(lastGraphqlCall('DashboardOverview')?.variables.filters).toEqual({ country: 'US' })
      await waitFor(() => expect(lastGraphqlCall('DashboardCurrencyDetail')?.variables.currency).toBe('INR'))
      expect(screen.getByLabelText('Country')).toHaveValue('US')
    })

    it('clears all filters', async () => {
      await renderDashboard('/?country=US&department=Engineering')

      await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }))

      await waitFor(() => expect(currentSearchParams().toString()).toBe(''))
    })

    it('explains an empty selection instead of drawing empty charts', async () => {
      respondToOverview(() => ({
        data: { dashboard: { headcount: 0, countriesCount: 0, currencies: [], headcountByCountry: [] }, reference: { countries: [], departments: [], currencies: [], jobTitles: [] } },
      }))
      renderApp('/?country=US')

      expect(await screen.findByText('No active employees match these filters.')).toBeInTheDocument()
      expect(screen.queryByRole('region', { name: 'Headcount by country' })).not.toBeInTheDocument()
    })
  })

  it('shows the GraphQL error message', async () => {
    respondToOverview(() => ({ errors: [{ message: 'Query has complexity of 300, which exceeds max complexity of 200' }] }))
    renderApp('/')

    expect(await screen.findByRole('alert')).toHaveTextContent('Query has complexity of 300, which exceeds max complexity of 200')
  })
})
