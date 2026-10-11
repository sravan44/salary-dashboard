import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { convertedUsd, lastGraphqlCall, respondToConverted } from '../../test/api-mock'
import { currentSearchParams, renderApp } from '../../test/render-app'
import type { Converted } from './types'

const reportingSelect = () => screen.findByRole('combobox', { name: 'Reporting currency' })
const converted = (overrides: Partial<Converted>) => () => ({ data: { dashboard: { converted: { ...convertedUsd, ...overrides } } } })

async function chooseUsd() {
  renderApp('/')
  await userEvent.selectOptions(await reportingSelect(), 'USD')
}

describe('Reporting currency', () => {
  it('shows original currencies by default (no conversion)', async () => {
    renderApp('/')

    expect(await reportingSelect()).toHaveValue('')
    expect(await screen.findByRole('combobox', { name: 'Salary currency' })).toBeInTheDocument()
  })

  it('converts the salary charts into the chosen currency, with filters, and keeps the choice in the URL', async () => {
    await chooseUsd()

    await waitFor(() => expect(lastGraphqlCall('DashboardConverted')?.variables).toEqual({ filters: {}, to: 'USD' }))
    expect(currentSearchParams().get('report')).toBe('USD')
    expect(await screen.findByRole('region', { name: 'Salary distribution (USD, converted)' })).toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Median and range by department (USD, converted)' })).toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Median salary by job title (USD, converted)' })).toBeInTheDocument()
    expect(screen.queryByRole('combobox', { name: 'Salary currency' })).not.toBeInTheDocument()
  })

  it('shows the rate, date and source beside every converted chart', async () => {
    await chooseUsd()

    const charts = await screen.findAllByRole('region', { name: /\(USD, converted\)$/ })
    expect(charts).toHaveLength(3)
    for (const chart of charts) {
      const provenance = within(chart).getByRole('note', { name: 'Conversion details' })
      expect(provenance).toHaveTextContent('Converted to USD at ECB reference rates via Frankfurter, rates of 2026-10-09')
      expect(provenance).toHaveTextContent('1 EUR = 1.1 USD')
      expect(provenance).toHaveTextContent('1 INR = 0.0119048 USD')
      expect(provenance).toHaveTextContent('Indicative only; stored salaries are not changed.')
    }
  })

  it('shows converted figures in the table view, in the reporting currency', async () => {
    await chooseUsd()

    const chart = await screen.findByRole('region', { name: 'Median and range by department (USD, converted)' })
    await userEvent.click(within(chart).getByRole('radio', { name: 'Table' }))
    expect(within(chart).getByRole('row', { name: /Engineering/ })).toHaveTextContent('$88,000')
  })

  it('says which employees are left out because their currency has no rate', async () => {
    respondToConverted(converted({ excludedCurrencies: [{ currency: 'SGD', headcount: 312 }], includedHeadcount: 8915 }))
    await chooseUsd()

    expect(await screen.findByText('312 employees paid in SGD are not included: no exchange rate is available.')).toBeInTheDocument()
  })

  it('warns when the rates are more than 7 days old', async () => {
    respondToConverted(converted({ stale: true, rateDate: '2026-09-25' }))
    await chooseUsd()

    expect(await screen.findByText('These rates are more than 7 days old (2026-09-25). Run the rate refresh to update them.')).toBeInTheDocument()
  })

  it('shows no converted charts when no rates have been fetched yet', async () => {
    respondToConverted(converted({ available: false, rateDate: null, source: null, rates: [], distribution: [], byDepartment: [], byJobTitle: [], includedHeadcount: 0 }))
    await chooseUsd()

    expect(await screen.findByText(/No exchange rates have been fetched yet/)).toBeInTheDocument()
    expect(screen.queryByRole('region', { name: /converted/ })).not.toBeInTheDocument()
  })

  it('says so when the converted figures cannot be loaded', async () => {
    respondToConverted(() => ({ errors: [{ message: 'Timeout on ConvertedDashboard.payStats' }] }))
    await chooseUsd()

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not load converted figures')
  })

  it('goes back to original currencies', async () => {
    renderApp('/?report=USD')
    await screen.findByRole('region', { name: 'Salary distribution (USD, converted)' })

    await userEvent.selectOptions(await reportingSelect(), '')

    expect(await screen.findByRole('combobox', { name: 'Salary currency' })).toBeInTheDocument()
    expect(currentSearchParams().has('report')).toBe(false)
  })
})
