import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { asha, directoryRequests, james, lastDirectoryRequest, respondToDirectory } from '../../test/api-mock'
import { chooseOptions, selectedOptions } from '../../test/multi-select'
import { currentSearchParams, renderApp } from '../../test/render-app'

async function renderDirectory(path = '/employees') {
  renderApp(path)
  await screen.findByRole('table', { name: 'Employees' })
}

const rows = () => within(screen.getByRole('table', { name: 'Employees' })).getAllByRole('row').slice(1)

describe('Employee directory', () => {
  describe('results', () => {
    it('lists employees with their current salary in its own currency', async () => {
      await renderDirectory()

      expect(rows()).toHaveLength(2)
      const ashaRow = within(rows()[0])
      expect(ashaRow.getByText('EMP-000001')).toBeInTheDocument()
      expect(ashaRow.getByText('Asha Rao')).toBeInTheDocument()
      expect(ashaRow.getByText('₹2,400,000')).toBeInTheDocument()
      expect(within(rows()[1]).getByText('$120,000.50')).toBeInTheDocument()
      expect(within(rows()[1]).getByText('terminated')).toBeInTheDocument()
      expect(screen.getByText('Showing 1–2 of 2')).toBeInTheDocument()
    })

    it('shows a dash when an employee has no salary yet', async () => {
      respondToDirectory(() => ({
        body: { data: [{ ...asha, current_salary: null }], meta: { page: 1, per_page: 25, total: 1, total_pages: 1 } },
      }))
      await renderDirectory()

      expect(within(rows()[0]).getByText('—')).toBeInTheDocument()
    })

    it('explains when nothing matches and offers to clear the filters', async () => {
      respondToDirectory(() => ({ body: { data: [], meta: { page: 1, per_page: 25, total: 0, total_pages: 0 } } }))
      renderApp('/employees?country=DE')

      expect(await screen.findByText('No employees match these filters.')).toBeInTheDocument()
      await userEvent.click(screen.getByRole('button', { name: 'Clear all filters' }))
      await waitFor(() => expect(currentSearchParams().toString()).toBe(''))
    })

    it('shows the API error message and the field problems', async () => {
      respondToDirectory(() => ({
        status: 400,
        body: { error: { code: 'invalid_parameters', message: 'Some query parameters are invalid', details: { country: ['must be one of: US, IN'] } } },
      }))
      renderApp('/employees')

      const alert = await screen.findByRole('alert')
      expect(alert).toHaveTextContent('Some query parameters are invalid')
      expect(alert).toHaveTextContent('country must be one of: US, IN')
    })

    it('shows a loading state while results are on their way', async () => {
      renderApp('/employees')

      expect(screen.getByLabelText('Loading employees')).toBeInTheDocument()
      await screen.findByRole('table', { name: 'Employees' })
    })
  })

  describe('search and filters', () => {
    it('searches as you type, keeping the search in the URL', async () => {
      await renderDirectory()

      await userEvent.type(screen.getByRole('searchbox', { name: 'Search employees' }), 'rao')

      await waitFor(() => expect(lastDirectoryRequest().get('q')).toBe('rao'))
      expect(currentSearchParams().get('q')).toBe('rao')
    })

    it('applies a filter, shows it as a removable chip, and removing the chip clears it', async () => {
      await renderDirectory()

      await chooseOptions('Country', 'India')
      await waitFor(() => expect(lastDirectoryRequest().getAll('country[]')).toEqual(['IN']))
      expect(currentSearchParams().getAll('country')).toEqual(['IN'])

      await userEvent.click(screen.getByRole('button', { name: 'Remove filter Country: India' }))
      await waitFor(() => expect(lastDirectoryRequest().has('country[]')).toBe(false))
      expect(currentSearchParams().has('country')).toBe(false)
    })

    it('takes several values per filter, with one chip per value; removing a chip keeps the others', async () => {
      await renderDirectory()

      await chooseOptions('Country', 'India', 'Germany')
      await waitFor(() => expect(lastDirectoryRequest().getAll('country[]')).toEqual(['IN', 'DE']))
      expect(currentSearchParams().getAll('country')).toEqual(['IN', 'DE'])
      expect(selectedOptions('Country')).toEqual(['India', 'Germany'])

      await userEvent.click(screen.getByRole('button', { name: 'Remove filter Country: India' }))
      await waitFor(() => expect(lastDirectoryRequest().getAll('country[]')).toEqual(['DE']))
      expect(screen.getByRole('button', { name: 'Remove filter Country: Germany' })).toBeInTheDocument()
    })

    it('combines several filters in one request', async () => {
      await renderDirectory()

      await chooseOptions('Department', 'Engineering', 'People')
      await chooseOptions('Job title', 'Software Engineer')
      await chooseOptions('Status', 'active')

      await waitFor(() => {
        const params = lastDirectoryRequest()
        expect(params.getAll('department[]')).toEqual(['Engineering', 'People'])
        expect(params.getAll('job_title[]')).toEqual(['Software Engineer'])
        expect(params.getAll('status[]')).toEqual(['active'])
      })
    })

    it('keeps every filter when several are changed quickly, before the search has fired', async () => {
      await renderDirectory()

      await userEvent.type(screen.getByRole('searchbox', { name: 'Search employees' }), 'rao')
      await chooseOptions('Country', 'India')
      await chooseOptions('Department', 'Engineering')

      await waitFor(() => expect(currentSearchParams().get('q')).toBe('rao'))
      expect(currentSearchParams().getAll('country')).toEqual(['IN'])
      expect(currentSearchParams().getAll('department')).toEqual(['Engineering'])
      expect(lastDirectoryRequest().getAll('country[]')).toEqual(['IN'])
    })

    it('restores filters from a bookmarked URL', async () => {
      await renderDirectory('/employees?country=US&country=IN&status=active&q=smith')

      expect(directoryRequests[0].getAll('country[]')).toEqual(['US', 'IN'])
      expect(directoryRequests[0].get('q')).toBe('smith')
      expect(selectedOptions('Country')).toEqual(['United States', 'India'])
      expect(screen.getByRole('searchbox', { name: 'Search employees' })).toHaveValue('smith')
      expect(screen.getByRole('button', { name: 'Remove filter Search: smith' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Remove filter Status: active' })).toBeInTheDocument()
    })

    it('clears every filter at once', async () => {
      await renderDirectory('/employees?country=US&department=People&q=x')

      await userEvent.click(screen.getByRole('button', { name: 'Clear all filters' }))

      await waitFor(() => expect(currentSearchParams().toString()).toBe(''))
      expect(screen.getByRole('searchbox', { name: 'Search employees' })).toHaveValue('')
    })

    it('goes back to page 1 when a filter changes', async () => {
      await renderDirectory('/employees?page=3')

      await chooseOptions('Department', 'People')

      await waitFor(() => expect(lastDirectoryRequest().getAll('department[]')).toEqual(['People']))
      expect(lastDirectoryRequest().has('page')).toBe(false)
    })
  })

  describe('salary range', () => {
    it('only allows a salary range once a currency is chosen, because amounts in different currencies are not comparable', async () => {
      await renderDirectory()

      expect(screen.getByLabelText('Min salary')).toBeDisabled()
      expect(screen.getByLabelText('Max salary')).toBeDisabled()

      await userEvent.selectOptions(screen.getByLabelText('Currency'), 'USD')
      await userEvent.type(screen.getByLabelText('Min salary'), '100000{Enter}')
      await userEvent.type(screen.getByLabelText('Max salary'), '150000')
      await userEvent.tab()

      await waitFor(() => {
        const params = lastDirectoryRequest()
        expect(params.get('currency')).toBe('USD')
        expect(params.get('min_salary')).toBe('100000')
        expect(params.get('max_salary')).toBe('150000')
      })
      expect(screen.getByRole('button', { name: 'Remove filter Min salary: 100000' })).toBeInTheDocument()
    })

    it('drops the salary range when the currency is removed', async () => {
      await renderDirectory('/employees?currency=USD&min_salary=100000')

      await userEvent.click(screen.getByRole('button', { name: 'Remove filter Currency: USD' }))

      await waitFor(() => expect(lastDirectoryRequest().has('currency')).toBe(false))
      expect(lastDirectoryRequest().has('min_salary')).toBe(false)
    })
  })

  describe('sorting', () => {
    it('sorts by a column and toggles direction on a second click', async () => {
      await renderDirectory()

      await userEvent.click(screen.getByRole('button', { name: 'Sort by Hire date' }))
      await waitFor(() => expect(lastDirectoryRequest().get('sort')).toBe('hire_date'))

      await userEvent.click(screen.getByRole('button', { name: 'Sort by Hire date' }))
      await waitFor(() => expect(lastDirectoryRequest().get('sort')).toBe('-hire_date'))
      expect(screen.getByRole('columnheader', { name: /Hire date/ })).toHaveAttribute('aria-sort', 'descending')
    })

    it('flips direction on a quick double click', async () => {
      await renderDirectory()
      const button = screen.getByRole('button', { name: 'Sort by Hire date' })

      await userEvent.dblClick(button)

      await waitFor(() => expect(currentSearchParams().get('sort')).toBe('-hire_date'))
    })

    it('only offers salary sorting within one currency', async () => {
      await renderDirectory()
      expect(screen.queryByRole('button', { name: 'Sort by Salary' })).not.toBeInTheDocument()

      await userEvent.selectOptions(screen.getByLabelText('Currency'), 'INR')
      await userEvent.click(await screen.findByRole('button', { name: 'Sort by Salary' }))

      await waitFor(() => expect(lastDirectoryRequest().get('sort')).toBe('salary'))
    })
  })

  describe('pagination', () => {
    beforeEach(() => {
      respondToDirectory((params) => ({
        body: {
          data: [params.get('page') === '2' ? james : asha],
          meta: { page: Number(params.get('page') ?? 1), per_page: 1, total: 2, total_pages: 2 },
        },
      }))
    })

    it('moves between pages and keeps the page in the URL', async () => {
      await renderDirectory('/employees?per_page=10')

      await userEvent.click(screen.getByRole('button', { name: '2' }))

      await waitFor(() => expect(lastDirectoryRequest().get('page')).toBe('2'))
      expect(currentSearchParams().get('page')).toBe('2')
      expect(await screen.findByText('James Smith')).toBeInTheDocument()
    })

    it('changes the page size', async () => {
      await renderDirectory()

      await userEvent.selectOptions(screen.getByLabelText('Rows per page'), '50')

      await waitFor(() => expect(lastDirectoryRequest().get('per_page')).toBe('50'))
    })
  })
})
