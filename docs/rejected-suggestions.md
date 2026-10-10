# Rejected and deferred suggestions

| Suggestion | Why it was considered | Decision | Reason | Revisit when |
|------------|-----------------------|----------|--------|--------------|
| Split employees / salary / future paystubs into microservices | Future HR domains differ | **Reject** (MVP) | No independent scaling or ownership need; adds deployment and consistency cost | A real service boundary appears |
| Single "total payroll" headline summing all salaries | An eye-catching dashboard number | **Reject** | Summing INR + USD is meaningless | Phase 2 FX with an explicit reporting currency and rate date |
| Build FX conversion alongside the core features | The playbook addendum includes it in the MVP | **Defer** to Phase 2 | Sravan: core requirements first; FX is extra scope | After M9 |
| SQLite (suggested in the brief) | Zero setup | **Reject** | No `percentile_cont`, weaker constraints, differs from prod | — |
| Store `current_salary` on `employees` | Faster reads | **Reject** | Duplicates truth; the partial index on `effective_to IS NULL` makes the join cheap | Measured bottleneck |
| One salary chart mixing all currencies (e.g. avg salary by country on one axis) | Simplest-looking chart | **Reject** | Bars in INR next to bars in USD on one axis mislead | Phase 2 FX reporting currency |
| Send all employee salaries to the browser and chart client-side | Easy with chart libraries | **Reject** | 10k rows of sensitive data over the wire; SQL aggregates are smaller and safer | — |
| Salary-range filter without a currency | Simpler filter | **Reject** | "50k–100k" means different things in INR vs USD | — |
| Cache insights | Faster dashboard | **Defer** | No baseline yet; 10k rows aggregate quickly in Postgres | M8 measurements show a need |
| Countries/departments as DB tables with admin UI | Normalisation | **Defer** | Static list is enough; no requirement to manage them | HR needs to edit them |
| Kubernetes manifests + future-service templates | Playbook suggests them | **Defer** (optional) | Does not serve the HR Manager; only if time remains | After M11 |
| Install gems from an alternative rubygems mirror when rubygems.org is blocked | Unblocks the backend quickly | **Reject** | Routes around the organisation's network policy and trusts an unvetted source | Instead: offline install from Sravan's own rbenv gem cache |
| Keep the generated `config/master.key` + `credentials.yml.enc` | Rails default | **Reject** | No secrets are needed yet; one less key to leak. Production reads `SECRET_KEY_BASE` from the environment | A real secret needs encrypted storage |
| Lower SimpleCov to line-only coverage | Easier to hit 90% | **Reject** | Branch coverage catches untested `if`/`else` paths, which matter for business rules | — |
| Use Faker for seed names | Common choice | **Reject** | Its global RNG makes determinism fragile, and it adds a runtime dependency to production seeding. Fixed name lists + our own `Random.new(seed)` are simpler | Need for much richer fake data |
| Postgres exclusion constraint (`btree_gist`, daterange) against overlapping salary periods | Strongest possible no-overlap guarantee | **Defer** | Needs an extension. The partial unique index + unique start date + the M5 service (row lock, date rule) cover the MVP's single-writer case | Concurrent multi-user editing |
| Add filter/sort indexes now | Expected to be needed | **Defer** to M8 | Index only what EXPLAIN on the 10k seed shows is needed | M8 |
| Separate `salary_revisions` table (3-table design) | Clean split between pay periods and change events | **Reject** (Sravan chose lean) | Revision would be 1:1 with a salary record. Columns on `compensations` give the same answers without a join | Revisions need their own lifecycle (e.g. approvals, multi-step) |
| `paper_trail` gem for the audit log | Standard Rails audit library | **Reject** | Not available offline here, and ~40 lines of `Versioned` covers what we need (create/update, changed fields, actor) with no magic | Need for reify/rollback, associations, or many more audited models |
| DB trigger forbidding UPDATE/DELETE on `versions` | Hard guarantee of append-only | **Defer** | The app already refuses edits (`readonly?`). A trigger would also block the seeder's documented replace-on-rerun | Production with direct DB access by others, or compliance requirements |
| Record a `version` for no-op saves | Complete log of every save call | **Reject** | Noise. Only real changes matter for "who changed what" | — |
