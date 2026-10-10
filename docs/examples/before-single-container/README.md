# Before: three containers (M1, `0675f36`). Reference only

These files are kept exactly as they were in M1 to show how the setup evolved. They are **not used** and are **not runnable from this folder**: the compose file's build paths point to `./backend` and `./frontend`, where these Dockerfiles used to live.

| File here | Was at | Role then |
|-----------|--------|-----------|
| `compose.yaml` | `/compose.yaml` | Three services: `db`, `backend` (Rails dev server), `frontend` (Vite dev server, proxying `/api` to `backend`) |
| `backend.Dockerfile.dev` | `backend/Dockerfile.dev` | Rails in development mode, source mounted for live reload |
| `frontend.Dockerfile.dev` | `frontend/Dockerfile.dev` | Vite dev server on :5173 |

## Before → after

| | Before (M1) | After (M2c, current) |
|---|---|---|
| Containers | db + backend + frontend | db + **one app** |
| Address | UI :5173, API :3000 (proxied) | everything on **:3000**, one origin |
| Mode | development servers | production build (React compiled; Rails in production mode) |
| Image | two dev images | one multi-stage `/Dockerfile`: Node build → gems → slim non-root runtime with healthcheck |
| Setup | `.env` required | none (local defaults in `compose.yaml`) |
| Data | manual `db:seed` | an empty database is seeded automatically on start |

## Why it changed
- **One deployable unit:** the same image runs locally and on the host, so there is nothing extra to keep in step.
- **One origin:** no CORS, and same-site cookies once login arrives.
- **Closer to production:** the local run exercises the real build, caching headers and boot path. That is how the lockfile and seeding problems surfaced (see `docs/evidence/m2c-single-container.md`).

Hot-reload development still runs natively: `bin/rails s` and `npm run dev`.
