# M8 evidence: performance on the 10k seed (and a 100k check)

**Hypothesis:** every hot path answers well within budget at 10,000 employees, uses a fixed number of queries, and doesn't scan more than it needs to. Indexes are added only where a plan shows they matter.

**Environment:**
- Data: 10,000 employees, 32,915 salary records, 42,918 audit rows.
- Machine: cloud Linux workspace, 2 vCPU, 8 GB; PostgreSQL 16.15 (local, after `VACUUM ANALYZE`).
- Server: Rails 8.1.4 in **production mode** (`RAILS_ENV=production`, Puma, plain HTTP on localhost), against the seeded database, 2026-10-11.

**How it was measured (reproducible):**
- `bin/rails runner script/perf/measure.rb LABEL` runs the app's own query objects: 3 warm-ups, then 20 timed runs (median, p95). It counts SQL statements and saves `EXPLAIN (ANALYZE, BUFFERS)` of each statement.
  - It runs with Active Record's query cache **off**. My first run had it on: the runner enables it, and the repeated runs were answered from memory, showing 0.8 ms for queries that take 15 ms. I caught it and fixed it before recording anything.
  - It runs inside a rolled-back transaction, so the temporary FX rates it needs leave no trace.
- `ruby script/perf/http.rb URL EMAIL PASSWORD [EMPLOYEE_ID]` signs in and times each endpoint end to end: 3 warm-ups, then 20 runs.
- **Budget:** under 200 ms per request on the server.

## Results: end-to-end requests (HTTP, ms)

| Request | before median | before p95 | after median | after p95 |
|---|---|---|---|---|
| GET directory (default page) | 17.3 | 23.2 | **8.7** | 9.5 |
| GET directory ?q=rao | 36.1 | 53.9 | **7.9** | 10.8 |
| GET directory 2 countries × dept × active | 12.5 | 14.2 | 8.2 | 9.3 |
| GET directory USD 100k–150k, salary desc | 12.3 | 14.4 | 11.7 | 14.0 |
| GET directory page 400 | 22.6 | 24.9 | 21.3 | 25.9 |
| GET employee profile | 3.5 | 3.8 | 3.5 | 4.2 |
| GET salary history | 3.6 | 4.4 | 4.0 | 4.4 |
| GET salary history ?report=USD | 4.1 | 6.6 | 5.5 | 6.4 |
| GET audit trail | 11.6 | 14.4 | **4.4** | 5.3 |
| POST /graphql DashboardOverview | 39.3 | 56.7 | **15.1** | 17.8 |
| POST /graphql DashboardCurrencyDetail (INR) | 33.7 | 37.8 | 30.7 | 33.5 |
| POST /graphql DashboardConverted (USD) | 92.1 | 125.4 | 89.6 | 103.2 |

**All within budget before and after; the slowest is the converted dashboard at about 90 ms.**

## Results: SQL (app query objects, ms)

| Case | statements before → after | median before | median after | full scans after |
|---|---|---|---|---|
| Directory: default page (name order) | 2 → 2 | 12.0 | **5.6** | employees (in the total count) |
| Directory: search "rao" | 2 → 2 | 29.3 | **5.7** | — |
| Directory: 2 countries × 1 dept × active | 2 → 2 | 8.5 | 5.2 | employees |
| Directory: USD 100k–150k, salary desc | 2 → 2 | 8.6 | 9.7 | employees |
| Directory: deep page (400 of 400) | 2 → 2 | 17.7 | 17.9 | employees |
| Employee: salary history | 1 → 1 | 1.2 | 1.0 | — |
| Employee: history in USD | 3 → 3 | 2.2 | 2.0 | fx_rates (6 rows) |
| Employee: audit trail | 1 → 1 | 8.5 | **2.2** | — |
| Dashboard: overview (summary) | **6 → 1** | 32.8 | **9.6** | employees |
| Dashboard: pay by department (INR) | 1 → 1 | 8.0 | 8.5 | employees |
| Dashboard: pay by job title (INR) | 1 → 1 | 8.1 | 7.9 | employees |
| Dashboard: distribution (INR) | 2 → 2 | 10.0 | 9.5 | employees |
| Dashboard: filtered (India) pay by dept | 1 → 1 | 8.9 | 8.1 | employees |
| Converted (USD): pay by department | 3 → 3 | 34.8 | 34.4 | fx_rates, employees |
| Converted (USD): distribution | 4 → 4 | 30.2 | 30.4 | fx_rates, employees |

Raw output: [`perf/sql-before.md`](perf/sql-before.md), [`perf/sql-after.md`](perf/sql-after.md), [`perf/http-before.md`](perf/http-before.md), [`perf/http-after.md`](perf/http-after.md). Plans: [`perf/plans-before.txt`](perf/plans-before.txt), [`perf/plans-after.txt`](perf/plans-after.txt).

