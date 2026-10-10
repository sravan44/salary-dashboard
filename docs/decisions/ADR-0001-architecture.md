# ADR-0001: Modular Rails monolith + React SPA, PostgreSQL, one repo

**Status:** Proposed (pending review)

## Context
We need a full-stack salary tool for one persona (HR Manager), 10,000 employees, and a ~2-day budget. It must be deployed and demoed. The role is Ruby on Rails.

## Options considered
1. **Rails API + React SPA in one repo, served from one container** (chosen)
2. Rails full-stack (Hotwire): fewer moving parts, but the brief asks for React/Next.
3. Next.js full-stack: fewer toolchains, but sidelines the Rails skills the role is about.
4. Microservices (salary, employees, future paystubs): no independent scaling, ownership or security boundary exists today. That adds deployment and consistency cost for no benefit.

## Decision
- One Git repo with `backend/` (Rails 8 API) and `frontend/` (React + TS via Vite) and a root `compose.yaml` for development.
- **PostgreSQL** in dev, test and prod for parity: partial unique indexes, `percentile_cont` for medians, CHECK constraints. SQLite was considered and rejected, because it lacks `percentile_cont` and differs from prod.
- In production, Rails serves the compiled SPA from `public/`. This gives one deployable unit and same-origin cookie auth, so no CORS or token storage in JS.
- Effective-dated, append-only `compensations` table (see domain-model.md).
- Analytics are grouped by currency. FX conversion is a later, bounded Phase 2.

## Consequences
- **+** Simple to run, test and deploy; business rules live in one codebase; transactions are trivial.
- **−** Two toolchains (Ruby, Node), and the Docker build is multi-stage.
- **−** Future service extraction needs module boundaries kept clean now (services and queries per domain folder).

## Evidence required
Request specs per endpoint, the rollback spec for salary change, measured query plans on the 10k seed, and a deployed smoke test.

## Revisit when
A domain needs independent release cadence, scaling, data ownership or security isolation (e.g. a paystub PDF generation load).
