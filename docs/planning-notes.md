# Planning and design notes

My thinking before building: how I broke the problem down, what the screens look like, which decisions carry the most risk, and how the time is spent. Diagrams are in [`architecture-diagrams.md`](architecture-diagrams.md).

## 1. Problem decomposition

Starting from the HR Manager's pain ("salaries live in Excel and I can't answer questions about pay"), I split the problem into three jobs:

| Job | What has to be true | Hardest part | Where it is solved |
|-----|---------------------|--------------|--------------------|
| **Find** people quickly | 10,000 rows searchable and filterable in under a second | Combining filters and pagination without loading everything | SQL query object + indexes (M3, M8) |
| **Change** pay safely | A salary edit never loses history and never half-applies | Effective dates, one current salary, concurrent edits | Append-only records + transaction + row lock + partial unique index (M5) |
| **Understand** pay | Answers are correct and not misleading | Multiple currencies; median is not a simple SQL aggregate | Group by currency, exact median, one currency per chart (M6); a reporting currency at named reference rates (M10) |

Everything else (auth, seed, deploy) supports these three jobs.

## 2. Screens (low-fidelity wireframes)

```
┌─ ACME Salary Insights ─────────────── [Dashboard] [Employees] ── HR Manager ⏻ ┐
│                                                                               │
│ DASHBOARD                                                                     │
│ Filters: [Country ▾] [Department ▾] [Job title ▾]              [Clear all]    │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                            │
│ │ Active staff │ │ Countries    │ │ Currencies   │                            │
│ │    9,412     │ │      8       │ │      7       │                            │
│ └──────────────┘ └──────────────┘ └──────────────┘                            │
│ ┌ Headcount by country ───────────┐ ┌ Salary distribution  Currency:[USD ▾] ┐ │
│ │ US ████████████ 2,100           │ │      ▂▅█▇▅▃▂▁                          │ │
│ │ IN ██████████ 1,800             │ │  40k   80k   120k  160k               │ │
│ │ ...                  [Table ⇄]  │ │                          [Table ⇄]    │ │
│ └─────────────────────────────────┘ └───────────────────────────────────────┘ │
│ ┌ Median & range by department (USD) ───────────────────────────────────────┐ │
│ │ Engineering  ├────────●──────────┤                                        │ │
│ │ Sales        ├─────●───────┤                                 [Table ⇄]    │ │
│ └───────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────┘

┌ EMPLOYEES ────────────────────────────────────────────────── [+ New employee] ┐
│ 🔍 [Search name, employee no., email      ]                                    │
│ [Country ▾] [Department ▾] [Job title ▾] [Status ▾] [Currency ▾] [Min] [Max]  │
│ Chips: (Country: IN ✕) (Department: Engineering ✕)                [Clear all] │
│ ┌──────────┬────────────────┬─────────┬─────────────┬────────────┬──────────┐ │
│ │ Emp no ↕ │ Name ↕         │ Country │ Department  │ Job title  │ Salary ↕ │ │
│ ├──────────┼────────────────┼─────────┼─────────────┼────────────┼──────────┤ │
│ │ EMP-0042 │ Asha Rao       │ IN      │ Engineering │ Sr Eng     │ ₹2,400,000│ │
│ └──────────┴────────────────┴─────────┴─────────────┴────────────┴──────────┘ │
│ Showing 1–25 of 1,204                                 ‹ 1 2 3 … 49 ›  [25 ▾]  │
└───────────────────────────────────────────────────────────────────────────────┘

┌ EMPLOYEE · EMP-0042 Asha Rao ─────────────────────── [Edit] [Deactivate]      ┐
│ Engineering · Senior Engineer · India · Active · Hired 2021-04-12             │
│ Current salary: ₹2,400,000 / year (since 2025-04-01)    [Record salary change]│
│ Salary history                                                                │
│  2025-04-01 → current     ₹2,400,000                                          │
│  2023-04-01 → 2025-03-31  ₹2,100,000   (+14.3%)                               │
│  2021-04-12 → 2023-03-31  ₹1,800,000   (+16.7%)                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

UX choices:
- The **directory is the home of daily work**. Search is focused on load, and the URL holds the filters, so the browser Back button and shared links behave as expected.
- **Salary is always shown with its currency symbol and code.** It is never a bare number.
- **"Record salary change" is a separate action** from "Edit profile". Pay changes are deliberate and dated, not a field you edit in passing.
- The history list shows the % change between records. It is derived at display time, never stored.
- Every chart has a table toggle (accessibility, and exact numbers for HR).

## 3. Key design decisions (summary; detail in the ADRs and docs)

| Decision | Alternatives | Why |
|----------|--------------|-----|
| Append-only `compensations` with `effective_from/to` | `salary` column on employee; audit-log table | History is a first-class business need, not an audit afterthought. The "current" record is cheap to find with a partial index. |
| Partial unique index `(employee_id) WHERE effective_to IS NULL` | App-level check only | The database guarantees at most one current salary, even under a race. |
| `SELECT … FOR UPDATE` on the employee during a change | Optimistic locking | Rare writes from a single HR user, so a simple pessimistic lock is enough. |
| Group every aggregate by currency | Convert to USD | No FX policy exists yet. *Update:* conversion was added in M10 as an explicit, indicative reporting-currency view with dated, sourced rates; per-currency figures stay the default. |
| Median in Postgres | Compute in Ruby | Keeps 10k amounts in the database; one query per chart. *Update:* built with `ROW_NUMBER` in numeric arithmetic instead of `percentile_cont`, which goes through floating point (see rejected-suggestions). |
| Histogram via `width_bucket` | Client-side binning | The browser gets about 10 rows, not 10,000 salaries. |
| Static reference list (countries, currencies, departments) | Lookup tables + admin UI | Nobody needs to edit them yet; one validated source. |
| Rails serves the built SPA | Separate frontend host | One deploy, same-origin cookie auth, no CORS. |
| Deterministic Faker seed (`Faker::Config.random = Random.new(42)`) + `insert_all` | `create!` in a loop | Reproducible data; inserting 10k rows takes seconds, not minutes. |

## 4. Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Deployment eats the last day | Med | High | Pick the host and do a "hello world" deploy early (right after M1) |
| Median/histogram SQL is wrong | Med | High | Hand-calculated fixture tests (`docs/analytics-definitions.md` in M6) |
| Coverage gate slows feature work | Med | Med | Write tests with each slice. The gate fails fast, so gaps are found early, not at the end. |
| Seed is slow or non-deterministic | Low | Med | `insert_all` batches, fixed RNG seed, a spec that runs the seed at small N |
| Charts mislead across currencies | Low | High | API requires `currency` for salary charts; UI test asserts the selector exists |
| Free-tier DB limits / cold starts | Med | Low | Documented in the README; demo video recorded as a fallback |

## 5. Time plan (≈ 2 focused days)

| Block | Milestones |
|-------|-----------|
| Day 1 AM | M0 docs → M1 skeletons + early deploy check |
| Day 1 PM | M2 schema + seed → M3 search and filter directory |
| Day 2 AM | M4 employee management → M5 salary history → M6 insights and charts |
| Day 2 PM | M7 auth/security → M8 performance → M9 deploy + demo |
| If time | M11 final review → optional K8s templates. *Update:* M10 FX was brought forward before M8 (assessment workflow 4). |

## 6. Testing strategy

| Layer | Tool | What it proves | Example |
|-------|------|----------------|---------|
| Model | RSpec | Validations + DB constraints | Amount ≤ 0 rejected, duplicate employee number rejected |
| Service | RSpec | Business rules + atomicity | Failed change leaves history unchanged |
| Query | RSpec | Correct numbers on a known fixture | USD median of [100k, 120k] = 110k; INR row separate |
| Request | RSpec | API contract, params, status codes, auth | `sort=password` → 400; no session → 401 |
| UI | Vitest + React Testing Library + MSW | User-visible behavior | Choosing a country filter updates the URL and the table |

All tests run offline, with time frozen and a fixed RNG seed. **The coverage threshold is 90% for both backend and frontend, and the test command fails below it.**
