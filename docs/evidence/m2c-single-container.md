# M2c evidence: frontend and backend in one Docker container

**Hypothesis:** one image runs the whole product. Rails serves the JSON API and the built React app on the same origin. Client-side routes and bookmarked links work on a full page load, unknown API paths stay JSON, missing asset files are not answered with the app page, and a new deploy is never hidden behind a cached `index.html`.

**Environment:** cloud Linux workspace, Rails 8.1.4 in `RAILS_ENV=production`, PostgreSQL 16.15 with the 10k seed, Chromium (Playwright), 2026-10-10.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| C1 | `/` and client routes (`/employees?...`) return the app page | request specs + curl below |
| C2 | `index.html` is sent with `Cache-Control: no-cache`; hashed assets are cached for a year | request spec + curl headers below |
| C3 | A missing `/assets/*.js` is a 404, not the app page | request spec + curl below |
| C4 | An unknown `/api/...` path is a JSON 404 | request spec + curl below |
| C5 | A clear message if the frontend was never built | request spec |
| C6 | Compose runs db + one app container on http://localhost:3000 | `docker compose config` + NOT RUN (below) |
| C7 | The app works end to end from :3000 only (no Vite), including a direct load and refresh of a filtered deep link | Chromium run below |

## Tests

```
$ bundle exec rspec
96 examples, 0 failures
Line coverage: 284 / 284 (100.00%)
Branch coverage: 68 / 68 (100.00%)
$ bin/rubocop          → 48 files inspected, no offenses detected
```
**Red before green:** `spec/requests/frontend_spec.rb` was run before the controller existed: `6 examples, 5 failures`. The one that passed was "missing asset → 404", which already held and had to keep holding.

## Docker

| Check | Result |
|-------|--------|
| `docker compose config --quiet` with **no `.env` file** | valid; services: `db`, `app`; local-only defaults applied (`POSTGRES_PASSWORD=postgres`, a non-production `SECRET_KEY_BASE`, `FORCE_SSL=false`) |
| `docker build .` | **NOT RUN.** This workspace's network policy blocks Docker Hub: `failed to resolve source metadata for docker.io/docker/dockerfile:1 … Forbidden` |

To run it on your Mac: `docker compose up --build`, then `docker compose exec app bin/rails db:seed`. Open http://localhost:3000. Expected: the image builds in three stages, `db` becomes healthy, then the `app` HEALTHCHECK on `/up` passes, and the app looks like the screenshot below.

## The image's layout, reproduced natively in production mode
Because the image could not be built here, its exact runtime layout was reproduced: `npm run build`, then `dist/assets → backend/public/assets`, `dist/index.html → backend/frontend/index.html`, then `RAILS_ENV=production FORCE_SSL=false bin/rails db:prepare && db:seed && rails s -p 3000`.

```
Seeded 10000 employees, 32915 salary records (10000 current) with random seed 42 in 9.6s
```

Raw output: [`m2c-single-container-smoke.txt`](m2c-single-container-smoke.txt)

| Request to :3000 | Status | Content-Type | Cache-Control |
|------------------|--------|--------------|---------------|
| `/up` | 200 | text/html | — |
| `/` | 200 | text/html (app page) | **no-cache** |
| `/employees?country=IN&page=2` | 200 | text/html (app page) | **no-cache** |
| `/assets/index-fTh4ZApF.js` | 200 | text/javascript | **public, max-age=31556952** (1 year) |
| `/assets/missing-abc123.js` | **404** | — | — |
| `/api/v1/employees?per_page=1` | 200 | application/json | — |
| `/api/v1/does-not-exist` | **404** | application/json `{"error":{"code":"not_found",…}}` | — |

**Chromium, :3000 only (no Vite dev server running):**
```
loaded: http://localhost:3000/employees?country=DE&department=Engineering&currency=EUR&sort=-salary
Showing 1–25 of 289
first row: EMP-000102 Kavya Rao DE Engineering Engineering Manager 2025-04-28 TERMINATED €168,900
API origins used: http://localhost:3000/api/v1/reference, http://localhost:3000/api/v1/employees
after browser refresh, still filtered: true | Showing 1–25 of 289
```
SQL check: DE + Engineering + EUR current salaries = **289**.
Screenshot: [`screenshots/m2c-single-container.png`](screenshots/m2c-single-container.png)

## First run on the Mac: boot crash, fixed
`docker compose up --build` on Sravan's Mac: `db` healthy, then `app` crashed with `Bundler::PermissionError … write to /app/Gemfile.lock`.

| Cause | Fix | Proof here |
|-------|-----|------------|
| The lockfile's `CHECKSUMS` section had **96 empty entries** (gems were installed offline, so no checksums were recorded). Bundler tries to fill them at every boot, which rewrites the lockfile; the non-root app user can't write it. | Removed the `CHECKSUMS` section. An offline-resolved lockfile can't have complete checksums: 17 entries are Ruby default gems with no `.gem` file. | Boot as a non-root user with a read-only lockfile: original → `PermissionError`; 79/96 checksums → frozen refuses (`empty CHECKSUMS entry for "base64"`); **no section → boots** (frozen and not frozen) |
| The image's `COPY backend/ ./` overwrote the lockfile that `bundle install` had just updated with the Mac's platform (`aarch64-linux`). | Keep the resolved lockfile across that copy; `BUNDLE_FROZEN=true` at runtime so the app never rewrites it. | Image runtime simulated: root-owned read-only app dir, non-root user, frozen bundle, production → `/up`, `/`, `/employees`, `/api/v1/employees` all 200; lockfile unchanged |

## Second run on the Mac: no employees, fixed
The app started but showed no employees. Seeding was a manual step, and inside the production-mode container `db:seed` refused unconditionally (`SEED_REPLACE` guard), even for an empty database.

Fix: the container start runs `bin/rails app:seed_if_empty` (enabled by `AUTO_SEED=true` in compose), and the production guard now only protects **existing** employees.

| Database at container start (simulated image runtime: non-root, frozen bundle, production) | Result |
|---|---|
| brand-new | `Seeded 10000 employees …` (Rails' `db:prepare` seeds a database it creates), API total 10000 |
| exists but empty | `Seeded 10000 employees …` via `app:seed_if_empty`, API total 10000 |
| already seeded (restart) | `Database already has 10000 employees; not seeding.` |
| manual `db:seed` on a non-empty production database | `Refusing to replace 10000 existing employees in production. Set SEED_REPLACE=1 to confirm.` |

Specs: `spec/tasks/seed_if_empty_spec.rb` (empty → seeds, existing → untouched, `AUTO_SEED` off → nothing); written first, failed with `Don't know how to build task 'app:seed_if_empty'`. Suite: `99 examples, 0 failures`, line 292/292, branch 72/72.

## What this does not prove
- **That the image itself builds and starts** (NOT RUN above). Building it on the Mac is the remaining check.
- **Gem install inside Docker** relies on rubygems.org being reachable from the build machine, which it is from a normal Mac. The lockfile lists only `x86_64-linux`, so on Apple Silicon Bundler adds `aarch64-linux` during the build (see rejected-suggestions: frozen lockfile deferred).
