# M10 evidence: reporting-currency conversion (brought forward)

**Why now:** converting analytics into a selected reporting currency, with transparent rate provenance, is assessment workflow 4. It was planned as "Phase 2", which conflicts with that, so it was brought forward ahead of M8 and M9.

**Hypothesis:** a chosen reporting currency converts each salary at dated, cached, sourced reference rates, then aggregates. Every converted chart says exactly which rate, date and source it used. Stored salaries never change, the provider is never called while a page loads, and missing, stale or absent rates are visible rather than silently papered over.

**Environment:** cloud Linux workspace, Rails 8.1.4, PostgreSQL 16 with the 10k seed, React 19, Chromium (Playwright), 2026-10-11. **Frankfurter is blocked by network policy here and from the Mac's Linux workspace**, so the provider is stubbed in every spec.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| X1 | One provider request per refresh (EUR base, 6 quotes); rates stored with date, source and fetch time; re-running is idempotent; a provider failure leaves the cache unchanged | `spec/services/fx/refresh_spec.rb` (stubbed provider) |
| X2 | Provider client: short timeouts; HTTP errors, bad bodies, a wrong base and network failures all become `ProviderError` | `spec/services/fx/frankfurter_client_spec.rb` (Net::HTTP stubbed, no network) |
| X3 | Latest rate date on or before today; exact cross rates from EUR; stale after 7 days; nil without rates | `spec/services/fx/snapshot_spec.rb` |
| X4 | Convert each salary, then aggregate (exact median, half-up average); histogram counts add up; filters apply; stored salaries unchanged | `spec/queries/insights/converted_query_spec.rb` (hand-calculated fixture) |
| X5 | Missing rate → those employees left out and named; no rates → nothing converted, clearly stated | query + GraphQL + UI specs; browser (SGD left out) |
| X6 | GraphQL `converted(to:)` with rates, date, source, stale flag, exclusions; same limits; any signed-in role | `spec/requests/graphql_spec.rb`; the schema contract test now also validates `DashboardConverted` |
| X7 | UI: reporting-currency choice (URL `?report=`); provenance note under **every** converted chart; stale and excluded warnings; no-rates notice; back to original currencies | `reporting-currency.test.tsx` (9 tests); browser |
| X8 | `fx:refresh` command; container start tries it and continues if it fails | `spec/tasks/fx_spec.rb`; Dockerfile CMD (container start **NOT RUN**, Docker Hub blocked) |

## Tests

```
backend:  285 examples, 0 failures · Line 984/984 (100%) · Branch 212/212 (100%)
          rubocop 126 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: 113 tests passed · lines 99.42% · branches 95.72% · functions 99.01%
          eslint 0 problems · tsc + vite build OK · npm audit (prod): 0 vulnerabilities
```

**Red before green:**
- The FX specs failed with uninitialized constants, the GraphQL specs with 4 failures, and the UI tests 8 of 8.
- One expected value in my own spec was wrong: the EUR median for US salaries. I had written 100,000; it is 90,909.09 (120,000 / 100,000 / 90,000 USD ÷ 1.10). The code was right, so I corrected the spec and added a comment showing the arithmetic.

## Live refresh from this workspace (expected to fail)

```
$ bin/rails fx:refresh
FX refresh failed: could not reach Frankfurter (Socket::ResolutionError). Existing rates are unchanged.
exit=1
```

## Live refresh on Sravan's Mac (2026-10-11): found a bug, fixed, then passed

**First run** (code as committed in `d400ed3`):
```
FX refresh failed: Frankfurter answered HTTP 301. Existing rates are unchanged.
```
The failure handling worked (clear message, cache kept), but the client didn't follow redirects. The stubbed specs couldn't catch this because they never returned a redirect. Two fixes, specs first:
- follow up to 3 HTTPS-only redirects (relative or absolute);
- keep a path in `FX_PROVIDER_URL`.

**Second run** (with the fix), plus where the old address points:
```
$ bin/rails fx:refresh
Stored 6 rates for 2026-10-09 (ECB reference rates via Frankfurter)
$ curl -sI "https://api.frankfurter.app/latest?from=EUR&to=USD" | grep -i -E "^HTTP|^location"
HTTP/2 301
location: https://api.frankfurter.dev/v1/latest?from=EUR&to=USD
```
The default address is now `https://api.frankfurter.dev/v1`, so no redirect is needed; redirects are still followed if the provider moves again. **Live fetch: PASS.**

## Browser run on the 10k seed (signed in as viewer@)

Because the real provider is unreachable, the local database was given rates **labelled "TEST RATES – not real (Frankfurter unreachable from this workspace)"**: 1 EUR = 1.10 USD = 92.40 INR = 0.85 GBP = 1.51 CAD = 1.66 AUD, dated 2026-10-09. SGD was left out on purpose. These rates were deleted after the run.

```
URL ?report=USD
Alert: "403 employees paid in SGD are not included: no exchange rate is available."
3 provenance notes, e.g.:
  Converted to USD at TEST RATES – not real (…), rates of 2026-10-09: 1 AUD = 0.662651 USD · 1 CAD = 0.728477 USD ·
  1 EUR = 1.1 USD · 1 GBP = 1.29412 USD · 1 INR = 0.0119048 USD · 1 USD = 1 USD. Indicative only; stored salaries are not changed.
Department table (USD, converted):
  Engineering      | 2,665 | $10,515.48 | median $81,300     | $238,300
  Sales            | 1,587 | $9,152.38  | median $72,000     | $206,400
  Customer Support | 1,170 | $7,286.90  | median $55,749.46  | $166,600
```

**Independent SQL check** (same factors, Postgres `percentile_cont` instead of the app's row-number median; SGD left out):

```
Engineering      | 2665 | 10515.48 | 238300.0 | avg 82220.66 | median 81300.0
Sales            | 1587 | 9152.38  | 206400.0 | avg 72284.66 | median 72000.0
Customer Support | 1170 | 7286.9   | 166600.0 | avg 56492.0  | median 55749.46
SGD (excluded): 403
```

Headcounts, minimums, medians and maximums match exactly. The only console error was the expected 401 from the signed-out session check.

## Screenshot
- [`m10-converted-dashboard.png`](screenshots/m10-converted-dashboard.png): dashboard in USD, with the SGD exclusion notice and the provenance under each of the three converted charts (TEST rates).

## What this does not prove
- **The container start refresh against the live provider.** Not run in Docker; the live command itself passed on the Mac.
- **The container start step (`fx:refresh` before the server): NOT RUN.** Docker Hub is blocked here.
- **Payroll-grade FX.** Out of scope by design (A12): the figures are indicative reference-rate conversions.
