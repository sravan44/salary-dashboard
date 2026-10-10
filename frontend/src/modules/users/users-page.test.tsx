import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { adminUser, failMockUsersList, respondToUserWrite, signInMockAs, userWrites } from '../../test/api-mock'
import { chooseOptions, selectedOptions } from '../../test/multi-select'
import { renderApp } from '../../test/render-app'

async function renderUsers() {
  signInMockAs(adminUser)
  renderApp('/admin/users')
  return screen.findByRole('table', { name: 'Users' })
}

const row = (email: string) => screen.getByRole('row', { name: new RegExp(email) })

describe('Users (admin)', () => {
  it('lists users with their roles', async () => {
    await renderUsers()

    expect(within(row('admin@acme.example')).getAllByRole('cell')[1]).toHaveTextContent('Admin')
    expect(selectedOptions('Roles for priya@acme.example')).toEqual(['Viewer'])
  })

  it('adds a user with several roles and a first password', async () => {
    await renderUsers()

    await userEvent.type(screen.getByRole('textbox', { name: 'Email' }), 'new.hr@acme.example')
    await chooseOptions('Roles', 'Viewer', 'HR manager')
    await userEvent.type(screen.getByLabelText(/^First password/), 'a long first password')
    await userEvent.click(screen.getByRole('button', { name: 'Add user' }))

    await waitFor(() =>
      expect(userWrites).toEqual([
        { method: 'POST', body: { user: { email: 'new.hr@acme.example', roles: ['viewer', 'hr_manager'], password: 'a long first password' } } },
      ]),
    )
    expect(await screen.findByRole('row', { name: /new\.hr@acme\.example/ })).toBeInTheDocument()
    expect(screen.getByRole('textbox', { name: 'Email' })).toHaveValue('')
  })

  it('shows the server’s field errors when adding fails', async () => {
    respondToUserWrite(() => ({
      status: 422,
      body: { error: { code: 'validation_failed', message: 'Some fields are invalid', details: { password: ['is too short (minimum is 12 characters)'] } } },
    }))
    await renderUsers()

    await userEvent.type(screen.getByRole('textbox', { name: 'Email' }), 'x@acme.example')
    await userEvent.click(screen.getByRole('button', { name: 'Add user' }))

    expect(await screen.findByText('Password is too short (minimum is 12 characters)')).toBeInTheDocument()
  })

  it('changes a user’s roles with the multi-select and saves', async () => {
    await renderUsers()
    const save = within(row('priya@acme.example')).getByRole('button', { name: 'Save' })
    expect(save).toBeDisabled()

    await chooseOptions('Roles for priya@acme.example', 'HR manager')
    await userEvent.click(save)

    await waitFor(() => expect(userWrites).toEqual([{ method: 'PATCH', id: '13', body: { user: { roles: ['viewer', 'hr_manager'] } } }]))
    expect(await within(row('priya@acme.example')).findByText('Saved')).toBeInTheDocument()
  })

  it('says so when the list cannot be loaded', async () => {
    failMockUsersList()
    signInMockAs(adminUser)
    renderApp('/admin/users')

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not load users')
  })

  it('shows a failure that is not about one field, for adding and for saving roles', async () => {
    respondToUserWrite(() => ({ status: 500, body: { error: { code: 'server_error', message: 'Server unavailable', details: {} } } }))
    await renderUsers()

    await userEvent.click(screen.getByRole('button', { name: 'Add user' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Server unavailable')

    await chooseOptions('Roles for priya@acme.example', 'Admin')
    await userEvent.click(within(row('priya@acme.example')).getByRole('button', { name: 'Save' }))
    expect(await within(row('priya@acme.example')).findByText('Server unavailable')).toBeInTheDocument()
  })

  it('shows why a role change was refused, on that row', async () => {
    respondToUserWrite(() => ({
      status: 422,
      body: { error: { code: 'validation_failed', message: 'Some fields are invalid', details: { roles: ['you cannot remove your own Admin role'] } } },
    }))
    await renderUsers()

    await chooseOptions('Roles for admin@acme.example', 'Viewer')
    await userEvent.click(within(row('admin@acme.example')).getByRole('button', { name: 'Save' }))

    expect(await within(row('admin@acme.example')).findByText('You cannot remove your own Admin role')).toBeInTheDocument()
  })
})
