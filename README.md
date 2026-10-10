# ACME Salary Insights

Salary management for an HR Manager overseeing 10,000 employees across multiple countries: find people, record salary changes with full history, and understand how the organisation pays people, always per currency.

**Start here:** [requirements (one page)](docs/requirements.md) · [planning notes](docs/planning-notes.md) · [architecture diagrams](docs/architecture-diagrams.md) · [milestones](docs/implementation-milestones.md) · [AI work log](docs/ai-work-log.md)

| Part | Stack |
|------|-------|
| `backend/` | Ruby 3.3.6, Rails 8.1 (API mode), PostgreSQL 16, RSpec, SimpleCov, RuboCop, Brakeman, bundler-audit |
| `frontend/` | React 19 + TypeScript, Vite, Mantine, React Router, Vitest + React Testing Library |

## Run with Docker (recommended)

```bash
cp .env.example .env          # then set POSTGRES_PASSWORD
docker compose up --build
```
- UI: http://localhost:5173 (calls to `/api` are proxied to the backend)
- API health: http://localhost:3000/up

## Run natively

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
