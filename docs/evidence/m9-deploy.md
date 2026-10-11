# M9 evidence: deploy

**Decisions (Sravan), in order:**
1. **Fly.io** in Mumbai, with Fly Postgres. This was abandoned: Fly has no Mumbai region, and the trial stops machines after 5 minutes (below).
2. **Render + Neon** (free) was prepared, then dropped before it was used.
3. **Now: AWS EC2 t3.micro, deployed by Capistrano driving Docker.**
   - It's "Capistrano driving Docker" rather than Kamal; Sravan's choice.
   - The address is the Elastic IP over plain HTTP for now; a domain and HTTPS come later.
   - PostgreSQL runs in a container on the same instance.
4. **Demo sign-ins:** the three demo accounts, with a **private** password generated on the server, not the README one.

**Hypothesis:** the M2c image runs unchanged on one small server. Capistrano gives repeatable deploys with rollback, and the database survives both. The first start prepares a working demo on its own. Every role boundary holds over the network, and no secret is in git.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| C1 | `cap production deploy`: git checkout into a release folder → `docker compose up --build` → wait for `/up` (up to 5 min) and show the app log if it fails | **dry run PASS** (below); **live: NOT RUN** |
| C2 | Rollback runs the previous release the same way (the hook is on `deploy:published`, which rollback also fires); data in the named volume `salary_db-data` survives | `docker.rake`; `compose config` below; **live: NOT RUN** |
| C3 | No secrets in git: the host, login, key path and branch come from `deploy/deploy.env` (git-ignored; template `deploy.env.example`) or the shell, and the shell wins; `*.pem` is git-ignored; `shared/.env` (mode 600) is written on the server and linked into each release; Compose refuses to start without the secrets | compose check below |
| C4 | The database is not exposed (no published port); only port 80 (app) and 22 (SSH, your IP) are open | `compose.production.yaml`; README security group |
| C5 | One-time server setup: 2 GB swap, Docker + Compose + Buildx from Ubuntu packages, generated secrets; safe to re-run | `deploy/server-setup.sh` (bash syntax checked); **live: NOT RUN** |
| C6 | First start on an empty database: migrate, seed 10k, demo users, FX refresh (non-fatal) | rehearsals below; **on EC2: NOT RUN** |
| C7 | The image builds | **PASS on Fly's remote builder** (below); on EC2: NOT RUN |
| C8 | Smoke script: 16 checks over HTTP or HTTPS, exit 1 on any failure | `backend/script/smoke.rb`; rehearsals |
| C9 | Demo video | **NOT RUN** |

## Checks run here

```
$ ruby -c deploy/Capfile deploy/config/deploy.rb deploy/config/deploy/production.rb deploy/lib/capistrano/tasks/docker.rake
Syntax OK ×4
$ bash -n deploy/server-setup.sh
server-setup.sh syntax OK

$ docker compose -f compose.production.yaml config --quiet            # no secrets set
error while interpolating services.app.environment.DB_PASSWORD: required variable POSTGRES_PASSWORD is missing a value: set POSTGRES_PASSWORD in shared/.env
error while interpolating services.app.environment.SECRET_KEY_BASE: required variable SECRET_KEY_BASE is missing a value: set SECRET_KEY_BASE in shared/.env
$ POSTGRES_PASSWORD=x SECRET_KEY_BASE=y docker compose -f compose.production.yaml config
valid · name: salary · FORCE_SSL: "false" · DEMO_USER_PASSWORD: "" · published: "80" · volume salary_db-data
```

`deploy/deploy.env` loader (plain Ruby, no gem):
```
file values:            ["13.200.10.20", "ubuntu", "~/.ssh/salary-dashboard.pem", "main"]
shell overrides file:   BRANCH=feature → "feature"
template left empty:    Set DEPLOY_HOST in deploy/deploy.env (copy deploy/deploy.env.example) or in your shell   exit=1
$ git check-ignore -v deploy/deploy.env x.pem   → .gitignore:8 deploy/deploy.env · .gitignore:9 *.pem
```
The first test run failed on the template's non-ASCII comment characters in a US-ASCII locale; the file is now read as UTF-8.

**Capistrano dry run.** Capistrano 3.20.1 and its dependencies were copied from Sravan's gem cache (SHA-256 matched on both sides: capistrano `b0d54ba5…`, sshkit `be3f10b9…`, net-ssh `3364dedc…`). The run used a `deploy.env` pointing at a documentation address (`203.0.113.10`); that file was then removed.

