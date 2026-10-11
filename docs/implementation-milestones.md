# Implementation milestones

Each milestone is one small, reviewed commit, or a few. **Every commit pauses for Sravan's approval.** The coverage gate (≥ 90% BE and FE) applies from M1 onward.

| # | Milestone | Delivers | Proof |
|---|-----------|----------|-------|
| M0 | Scope and decision docs | This `docs/` folder, CLAUDE.md. **No app code.** | Review |
| M1 | Skeletons | `backend/` Rails 8.1 API (`/up`), `frontend/` Vite React TS shell, root `compose.yaml`, RSpec + SimpleCov(90), Vitest + coverage(90), RuboCop, ESLint, README setup | Test + build output |
| M2a | Employees module: data and seed | `Employee`, `Compensation` + constraints/indexes, `Acme::Reference`, deterministic seed of 10,000 | Model specs, seed spec, recorded counts / duplicate check / re-run |
| M2b | Employees module: search and filter directory (BE + FE) | `GET /employees` (+ show), `DirectoryQuery` (search, combined filters, salary range), React directory with filter bar, chips and URL state | Request specs, UI tests, sample responses |
| M2c | One container (pulled forward from M9 at Sravan's request) | Root multi-stage `Dockerfile` (React build + Rails), Rails serves SPA + API, compose = db + app | Request specs, production-mode smoke on :3000, browser run |
| M4 | Employee management | Create/edit/deactivate API + forms | Specs + UI tests |
| M5 | Salary history | `RecordChange` service, history API, history panel + "record change" form | Service/rollback specs, DB before/after evidence |
| M6 | Pay dashboard over GraphQL | `/graphql` (Insights query objects; depth/complexity/limit/bucket/timeout limits; introspection switch), GraphiQL at `/graphiql`, schema contract tests, dashboard with KPI tiles + 6 Highcharts charts (type switcher, table view), lazy-loaded | Hand-calculated fixture specs, limit specs, SQL cross-check on 10k, contract test, browser run, screenshots |
| M6b | Multi-select filters | Directory (`key[]`) and dashboard (`DashboardFilters` lists) take several values per filter (OR within, AND across, ≤ 50); Mantine MultiSelect with one chip per value; currency stays single | Request/GraphQL specs, UI tests, 10k SQL cross-check, screenshots |
| M7 | Auth and roles | `User` (combinable roles: viewer / hr_manager / admin), cookie sessions (12 h, digest stored, rate-limited sign-in), 401/403 on every API and GraphQL route, JSON-only mutations, audit author = user, login page, role-aware UI, Admin **Users** screen with roles multi-select, demo users + `users:create` | Role-by-endpoint matrix spec, session/rate-limit specs, UI tests per role, browser run per role, scan output |
| M10 | Reporting-currency conversion (**brought forward** from Phase 2: assessment workflow 4) | `fx_rates` cache (EUR base, dated, sourced), Frankfurter client (one request, short timeouts), `fx:refresh` (also at container start, non-fatal), `FxRefreshJob` on a Solid Queue recurring schedule (weekdays 16:30 Europe/Berlin, retried), cross rates in exact decimals, convert-then-aggregate analytics in SQL, GraphQL `converted(to:)`, UI reporting-currency choice with provenance under every converted chart, missing/stale/no-rate handling | Stubbed-provider specs, hand-calculated fixture, SQL cross-check on 10k, UI tests, browser run; one live `fx:refresh` (run on a networked machine) |
| M8 | Performance | EXPLAIN / timings on 10k seed; indexes only where justified | `docs/evidence/performance.md` |
| M9 | Deploy and demo | Host deploy of the M2c image, smoke test, demo video, README | URL + smoke log |
| M11 | Final review | Requirement-to-evidence matrix, limitations | Matrix with no unsupported PASS |

Optional, only if time allows after M11: Kubernetes manifests plus clearly labelled future-service templates.
