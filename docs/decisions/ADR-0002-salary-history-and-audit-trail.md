# ADR-0002: Salary history with reasons, plus an append-only audit trail

**Status:** Proposed (pending review)

## Why we revised the design
The first data model stored *what* an employee was paid and *when*: effective-dated salary records. For an HR team moving off spreadsheets, that answers only half of the questions they get asked:

- **"Why did this person's pay change?"** A history of amounts can't tell an annual review from a promotion, a market correction, or a fix for a typo.
- **"Who changed it, and what did it say before?"** In Excel, an overwritten cell is simply gone. Salary data is sensitive and disputes happen, so HR has to be able to show who changed what, and when.
- **Profile changes matter too.** A move from Sales to Product, or a status change to terminated, changes how someone appears in pay reports, yet it isn't a salary record at all.

So salary history needed to carry **meaning** (why), and every change needed to leave a **trace** (who, when, before → after).

## Decision
1. **Salary history explains itself.** Each salary record now has a **reason** (`hire`, `annual_review`, `promotion`, `market_adjustment`, `correction`), optional **notes**, and **revised_by**. The reasons are a fixed list enforced by the database, so they can be counted and reported on reliably.
2. **An append-only audit trail** (`versions`) records every create and update of an employee or a salary record: who made the change, when, and each changed field as old → new. It is written in the same database transaction as the change, so a change can't be saved without its audit entry, and the app cannot edit or delete audit entries.

We chose the **lean design**: revision details live as columns on the salary record rather than in a separate revisions table. Every revision corresponds to exactly one salary record, so a separate table would add a join without answering any new question.

## How this helps
| Need | How the design answers it |
|------|---------------------------|
| Explain a pay change to an employee or manager | Each salary record states its reason and notes, next to the amount and dates |
| Report on how pay moves | "How many raises were market adjustments this year, and in which countries?" becomes a simple count by reason, per currency |
| Resolve disputes and errors | The audit trail shows the exact previous value and who changed it. A correction is a new, labelled record, so the mistake and its fix both stay visible |
| Trust the numbers | Nothing is overwritten or silently lost: salary history is append-only, and the audit trail is read-only to the app |
| Audits and compliance conversations | A complete, timestamped record of who changed sensitive pay data, ready when policy asks for it |
| Context behind analytics | Department or status changes are logged, so a shift in a team's pay statistics can be traced to the people who moved |
| Future growth | `revised_by`/`whodunnit` become the signed-in user once login exists. Approvals, if ever required, can build on the reason and audit data without reshaping history |

## Trade-offs
- **More rows.** The demo dataset has ~43k audit entries alongside ~33k salary records. That's small for PostgreSQL, but the audit table grows with every edit and may need archiving one day.
- **Seeding takes longer** (about 7 s instead of 3 s for 10,000 employees), because it writes the audit entries too.
- **Audit protection is enforced by the application, not the database.** Someone with direct database access could still alter it. A database-level guard is deferred until there is a real need (see rejected-suggestions).
- **Who made a change is a text label until users exist** (M7).

## Revisit when
- Changes need approval before taking effect (revisions get their own lifecycle and table).
- Compliance requires tamper-proof history (database-level protection, or an external log).
- The audit table's size starts to affect performance or storage cost.
