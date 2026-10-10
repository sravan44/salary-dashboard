import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderApp } from '../test/render-app'

describe('App shell', () => {
  it('shows the product name and main navigation', async () => {
    renderApp()

    expect(await screen.findByRole('heading', { name: 'ACME Salary Insights' })).toBeInTheDocument()
    const nav = await screen.findByRole('navigation', { name: 'Main' })
    expect(nav).toHaveTextContent('Dashboard')
    expect(nav).toHaveTextContent('Employees')
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
