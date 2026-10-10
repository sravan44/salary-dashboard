# M6 evidence: pay dashboard over GraphQL (backend + frontend)

**Hypothesis:** one GraphQL endpoint answers every dashboard widget for the same filtered population. Its numbers match hand calculation and SQL, expensive or invalid queries are rejected up front, salary figures never mix currencies, and the UI shows six charts whose type can be switched. GraphiQL is available locally.

**Environment:** cloud Linux workspace, Rails 8.1.4 + graphql-ruby 2.6.11 (installed offline from Sravan's rbenv cache), PostgreSQL 16.15 with the 10k seed, React 19 + Highcharts 12.6.2 + GraphiQL 4.1.2, Chromium (Playwright), production mode on one origin (as in the Docker image), 2026-10-10.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| G1 | Headcount, countries, currencies, by country/department, hires by year: active employees + filters | query specs (hand-calculated fixture) + GraphQL request specs |
| G2 | Pay stats per (group, currency); exact median; average half up; current salary only; never combined across currencies | query specs + SQL cross-check below |
| G3 | Histogram for one currency; counts sum to its headcount | query spec + 10k check (878 = 878) |
| G4 | Limits: depth 8, complexity 200, limit ≤ 100, 5–20 buckets, 5 s timeout, enum validation, POST only | GraphQL specs + live errors below |
| G5 | Introspection and GraphiQL only when `GRAPHIQL_ENABLED` | request specs (on/off) |
| G6 | Frontend queries are valid against the server schema | contract tests (SDL committed + backend drift spec) |
| G7 | Dashboard: KPI tiles + 6 charts; chart type switchable; table view; one currency per salary chart; filters in the URL | 20 dashboard UI tests + browser run |

## Tests

```
backend:  140 examples, 0 failures · Line 516/516 (100%) · Branch 92/92 (100%)
          rubocop 80 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: 63 tests passed · lines 99.57% · branches 97.48% · functions 100%
          eslint 0 problems · tsc + vite build OK · npm audit (prod): 0 vulnerabilities
```

**Red before green:** the query specs failed with `uninitialized constant Insights`; the GraphQL request specs gave 14 of 15 failures; the dashboard UI tests gave 12 of 12 failures, and then failed again for the new charts and the Highcharts types.

## Numbers checked against independent SQL (10k seed, Germany)

| | GraphQL | SQL (`AVG`, `percentile_cont`) |
|---|---|---|
| headcount | 878 | 878 |
| Engineering EUR | 260 · min 49,300 · max 163,800 · avg 87,800.00 · median 82,500.00 | 260 · 49,300 · 163,800 · 87,800.00 · 82,500 |
| Sales EUR (even count) | 170 · avg 77,654.71 · median 72,850.00 | 170 · 77,654.71 · 72,850 |
| Customer Support EUR | 110 · avg 61,991.82 · median 57,600.00 | 110 · 61,991.82 · 57,600 |
| histogram (5 buckets) | 272 + 324 + 165 + 88 + 29 = 878 | headcount 878 |
| India · Engineering · INR (browser table) | 689 · ₹883,300 · median ₹1,473,200 · ₹3,092,000 | 689 · 883,300 · 1,473,200 · 3,092,000 |

Raw responses and limit errors: [`m6-graphql-samples.txt`](m6-graphql-samples.txt).

## Limits, live
```
limit 101          → limit must be between 1 and 100
buckets 30         → buckets must be between 5 and 20
3 × payStats(100)  → Query has complexity of 301, which exceeds max complexity of 200
9-level query      → Query has depth of 9, which exceeds max depth of 8
country: XX        → Argument 'country' on InputObject 'DashboardFilters' has an invalid value (XX)
distribution {..}  → Field 'distribution' is missing required arguments: currency
```

## Problems found by running it for real (each now has a test)
1. **The UI's query was rejected by the server.** It declared `$currency: Currency!`, but the schema named the type `CurrencyEnum`. MSW-based UI tests can't see this, because MSW doesn't validate against the real schema. **Fix:** enums now have clean public names (`Currency`, `CountryCode`, `Department`, `PayGroupBy`). **Guard:** the SDL is committed to `frontend/src/graphql/schema.graphql`; a backend spec fails if it drifts, and a frontend test validates every UI query and GraphiQL's starting query against it. The contract test was shown failing on the bug before the fix.
2. **Errors showed as a long spinner,** because TanStack Query retried 3 times with backoff. **Fix:** a retry policy (`shared/query-retry.ts`, tested) that retries only network and 5xx failures, at most twice.
3. **A wasted request in the previous selection's currency.** Changing the country briefly asked for "India in USD", because the default currency was taken from the previous selection still on screen. Reproduced in a UI test (`['USD', 'INR']`), then fixed by not deriving the default from placeholder data.
4. **`/favicon.ico` 404 on every page load.** Fixed with an inline SVG data-URI icon.
5. **The hires-by-year axis started at 500,** making the partial year 2026 look like a collapse. The axis now starts at 0, and the last year is labelled "(to date)".
6. **`react-router-dom` 7.6.3 had advisories** (open redirects in `<Link>`/`useNavigate`, plus SSR-only issues). It came from 2b, and `npm audit` wasn't part of the checks then. Upgraded to 7.18.4; the audit is now clean.

## Performance
- **The app's own bundle stays 204 kB:** the dashboard (Highcharts, 544 kB) is lazy-loaded, and GraphiQL (716 kB) loads only on `/graphiql`.
- **The test suite takes ~72 s,** because Highcharts draws real SVG in jsdom; per-test timeout raised to 15 s. Rendering charts only in the chart-type tests would make it fast again (follow-up).

## Screenshots (Chromium, real API, 10k seed)
- [`m6-dashboard.png`](screenshots/m6-dashboard.png): the default dashboard. Tiles, then bar, donut, line, histogram, range dot plot and bar charts.
- [`m6-dashboard-switched.png`](screenshots/m6-dashboard-switched.png): headcount by country switched to Pie, distribution to Area.
- [`m6-graphiql.png`](screenshots/m6-graphiql.png): GraphiQL at `/graphiql` running its starting query.

## What this does not prove
- **Authentication.** The dashboard and API are still open; login arrives in M7.
- **Query performance under load.** EXPLAIN and index work is M8.
- **Highcharts licensing for commercial use** (see rejected-suggestions).
