import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { adminUser, failMockUsersList, passwordCalls, respondToPasswordCall, respondToUserWrite, signInMockAs, userWrites } from '../../test/api-mock'
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

  it('adds a user without a password and sends nothing yet: they show as invited', async () => {
    await renderUsers()

    await userEvent.type(screen.getByRole('textbox', { name: 'Email' }), 'invited@acme.example')
    await chooseOptions('Roles', 'Viewer')
    await userEvent.click(screen.getByRole('button', { name: 'Add user' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Added invited@acme.example. They have no password yet: send them a password link when ready.')
    expect(userWrites).toEqual([{ method: 'POST', body: { user: { email: 'invited@acme.example', roles: ['viewer'], password: '' } } }])
    expect(passwordCalls).toEqual([])
    expect(within(await screen.findByRole('row', { name: /invited@acme\.example/ })).getByText('Invited')).toBeInTheDocument()
  })

  it('says plainly when the admin set the first password', async () => {
    await renderUsers()

    await userEvent.type(screen.getByRole('textbox', { name: 'Email' }), 'set@acme.example')
    await chooseOptions('Roles', 'Viewer')
    await userEvent.type(screen.getByLabelText(/^First password/), 'a long first password')
    await userEvent.click(screen.getByRole('button', { name: 'Add user' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Added set@acme.example')
    expect(screen.getByRole('alert')).not.toHaveTextContent('emailed')
  })

  it('shows whether each user has chosen a password', async () => {
    await renderUsers()

    expect(within(row('admin@acme.example')).getByText('Set')).toBeInTheDocument()
    expect(within(row('priya@acme.example')).getByText('Invited')).toBeInTheDocument()
  })

  it('filters by email, role and password status, and clears the filters', async () => {
    await renderUsers()
    expect(screen.getByText('Showing 3 of 3 users')).toBeInTheDocument()

    await userEvent.type(screen.getByRole('textbox', { name: 'Search email' }), 'PRI')
    expect(screen.getByText('Showing 1 of 3 users')).toBeInTheDocument()
    expect(row('priya@acme.example')).toBeInTheDocument()
    expect(screen.queryByRole('row', { name: /admin@acme\.example/ })).not.toBeInTheDocument()

    await userEvent.clear(screen.getByRole('textbox', { name: 'Search email' }))
    await chooseOptions('Filter by role', 'HR manager', 'Admin')
    expect(screen.getByText('Showing 2 of 3 users')).toBeInTheDocument()

    await chooseOptions('Filter by password', 'Set')
    expect(screen.getByText('Showing 2 of 3 users')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }))
    await chooseOptions('Filter by password', 'Invited (no password yet)')
    expect(screen.getByText('Showing 1 of 3 users')).toBeInTheDocument()
    expect(row('priya@acme.example')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }))
    expect(screen.getByText('Showing 3 of 3 users')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Clear filters' })).not.toBeInTheDocument()
  })

  it('shows a checkbox beside each multi-select option, ticked when it is chosen', async () => {
    await renderUsers()
    // The checkbox is a picture of the option's state (the option itself is announced as selected), not a control.
    const box = (name: string) => screen.getByRole('option', { name }).querySelector('.mantine-CheckboxIndicator-indicator')
    const ticked = (name: string) => box(name)?.hasAttribute('data-checked')

    await userEvent.click(screen.getByRole('textbox', { name: 'Filter by role' }))
    expect(box('Admin')).toHaveAttribute('aria-hidden', 'true')
    expect(ticked('Admin')).toBe(false)
    await userEvent.click(screen.getByRole('option', { name: 'Admin' }))

    expect(ticked('Admin')).toBe(true)
    expect(ticked('Viewer')).toBe(false)
    expect(screen.getByRole('option', { name: 'Admin' })).toHaveAttribute('aria-selected', 'true')
    await userEvent.click(screen.getByRole('option', { name: 'Admin' }))
    expect(ticked('Admin')).toBe(false)
  })

  it('sends password links to the users chosen in the multi-select', async () => {
    await renderUsers()
    expect(screen.getByRole('button', { name: 'Send password link' })).toBeDisabled()

    await chooseOptions('Send a password link to', 'priya@acme.example (invited)', 'hr.lead@acme.example')
    await userEvent.click(screen.getByRole('button', { name: 'Send password link' }))

    expect(await screen.findByRole('status')).toHaveTextContent('Password link sent to 2 users')
    expect(passwordCalls).toEqual([{ method: 'POST', path: '/api/v1/users/password_links', body: { user_ids: [13, 14] } }])
    expect(selectedOptions('Send a password link to')).toEqual([])
  })

  it('can choose everyone the filters show, then send', async () => {
    await renderUsers()

    await chooseOptions('Filter by password', 'Invited (no password yet)')
    await userEvent.click(screen.getByRole('button', { name: 'Choose everyone shown' }))
    expect(selectedOptions('Send a password link to')).toEqual(['priya@acme.example (invited)'])

    await userEvent.click(screen.getByRole('button', { name: 'Send password link' }))
    expect(await screen.findByRole('status')).toHaveTextContent('Password link sent to 1 user')
    expect(passwordCalls.at(-1)?.body).toEqual({ user_ids: [13] })
  })

  it('cannot choose everyone when the filters show nobody', async () => {
    await renderUsers()

    await userEvent.type(screen.getByRole('textbox', { name: 'Search email' }), 'nobody')

    expect(screen.getByText('Showing 0 of 3 users')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Choose everyone shown' })).toBeDisabled()
  })

  it('shows an error when the links could not be sent', async () => {
    respondToPasswordCall(() => ({ status: 500, body: { error: { code: 'server_error', message: 'Mail server unavailable', details: {} } } }))
    await renderUsers()

    await chooseOptions('Send a password link to', 'hr.lead@acme.example')
    await userEvent.click(screen.getByRole('button', { name: 'Send password link' }))

    expect(await screen.findByText('Mail server unavailable')).toBeInTheDocument()
  })

  it('sets a user’s password in a dialog, showing field errors first', async () => {
    let attempts = 0
    respondToPasswordCall(() =>
      attempts++ === 0 ? { status: 422, body: { error: { code: 'validation_failed', message: 'Some fields are invalid', details: { password: ['is too short (minimum is 12 characters)'] } } } } : null,
    )
    await renderUsers()

    await userEvent.click(within(row('priya@acme.example')).getByRole('button', { name: 'Set password' }))
    const dialog = await screen.findByRole('dialog', { name: 'Set a password for priya@acme.example' })
    await userEvent.type(within(dialog).getByLabelText(/^New password/), 'short')
    await userEvent.type(within(dialog).getByLabelText(/^Confirm new password/), 'short')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save password' }))
    expect(await within(dialog).findByText('New password is too short (minimum is 12 characters)')).toBeInTheDocument()

    await userEvent.clear(within(dialog).getByLabelText(/^New password/))
    await userEvent.clear(within(dialog).getByLabelText(/^Confirm new password/))
    await userEvent.type(within(dialog).getByLabelText(/^New password/), 'set by the admin!')
    await userEvent.type(within(dialog).getByLabelText(/^Confirm new password/), 'set by the admin!')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save password' }))

    expect(await within(row('priya@acme.example')).findByRole('status')).toHaveTextContent('Password set for priya@acme.example')
    expect(passwordCalls.at(-1)).toEqual({ method: 'PATCH', path: '/api/v1/users/13/password', body: { password: 'set by the admin!', password_confirmation: 'set by the admin!' } })
    await waitFor(() => expect(within(row('priya@acme.example')).getByText('Set')).toBeInTheDocument())
  })

  it('cancels the password dialog without saving', async () => {
    await renderUsers()

    await userEvent.click(within(row('priya@acme.example')).getByRole('button', { name: 'Set password' }))
    const dialog = await screen.findByRole('dialog', { name: 'Set a password for priya@acme.example' })
    await userEvent.click(within(dialog).getByRole('button', { name: 'Cancel' }))

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(passwordCalls).toEqual([])
  })

  it('shows a general error in the password dialog', async () => {
    respondToPasswordCall(() => ({ status: 500, body: { error: { code: 'server_error', message: 'Something went wrong', details: {} } } }))
    await renderUsers()

    await userEvent.click(within(row('priya@acme.example')).getByRole('button', { name: 'Set password' }))
    const dialog = await screen.findByRole('dialog', { name: 'Set a password for priya@acme.example' })
    await userEvent.type(within(dialog).getByLabelText(/^New password/), 'set by the admin!')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save password' }))

    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Something went wrong')
  })
})
