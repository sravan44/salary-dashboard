# Implementation milestones

Each milestone is one small, reviewed commit, or a few. **Every commit pauses for Sravan's approval.** The coverage gate (≥ 90% BE and FE) applies from M1 onward.

| # | Milestone | Delivers | Proof |
|---|-----------|----------|-------|
| M0 | Scope and decision docs | This `docs/` folder, CLAUDE.md. **No app code.** | Review |
| M1 | Skeletons | `backend/` Rails 8.1 API (`/up`), `frontend/` Vite React TS shell, root `compose.yaml`, RSpec + SimpleCov(90), Vitest + coverage(90), RuboCop, ESLint, README setup | Test + build output |
| M2 | Schema and seed | `Employee`, `Compensation` + constraints/indexes, `Acme::Reference`, deterministic seed of 10,000 | Model specs, seed spec, recorded counts / duplicate check / re-run |
| M3 | Search and filter directory | `GET /employees` (+ show), `DirectoryQuery` (search, combined filters, salary range), React directory with filter bar, chips and URL state | Request specs, UI tests, sample responses |
| M4 | Employee management | Create/edit/deactivate API + forms | Specs + UI tests |
| M5 | Salary history | `RecordChange` service, history API, history panel + "record change" form | Service/rollback specs, DB before/after evidence |
| M6 | Pay insights and charts | `PayStatsQuery`, summary/distribution/pay endpoints with shared filters; dashboard with KPI tiles, 3 Recharts charts, currency selector, table view | Hand-calculated fixture spec, histogram sum spec, UI tests, screenshot |
| M7 | Auth and security | `User`, session login, 401 on protected routes, Brakeman + bundler-audit + npm audit | Request specs, scan output |
| M8 | Performance | EXPLAIN / timings on 10k seed; indexes only where justified | `docs/evidence/performance.md` |
| M9 | Deploy and demo | Production Dockerfile, host deploy, smoke test, demo video, README | URL + smoke log |
| M10 | Phase 2: FX | Frankfurter adapter, rate cache table, reporting-currency view | Stubbed-provider specs + one manual live smoke test |
| M11 | Final review | Requirement-to-evidence matrix, limitations | Matrix with no unsupported PASS |

Optional, only if time allows after M11: Kubernetes manifests plus clearly labelled future-service templates.
