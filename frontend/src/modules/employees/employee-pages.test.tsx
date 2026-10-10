import { screen, waitFor, waitForElementToBeRemoved, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { employeeWrites, respondToEmployeeWrite } from '../../test/api-mock'
import { currentLocation, renderApp } from '../../test/render-app'

const field = (name: string) => screen.getByRole('textbox', { name })
const select = (name: string) => screen.getByRole('combobox', { name })

describe('Employee pages', () => {
  describe('from the directory', () => {
    it('links each name to that employee’s page', async () => {
      renderApp('/employees')

      await userEvent.click(await screen.findByRole('link', { name: 'Asha Rao' }))
      expect(await screen.findByRole('heading', { name: 'Asha Rao' })).toBeInTheDocument()
      expect(currentLocation.pathname).toBe('/employees/1')
    })

    it('offers "Add employee"', async () => {
      renderApp('/employees')

      await userEvent.click(await screen.findByRole('link', { name: 'Add employee' }))
      expect(await screen.findByRole('heading', { name: 'Add employee' })).toBeInTheDocument()
    })
  })

  describe('employee page', () => {
    it('shows the profile and the current salary in its own currency', async () => {
      renderApp('/employees/1')

      expect(await screen.findByRole('heading', { name: 'Asha Rao' })).toBeInTheDocument()
      expect(screen.getByText('EMP-000001')).toBeInTheDocument()
      expect(screen.getByText('asha.rao@acme.example')).toBeInTheDocument()
      expect(screen.getByText('India')).toBeInTheDocument()
      expect(screen.getByText('₹2,400,000')).toBeInTheDocument()
      expect(screen.getByText('active')).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Edit' })).toHaveAttribute('href', '/employees/1/edit')
    })

    it('says so when the employee does not exist', async () => {
      renderApp('/employees/99')

      expect(await screen.findByText('Employee not found.')).toBeInTheDocument()
    })

    it('deactivates only after confirmation, keeping the record', async () => {
      renderApp('/employees/1')
      await userEvent.click(await screen.findByRole('button', { name: 'Deactivate' }))

      const dialog = await screen.findByRole('dialog', { name: 'Deactivate Asha Rao?' })
      await userEvent.click(within(dialog).getByRole('button', { name: 'Cancel' }))
      await waitForElementToBeRemoved(() => screen.queryByRole('dialog'))
      expect(employeeWrites).toHaveLength(0)

      await userEvent.click(screen.getByRole('button', { name: 'Deactivate' }))
      await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Deactivate' }))

      await waitFor(() => expect(employeeWrites).toEqual([{ method: 'PATCH', id: '1', body: { employee: { status: 'terminated' } } }]))
      await waitForElementToBeRemoved(() => screen.queryByRole('dialog'))
      expect(await screen.findByText('terminated')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Reactivate' })).toBeInTheDocument()
    })

    it('reactivates a terminated employee after confirmation', async () => {
      renderApp('/employees/2')
      await userEvent.click(await screen.findByRole('button', { name: 'Reactivate' }))
      await userEvent.click(within(await screen.findByRole('dialog', { name: 'Reactivate James Smith?' })).getByRole('button', { name: 'Reactivate' }))

      await waitFor(() => expect(employeeWrites.at(-1)?.body).toEqual({ employee: { status: 'active' } }))
      expect(await screen.findByText('active')).toBeInTheDocument()
    })

    it('shows why a status change failed', async () => {
      respondToEmployeeWrite(() => ({ status: 500, body: { error: { code: 'server_error', message: 'Something went wrong' } } }))
      renderApp('/employees/1')
      await userEvent.click(await screen.findByRole('button', { name: 'Deactivate' }))
      await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Deactivate' }))

      expect(await screen.findByRole('alert')).toHaveTextContent('Something went wrong')
    })
  })

  describe('add employee', () => {
    async function fillProfile() {
      await userEvent.type(field('Full name'), 'Meera Iyer')
      await userEvent.type(field('Email'), 'meera@acme.example')
      await userEvent.selectOptions(select('Country'), 'IN')
      await userEvent.selectOptions(select('Department'), 'Engineering')
      await userEvent.type(field('Job title'), 'Data Engineer')
      await userEvent.type(screen.getByLabelText(/^Hire date/), '2026-10-01')
      await userEvent.type(field('Annual salary'), '1850000')
    }

    it('creates the employee with a first salary in the country’s currency, then opens their page', async () => {
      renderApp('/employees/new')
      await screen.findByRole('option', { name: 'India' })

      await fillProfile()
      expect(select('Currency')).toHaveValue('INR')
      await userEvent.click(screen.getByRole('button', { name: 'Create employee' }))

      await waitFor(() =>
        expect(employeeWrites).toEqual([
          {
            method: 'POST',
            body: {
              employee: {
                full_name: 'Meera Iyer', email: 'meera@acme.example', country_code: 'IN', department: 'Engineering',
                job_title: 'Data Engineer', hire_date: '2026-10-01', salary: { amount: '1850000', currency: 'INR' },
              },
            },
          },
        ]),
      )
      expect(await screen.findByRole('heading', { name: 'Meera Iyer' })).toBeInTheDocument()
      expect(currentLocation.pathname).toBe('/employees/3')
    })

    it('keeps a currency the user chose when the country changes later', async () => {
      renderApp('/employees/new')
      await screen.findByRole('option', { name: 'India' })

      await userEvent.selectOptions(select('Country'), 'IN')
      await userEvent.selectOptions(select('Currency'), 'USD')
      await userEvent.selectOptions(select('Country'), 'DE')

      expect(select('Currency')).toHaveValue('USD')
    })

    it('shows the server’s errors under the right fields and stays on the form', async () => {
      respondToEmployeeWrite(() => ({
        status: 422,
        body: {
          error: {
            code: 'validation_failed', message: 'Some fields are invalid',
            details: { email: ['has already been taken'], 'salary.amount': ['must be greater than 0'] },
          },
        },
      }))
      renderApp('/employees/new')
      await screen.findByRole('option', { name: 'India' })

      await fillProfile()
      await userEvent.click(screen.getByRole('button', { name: 'Create employee' }))

      expect(await screen.findByText('Email has already been taken')).toBeInTheDocument()
      expect(screen.getByText('Annual salary must be greater than 0')).toBeInTheDocument()
      expect(field('Email')).toHaveAttribute('aria-invalid', 'true')
      expect(currentLocation.pathname).toBe('/employees/new')
    })
  })

  describe('save failures that are not about one field', () => {
    it('shows the message above the form and keeps what was typed', async () => {
      respondToEmployeeWrite(() => ({ status: 500, body: { error: { code: 'server_error', message: 'The server is unavailable' } } }))
      renderApp('/employees/1/edit')
      await waitFor(() => expect(field('Full name')).toHaveValue('Asha Rao'))

      await userEvent.type(field('Full name'), ' K')
      await userEvent.click(screen.getByRole('button', { name: 'Save changes' }))

      expect(await screen.findByRole('alert')).toHaveTextContent('The server is unavailable')
      expect(field('Full name')).toHaveValue('Asha Rao K')
    })
  })

  describe('edit employee', () => {
    it('saves only the editable fields; the hire date is shown but locked', async () => {
      renderApp('/employees/1/edit')

      await waitFor(() => expect(field('Full name')).toHaveValue('Asha Rao'))
      expect(screen.getByLabelText(/^Hire date/)).toBeDisabled()
      expect(screen.queryByRole('textbox', { name: 'Annual salary' })).not.toBeInTheDocument()

      await userEvent.clear(field('Job title'))
      await userEvent.type(field('Job title'), 'Staff Engineer')
      await userEvent.click(screen.getByRole('button', { name: 'Save changes' }))

      await waitFor(() =>
        expect(employeeWrites).toEqual([
          {
            method: 'PATCH', id: '1',
            body: {
              employee: {
                full_name: 'Asha Rao', email: 'asha.rao@acme.example', country_code: 'IN', department: 'Engineering', job_title: 'Staff Engineer',
              },
            },
          },
        ]),
      )
      expect(await screen.findByText('Staff Engineer')).toBeInTheDocument()
      expect(currentLocation.pathname).toBe('/employees/1')
    })

    it('goes back to the employee page on Cancel without saving', async () => {
      renderApp('/employees/1/edit')
      await waitFor(() => expect(field('Full name')).toHaveValue('Asha Rao'))

      await userEvent.click(screen.getByRole('link', { name: 'Cancel' }))

      expect(await screen.findByRole('heading', { name: 'Asha Rao' })).toBeInTheDocument()
      expect(employeeWrites).toHaveLength(0)
    })
  })
})
