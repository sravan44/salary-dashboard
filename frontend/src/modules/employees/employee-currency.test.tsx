import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { historyRequests, respondToHistoryConversion } from '../../test/api-mock'
import { currentSearchParams, renderApp } from '../../test/render-app'

const showIn = () => screen.findByRole('combobox', { name: 'Show amounts in' })
const historyRows = async () =>
  within(await screen.findByRole('table', { name: 'Salary history' })).getAllByRole('row').map((row) =>
    within(row).queryAllByRole(row.querySelector('th') ? 'columnheader' : 'cell').map((cell) => cell.textContent),
  )

describe('Employee amounts in a reporting currency', () => {
  it('shows original currencies by default, with no conversion requested', async () => {
    renderApp('/employees/1')

    expect(await showIn()).toHaveValue('')
    await waitFor(() => expect(historyRequests).toEqual([null]))
    expect((await historyRows())[0]).not.toContain('In USD')
  })

  it('adds the amount in the chosen currency next to every salary record and the current salary, kept in the URL', async () => {
    renderApp('/employees/1')
    await userEvent.selectOptions(await showIn(), 'USD')

    await waitFor(async () => expect((await historyRows())[0]).toContain('In USD'))
    const rows = await historyRows()
    expect(rows.slice(1).map((r) => [r[1], r[2]])).toEqual([
      ['₹2,400,000', '$28,571.43'],
      ['₹2,000,000', '$23,809.52'],
      ['₹1,800,000', '$21,428.57'],
    ])
    expect(rows[1][3]).toBe('+20.00%') // the % change stays on the original amounts
    expect(within(screen.getByRole('region', { name: 'Profile' })).getByText('₹2,400,000 (≈ $28,571.43)')).toBeInTheDocument()
    expect(currentSearchParams().get('report')).toBe('USD')
    expect(historyRequests.at(-1)).toBe('USD')
  })

  it('shows which rates, date and source were used, and that it is indicative', async () => {
    renderApp('/employees/1?report=USD')

    const note = await screen.findByRole('note', { name: 'Conversion details' })
    expect(note).toHaveTextContent('Converted to USD at ECB reference rates via Frankfurter, rates of 2026-10-09: 1 INR = 0.0119048 USD')
    expect(note).toHaveTextContent("Indicative: today's rates are applied to every record, including past ones.")
  })

  it('marks amounts it cannot convert and names the currency', async () => {
    renderApp('/employees/2?report=USD') // James: USD now, INR before; pretend there is no INR rate
    respondToHistoryConversion((to, currencies) => ({
      to, available: true, rate_date: '2026-10-09', source: 'ECB reference rates via Frankfurter', stale: false,
      rates: currencies.includes('USD') ? [{ currency: 'USD', rate: '1.0' }] : [], missing: currencies.filter((c) => c !== 'USD'),
    }))

    await waitFor(async () => expect((await historyRows())[2][2]).toBe('n/a (no rate)'))
    expect(screen.getByText('No exchange rate for INR: those amounts are not converted.')).toBeInTheDocument()
  })

  it('warns about stale rates and explains when there are no rates at all', async () => {
    respondToHistoryConversion((to, currencies) => ({ to, available: true, rate_date: '2026-09-25', source: 'ECB reference rates via Frankfurter', stale: true, rates: [{ currency: 'INR', rate: '0.0119047619' }], missing: currencies.filter((c) => c !== 'INR') }))
    renderApp('/employees/1?report=USD')
    expect(await screen.findByText('These rates are more than 7 days old (2026-09-25).')).toBeInTheDocument()
  })

  it('explains when no rates have been fetched yet', async () => {
    respondToHistoryConversion((to, currencies) => ({ to, available: false, rate_date: null, source: null, stale: false, rates: [], missing: currencies }))
    renderApp('/employees/1?report=USD')

    expect(await screen.findByText(/No exchange rates have been fetched yet/)).toBeInTheDocument()
  })

  it('goes back to original currencies', async () => {
    renderApp('/employees/1?report=USD')
    await screen.findByRole('note', { name: 'Conversion details' })

    await userEvent.selectOptions(await showIn(), '')

    await waitFor(async () => expect((await historyRows())[0]).not.toContain('In USD'))
    expect(currentSearchParams().has('report')).toBe(false)
  })
})
