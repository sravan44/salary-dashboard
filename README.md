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

## Deploy to AWS EC2 (Capistrano + Docker)

Step-by-step runbook: [`deploy/README.md`](deploy/README.md).

**Capistrano** deploys to one **t3.micro** (Ubuntu 24.04; the running instance is in Frankfurt, `eu-central-1`). Each deploy works like this:
1. Capistrano checks the repository out into a new release folder on the server.
2. **Docker Compose** (`compose.production.yaml`) builds the image from that release.
3. Compose replaces the app container behind **Caddy**, which serves HTTPS once a domain is set. PostgreSQL runs in its own container, and its named volume survives every deploy and rollback.
4. The deploy waits until `/up` answers.

The first start migrates, seeds the 10,000 employees, creates the demo sign-ins and fetches exchange rates; later starts change nothing. The weekday rate refresh runs inside the app, because the server is always on.

**1. Create the instance** (AWS console; any region, ideally one near your users)
- **Instance:** Ubuntu Server 24.04 LTS (x86_64), **t3.micro**, 20 GB gp3 disk.
- **Key pair:** save it as `~/.ssh/salary-dashboard.pem`, then run `chmod 600` on it.
- **Security group:** SSH (22) from **My IP** only; HTTP (80) and HTTPS (443) from anywhere.
- **Elastic IP:** allocate one and associate it with the instance, so the address survives restarts.

**2. Prepare the server once**

This installs 2 GB of swap (the image build needs more than 1 GB) and Docker with Compose. It also writes the secrets to `~/salary-dashboard/shared/.env` on the server only, and prints the private demo password once.
```bash
ssh -i ~/.ssh/salary-dashboard.pem ubuntu@<elastic-ip> 'bash -s' < deploy/server-setup.sh
```

**3. Deploy** (from your machine; the first deploy builds the image on the server and takes several minutes)

Fill in your instance's details once, in a git-ignored file:
```bash
cd deploy
cp deploy.env.example deploy.env
bundle install
bundle exec cap production deploy
```
In `deploy.env`, set `DEPLOY_HOST` (the Elastic IP), `DEPLOY_USER` (`ubuntu`), `DEPLOY_KEY` (the path to your `.pem`) and `BRANCH`. No AWS/IAM access keys are needed: Capistrano only uses SSH. A variable set in your shell overrides the file. `deploy/deploy.env` and `*.pem` files are git-ignored.

Other commands:
- `bundle exec cap production deploy:rollback`: run the previous release again; the data stays.
- `bundle exec cap production docker:ps`: show the containers' state.
- `bundle exec cap production docker:logs`: show the app's recent log.

**4. Check it**
```bash
SMOKE_PASSWORD='<demo password>' ruby backend/script/smoke.rb http://<elastic-ip>
```
`backend/script/smoke.rb` uses the Ruby standard library only. It checks:
- health and the app page;
- 401 when signed out, and viewer and HR access (200/403);
- cookie flags;
- exchange rates with their source, and salary history in USD;
- sign-out.

Over HTTPS it also checks the redirect and HSTS. It exits non-zero on any failure.

**HTTPS.** Caddy runs in front of the app (`deploy/Caddyfile`). With `APP_HOST` set to a domain in the server's `shared/.env`, Caddy gets a Let's Encrypt certificate, renews it, and redirects http to https. Without `APP_HOST`, it serves plain HTTP on the IP. To switch HTTPS on:
1. Point the domain's A record at the server's IP.
2. Open port 443 in the security group.
3. Set `APP_HOST=<domain>` and `FORCE_SSL=true` in `shared/.env`.
4. Deploy. The exact commands are in [`deploy/README.md`](deploy/README.md).

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

**Passwords and account emails:**
- An Admin can add a user without a password; nothing is sent at that point.
- On the **Users** page (filterable by email, role and password status), the Admin picks users in a multi-select and sends them a **password link**. Users without a password get a set-password link, valid 24 hours; others get a reset link, valid 2 hours. Each link works once.
- An Admin can also set a password directly.
- Anyone can **change their own password** (header → *Change password*) or use **Forgot password?** on the sign-in page.
- No email ever contains a password.

**Demo email inbox (extended behaviour, beyond the accepted scope).** So the password links can be tried without a real mailbox, emails can be kept in an inbox page ([letter_opener_web](https://github.com/fgrehm/letter_opener_web)) instead of being sent:
- **Admins only.** Sign in as an Admin, then use **Email inbox (demo)** in the menu (`/letter_opener`; in development also http://localhost:5173/letter_opener). Anyone else, signed in or not, never sees it.
- **Development and local Docker:** on (`compose.yaml` sets `EMAIL_INBOX=true`). **A server:** only with `EMAIL_INBOX=true` in its `.env`, and only while SMTP isn't set; SMTP always wins. Each deploy empties the inbox.
- **This is for the demo only.** In production, email will go out through SMTP (`SMTP_USERNAME`, `SMTP_PASSWORD` and optionally `MAIL_FROM`; see `.env.example` and [`deploy/README.md`](deploy/README.md)), with `EMAIL_INBOX` left off.

## Exchange rates (reporting currency)

```bash
cd backend
bin/rails fx:refresh     # one request to Frankfurter (ECB reference rates); cached in fx_rates; safe to re-run
```
**Kept in sync automatically:** `FxRefreshJob` runs every weekday at 16:30 Frankfurt time (after the ECB publishes; `config/recurring.yml`) through **Solid Queue**, which runs inside Puma in the same container and stores its jobs in the same PostgreSQL database (no Redis, no second service). A provider failure is retried twice, 30 minutes apart; after that the cached rates stay, and the dashboard flags them as stale once they're more than 7 days old. The Docker image also refreshes once on start; if the provider can't be reached, the app still starts. Set `SOLID_QUEUE_IN_PUMA=false` to run `bin/jobs` as a separate process instead. Each app process keeps the rates in memory: a request costs one tiny version query, and the rates are re-read only after a refresh. Admins can also see the cached rates on the **Exchange rates** page (third link in an Admin's menu) and fetch fresh ones with **Sync rates** (up to 5 times per 10 minutes; if the provider fails, the cached rates stay). On the dashboard, **Reporting currency** converts every salary at those rates (indicative only) and shows the rate, date and source under each converted chart. `FX_PROVIDER_URL` overrides the provider address (default `https://api.frankfurter.dev/v1`; HTTPS redirects are followed, up to 3).

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