```
$ cap -T
cap docker:health  # Wait until the app answers its health check
cap docker:logs    # Show the app's recent log (LINES=100)
cap docker:ps      # Show the containers' state
cap docker:up      # Build the image from the current release and (re)start the database and app containers
$ cap production deploy --dry-run        exit=0
git:check         git ls-remote https://github.com/sravan44/salary-dashboard.git HEAD
git:clone         The repository mirror is at /home/ubuntu/salary-dashboard/repo
git:create_release git archive main | tar -x -f - -C /home/ubuntu/salary-dashboard/releases/20261011055325
deploy:symlink:release  ln -s …/releases/20261011055325 …/current
docker:up         docker compose -f compose.production.yaml up --detach --build --remove-orphans
                  docker image prune --force
docker:health     Healthy: http://localhost/up      ← a dry run fakes every check, so this proves the order, not health
$ cap production deploy --dry-run   (no deploy.env, no DEPLOY_HOST)
Set DEPLOY_HOST in deploy/deploy.env (copy deploy/deploy.env.example) or in your shell
```
A rollback can't be dry-run meaningfully: it stops at `deploy:rollback_release_path`, because there are no releases without a server. That rollback re-runs `docker:up` relies on Capistrano firing `deploy:published` during rollback; that has to be checked live.

## Rehearsal of the first start (production mode, new empty database)

```
db:prepare: exit 0, 10.0 s, peak 137 MB   ← creates, migrates, seeds 10,000 employees, creates the demo users
app:seed_if_empty: exit 0, 0.8 s          (Database already has 10000 employees; not seeding.)
users:seed_demo: exit 0, 0.7 s            (Demo users already exist; left unchanged.)
fx:refresh: exit 1, 0.6 s                 (provider blocked here; the start continues)
```

The smoke test (with 6 rates labelled `TEST RATES – not real`) passed all 16 checks:

```
PASS  GET /up · GET / serves the app · GET /dashboard · GET /graphiql is off
PASS  signed out: employees 401 · graphql 401
PASS  viewer signs in (201) · cookie HttpOnly + SameSite=Lax · headcount 9227 · employees 403
PASS  FX rates available (USD) (2026-10-09 · TEST RATES – not real (smoke rehearsal) · included 9227 · excluded [])
PASS  hr signs in (201) · employees 200 (total 10000) · salary history in USD · users 403
PASS  sign out → 204, then 401
All checks passed.   exit=0
```

Without rates, the same script failed exactly the two FX checks, so it does catch a deploy that can't reach the provider.

**Memory, for the t3.micro's 1 GB:**
- The app with Solid Queue inside Puma: 5 processes, 508 MB RSS in total (overcounted, because the processes share memory).
- PostgreSQL: about 100 MB.
- The image build needs more, hence the 2 GB swap.

## What happened on Fly.io (2026-10-11)

| Step | Result |
|---|---|
| `fly postgres create --region bom` | `Error: region bom not found`: Fly has no India region |
| My zsh commands with inline `#` comments | `zsh: no matches found`: an empty demo password was saved (harmless: an empty value creates no users) |
| `fly launch` (run once by mistake) | Created a second app and rewrote `fly.toml` |
| `fly deploy --remote-only` | **The image built on Fly's builder**: the first real `docker build`, which isn't possible here (Docker Hub blocked) |
| First deploy | 2 app machines by default; the app assumes one |
| App start | `Missing secret_key_base` (secrets not set), then `PG::ConnectionBad` |
| Database log | **`Trial machine stopping. To run for longer than 5m0s, add a credit card`** |

Fly's trial stopped the database before the app's first start could finish. The Fly and Render configurations have been removed; only this record remains.

## Live on EC2 (to fill in from Sravan's terminal)
- `server-setup.sh` output: **NOT RUN**
- `cap production deploy` output (build, health): **NOT RUN**
- `ruby backend/script/smoke.rb http://<elastic-ip>`: **NOT RUN**
- `cap production deploy:rollback` and data kept: **NOT RUN**
- Demo video: **NOT RUN**

## What this does not prove (yet)
- **The live deploy and rollback.**
- **HTTPS.** Plain HTTP until a domain is pointed (A13).
- **Backups.** One instance and one volume; a `pg_dump` schedule isn't set up yet.
