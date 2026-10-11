import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { adminUser, hrUser, signInMockAs } from '../test/api-mock'
import { renderApp } from '../test/render-app'

describe('App shell', () => {
  it('shows the product name and main navigation', async () => {
    renderApp()

    expect(await screen.findByRole('heading', { name: 'ACME Salary Insights' })).toBeInTheDocument()
    const nav = await screen.findByRole('navigation', { name: 'Main' })
    expect(nav).toHaveTextContent('Dashboard')
    expect(nav).toHaveTextContent('Employees')
  })

  it('links Admins to the demo email inbox when the server has it on', async () => {
    signInMockAs(adminUser)
    renderApp()

    const nav = await screen.findByRole('navigation', { name: 'Main' })
    const link = await within(nav).findByRole('link', { name: /Email inbox \(demo\)/ })
    expect(link).toHaveAttribute('href', '/letter_opener/')
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', 'noopener')
  })

  it('shows no inbox link to other roles, or to Admins when the server has it off', async () => {
    signInMockAs(hrUser)
    const { unmount } = renderApp()
    expect(await screen.findByRole('navigation', { name: 'Main' })).not.toHaveTextContent('Email inbox')
    unmount()

    signInMockAs({ ...adminUser, email_inbox: false })
    renderApp()
    expect(await screen.findByRole('link', { name: 'Users' })).toBeInTheDocument()
    expect(screen.getByRole('navigation', { name: 'Main' })).not.toHaveTextContent('Email inbox')
  })

  it('opens the dashboard by default', async () => {
    renderApp()

    expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument()
  })

  it('navigates to the employees page from the menu', async () => {
    renderApp()

    await userEvent.click(await screen.findByRole('link', { name: 'Employees' }))

    expect(screen.getByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })

  it('redirects unknown paths to the dashboard', async () => {
    renderApp('/does-not-exist')

    expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument()
  })
})
