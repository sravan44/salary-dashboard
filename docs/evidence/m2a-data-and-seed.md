# M2a evidence: employee data, salary history with reasons, audit trail + deterministic 10,000 seed

**Hypothesis:** the schema makes invalid salary data impossible (in the model *and* in the database). Every salary record says why it exists, and every create/update of an employee or salary is written to an append-only audit log. The seed produces exactly 10,000 synthetic employees with consistent salary history, and re-running it with the same seed produces identical data, never duplicates.

**Environment:** cloud Linux workspace, Ruby 3.3.6, Rails 8.1.4, PostgreSQL 16.15, 2026-10-10.

## Acceptance criteria → proof

| # | Criterion | Proof |
|---|-----------|-------|
| AC1 | Employee number unique, `EMP-000000` format | model spec + unique index (spec saves with validations skipped → `RecordNotUnique`) |
| AC2 | Email unique case-insensitively, stored lower-case | model spec |
| AC3 | Country, department, currency come from one reference list | `Acme::Reference` spec + inclusion validations |
| AC4 | Status only `active`/`terminated` | enum validation + DB CHECK (SQL below) |
| AC5 | Amount is exact decimal, > 0, fits numeric(14,2) | model spec (`BigDecimal` round-trip) + DB CHECK (SQL below) |
| AC6 | End date never before start date | model spec + DB CHECK |
| AC7 | **At most one current salary per employee** | partial unique index; spec + raw SQL below |
| AC8 | No two records start on the same day | unique index `(employee_id, effective_from)`; spec |
| AC9 | Employees with history cannot be deleted | `restrict_with_exception`; spec |
| AC12 | Every salary record has a reason from a fixed list; optional notes ≤ 1000 chars | model spec + DB CHECK |
| AC13 | Every create/update of an employee or salary writes a `versions` row (who, event, changed fields old → new) in the same transaction; no-op saves write nothing | version spec + runner demo below |
| AC14 | Audit rows cannot be edited or deleted through the app; unknown events rejected by DB | version spec + runner demo below |
| AC15 | Seed: first record = `hire`, later = `annual_review`/`market_adjustment`, `revised_by = seed`, one `create` version per seeded row | seeder spec + 10k queries below |
| AC10 | Seed: exactly N employees, each with one current salary, gap-free history, local currency, nothing future-dated, all records valid | seeder spec (N = 300) + 10k queries below |
| AC11 | Seed is deterministic and re-runnable | seeder spec + checksums below |

## Tests

```
$ bundle exec rspec
57 examples, 0 failures
Line coverage: 150 / 150 (100.00%)
Branch coverage: 16 / 16 (100.00%)

$ bin/rubocop
37 files inspected, no offenses detected

$ for s in 1 2 3 4 5 12345; do bundle exec rspec --seed $s; done   # random order: Current.actor must not leak
57 examples, 0 failures   (x6)
```

**Red before green (history/audit addition).** The new specs were run against the previous 2a code first: `48 examples, 25 failures`, plus `NameError` loading `version_spec` (no `Version` class). Then the implementation was added.

**Two problems found on the way** (both fixed, both worth knowing):
1. **Stale `schema.rb`.** I edited the not-yet-committed `compensations` migration. On a fresh database, Rails 8.1's `db:migrate` *loads `schema.rb`* instead of running migrations, so the old table (without `reason`) came back silently. Fixed by regenerating `schema.rb` from the migrations. Rule going forward: committed migrations are never edited, only new ones added.
2. **Seed logged amounts as integers.** `BigDecimal#round(-2)` returns an Integer, so seeded audit rows logged `64600` while app edits log `"64600.0"`. The spec "logs the same values that were stored" caught it; the seeder now keeps amounts as `BigDecimal`.

## Seed: 10,000 employees

```
$ bin/rails db:seed
Seeded 10000 employees, 32915 salary records (10000 current) with random seed 42 in 7.34s
```
Total including Rails boot: 8.2 s. It was 3.2 s before the audit trail; the extra time is writing 42,915 version rows.

**Exact counts**

| employees | salary_records | current | versions | employee versions | salary versions |
|-----------|----------------|---------|----------|-------------------|-----------------|
| 10000 | 32915 | 10000 | 42915 | 10000 | 32915 |

**Integrity checks (all expected 0):** duplicate employee_number **0** · duplicate email **0** · employees without exactly one current salary **0** · future-dated records **0** · first record not a hire **0** · salary records without an audit version **0**

