# M4 evidence: employee management (create, edit, deactivate, reactivate)

**Hypothesis:** HR can add an employee together with their first salary, edit the profile, and deactivate or reactivate them. Nothing is half-saved, employee numbers never collide, history is never rewritten, every change is audited, and the dashboard follows status changes.

**Decisions (Sravan):** the employee number is auto-generated; reactivation is allowed; the hire date is locked after creation.

**Environment:** cloud Linux workspace, Rails 8.1.4, PostgreSQL 16 with the 10k seed, React 19 + Mantine 7, Chromium (Playwright), 2026-10-10.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| E1 | Create saves the employee and the first salary (reason `hire`, from the hire date) in one transaction; any invalid field saves nothing | `Employees::Create` specs (counts of employees, salaries and versions unchanged on failure) |
| E2 | Next free `EMP-######`, unique even for simultaneous creates | specs: `EMP-000041` → `EMP-000042`; 4 creates in parallel threads → 4 distinct, consecutive numbers; exhaustion fails loudly |
| E3 | Hire date required and not in the future; any supported currency | specs (frozen date 2026-10-10) |
| E4 | Edit covers profile and status only; hire date, number and salary are refused with a field reason; a country change leaves the salary currency alone | `Employees::Update` specs + request specs |
| E5 | Deactivate and reactivate keep the record and history; both are audited | specs + browser run (dashboard 9,228 → 9,227 → 9,228) |
| E6 | 422 `validation_failed` with errors per field; duplicate email on `email` (including a race caught only by the database); 400 without an `employee` object | request + service specs |
| E7 | Audit: who = `unauthenticated` until M7 | request spec + DB check below |
| E8 | UI: Add employee, name links, profile page, create/edit forms with inline server errors, currency follows the country until chosen, hire date locked on edit, confirmation dialogs | 13 UI tests + browser run + screenshots |

## Tests

```
backend:  180 examples, 0 failures · Line 601/601 (100%) · Branch 114/114 (100%)
          rubocop 84 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: 79 tests passed · lines 99.38% · branches 96.98% · functions 99.22%
          eslint 0 problems · tsc + vite build OK · npm audit (prod): 0 vulnerabilities
```

**Red before green:** the service and request specs failed with `uninitialized constant Employees::Create`, and all 11 new UI tests failed. Later additions also failed first: 2 model specs for the blank-value messages, and the rescue-path specs.

## Bugs found by the tests and the browser
1. **Race on employee numbers (parallel-create spec).** Creates validated a *provisional* number before taking the lock. When another create committed that number in between, the create failed with "employee number has already been taken". **Fix:** the number is assigned only under the lock and is not validated beforehand. The spec now passed 6 out of 6 runs.
2. **A failed save could look like success (rescue-path spec).** After `save!` failed and the transaction rolled back, the service re-validated the employee, found nothing wrong and returned success with nothing saved. **Fix:** report the errors captured at save time.
3. **A status dialog flipped its wording while closing (UI test).** After deactivating, the fading dialog briefly read "Reactivate". **Fix:** the dialog keeps the action it was opened for.
4. **Empty choices read "is not included in the list" (browser).** A blank country, department or currency now says "can't be blank" (model specs).

## Browser run on the 10k seed (production build served by Rails)

| Step | Result |
|---|---|
| Submit an empty form | 422; an error under every field (see screenshot) |
| Create Meera Iyer, India, ₹1,850,000 | Currency pre-filled as INR; created as **EMP-010001**; profile page shows ₹1,850,000 |
| Edit job title | Hire date input disabled; saved and back on the profile |
| Dashboard active headcount | 9,227 before → **9,228** after create → **9,227** after deactivate → **9,228** after reactivate |
| Create the same email again | Refused (email already taken) |
| Browser console | Only the network log line for the deliberate 422 |

Audit trail recorded in the database:

```
create | unauthenticated | full_name, hire_date, job_title, department, country_code, employee_number (+ email)
update | unauthenticated | {"job_title":["Data Engineer","Senior Data Engineer"]}
update | unauthenticated | {"status":["active","terminated"]}
update | unauthenticated | {"status":["terminated","active"]}
salary: 1850000.0 INR from 2026-10-01, reason hire, version create by unauthenticated
```

The test employee and its audit rows were then removed with SQL, so the seed stays at 10,000 employees, EMP-010000 and 42,915 versions. The app itself never deletes anything.

## Screenshots
- [`m4-create-errors.png`](screenshots/m4-create-errors.png): server field errors shown inline.
- [`m4-employee-page.png`](screenshots/m4-employee-page.png): the new employee's profile.
- [`m4-deactivate-confirm.png`](screenshots/m4-deactivate-confirm.png): the confirmation dialog.

## What this does not prove
- **Authentication.** The endpoints are open until M7.
- **Salary changes and the history view.** That is M5.
- **`docker build`: NOT RUN** (Docker Hub is blocked here).
