# Requirements traceability

Each requirement maps to an acceptance criterion and a planned verification. The **Status** column is updated only when real evidence exists in `docs/evidence/`.

| ID | Requirement (source) | Acceptance criterion | Verification method | Milestone | Status |
|----|----------------------|----------------------|---------------------|-----------|--------|
| R1 | One-page requirements before building (brief) | `docs/requirements.md` is in the first commit, with no app code | `git show --stat <first commit>` | M0 | Pending review |
| R2 | Backend in role framework (brief) | Rails JSON API boots and `/up` returns 200 | Request spec + `curl` | M1 | — |
| R3 | React UI (brief) | React + TS app builds and renders the shell | Vitest render test + `npm run build` | M1 | — |
| R4 | Relational DB (brief) | PostgreSQL schema with FK, unique and check constraints | Migration + model specs hitting constraints | M2 | — |
| R5 | Seed 10,000 employees (brief) | Exactly 10,000 employees, each with exactly one current salary; a re-run creates no duplicates | Seed spec (scaled) + console counts recorded | M2 | — |
| R6 | Search and filter employees (F1) | Search (name/number/email), combined filters incl. salary range plus currency, sort allowlist and pagination behave as in `api-contract.md`; invalid params return 400; filters persist in the URL | Request specs (each filter + combination + invalid) + UI test (filter chip, clear, URL) | M3 | — |
| R7 | Manage employees (F2) | Create/edit validate; deactivation keeps the record | Model + request specs + UI test | M4 | — |
| R8 | Salary history (F3) | A valid change closes the old record and opens a new one atomically; an invalid change leaves history unchanged | Service spec (incl. rollback) + request spec + DB evidence | M5 | — |
| R9 | Pay insights (F4) | Metrics match a hand-calculated fixture; currencies are never mixed; terminated employees are excluded | Query-object spec with fixture table | M6 | — |
| R9b | Visual dashboard (F4b) | KPI tiles and 3 charts match the API for the same filters; salary charts show one currency; histogram bucket counts sum to the headcount for that currency | Query spec (bucket sum = headcount), UI tests (chart renders data, currency selector, filter change refetches, table view) | M6 | — |
| R10 | Access control (F5) | Unauthenticated requests to salary endpoints return 401 | Request specs | M7 | — |
| R11 | Meaningful, fast, deterministic tests (brief) | Suite runs offline, time is frozen, coverage ≥ 90% is enforced (BE + FE) | SimpleCov / Vitest thresholds fail the run below 90 | every | — |
| R12 | Performance at 10k (implicit) | Directory and insights queries measured on 10k seed; indexes justified by EXPLAIN | `docs/evidence/performance.md` | M8 | — |
| R13 | Deployed + video demo (brief) | Public URL passes the smoke test; demo video linked in README | Smoke-test log + link | M9 | — |
| R14 | Incremental commits + AI artifacts (brief) | One commit per reviewed milestone; `ai-work-log.md` and `rejected-suggestions.md` kept current | `git log`, docs | every | — |
| R15 | FX indicative conversion (Phase 2) | Converted figures show rate, date and source; source salaries unchanged; no per-employee API call | Service spec with stubbed provider | M10 | — |

Every requirement has a proof plan; none is flagged.
