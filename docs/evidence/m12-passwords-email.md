# M12 evidence: passwords and account emails

**Decisions (Sravan):**
- **New user:** the Admin either types a password, or leaves it empty. No email ever contains a password. Emailing passwords was the original idea; Sravan chose links after I raised the risk.
- **Then (follow-up request):** don't email on creation. The Admin picks users in a **multi-select** and sends password links when ready, and the Users page gets **filters**.
- **Password features:** change my password, Admin sends a reset link, forgot password, and the Admin can also set a password directly.
- **Delivery:** Gmail SMTP, with the credentials in the server's `.env`.

**Hypothesis:** every account can get a password without one ever being sent, read by an Admin, or logged. Links expire, work once, and stop working after any password change. Asking for a link reveals nothing about which emails have accounts. Every change is audited and ends the user's other sessions.

**Environment:** cloud Linux workspace, Rails 8.1.4 (Action Mailer enabled; the only new gem is development-only `letter_opener_web`), PostgreSQL 16, React 19, 2026-10-11.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| P1 | Admin adds a user with a password, or without one; **nothing is emailed on creation**, and the invited account holds a random password nobody knows (`password_set: false`) | `spec/requests/api/v1/users_spec.rb`; UI test |
| P2 | Admin sets a user's password; that user is signed out everywhere; audited as the Admin | users request spec; UI test (dialog, field errors, cancel) |
| P3 | Admin multi-selects users (or "everyone shown" by the filters) and sends password links: a set-password link (24 h) to invited users, a reset link (2 h) to others; 1–50 distinct users; nothing is sent if any user doesn't exist | users request spec (4 cases); mailer spec; UI tests |
| P3b | Users page filters by email (search), role and password status (multi-selects; OR within, AND across), with "Clear filters" and a "Showing n of m" count | UI tests |
| P4 | Forgot password: same 202 answer for known and unknown emails; 5 requests per 15 min per IP | `password_resets_spec.rb`; UI test; end-to-end run |
| P5 | Change my password: current password checked; this session stays, others end | `passwords_spec.rb`; UI test; end-to-end run |
| P6 | Links are signed, expire (2 h / 24 h), work once, stop working after any password change, can't be swapped between kinds; 10 link attempts per 15 min per IP, **counted separately** from requests | `user_password_tokens_spec.rb`, `password_resets_spec.rb` |
| P7 | Token after `#`, never in the request log; request parameters filtered | end-to-end run (below) |
| P8 | Gmail SMTP from `SMTP_USERNAME` / `SMTP_PASSWORD` in the server's `.env`; the `/letter_opener` inbox in development (letter_opener_web); memory in tests; without SMTP, no email is sent and a warning is logged | `config/environments/*.rb`; `compose.production.yaml`; **live Gmail send: NOT RUN** |
| P9 | Access: setting someone else's password or sending password links is Admin only (401 / 403 / 403 / 200 or 202); change mine needs sign-in; the link endpoints are open | `spec/requests/authorization_spec.rb` (5 new rows) |
| P10 | Audit: each password change records `password_changed_at` and who did it (`"<email> (link)"` for links), never the password or digest | `set_password_spec.rb`; request specs |

## Tests

```
backend:  355 examples, 0 failures · Line coverage 100% · Branch coverage 100%
          rubocop 151 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: 142 tests passed (was 120) · lines 99.53% · branches 96.23% · functions 99.21%
          eslint 0 problems · tsc OK · vite build OK
```

**Red before green:**
- The new backend specs failed to load with `uninitialized constant UserMailer` and `Users::SetPassword`.
- For the follow-up (bulk links, no email on create), the changed specs failed 5 of 40 before the code.
- The frontend password tests failed on missing pages and links.
- **Exception:** for the follow-up's UI (filters and the links multi-select), I wrote the screen before its tests, so those tests were never seen failing.

**A flaky run:** one full frontend run with coverage reported 1 failed test out of 142. The next 9 runs (5 plain, 4 with coverage) all passed, and I didn't keep that run's output, so the test is not identified. The suite's timeout is 15 s, and the Users tests take up to about 1.7 s each.

## Found while building