## What the plans showed, and what changed

| Finding (plan) | Why it matters | Change | Effect |
|---|---|---|---|
| **The audit trail walked the whole log backwards** (`Index Scan Backward using versions_pkey … Rows Removed by Filter: 42913`) because of `WHERE … OR …` plus `ORDER BY id DESC` | The log is append-only and only grows, so every employee page got slower over time | `Versions::ForEmployeeQuery`: `UNION ALL` of two lookups on `(item_type, item_id, id)` | 6.7 → **0.04 ms** in the database; flat at 100k (0.1 ms with 429k audit rows) |
| **The dashboard overview made 6 passes** over the same population join (about 6 ms each) | Every dashboard load, and it grows with headcount | `SummaryQuery`: one `GROUPING SETS` query | 6 queries / 32.8 ms → **1 / 9.6 ms** |
| **The default directory page sorted all rows to show 25** (`Sort … top-N heapsort` over 10,000 joined rows) | The most common request | Index `(full_name, id)` (new migration) | Page query 9.5 → **0.07 ms**; what's left is the total count |
| **Search scanned every row** (`ILIKE '%…%'` on three columns; a btree can't serve a substring) | Search-as-you-type fires on every pause | `pg_trgm` + trigram GIN indexes on name, email and number (new migration) | Search count 12.7 → **0.6 ms** (`BitmapOr` of the three indexes) |

These were tested first inside a rolled-back transaction on the real data, before the migration:

```
| Query               | before ms | + (full_name, id) btree | + trigram GIN ×3 |
| default page        | 10.164    | 0.135                   | 0.134            |
| deep page           | 17.429    | 16.562                  | 17.137           |
| search rao (page)   | 14.56     | 1.428                   | 1.522            |
| search rao (count)  | 12.746    | 12.441                  | 0.609            |
| search 'smith' (count) | 12.914 | 12.758                  | 0.559            |
```

**Guarded by specs** (`spec/performance/query_counts_spec.rb`, counting SQL statements):
- the directory issues 2 queries for 2 or for 100 rows per page (no N+1);
- the dashboard overview issues 1 query;
- the audit trail is 1 `UNION ALL` query.

## Not changed, on purpose (with numbers)
- **Deep pages:** OFFSET pagination still walks past earlier rows. Page 400 takes 18 ms at 10k and 55 ms at 100k. Keyset pagination would fix it, but nobody pages 400 deep in an HR directory.
- **The total count on unfiltered directory pages** scans the joined rows: about 5 ms at 10k. It's needed for "Showing 1–25 of 10,000".
- **Aggregates** (pay stats, histogram, converted) read the whole filtered population, about 8–35 ms at 10k. That is inherent to medians and histograms. No index helps, because they need every row.
- **Redundant index noticed:** `index_compensations_on_employee_id` is covered by the unique `(employee_id, effective_from)` index. It costs a little on writes only. Left as is: the gain is negligible and dropping it adds risk without a measured benefit.

## Scaling check: 100,000 employees (separate throwaway database, then dropped)
Seeded with `SEED_EMPLOYEES=100000` (91 s): 100,000 employees, 329,022 salary records, 429,025 audit rows. SQL timings (10 runs) are in [`perf/sql-after-100k.md`](perf/sql-after-100k.md):

| Path | 10k median | 100k median | Behaviour |
|---|---|---|---|
| Directory search "rao" | 5.7 | 10.4 | index-served |
| Directory default page | 5.6 | 30.3 | page from the index; the count is linear |
| Audit trail | 2.2 | 1.7 | **flat** (index lookups) |
| Salary history | 1.0 | 1.2 | flat |
| Dashboard overview | 9.6 | 103.7 | linear (one pass) |
| Pay by department (INR) | 8.5 | 88.3 | linear |
| Converted (USD): pay by department | 34.4 | 380.2 | linear; **would exceed the budget at about 10× the assessment's size** |

**Known limit:** at 100k employees, the converted dashboard would take about 0.7 s. If the data grows that far, the fix is to cache converted aggregates per (filters, rate version), or precompute converted amounts when rates refresh. Not built now: at the assessment's 10k it's about 90 ms end to end.

## Tests
```
backend:  313 examples, 0 failures · Line 1051/1051 (100%) · Branch 238/238 (100%) · rubocop 139 files, no offenses
frontend: unchanged by M8 (not re-run)
```

## What this does not prove
- **Production hardware and network latency.** Measured on localhost in a 2-vCPU workspace.
- **Concurrency.** Single-client measurements only.
- **The deployed host.** M9.