**Reasons:** annual_review 19,387 · hire 10,000 · market_adjustment 3,528

**Determinism.** An md5 over every employee field and every salary record, ordered:

| Run | Checksum |
|-----|----------|
| seed 42, run 1 | `83276361ac7eef4b36c169f383cbe77f` |
| seed 42, run 2 | `83276361ac7eef4b36c169f383cbe77f` ← identical |

(The checksum now also covers `reason`. It differs from the earlier 2a draft because choosing reasons consumes random numbers, so the generated values shift. A different seed still gives different data, as the spec "produces different data for a different random seed" shows.)

(A first attempt printed "IDENTICAL" for two *empty* checksums because the timing tool was missing and the seed never ran. That run was discarded, and the check now also requires a non-empty checksum.)

**Distribution: current salary by country and currency** (two countries share EUR)

| country | currency | employees | min | max |
|---------|----------|-----------|-----|-----|
| US | USD | 2958 | 47,700 | 238,300 |
| IN | INR | 2530 | 612,100 | 3,092,000 |
| GB | GBP | 1205 | 28,700 | 144,300 |
| DE | EUR | 960 | 34,100 | 168,900 |
| FR | EUR | 726 | 28,600 | 144,000 |
| CA | CAD | 705 | 44,400 | 219,000 |
| AU | AUD | 483 | 51,900 | 251,200 |
| SG | SGD | 433 | 40,900 | 203,100 |

**Departments:** Engineering 3037 · Sales 1796 · Customer Support 1319 · Operations 1002 · Product 775 · Marketing 752 · Finance 738 · People 581
**Status:** active 9227 · terminated 773
**History length:** 1 record: 1149 · 2: 1244 · 3: 1150 · 4: 6457

**Sample (EMP-000042):** four USD records, each closed the day before the next starts, each with its reason:

| amount | from | to | reason | revised_by |
|--------|------|----|--------|------------|
| 59,600 | 2016-06-13 | 2019-01-08 | hire | seed |
| 66,500 | 2019-01-09 | 2021-08-06 | annual_review | seed |
| 72,000 | 2021-08-07 | 2024-03-03 | annual_review | seed |
| 79,000 | 2024-03-04 | current | annual_review | seed |

Its audit entry for the current record (`versions`, item_type `Compensation`, event `create`, whodunnit `seed`):
```json
{ "amount": [null, "79000.0"], "currency": [null, "USD"], "reason": [null, "annual_review"],
  "revised_by": [null, "seed"], "employee_id": [null, 10042],
  "effective_from": [null, "2024-03-04"], "effective_to": [null, null] }
```

## Audit trail for an edit made in the app

```
$ bin/rails runner  # Current.actor = "hr.manager@acme.example"; EMP-000042.update!(department: "Product", job_title: "Product Manager"); then a no-op save!
{"versions_for_employee":2,"last_event":"update","whodunnit":"hr.manager@acme.example",
 "object_changes":{"job_title":["Support Specialist","Product Manager"],"department":["Customer Support","Product"]}}
tamper attempt: ActiveRecord::ReadOnlyRecord
```
Only the changed fields are logged, as old → new. The no-op save added nothing (2 versions = seed create + this update). Editing the audit row is refused. The dev data was re-seeded afterwards.

## The database refuses bad data even without Rails

```
-- 2nd current salary for EMP-000042, raw SQL
ERROR:  duplicate key value violates unique constraint "index_compensations_one_current_per_employee"
-- zero salary
ERROR:  new row for relation "compensations" violates check constraint "compensations_amount_positive"
-- unknown status
ERROR:  new row for relation "employees" violates check constraint "employees_status_known"
```

## What this does not prove
- **The salary bands are synthetic and plausible, not real market data.** Job titles don't change across history (no promotions are modelled).
- **No filter or sort indexes yet.** These are added in M8, only where EXPLAIN on this dataset justifies them.
- **`whodunnit` / `revised_by` are free-text actor labels until users exist (M7)**, when they become the signed-in user. Audit rows are protected from edits by the app (`readonly?`), not by a database trigger (see rejected-suggestions).
- **Overlapping date ranges** (as opposed to two records with the *same* start date) are prevented by the seeder's construction. For writes in general, the M5 salary-change service will prevent them. A Postgres exclusion constraint was considered and deferred (see rejected-suggestions).
