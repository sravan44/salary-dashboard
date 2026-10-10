import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import { MemoryRouter, useLocation } from 'react-router-dom'
import { App } from '../app/app'

/** The router location the app is currently showing, so tests can assert URL state. */
export const currentLocation = { pathname: '', search: '' }

function LocationProbe() {
  const location = useLocation()
  currentLocation.pathname = location.pathname
  currentLocation.search = location.search
  return null
}

export function currentSearchParams() {
  return new URLSearchParams(currentLocation.search)
}

export function renderApp(path = '/') {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[path]}>
        <App />
        <LocationProbe />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}
