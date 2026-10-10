# M5 evidence: salary history (view, record a change, audit)

**Hypothesis:** HR sees an employee's current salary and full history, with the % change between records. A pay change is recorded without losing or overwriting the previous record, even when two changes arrive at once. Every step is audited. Only HR managers can see or change any of it.

**Environment:** cloud Linux workspace, Rails 8.1.4, PostgreSQL 16 with the 10k seed, React 19 + Mantine 7, Chromium (Playwright), 2026-10-10/11.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| H1 | Full history, newest first; current record has no end date; % change derived (2 dp, half-up), empty across currencies | request spec (INR → INR +11.11%, INR → USD null); UI tests; browser |
| H2 | One transaction: lock the employee, check, close the current record the day before, insert the new one; `revised_by` = signed-in user | service specs; DB before/after below |
| H3 | Rejections leave history unchanged: date on or before the current start, future date, blank or invalid date, amount ≤ 0, unsupported currency, reason `hire` or unknown, deactivated employee | service specs (counts of records, versions and `effective_to` unchanged); browser |
| H4 | Failure after closing the current record rolls the close back | service spec (simulated insert failure) |
| H5 | Concurrent changes are serialised: one current record, contiguous periods | 4-thread spec, 5 out of 5 runs; **without the row lock it failed 1 run in 3** with `RecordNotUnique` (the partial unique index caught the race as a crash) |
| H6 | Audit trail: employee and salary records, newest first, field-level old → new, who and when | request spec; UI test; browser |
| H7 | HR manager only (viewer and admin-only users get 403) | authorization matrix (3 new endpoints × 4 callers); browser (viewer GET/POST 403) |
| H8 | UI: history table, record-change form (currency, date and reason pre-filled; inline errors; non-field refusal shown at the top), disabled for deactivated employees, audit log, refresh after saving | 8 UI tests; browser |

## Tests

```
backend:  255 examples, 0 failures · Line 817/817 (100%) · Branch 176/176 (100%)
          rubocop 109 files, no offenses · brakeman 0 warnings · bundler-audit: no vulnerabilities
frontend: 103 tests passed · lines 99.39% · branches 95.71% · functions 98.98%
          eslint 0 problems · tsc + vite build OK · npm audit (prod): 0 vulnerabilities
```

**Red before green:** 7 backend specs failed (`uninitialized constant Compensations`), and all 7 new UI tests failed.

## Found while building
1. **The lock is necessary, and the test shows it.** Removing `Employee.lock` made the parallel spec fail (1 run in 3): two changes read the same current record, and the second insert hit the unique index. With the lock, it passed 5 out of 5.
2. **Empty tables while loading (UI tests).** The history table and the audit log rendered empty before their data arrived, which looks like "no history". They now show a loader.
3. **A page-wide text lookup in an older test** could have matched the new history table. It is now scoped to the Profile region.
4. **Not a bug:** in the first browser run the profile still showed the old salary right after saving. A second run waited for it, and it updated in **109 ms** without a reload. My script had read the page too early.

## Browser run on the 10k seed (signed in as hr@)

Employee **EMP-000001 Grace Moreau (GB)**:

```
BEFORE
  2023-11-18 → current    | £76,500 | +7.14% | Annual review     | seed
  2021-01-05 → 2023-11-17 | £71,400 | +5.93% | Market adjustment | seed
  2018-02-22 → 2021-01-04 | £67,400 | +4.33% | Annual review     | seed
  2015-04-12 → 2018-02-21 | £64,600 | —      | Hire              | seed
Effective from 2023-01-01 → "Effective from must be after the current salary's start date (2023-11-18)"
AFTER (£80,325 from 2026-10-01, Promotion, "Promoted to Senior")
  2026-10-01 → current    | £80,325 | +5.00% | Promotion | Promoted to Senior | hr@acme.example
  2023-11-18 → 2026-09-30 | £76,500 | +7.14% | Annual review | seed
  … (older rows unchanged)
Audit: "Salary record created" (hr@acme.example) and "Salary record updated: Effective to: — → 2026-09-30"
Viewer calling GET / POST /api/v1/employees/:id/compensations → 403 / 403
```

The database after a second change (£81,000 from 2026-10-05, correction):

```
98751  | 76500.0 | GBP | 2023-11-18 | 2026-09-30 | annual_review | seed
131663 | 80325.0 | GBP | 2026-10-01 | 2026-10-04 | promotion     | hr@acme.example
131664 | 81000.0 | GBP | 2026-10-05 | current    | correction    | hr@acme.example
current records: 1
```

The only console errors were the browser logging the deliberate 401 (signed out), 422 (invalid date) and 403 (viewer) responses.

**Cleanup:**
- I first restored the employee by hand, and that also deleted their 4 seed audit rows: the seed had run the same day, so "rows from the last day" matched them.
- I then re-ran the deterministic seed: 10,000 employees, EMP-000001 back to 4 records and 5 audit entries, and the 3 demo users untouched.
- The app itself never deletes history.

## Screenshots
- [`m5-salary-history.png`](screenshots/m5-salary-history.png): profile, salary history after the change, and the audit log.
- [`m5-record-change-error.png`](screenshots/m5-record-change-error.png): the record-change form refusing a date before the current start.

## What this does not prove
- **Reporting-currency conversion.** That is the next milestone (M10).
- **Scheduled (future-dated) raises and corrections after an employee has left.** Excluded by A4 and A21.
- **`docker build`: NOT RUN** (Docker Hub is blocked here).
