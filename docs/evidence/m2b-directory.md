# M2b evidence: employee search and filter directory (backend + frontend)

**Hypothesis:** the HR Manager can find any of the 10,000 employees by searching and combining filters. Everything is computed in SQL, invalid input gets a clear 400, the view lives in the URL, and salaries are never compared across currencies.

**Environment:** cloud Linux workspace, Rails 8.1.4 + PostgreSQL 16.15 with the 10k seed (random seed 42), React 19 + Vite, Chromium (Playwright) for the browser run, 2026-10-10.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| D1 | Search by part of a name, employee number or email, case-insensitive; `%`/`_` are literal | request specs |
| D2 | Filters by country, department, job title, status and current-salary currency combine with AND | request specs + SQL cross-check below |
| D3 | Salary range needs a currency; non-numeric, negative and inverted ranges are rejected | request specs + 400 samples |
| D4 | Sort only by allowlisted fields; salary sort only within one currency | request specs + 400 samples |
| D5 | Pagination 1–100 per page; a page past the end returns empty data, not an error | request specs + sample |
| D6 | Every problem returned at once as `{error: {code, message, details}}`; unknown employee → 404 | request specs + samples |
| D7 | Money is an exact string with its currency (`"120000.00"`, `USD`) | `Money` spec (exact at 999,999,999,999.99) + request spec |
| D8 | UI: search as you type, filter dropdowns, removable chips, clear all, salary range enabled only with a currency, sortable columns, pagination, page size | 21 UI tests |
| D9 | The filtered view lives in the URL (bookmarkable, back button works) | UI tests + browser run |
| D10 | Loading, empty and error states | UI tests + screenshot |
| D11 | Different currencies never look the same on screen | `formatMoney` test + screenshot |

## Tests

```
$ cd backend && bundle exec rspec
90 examples, 0 failures
Line coverage: 275 / 275 (100.00%)
Branch coverage: 66 / 66 (100.00%)
$ bin/rubocop                              → 46 files inspected, no offenses detected
$ bundle exec brakeman --no-pager -q       → Security Warnings: 0   (the ORDER BY uses only allowlisted columns)

$ cd frontend && npm run test:coverage
Tests  32 passed (32)
All files | 100 % statements | 97.69 % branches | 100 % functions | 100 % lines
$ npm run lint                             → 0 problems
$ npm run build                            → ✓ built (type-check passed)
```

**Red before green.** The backend request specs were run before any controller existed: `29 examples, 29 failures`, plus `uninitialized constant Money`. The UI tests were run before the page existed: 17 of 17 directory tests failed, plus the missing `format-money` module.

## Bugs found by running it for real (and the tests that now guard them)

1. **Quick filter changes overwrote each other.** In Chromium, setting search, country, department, currency and min salary quickly produced `?currency=INR&q=rao&min_salary=2000000&sort=salary`: country and department were lost, and a double click on Salary didn't flip it to descending. Cause: React Router's `setSearchParams(prev => …)` receives the params of the *last render*, and navigations run as transitions, so two quick changes started from the same stale params. The jsdom UI tests could not show it, because Testing Library flushes renders between events. A hook test that fires two changes in the same tick reproduced both symptoms (`expected null to be 'IN'`, `expected 'salary' to be '-salary'`). Fix: build every change from a ref that is updated synchronously. After the fix, the same browser run produced `?country=IN&department=Engineering&currency=INR&q=rao&min_salary=2000000&sort=-salary`.
2. **USD, CAD, AUD and SGD all showed as `$`.** A Canadian salary showed as `$83,100`, indistinguishable from US dollars, which is exactly the cross-currency confusion this product must avoid. A test now requires four distinct renderings; the UI shows `$`, `CA$`, `A$` and `SGD`.
3. **Two "Clear all filters" buttons** appeared on an empty result (one beside the chips, one in the empty state). The empty state now shows a hint instead.

## Real API on the 10k seed
Full requests and responses: [`m2b-api-samples.txt`](m2b-api-samples.txt).

| Request | Status | Total | Time |
|---------|--------|-------|------|
| `/api/v1/employees?per_page=3` | 200 | 10,000 | 83 ms (first request, cold) |
| `?q=rao&country=IN&department=Engineering` | 200 | 23 | 14 ms |
| `?currency=EUR&min_salary=100000&max_salary=120000&sort=-salary` | 200 | 143 | 21 ms |
| `?status=terminated&per_page=2&page=3&sort=-hire_date` | 200 | 773 | 19 ms |
| `?country=SG&department=People&job_title=Head of People&status=terminated` | 200 | 0 (empty page) | 20 ms |
| `?per_page=5&page=9999` | 200 | 10,000, `data: []` | 41 ms |
| `?min_salary=50000` | **400** | `currency: is required when filtering by salary` | 3 ms |
| `?sort=salary` | **400** | `sort: by salary requires a currency filter` | 3 ms |
| `?sort=password&page=0&country=XX` | **400** | three problems listed together | 4 ms |
| `/api/v1/employees/999999` | **404** | `not_found` | 7 ms |

Timings are single local requests with no indexes beyond uniqueness. They show the shape, not a benchmark; measured performance work is M8.

**Independent check against SQL**

| Filter | API total | SQL count |
|--------|-----------|-----------|
| q=rao, IN, Engineering | 23 | 23 |
| EUR, 100,000–120,000 | 143 | 143 (top: EMP-007852, 119,900.00, the same as the API's first row) |
| q=rao, IN, Engineering, INR ≥ 2,000,000 (browser run) | 5 | 5 |

## Screenshots (Chromium, 1440×1000, real API, 10k seed)
- [`m2b-directory-default.png`](screenshots/m2b-directory-default.png): 10,000 employees sorted by name. Each salary is shown in its own currency, and `CA$` / `SGD` are distinct from `$`.
- [`m2b-directory-filtered.png`](screenshots/m2b-directory-filtered.png): search "rao" + India + Engineering + INR + min ₹2,000,000, sorted by salary descending. 5 results, with chips for every filter.
- [`m2b-directory-empty.png`](screenshots/m2b-directory-empty.png): a combination with no matches shows the empty state and the remaining chips.

## What this does not prove
- **Performance at scale.** No EXPLAIN plans or index work yet (M8).
- **Access control.** The API is still open; authentication arrives in M7.
- **The directory is read-only.** Creating, editing and salary changes come in M4/M5.
