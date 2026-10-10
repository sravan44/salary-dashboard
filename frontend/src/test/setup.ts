import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterAll, afterEach, beforeAll } from 'vitest'
import { resetApiMock, server } from './api-mock'

// Any request without a handler fails the test: no accidental network calls.
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => {
  cleanup()
  server.resetHandlers()
  resetApiMock()
})
afterAll(() => server.close())

// jsdom lacks these browser APIs; Mantine uses them for color scheme and layout.
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  }),
})

class ResizeObserverStub {
  observe() {}
  unobserve() {}
  disconnect() {}
}
window.ResizeObserver = ResizeObserverStub
window.HTMLElement.prototype.scrollIntoView = () => {}

// jsdom lacks these browser APIs; Highcharts uses them for feature detection and SVG text measurement.
if (!window.CSS?.supports) {
  Object.defineProperty(window, 'CSS', { value: { ...window.CSS, supports: () => false }, writable: true })
}
const svgProto = window.SVGElement.prototype as SVGElement & { getBBox?: () => DOMRect }
if (!svgProto.getBBox) {
  svgProto.getBBox = () => ({ x: 0, y: 0, width: 40, height: 12 }) as DOMRect
}
