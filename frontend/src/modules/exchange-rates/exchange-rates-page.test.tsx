import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { adminUser, hrUser, rateSyncCalls, respondToRateSync, setMockRates, signInMockAs } from '../../test/api-mock'
import { renderApp } from '../../test/render-app'

async function renderRates() {
  signInMockAs(adminUser)
  renderApp('/admin/exchange-rates')
  return screen.findByRole('table', { name: 'Exchange rates' })
}

const rateCells = (table: HTMLElement) =>
  within(table).getAllByRole('row').slice(1).map((row) => within(row).getAllByRole('cell').map((cell) => cell.textContent))

describe('Exchange rates (admin)', () => {
  it('is the third menu link for an Admin and lists 1 EUR in each currency with its date and source', async () => {
    signInMockAs(adminUser)
    renderApp()
    const nav = await screen.findByRole('navigation', { name: 'Main' })
    const links = within(nav).getAllByRole('link').map((link) => link.textContent)
    expect(links.slice(0, 3)).toEqual(['Dashboard', 'Users', 'Exchange rates'])

    await userEvent.click(within(nav).getByRole('link', { name: 'Exchange rates' }))
    const table = await screen.findByRole('table', { name: 'Exchange rates' })

    expect(rateCells(table)).toEqual([['GBP', '0.85'], ['INR', '92.4'], ['USD', '1.1']])
    expect(screen.getByText('Rates for 2026-10-09 · ECB reference rates via Frankfurter · fetched 2026-10-09 16:00 UTC')).toBeInTheDocument()
    expect(screen.queryByText('Stale')).not.toBeInTheDocument()
  })

  it('syncs the rates on demand and shows the new snapshot', async () => {
    const table = await renderRates()
    respondToRateSync(() => ({
      status: 200,
      body: {
        data: {
          base: 'EUR', rate_date: '2026-10-10', source: 'ECB reference rates via Frankfurter', fetched_at: '2026-10-11T09:00:00Z',
          stale: false, stored: 2, rates: [{ currency: 'INR', rate: '93.1' }, { currency: 'USD', rate: '1.12' }],
        },
      },
    }))

    await userEvent.click(screen.getByRole('button', { name: 'Sync rates' }))

    expect(await screen.findByText('Synced 2 rates for 2026-10-10.')).toBeInTheDocument()
    expect(rateSyncCalls).toHaveLength(1)
    expect(rateCells(table)).toEqual([['INR', '93.1'], ['USD', '1.12']])
  })

  it('keeps the cached rates and shows why when the sync fails', async () => {
    const table = await renderRates()
    respondToRateSync(() => ({
      status: 502,
      body: { error: { code: 'provider_unavailable', message: "Couldn't reach the rate provider, so the cached rates are unchanged. Try again later." } },
    }))

    await userEvent.click(screen.getByRole('button', { name: 'Sync rates' }))

    expect(await screen.findByText("Couldn't reach the rate provider, so the cached rates are unchanged. Try again later.")).toBeInTheDocument()
    expect(rateCells(table)).toEqual([['GBP', '0.85'], ['INR', '92.4'], ['USD', '1.1']])
  })

  it('flags stale rates', async () => {
    setMockRates({ stale: true })
    await renderRates()

    expect(screen.getByText('Stale')).toBeInTheDocument()
  })

  it('says so when no rates have been fetched yet', async () => {
    setMockRates({ rate_date: null, source: null, fetched_at: null, rates: [] })
    signInMockAs(adminUser)
    renderApp('/admin/exchange-rates')

    expect(await screen.findByText('No rates yet. Choose "Sync rates" to fetch them.')).toBeInTheDocument()
  })

  it('is not offered to other roles', async () => {
    signInMockAs(hrUser)
    renderApp('/admin/exchange-rates')

    const nav = await screen.findByRole('navigation', { name: 'Main' })
    expect(nav).not.toHaveTextContent('Exchange rates')
    expect(screen.getByText(/You don’t have access to this page/)).toBeInTheDocument()
    expect(screen.queryByRole('table', { name: 'Exchange rates' })).not.toBeInTheDocument()
  })
})
