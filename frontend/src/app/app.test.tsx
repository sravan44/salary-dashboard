import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderApp } from '../test/render-app'

describe('App shell', () => {
  it('shows the product name and main navigation', () => {
    renderApp()

    expect(screen.getByRole('heading', { name: 'ACME Salary Insights' })).toBeInTheDocument()
    const nav = screen.getByRole('navigation', { name: 'Main' })
    expect(nav).toHaveTextContent('Dashboard')
    expect(nav).toHaveTextContent('Employees')
  })

  it('opens the dashboard by default', () => {
    renderApp()

    expect(screen.getByRole('heading', { name: 'Dashboard' })).toBeInTheDocument()
  })

  it('navigates to the employees page from the menu', async () => {
    renderApp()

    await userEvent.click(screen.getByRole('link', { name: 'Employees' }))

    expect(screen.getByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })

  it('redirects unknown paths to the dashboard', () => {
    renderApp('/does-not-exist')

    expect(screen.getByRole('heading', { name: 'Dashboard' })).toBeInTheDocument()
  })
})
