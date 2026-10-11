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

## Keeping rates in sync (Solid Queue recurring job)

Sravan asked for a scheduled sync and chose Solid Queue. It came from his rbenv cache, with SHA-256 verified on both sides:
- `solid_queue-1.7.0` `6566b70b…cd20c`
- `fugit-1.14.0` `e311a9cc…f37e`
- `et-orbi-1.4.2` `bb555dae…cd20c`
- `raabro-1.5.0` `3f998a7b…440a`

| # | Criterion | Proof |
|---|-----------|-------|
| S1 | `FxRefreshJob` refreshes the cache | `spec/jobs/fx_refresh_job_spec.rb` |
| S2 | A provider error retries exactly 30 min later (no jitter); the cache is kept meanwhile | same spec |
| S3 | After 3 attempts it stops, logs why, and changes nothing | same spec (3 provider calls, error logged, queue empty) |
| S4 | Schedule: weekdays 16:30 Europe/Berlin in development and production; Solid Queue accepts it | `spec/config/recurring_schedule_spec.rb` (from Fri 17:00 the next run is Mon 16:30) |
| S5 | Runs inside Puma in the one container; tables in the same PostgreSQL database | real run below |

```
backend: 297 examples, 0 failures · Line 1003/1003 (100%) · Branch 216/216 (100%)
         rubocop 131 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: unchanged by this step (not re-run)
```

**Real run** (dev server; Solid Queue started by the Puma plugin):

```
processes: ["Dispatcher", "Scheduler", "Supervisor(fork)", "Worker"]
recurring: refresh_exchange_rates | 30 16 * * 1-5 Europe/Berlin | FxRefreshJob
recurring: clear_solid_queue_finished_jobs | every hour at minute 12 | SolidQueue::Job.clear_finished_in_batches(...)
FxRefreshJob.perform_later at 02:13:42Z
job 1  ran 02:13:42, finished
job 2  scheduled_at 02:43:43 (retry 1)   ← exactly 30 minutes later
log: Retrying FxRefreshJob … after 1 attempts in 1800 seconds, due to a Fx::ProviderError (could not reach Frankfurter (Socket::ResolutionError)).
```

The retry is expected here, because the provider is blocked in this workspace. The successful live fetch is the Mac run above. The local queue was cleared afterwards.

## Rates kept in memory (version check)

Sravan asked not to read the rates from the database every time, and chose "check a version, reload on change". Each app process keeps the latest snapshot in memory. Each request runs one tiny version query (`MAX(rate_date), MAX(fetched_at)`); the rates are re-read only when that changes, e.g. after the scheduled refresh (another process).

| # | Criterion | Proof |
|---|-----------|-------|
| C1 | First request: version + rates (2 queries); later requests: version only (1) | `spec/services/fx/snapshot_spec.rb` (counts SQL statements) |
| C2 | A refresh (same date, new fetch time) or a new rate date is picked up on the next request | same spec |
| C3 | Staleness is still judged against each request's date | same spec |

Real check on the dev database (temporary TEST rates, removed afterwards):
```
request 1: 2 rate queries
request 2: 1 rate queries
request 3: 1 rate queries
after a refresh: 2 rate queries; EUR→USD now 1.2
```

```
backend: 301 examples, 0 failures · Line 1012/1012 (100%) · Branch 218/218 (100%) · rubocop 131 files, no offenses · brakeman 0 warnings
```

## Employee page amounts in a reporting currency

Sravan asked for the employee page's amounts to be shown in a chosen currency, with the rate-date picker deferred. Anyone who can open the page may switch it (URL `?report=`).

| # | Criterion | Proof |
|---|-----------|-------|
| E1 | `?report=` adds the converted amount per record (exact, 2 dp half up), plus rates, date, source, stale flag and missing currencies; without it the response is unchanged; an unsupported currency → 400; stored salaries unchanged | `spec/services/fx/conversion_spec.rb`, `spec/requests/api/v1/compensations_spec.rb` |
| E2 | The % change stays on the original amounts | request spec + UI test |
| E3 | UI: "Show amounts in" choice; "In USD" column; profile "₹2,400,000 (≈ $28,571.43)"; provenance note; no-rate, stale and no-rates messages; back to original | `employee-currency.test.tsx` (7 tests) |
| E4 | The history is fetched once per page (the page and the history section share it) | UI test (one request per view); found when the first version fetched it twice |

```
backend:  310 examples, 0 failures · Line 1037/1037 (100%) · Branch 236/236 (100%) · rubocop 133 files, no offenses
frontend: 120 tests passed · lines 99.44% · branches 95.62% · eslint 0 problems · tsc OK
```

Browser (hr@, EMP-000001, temporary rates labelled "TEST RATES – not real", removed afterwards):

```
?report=USD
PROFILE £76,500 (≈ $99,000)                                   (76,500 × 1.10 / 0.85 = 99,000)
2023-11-18 → current    | £76,500 | $99,000    | +7.14%
2021-01-05 → 2023-11-17 | £71,400 | $92,400    | +5.93%
2018-02-22 → 2021-01-04 | £67,400 | $87,223.53 | +4.33%
2015-04-12 → 2018-02-21 | £64,600 | $83,600    | —
NOTE Converted to USD at TEST RATES – not real, rates of 2026-10-09: 1 GBP = 1.29412 USD. Indicative: today's rates are applied to every record, including past ones.
```

## Screenshot
- [`m10-employee-in-usd.png`](screenshots/m10-employee-in-usd.png): employee page with amounts in USD (TEST rates).
- [`m10-converted-dashboard.png`](screenshots/m10-converted-dashboard.png): dashboard in USD, with the SGD exclusion notice and the provenance under each of the three converted charts (TEST rates).

## What this does not prove
- **The container start refresh against the live provider.** Not run in Docker; the live command itself passed on the Mac.
- **The container start step (`fx:refresh` before the server): NOT RUN.** Docker Hub is blocked here.
- **Payroll-grade FX.** Out of scope by design (A12): the figures are indicative reference-rate conversions.