1. **Rate limits shared one counter (a real bug).** Rails keys a rate limit by controller and IP, so "Forgot password?" requests and link attempts were counted together: 5 bad link attempts would have blocked asking for a new link. A spec reproduced it (`11 examples, 1 failure` without the fix). Naming each limit (`request-link`, `use-link`) fixed it.
2. **Mantine's `Alert` ignores a custom `role`.** It always renders `role="alert"`, so my `role="status"` on success messages did nothing. I removed the misleading prop, and the tests now assert what is actually rendered.
3. **An unreachable branch.** The token's salt is never nil (every account has a digest), so the `&.` came out instead of being tested.
4. **The build's stricter type check** caught a possibly-null error access that `tsc --noEmit` allowed. Fixed.
5. **My own limit test was wrong.** It sent the same user 51 times to test the 50-user limit, but the server counts distinct users (1), as intended. The test now sends 51 different IDs.

## End-to-end run (development server, emails written to `tmp/mails`; the development inbox replaced this later, see below)

```
1. admin signs in                                          201
2. admin adds e2e.invite@acme.example, no password         {"password_set":false, ...}   (this run predates the follow-up: creation then sent the invitation; it is now sent from the multi-select)
3. the email   From: no-reply@acme.example · To: e2e.invite@acme.example · Subject: Your ACME Salary Insights account
               "Choose your password here (the link works once and expires in 24 hours):
                http://localhost:3000/reset-password#token=eyJfcmFpbHMi…"   (no password anywhere in it)
4. invited user signs in before choosing a password        401
5. the link sets the password                              204
6. the same link again                                     422 invalid_token "This link is invalid or has expired. Ask for a new one."
7. the new user signs in                                   201
8. they change their own password                          204
9. admin list                                              e2e.invite@acme.example password_set: true
10. forgot password, unknown and known email               identical 202 bodies; a mail file only for viewer@acme.example
11. request log                                            Parameters: {"token"=>"[FILTERED]", "password"=>"[FILTERED]", …}
```

**What the log check found:** the token never appears in a request line. It did appear 3 times in the development log, because Rails' mailer writes whole email bodies at **debug** level (`debug { event.payload[:mail] }`), and development runs at debug. Production logs at `info` (`RAILS_LOG_LEVEL` defaults to info), where only `Delivered mail <id>` is written. The token isn't stored in the job queue either: the job carries only the user, and the token is generated when the email is built. The test account was removed afterwards.

## Development inbox (letter_opener_web, follow-up request)

Sravan asked for letter_opener, then for letter_opener_web's inbox page. Both gems came from his Mac's gem cache (SHA-256 checked on both sides). It is in the Gemfile's `development` group only; the engine is mounted at `/letter_opener` only when `Rails.env.development?`, and Vite proxies the same path.

```
bin/rails runner '… UserMailer.password_reset(viewer).deliver_now …'
  delivery: letter_opener_web -> viewer@acme.example
GET /letter_opener/                 200  lists "Reset your ACME Salary Insights password"
GET /letter_opener/<id>/rich        200  contains reset-password#token=eyJfcmFp…
GET /login                          200  (the React app's catch-all still works)
GET :5173/letter_opener/ (Vite)     200  lists "Your ACME Salary Insights account"
test env: letter_opener route mounted? false
```

