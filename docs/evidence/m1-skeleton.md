# M1 evidence: application skeletons (backend + frontend)

**Hypothesis:** both apps boot, their test suites run with a coverage gate that **fails below 90%**, lint and security checks are clean, and the frontend reaches the backend through the dev proxy.

**Environment:** cloud Linux workspace, Ruby 3.3.6, Node 22.22, PostgreSQL 16.15 (local cluster), 2026-10-10.

## Backend (Rails 8.1.4 API)

| Check | Command | Actual result |
|-------|---------|---------------|
| Tests + coverage | `bundle exec rspec` | `1 example, 0 failures`; `Line coverage: 3 / 3 (100.00%)` |
| Gate fails below 90% | add an untested `app/models/gate_probe.rb`, run `bundle exec rspec`, remove it | `Line coverage (71.42%) is below the expected minimum coverage (90.00%)`; `SimpleCov failed with exit 2`; **exit code 2** |
| Style | `bin/rubocop` | `21 files inspected, no offenses detected` |
| Static security | `bundle exec brakeman --no-pager -q` | `Errors: 0`, `Security Warnings: 0` |
| Vulnerable gems | `bin/bundler-audit check` (advisory DB dated 2026-10-07) | First run: **net-imap 0.4.9.1** (4 DoS CVEs) and **uri 0.13.1** (CVE-2025-27221, CVE-2025-61594), both pulled in by Rails. Fixed with `bundle lock --update net-imap` / `uri` → 0.6.7 / 1.1.2. Re-run: `No vulnerabilities found` |
| Health endpoint | `curl localhost:3000/up` | `200` |

## Frontend (React 19 + TypeScript, Vite)

| Check | Command | Actual result |
|-------|---------|---------------|
| Tests + coverage | `npm run test:coverage` | `Tests 4 passed (4)`; all files 100% statements/branches/functions/lines |
| Gate fails below 90% | add an untested `src/gate-probe.ts`, run, remove it | `ERROR: Coverage for lines (84.48%) does not meet global threshold (90%)` (also functions 80%, branches 83.33%); **exit code 1** |
| Lint | `npm run lint` | no output (0 problems) |
| Type-check + build | `npm run build` | `✓ built in 2.58s` |

Tests (behavior, not implementation): shows product name and main navigation · opens the dashboard by default · navigates to Employees from the menu · redirects unknown paths to the dashboard.

## End to end (native)

| Step | Actual result |
|------|---------------|
| `curl localhost:5173/` | `<title>ACME Salary Insights</title>` |
| `curl localhost:5173/api/v1/nothing` (Vite proxy → Rails) | `404`, and the Rails log shows `Started GET "/api/v1/nothing"`, which proves the proxy reaches Rails |

## Docker Compose

| Check | Actual result |
|-------|---------------|
| `docker compose config --quiet` (with `POSTGRES_PASSWORD` set) | valid |
| Without `POSTGRES_PASSWORD` | refuses: `required variable POSTGRES_PASSWORD is missing a value` |
| `docker compose up --build` | **NOT RUN.** Docker Hub (`registry-1.docker.io`) is blocked by this workspace's network policy. Run on the Mac: `cp .env.example .env && docker compose up --build`. Expected: `db` healthy → `backend` healthy (`/up` 200) → UI at http://localhost:5173 |

## Environment note: offline gem install
rubygems.org is blocked by the network allowlist. The gems were installed **offline** from the cached `.gem` files in Sravan's local rbenv Ruby 3.3.6 (`gem install --local`, `bundle install --local`). Nothing came from an unofficial mirror. `Gemfile.lock` lists only `x86_64-linux-gnu`; the first `bundle install` on the Mac (which has internet) adds `arm64-darwin` automatically.

## What this does not prove
That the Compose stack builds (NOT RUN, above), or anything about business features, which start in M2.
