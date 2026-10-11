# Requirements traceability

Each requirement maps to an acceptance criterion and a planned verification. The **Status** column is updated only when real evidence exists in `docs/evidence/`.

| ID | Requirement (source) | Acceptance criterion | Verification method | Milestone | Status |
|----|----------------------|----------------------|---------------------|-----------|--------|
| R1 | One-page requirements before building (brief) | `docs/requirements.md` is in the first commit, with no app code | `git show --stat <first commit>` | M0 | PASS: `e383d06` is docs-only |
| R2 | Backend in role framework (brief) | Rails JSON API boots and `/up` returns 200 | Request spec + `curl` | M1 | PASS: `docs/evidence/m1-skeleton.md` |
| R3 | React UI (brief) | React + TS app builds and renders the shell | Vitest render test + `npm run build` | M1 | PASS: `docs/evidence/m1-skeleton.md` |
| R4 | Relational DB (brief) | PostgreSQL schema with FK, unique and check constraints | Migration + model specs hitting constraints | M2a | PASS: `docs/evidence/m2a-data-and-seed.md` |
| R5 | Seed 10,000 employees (brief) | Exactly 10,000 employees, each with exactly one current salary; a re-run creates no duplicates | Seed spec (scaled) + console counts recorded | M2a | PASS: `docs/evidence/m2a-data-and-seed.md` |
| R6 | Search and filter employees (F1) | Search (name/number/email), combined filters incl. salary range plus currency, sort allowlist and pagination behave as in `api-contract.md`; invalid params return 400; filters persist in the URL | Request specs (each filter + combination + invalid) + UI test (filter chip, clear, URL) | M2b | PASS: `docs/evidence/m2b-directory.md` |
| R7 | Manage employees (F2) | Create/edit validate; deactivation keeps the record | Model + request specs + UI test | M4 | PASS: `docs/evidence/m4-employee-management.md` |
| R8 | Salary history (F3) | A valid change closes the old record and opens a new one atomically; an invalid change leaves history unchanged; concurrent changes are serialised; every step is audited | Service spec (incl. rollback + parallel threads) + request spec + DB evidence | M5 | PASS: `docs/evidence/m5-salary-history.md` |
| R9 | Pay insights (F4) | Metrics match a hand-calculated fixture; currencies are never mixed; terminated employees are excluded | Query-object spec with fixture table + SQL cross-check on 10k | M6 | PASS: `docs/evidence/m6-graphql-dashboard.md` |
| R9b | Visual dashboard (F4b) | KPI tiles and 6 switchable charts match the API for the same filters (multi-select filters); salary charts show one currency; histogram bucket counts sum to the headcount for that currency | Query spec (bucket sum = headcount), UI tests (chart types, table view, currency selector, filters), browser run | M6, M6b | PASS: `docs/evidence/m6-graphql-dashboard.md`, `docs/evidence/m6b-multi-select-filters.md` |
| R10 | Access control (F5) | Every API/GraphQL request needs sign-in (401); roles decide access (403): Viewer dashboard only, HR manager employees + salaries, Admin users | Role-by-endpoint matrix spec, session specs, UI tests per role, browser run | M7 | PASS: `docs/evidence/m7-auth-roles.md` (matrix extended in M5) |
| R11 | Meaningful, fast, deterministic tests (brief) | Suite runs offline, time is frozen, coverage ≥ 90% is enforced (BE + FE) | SimpleCov / Vitest thresholds fail the run below 90 | every | PASS (offline, frozen time, gates enforced; each evidence file has real output). Known cost: the frontend suite takes about 70 s because Highcharts draws real SVG |
| R12 | Performance at 10k (implicit) | Directory and insights queries measured on 10k seed; indexes justified by EXPLAIN | `script/perf/measure.rb` + `script/perf/http.rb` (production mode), before/after plans, query-count specs, 100k scaling check | M8 | PASS: `docs/evidence/performance.md` (all requests ≤ ~90 ms median at 10k; budget 200 ms) |
| R13 | Deployed + video demo (brief) | Public URL passes the smoke test; demo video linked in README | Smoke-test log + link | M9 | — |
| R14 | Incremental commits + AI artifacts (brief) | One commit per reviewed milestone; `ai-work-log.md` and `rejected-suggestions.md` kept current | `git log`, docs | every | — |
| R15 | Reporting-currency conversion (F7; brought forward from Phase 2) | Converted figures show rate, date and source; source salaries unchanged; provider never called while a page loads (no per-employee call); missing, stale and no-rate cases are visible | Stubbed-provider specs, hand-calculated fixture, SQL cross-check on 10k, UI tests | M10 | PASS: `docs/evidence/m10-reporting-currency.md` (live `fx:refresh` on the Mac stored 6 real ECB rates for 2026-10-09, after fixing the 301 redirect it found) |

Every requirement has a proof plan; none is flagged.