**Found:** letter_opener_web needs `rexml`, and the copy first resolved (3.3.9) has a known denial-of-service issue (CVE-2025-58767, fixed in 3.4.2); `bundler-audit` failed on it. The lockfile now pins rexml 3.4.4 (also from Sravan's cache), and the audit is clean. The app itself parses no XML.

Earlier, my first letter_opener check failed only because the local PostgreSQL had stopped; after restarting it, the same command delivered.

```
backend: 355 examples, 0 failures · Line 100% · Branch 100% · rubocop no offenses · brakeman 0 warnings · bundler-audit: No vulnerabilities found
frontend: eslint clean · vite build OK (vite.config.ts changed: one proxy line)
```

## Checkboxes in multi-selects (follow-up request)

Every multi-select option now shows a checkbox, ticked when chosen. It is set once in `frontend/src/app/theme.tsx` (`MultiSelect` default `renderOption`, Mantine's built-in check icon off), so the Users, Employees and Dashboard filters all match. The checkbox is a picture only (`CheckboxIndicator`, `aria-hidden`); clicks and the "selected" state still belong to the option.

- **Test first:** `users-page.test.tsx` "shows a checkbox beside each multi-select option…" failed with the theme removed from the app (`toHaveAttribute` on a missing indicator), and passes with it.
- **Seen in Chromium** (development server): ticked boxes on the Users filters and the links list; on Employees, choosing India and Germany ticked both and set `?country=IN&country=DE`.

```
frontend: 143 tests passed · lines 99.53% · branches 96.23% · functions 99.21% · eslint clean · tsc OK · vite build OK
```

## Admin-only demo inbox (follow-up request; extended behaviour E1)

The inbox now works on a server too, for the demo: with `EMAIL_INBOX=true` and no SMTP settings, emails go to `/letter_opener` instead of nowhere. Everywhere, only a signed-in Admin reaches it (`EmailInboxConstraint`); the session response carries `email_inbox`, which the menu uses to show **Email inbox (demo)**. The gem moved from the development group to the main group, so the Docker image includes it; it stays unused unless the flag is on.

- **Specs first:** `spec/requests/email_inbox_spec.rb` (10 examples) failed 5 before the code (the "hidden" cases passed trivially because nothing was mounted yet); the UI test failed on the missing link.
- **Production mode, production gems only** (`RAILS_ENV=production BUNDLE_WITHOUT=development:test`):
```
EMAIL_INBOX=true   delivery: letter_opener_web   letters in inbox: 1
                   log: "EMAIL_INBOX is on: account emails go to the Admin inbox at /letter_opener, not to people"
EMAIL_INBOX=false  delivery: test                letters in inbox: 0
admin session:  "email_inbox":true        viewer session: "email_inbox":false
admin:      GET /letter_opener -> 200 (inbox)   POST clear -> 302
viewer:     GET /letter_opener -> 200 (the React app, no inbox)   POST clear -> 404
signed out: GET /letter_opener -> 200 (the React app, no inbox)   POST clear -> 404
```
- **Risk reasoning:** the inbox shows reset links for every user, including other Admins. An Admin can already set any user's password, so it adds no power. The engine skips CSRF checks in API-only apps, but the session cookie is SameSite=Lax, so another site's POST arrives without it and gets 404.
- **NOT RUN:** the Docker image build with the gem in the main group, and the live demo with `EMAIL_INBOX=true`.

## Exchange rates page for Admins (follow-up request)

`GET /api/v1/exchange_rates` lists the latest cached snapshot (1 EUR in each currency, rate date, source, fetch time, stale after 7 days); `POST /api/v1/exchange_rates/sync` runs the existing `Fx::Refresh` now. Admin only, 5 syncs per 10 minutes; a provider failure answers 502 and leaves the cache as it was. The page sits after **Users** in the menu, so an Admin-only user sees Dashboard, Users, **Exchange rates**.

- **Specs first:** `spec/requests/api/v1/exchange_rates_spec.rb` (7 examples) and one access-matrix row: 8 failures before the code, 0 after. The provider is a fake in every spec.
- **UI tests first:** `exchange-rates-page.test.tsx` (6 tests: menu position, table and provenance, sync success, sync failure keeps the table, stale badge, empty state, other roles) all failed before the page.
- **NOT RUN:** a sync against the real Frankfurter service from this workspace (its network is restricted); the live demo.

## Final checks before the commit (everything above together)

```
backend:  373 examples, 0 failures · Line coverage 100% (1164/1164) · Branch coverage 100% (278/278)
          rubocop 156 files, no offenses · brakeman Security Warnings: 0 · bundler-audit: No vulnerabilities found
frontend: 151 tests passed (18 files) · lines 99.55% · branches 96.07% · functions 99.23%
          eslint 0 problems · tsc OK · vite build OK
```
RuboCop first found a trailing blank line in the Gemfile, and ESLint an unused variable in the rates hook; both fixed before these runs. An existing role test listed only an Admin's first two menu links and was updated for the two new ones.

## What this does not prove
- **Delivery through Gmail.** NOT RUN: it needs Sravan's Gmail app password on the server (`deploy/README.md`, "Account emails through Gmail").
- **Inbox placement.** Gmail-sent mail from a personal account may land in spam for some recipients.
- **Debug-level production logs.** If `RAILS_LOG_LEVEL=debug` were set in production, email bodies (and so links) would be logged; keep it at `info`.
