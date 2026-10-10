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
| A7 | Who may access the data? | A single `hr_manager` role, authenticated. Every API route except login and health requires it. | Too coarse for a real org | Multiple roles or regions requested |
| A8 | Approvals? | None in the MVP | Changes take effect immediately | Approval policy exists |
| A9 | Which population does Insights cover? | Active employees and their current salary | HR expected terminated staff included | HR clarifies |
| A10 | Median definition | For an even count, the mean of the two middle values. Results are rounded to 2 dp, half-up. | — | — |
| A11 | Seed data | Synthetic only and deterministic (fixed RNG seed). Salary bands per country × level are plausible but **not** real market data. | Distributions look artificial | — |
| A12 | FX (Phase 2) | Frankfurter reference rates, cached per (base, quote, date). Labelled "indicative", never used for payroll. | Provider down or terms change | Verified at Phase 2 start |
| A13 | Deployment host | Chosen at M8: the lowest-friction host with managed Postgres. A single container where Rails serves the built React app. | Free-tier limits | — |

## Explicit assessment requirements vs. assumptions vs. optional ideas
- **Explicit:** one-page requirements; backend plus React UI; relational DB; seed of 10,000; meaningful unit tests; incremental commits; AI artifacts; deployed app; video demo.
- **Assumed (above):** A1–A13.
- **Optional / later:** FX (Phase 2), CSV import/export, Kubernetes manifests and future-service templates, audit log of who changed what.
