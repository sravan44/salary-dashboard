/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    // Two pages: the app, and GraphiQL (served by Rails at /graphiql only where enabled).
    rollupOptions: { input: { main: 'index.html', graphiql: 'graphiql.html' } },
    // The GraphiQL chunk (~720 kB) loads only on /graphiql; the app's own bundle stays ~200 kB.
    chunkSizeWarningLimit: 800,
  },
  server: {
    host: true,
    // In development the Rails API runs separately; proxy keeps calls same-origin.
    proxy: {
      '/api': process.env.API_PROXY_TARGET ?? 'http://localhost:3000',
      '/graphql': process.env.API_PROXY_TARGET ?? 'http://localhost:3000',
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    // Highcharts draws real SVG in jsdom (~0.3 s per chart); a dashboard test that changes several filters
    // re-renders six charts each time, so allow 15 s instead of the 5 s default.
    testTimeout: 15_000,
    coverage: {
      provider: 'v8',
      include: ['src/**/*.{ts,tsx}'],
      // Entry files only mount into the real DOM; GraphiQL is a third-party UI. Both are exercised by the build
      // and the browser run (docs/evidence), not unit tests.
      exclude: ['src/main.tsx', 'src/graphiql/main.tsx', 'src/vite-env.d.ts', 'src/test/**', 'src/**/*.test.{ts,tsx}'],
      thresholds: { lines: 90, statements: 90, functions: 90, branches: 90 },
      reporter: ['text', 'html'],
    },
  },
})
