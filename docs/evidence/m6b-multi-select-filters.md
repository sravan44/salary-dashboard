# M6b evidence: multi-select filters (directory + dashboard)

**Hypothesis:** country, department, job title and status each take several values. Values within one filter combine with OR, and different filters with AND, on both the REST directory and the GraphQL dashboard. The UI offers a searchable multi-select with one chip per value, and the selection stays in the URL. Currency stays single, so salary ranges and salary charts never mix currencies.

**Environment:** cloud Linux workspace, Rails 8.1.4 + graphql-ruby 2.6.11, PostgreSQL 16 with the 10k seed, React 19 + Mantine 7.17.8 `MultiSelect`, Chromium (Playwright), 2026-10-10.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| S1 | Directory: `country[]=DE&country[]=FR` returns both; `country=DE` still works | request specs + 10k check below |
| S2 | OR within a filter, AND across filters | request specs (`IN,US` × `Finance,People` → 1 employee) + Population specs |
| S3 | Every value validated (unknown → 400 listing the filter); blank / repeated values ignored; > 50 values → 400 | request specs |
| S4 | GraphQL `DashboardFilters` fields are lists (≤ 50); a single value still accepted | GraphQL specs; regenerated SDL + contract tests |
| S5 | UI: searchable MultiSelect on both pages; one chip per value, removing one keeps the rest; URL uses repeated keys and restores on load | UI tests + hook tests + browser run |
| S6 | Currency stays one value (directory and dashboard salary charts) | unchanged currency tests still pass; NativeSelect kept |

## Tests

```
backend:  148 examples, 0 failures · Line 527/527 (100%) · Branch 98/98 (100%)
          rubocop 80 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: 66 tests passed · lines 99.69% · branches 97.98% · functions 100%
          eslint 0 problems · tsc + vite build OK
```

**Red before green:** 7 of the new or changed backend specs failed before the change (the Population OR case already passed, because `where(column => array)` handles lists); 13 frontend tests failed.

## Numbers checked against independent SQL (10k seed)

| Request | App | SQL |
|---|---|---|
| GraphQL `country: [DE, FR]` headcount | 1,547 | 878 (DE) + 669 (FR) = 1,547 |
| Directory, Country Germany + France, Department Engineering + Sales (browser) | "Showing 1–25 of 841" | `Employee.where(country_code: %w[DE FR], department: %w[Engineering Sales]).count` = 841 |
| Dashboard, Country Germany + France, Department Engineering (browser) | Active employees 475 | `Employee.active.where(country_code: %w[DE FR], department: "Engineering").count` = 475 |

The browser runs logged no console errors. Page URLs: `?country=DE&country=FR&department=Engineering`.

## Found by running it for real
- **The dashboard filter row was misaligned.** Its labels were bottom-aligned, so a multi-select holding two pills grew to two lines and pushed the other labels down. The row is now top-aligned. This is visual only, so it's checked by screenshot rather than a test.

## Screenshots
- [`m6b-directory-multiselect.png`](screenshots/m6b-directory-multiselect.png): two countries and two departments, with one chip per value; 841 results.
- [`m6b-dashboard-multiselect.png`](screenshots/m6b-dashboard-multiselect.png): Germany + France, Engineering; 475 active employees.

## What this does not prove
- **`docker build`: NOT RUN** (Docker Hub is blocked here). The same build was served from Rails locally instead.
- **Query plans for large `IN` lists:** performance work is M8, and the 50-value cap bounds them.
