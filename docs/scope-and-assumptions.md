# Scope and assumptions

The assessment brief does not settle several business rules. Each one below is a **provisional default**: chosen so work can proceed, recorded here, and easy to revisit.

| # | Open question | Provisional default | Risk if wrong | Revisit when |
|---|---------------|---------------------|---------------|--------------|
| A1 | What does "salary" mean? | Annual base salary only | Bonus-heavy roles look underpaid | HR asks for total comp |
| A2 | Which countries and currencies? | 8 seeded countries with ISO-4217 currencies: US/USD, IN/INR, GB/GBP, DE/EUR, FR/EUR, CA/CAD, AU/AUD, SG/SGD. Two countries share EUR on purpose. | Supported list is too narrow | New country needed (config change plus seed) |
| A3 | Is currency fixed by country? | No. Currency is stored **per compensation record** and defaults to the country's currency, so expat contracts are possible. | Mis-entered currency | Policy says otherwise |
| A4 | How are changes effective-dated? | A new record starts on `effective_from`. The previous record gets `effective_to = new.effective_from - 1 day`. The new date must be **after** the latest record's start and **not in the future**. | Retro-corrections and pre-planned raises are not supported | HR needs scheduled raises or corrections |
| A5 | Can history be edited or deleted? | No. History is append-only; a correction is a new record. | A typo stays in history | Audit/correction workflow requested |
| A6 | Can employees be deleted? | No. Status becomes `terminated`, and history and the record are kept. | — | Data-retention policy defined |
| A7 | Who may access the data? | Every API and GraphQL request needs a signed-in user. Roles combine: `viewer` (dashboard only), `hr_manager` (+ employees and salaries), `admin` (+ users and roles) (decided by Sravan, replacing the single HR role). | Too coarse for regions or departments | Regional or per-department access requested |
| A8 | Approvals? | None in the MVP | Changes take effect immediately | Approval policy exists |
| A9 | Which population does Insights cover? | Active employees and their current salary | HR expected terminated staff included | HR clarifies |
| A10 | Median definition | For an even count, the mean of the two middle values. Results are rounded to 2 dp, half-up. | — | — |
| A11 | Seed data | Synthetic only and deterministic (fixed RNG seed). Salary bands per country × level are plausible but **not** real market data. | Distributions look artificial | — |
| A12 | FX conversion (F7, M10) | ECB reference rates via Frankfurter, fetched once per refresh (EUR base) and cached per (base, quote, date); cross rates derived exactly; refreshed every weekday at 16:30 Frankfurt time by a Solid Queue recurring job (retried twice). Each salary is converted, then aggregated. Labelled "indicative", never used for payroll, never written back to salaries. Rates older than 7 days are flagged. A currency without a rate is left out and named. | Provider down or terms change (cached rates keep working; refresh fails visibly) | A payroll-grade FX policy is needed |
| A14 | Who sets the employee number? | The server: the next free `EMP-######`, assigned under a database lock (decided by Sravan). | HR has numbers from another system | Import from an HR system |
| A15 | Can a deactivated employee come back? | Yes. Reactivation sets `active` again; both changes are in the audit log (decided by Sravan). | — | — |
| A16 | Can the hire date be edited? | No, it is locked after creation: it starts the salary history, and changing it would rewrite a salary record (decided by Sravan). | A wrong hire date stays | A correction workflow (with M5) is requested |
| A17 | Does changing an employee's country change their salary currency? | No. Pay changes only through a recorded salary change (M5). | Currency looks wrong after a move | — |
| A18 | Who is recorded in the audit log? | The signed-in user's email (since M7). Before login existed, changes were recorded as `unauthenticated`. | — | — |
| A19 | Can a Viewer infer one person's pay from small groups on the dashboard? | Yes, for now: all aggregates are shown to Viewers (decided by Sravan). A group of one person shows that person's salary. | Pay leaks to Viewers via tiny groups | Before Viewers outside HR get access: hide groups under 5 people |
| A20 | How do accounts start? | `db:seed` creates demo sign-ins per role with a password documented in the README (Sravan's request); in production only when `DEMO_USER_PASSWORD` is set on purpose. `users:create` for real deployments; Admins add users and set roles in the app. No self sign-up, no password reset or account disabling yet. | A forgotten password needs a console fix | Users ask for self-service |
| A21 | Can a deactivated employee get a pay change? | No. Reactivate first, so pay history never moves for someone who has left. | A back-dated correction for a leaver needs a reactivation | HR asks for corrections after exit |
| A13 | Deployment host | One AWS EC2 t3.micro (Ubuntu, Frankfurt `eu-central-1`, as Sravan created it, 20 GB disk), deployed by Capistrano driving Docker Compose (Sravan's choice at M9, after Fly.io's trial stopped machines after 5 minutes). PostgreSQL, the app and Caddy in containers on the same instance; database in a named volume; 2 GB swap for builds. HTTPS through Caddy (Let's Encrypt) once `APP_HOST` names Sravan's subdomain; plain HTTP on the IP until then. An Elastic IP (Sravan's decision, so restarts keep the address) and the DNS name `salary-demo.generateforgood.in`, which the deploy and SSH also use. | A single instance has no failover; no backups until a `pg_dump` schedule exists; an unattached Elastic IP is billed | Real data: a managed database with backups |

## Explicit assessment requirements vs. assumptions vs. optional ideas
- **Explicit:** one-page requirements; backend plus React UI; relational DB; seed of 10,000; meaningful unit tests; incremental commits; AI artifacts; deployed app; video demo.
- **Assumed (above):** A1–A21.
- **Optional / later:** CSV import/export, Kubernetes manifests and future-service templates, audit log of who changed what.
