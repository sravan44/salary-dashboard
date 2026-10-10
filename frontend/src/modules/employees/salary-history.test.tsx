import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { failMockAuditTrail, respondToSalaryChange, salaryChanges } from '../../test/api-mock'
import { renderApp } from '../../test/render-app'

const historyTable = () => screen.findByRole('table', { name: 'Salary history' })
const rowTexts = async () =>
  within(await historyTable()).getAllByRole('row').slice(1).map((row) => within(row).getAllByRole('cell').map((cell) => cell.textContent))

describe('Salary history', () => {
  it('lists every salary record newest first, in its own currency, with the % change', async () => {
    renderApp('/employees/1')

    expect(await rowTexts()).toEqual([
      ['2025-04-01 → current', '₹2,400,000', '+20.00%', 'Promotion', 'Lead role', 'hr@acme.example'],
      ['2024-04-01 → 2025-03-31', '₹2,000,000', '+11.11%', 'Annual review', '', 'seed'],
      ['2019-04-01 → 2024-03-31', '₹1,800,000', '—', 'Hire', '', 'seed'],
    ])
  })

  it('does not compute a % change across currencies', async () => {
    renderApp('/employees/2')

    const rows = await rowTexts()
    expect(rows[0].slice(0, 3)).toEqual(['2024-01-01 → current', '$120,000.50', 'n/a (currency changed)'])
  })

  it('records a change: the old record is closed, the new one is current, and the profile shows the new salary', async () => {
    renderApp('/employees/1')
    await historyTable()

    await userEvent.click(screen.getByRole('button', { name: 'Record salary change' }))
    const dialog = await screen.findByRole('dialog', { name: 'Record salary change for Asha Rao' })
    expect(within(dialog).getByRole('combobox', { name: 'Currency' })).toHaveValue('INR')

    await userEvent.type(within(dialog).getByRole('textbox', { name: 'New annual salary' }), '2640000')
    const date = within(dialog).getByLabelText(/^Effective from/)
    await userEvent.clear(date)
    await userEvent.type(date, '2026-10-01')
    await userEvent.selectOptions(within(dialog).getByRole('combobox', { name: 'Reason' }), 'annual_review')
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'Notes' }), 'FY26 review')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Record change' }))

    await waitFor(() =>
      expect(salaryChanges).toEqual([
        { id: '1', body: { compensation: { amount: '2640000', currency: 'INR', effective_from: '2026-10-01', reason: 'annual_review', notes: 'FY26 review' } } },
      ]),
    )
    await waitFor(async () => expect((await rowTexts())[0]).toEqual(['2026-10-01 → current', '₹2,640,000', '+10.00%', 'Annual review', 'FY26 review', 'hr@acme.example']))
    expect((await rowTexts())[1][0]).toBe('2025-04-01 → 2026-09-30')
    expect(within(screen.getByRole('region', { name: 'Profile' })).getByText('₹2,640,000')).toBeInTheDocument()
  })

  it('shows the server’s reasons under the fields and keeps the form open', async () => {
    respondToSalaryChange(() => ({
      status: 422,
      body: { error: { code: 'validation_failed', message: 'Some fields are invalid', details: { effective_from: ["must be after the current salary's start date (2025-04-01)"], amount: ['must be greater than 0'] } } },
    }))
    renderApp('/employees/1')
    await historyTable()

    await userEvent.click(screen.getByRole('button', { name: 'Record salary change' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Record change' }))

    expect(await within(dialog).findByText("Effective from must be after the current salary's start date (2025-04-01)")).toBeInTheDocument()
    expect(within(dialog).getByText('New annual salary must be greater than 0')).toBeInTheDocument()
  })

  it('shows a refusal that is not about one field (e.g. a deactivated employee) at the top of the form', async () => {
    respondToSalaryChange(() => ({
      status: 422,
      body: { error: { code: 'validation_failed', message: 'Some fields are invalid', details: { employee: ['is deactivated; reactivate them before recording a pay change'] } } },
    }))
    renderApp('/employees/1')
    await historyTable()

    await userEvent.click(screen.getByRole('button', { name: 'Record salary change' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Record change' }))

    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Employee is deactivated; reactivate them before recording a pay change')
  })

  it('does not offer a pay change for a deactivated employee', async () => {
    renderApp('/employees/2')
    await historyTable()

    expect(screen.getByRole('button', { name: 'Record salary change' })).toBeDisabled()
    expect(screen.getByText('Reactivate this employee to record a pay change.')).toBeInTheDocument()
  })
})

describe('Audit log', () => {
  it('says so when the audit log cannot be loaded, without hiding the rest of the page', async () => {
    failMockAuditTrail()
    renderApp('/employees/1')

    expect(await screen.findByText('Audit log unavailable')).toBeInTheDocument()
    expect(await historyTable()).toBeInTheDocument()
  })

  it('shows who changed what and when, field by field', async () => {
    renderApp('/employees/1')

    const log = await screen.findByRole('list', { name: 'Audit log' })
    const entries = within(log).getAllByRole('listitem').map((item) => item.textContent)
    expect(entries[0]).toContain('2025-04-02 10:15 UTC · hr@acme.example · Salary record created')
    expect(entries[0]).toContain('Amount: — → 2400000.00')
    expect(entries[1]).toContain('Salary record updated')
    expect(entries[1]).toContain('Effective to: — → 2025-03-31')
    expect(entries[2]).toContain('admin@acme.example · Employee updated')
    expect(entries[2]).toContain('Job title: Engineer → Software Engineer')
  })
})
