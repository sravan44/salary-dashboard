# ACME Salary Insights

Salary management for an HR Manager overseeing 10,000 employees across multiple countries: find people, record salary changes with full history, and understand how the organisation pays people, always per currency.

**Start here:** [requirements (one page)](docs/requirements.md) · [planning notes](docs/planning-notes.md) · [architecture diagrams](docs/architecture-diagrams.md) · [milestones](docs/implementation-milestones.md) · [AI work log](docs/ai-work-log.md)

| Part | Stack |
|------|-------|
| `backend/` | Ruby 3.3.6, Rails 8.1 (API mode), graphql-ruby, PostgreSQL 16, RSpec, SimpleCov, RuboCop, Brakeman, bundler-audit |
| `frontend/` | React 19 + TypeScript, Vite, Mantine, React Router, TanStack Query, Highcharts, GraphiQL, Vitest + React Testing Library |

## Demo sign-ins

`bin/rails db:seed` (and the Docker setup) creates one account per role:

| Email | Password | Roles | Can use |
|---|---|---|---|
| `admin@acme.example` | `local-demo-password` | Admin, HR manager, Viewer | Dashboard, Employees, **Users** (add people, change roles) |
| `hr@acme.example` | `local-demo-password` | HR manager | Dashboard, Employees (view salaries, create, edit, deactivate) |
| `viewer@acme.example` | `local-demo-password` | Viewer | Dashboard only (no individual employees or salaries) |

> **Local and demo use only.** The password is public, so in production these accounts are **never** created unless `DEMO_USER_PASSWORD` is set on purpose (for example, for a demo deployment), and then that password is used instead. Real deployments create users with `bin/rails users:create`, and Admins add people on the **Users** page. Existing accounts are never changed by re-seeding.

## Run with Docker (recommended)

One container runs the whole app: Rails serves the API **and** the built React app at http://localhost:3000. A second container runs PostgreSQL.

```bash
docker compose up --build    # no setup needed; builds the image, starts db + app, seeds 10,000 employees on first start
```
Local defaults (database password, secret key) live in `compose.yaml` and suit local use only; a `.env` file can override them.
- App: http://localhost:3000 · Health: http://localhost:3000/up · REST: http://localhost:3000/api/v1/employees
- GraphQL: `POST http://localhost:3000/graphql` · GraphiQL explorer: http://localhost:3000/graphiql (enabled locally via `GRAPHIQL_ENABLED`)

Build the image on its own with `docker build -t salary-insights .`. It runs in production mode; set `DATABASE_URL` (or `DB_*`) and `SECRET_KEY_BASE`. Leave `FORCE_SSL` at its default (`true`) behind an HTTPS proxy.

## Run natively (development, with hot reload)

Prerequisites: Ruby 3.3.6 (rbenv reads `backend/.ruby-version`), Node 22, PostgreSQL 16 running locally.

```bash
# Backend
cd backend
bundle install
DB_PASSWORD=<your local password> bin/rails db:prepare
bin/rails server              # http://localhost:3000

# Frontend (second terminal)
cd frontend
npm ci
npm run dev                   # http://localhost:5173
```
Database settings come from `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` (defaults: `localhost`, `5432`, `postgres`, empty).

Accounts (no sign-up page):
```bash
bin/rails users:seed_demo        # just the demo sign-ins above, without re-seeding employees
EMAIL=you@example.com ROLES=admin,hr_manager PASSWORD=<12+ chars> bin/rails users:create   # real deployments
```
After that, an Admin adds people and changes roles on the **Users** page.

## Exchange rates (reporting currency)

```bash
cd backend
bin/rails fx:refresh     # one request to Frankfurter (ECB reference rates); cached in fx_rates; safe to re-run
```
**Kept in sync automatically:** `FxRefreshJob` runs every weekday at 16:30 Frankfurt time (after the ECB publishes; `config/recurring.yml`) through **Solid Queue**, which runs inside Puma in the same container and stores its jobs in the same PostgreSQL database (no Redis, no second service). A provider failure is retried twice, 30 minutes apart; after that the cached rates stay, and the dashboard flags them as stale once they're more than 7 days old. The Docker image also refreshes once on start; if the provider can't be reached, the app still starts. Set `SOLID_QUEUE_IN_PUMA=false` to run `bin/jobs` as a separate process instead. Each app process keeps the rates in memory: a request costs one tiny version query, and the rates are re-read only after a refresh. On the dashboard, **Reporting currency** converts every salary at those rates (indicative only) and shows the rate, date and source under each converted chart. `FX_PROVIDER_URL` overrides the provider address (default `https://api.frankfurter.dev/v1`; HTTPS redirects are followed, up to 3).

## Seed data

```bash
cd backend
bin/rails db:seed                     # exactly 10,000 synthetic employees, random seed 42
SEED_EMPLOYEES=500 SEED_RANDOM=7 bin/rails db:seed
```
Re-running replaces all employees and salary history, and the same seed always gives identical data. In production it only replaces existing employees with `SEED_REPLACE=1`; `bin/rails app:seed_if_empty` (with `AUTO_SEED=true`) seeds only an empty database.

## Tests and quality checks

Both test suites **fail if coverage drops below 90%**.

```bash
# Backend
cd backend
bundle exec rspec                      # tests + SimpleCov gate (line and branch ≥ 90%)
bin/rubocop                            # style
bundle exec brakeman --no-pager -q     # static security analysis
bin/bundler-audit check                # known-vulnerable gems

# Frontend
cd frontend
npm run test:coverage                  # tests + coverage gate (lines/branches/functions/statements ≥ 90%)
npm run lint
npm run build                          # type-check + production build
```

## Project status
Built milestone by milestone (see [milestones](docs/implementation-milestones.md)). Each milestone's proof is in [`docs/evidence/`](docs/evidence/).
