# M7 evidence: sign-in and roles

**Hypothesis:** nobody reaches data without signing in. Each role reaches exactly what it should, on the server as well as in the UI. Sessions are safe to hold in a browser. Admins can manage roles without locking everyone out.

**Decisions (Sravan):**
- Three roles: Viewer, HR manager and Admin. A user may hold several (chosen with a multi-select), and their access is the union.
- A Viewer sees only the dashboard, with all figures shown for now (hiding small groups is deferred, see A19).
- Accounts come from seeded demo users, a `users:create` command, and the Admin screen.

**Environment:** cloud Linux workspace, Rails 8.1.4, bcrypt 3.1.22 (from Sravan's rbenv cache; SHA-256 `1f0072e8…f29032` matched on both sides), PostgreSQL 16 with the 10k seed, React 19 + Mantine 7, Chromium (Playwright), 2026-10-10.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| A1 | Every API and GraphQL request needs a signed-in user (401); health check and app page stay open | role-by-endpoint matrix spec; curl below |
| A2 | Roles decide access: 9 endpoints × {signed out, viewer, hr_manager, admin} | `spec/requests/authorization_spec.rb` (matrix), plus a combined-roles case |
| A3 | Session: random token in an HttpOnly, SameSite=Lax cookie (Secure over HTTPS); only its SHA-256 digest is stored; 12 h expiry; sign-out ends it at once | session model + request specs; DB check below |
| A4 | Same 401 for an unknown email and a wrong password; 10 attempts per 3 min per IP, then 429 | request specs; live curl below |
| A5 | Writes are JSON-only (415 otherwise) | spec; curl below |
| A6 | Audit author = the signed-in user; password digests never logged | specs; DB check below |
| A7 | Users: Admin lists, adds (12–72 character password, 1+ known roles) and changes roles; never removes their own or the last Admin role (rows locked) | users request specs + UI tests + browser |
| A8 | Accounts: `users:seed_demo` (only with `DEMO_USER_PASSWORD`, never changes existing users), `users:create` (password from the environment, never printed) | rake task specs |
| A9 | UI: login page with "return to" after a redirect; header with user and roles; nav and pages by permission; "no access" message; expired session → login; deliberate sign-out → a fresh login page | 11 auth + 7 users UI tests; browser run |

## Tests

```
backend:  227 examples, 0 failures · Line 740/740 (100%) · Branch 150/150 (100%)
          rubocop 101 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: 95 tests passed · lines 99.5% · branches 97.24% · functions 99.41%
          eslint 0 problems · tsc + vite build OK · npm audit (prod): 0 vulnerabilities
```

**Red before green:**
- Backend specs failed with `uninitialized constant User` / `Session`.
- Once sign-in was enforced, all 58 existing request specs failed with 401, as expected. They now sign in with the least role they need (viewer for GraphQL and reference data, HR for employees).
- 11 of the new UI tests failed before the auth code existed.

## Bugs found by the tests and the browser (each fixed and covered by a test)
1. **The "JSON-only" protection existed only in a comment.** The code said writes were JSON-only, but a plain HTML form POST was accepted. **Fix:** 415 `json_required` for any POST/PATCH that isn't JSON, plus a spec.
2. **The layout crashed on sign-out.** It re-rendered with no user before the guard redirected; in the browser that is a blank page. **Fix:** the layout renders nothing without a user.
3. **A failed sign-in check looked like "signed out".** If `GET /session` failed (for example, the server was down), people were sent to the login page. **Fix:** a clear "Could not check your sign-in" message.
4. **Sign-out sent the next person to the previous user's page (browser).** The login page remembered where the last user had been, so a viewer could land on an Employees "no access" page. **Fix:** a deliberate sign-out starts on a plain login page. An expired session still returns the same person to where they were.

## Live checks on the 10k seed (dev server, production build of the UI)

```
signed out:  GET /api/v1/employees 401 · POST /graphql 401 · GET /up 200 · GET /employees (app page) 200
form-encoded POST /api/v1/session → 415
11 failed sign-ins in a row → 401 ×5, then 429 ×6 (6 attempts had already been used by the browser run; limit 10 per 3 min)
viewer: sign in 201 → POST /graphql {"data":{"dashboard":{"headcount":9227}}} · GET /graphiql 200 → sign out 204 → POST /graphql 401
```

**Browser run:**

| Who | Result |
|---|---|
| Signed out, opening `/employees?country=IN` | Redirected to `/login?next=%2Femployees%3Fcountry%3DIN`; a wrong password shows "Email or password is incorrect" |
| viewer@ | Nav: Dashboard only. `/employees` → "You don't have access to this page." Dashboard shows 9,227. Calling the employees API directly → **403** |
| hr@ | Nav: Dashboard, Employees. Directory "Showing 1–25 of 10,000" |
| admin@ (Admin + HR manager) | Nav: Dashboard, Employees, Users. Added priya.new@ as Viewer, then changed her roles to Viewer + HR manager ("Saved"). Removing own Admin role refused: "You cannot remove your own Admin role" |
| priya.new@ (new account) | Signs in with the first password; nav: Dashboard, Employees; header shows both roles |

The only console errors were the browser logging deliberate 401/403/422 responses.

**Database after the run:**

```
create | admin@acme.example | {"email":[null,"priya.new@acme.example"],"roles":[[],["viewer"]]}
update | admin@acme.example | {"roles":[["viewer"],["viewer","hr_manager"]]}
password_digest logged anywhere: false
sessions stored: 5, token column holds digests only: true
```

The test user, its audit rows and the sessions were then removed. The local database keeps the three demo users.

## Screenshots
- [`m7-login-error.png`](screenshots/m7-login-error.png): sign-in with a wrong password.
- [`m7-viewer-dashboard.png`](screenshots/m7-viewer-dashboard.png): a Viewer sees only the dashboard.
- [`m7-users-admin.png`](screenshots/m7-users-admin.png): the Users screen, with roles multi-selects, "Saved", and the refused self-demotion.
- [`m7-header-roles.png`](screenshots/m7-header-roles.png): the signed-in user with two roles.

## What this does not prove
- **Small-group inference by Viewers.** Deferred by decision (A19).
- **Password reset and disabling accounts.** Deferred.
- **Rate limiting across several containers.** It uses a per-process store.
- **`docker build`: NOT RUN** (Docker Hub is blocked here). The new `users:seed_demo` start step and the `DEMO_USER_PASSWORD` compose variable are therefore untested inside the container. The task itself has specs.
