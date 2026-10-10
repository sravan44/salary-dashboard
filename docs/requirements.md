# ACME Salary Insights — Requirements (one page)

## Goal
ACME's HR team manages salary data for **10,000 employees in several countries** in spreadsheets. That is slow, error-prone, and makes it hard to answer "how do we pay people?". We are building a web application in which the **HR Manager** can (1) keep employee salary data accurate, with history, and (2) answer compensation questions directly, without exporting to Excel.

## Persona and core questions
**HR Manager**: works in the app daily, is comfortable with spreadsheets, and needs speed and trustworthy numbers.
1. "Find employee X and show me their current salary and how it has changed."
2. "Record a raise for X, effective on a date, and keep the old salary on record."
3. "What do we pay in country C / department D / job title J: average, median, range?"
4. "How many people do we have where, and how is pay spread out?" Shown as **charts**, not just tables.

## Scope (MVP, built in this order)
| # | Feature | Acceptance summary |
|---|---------|--------------------|
| F1 | **Search and filter employees** | Search by name, employee number or email (case-insensitive, partial match). Filters for country, department, job title, status and salary range, which **combine** (AND). Allowlisted sorting and server-side pagination across all 10,000 records. Active filters appear as removable chips with a "clear all" option, and they live in the URL so a filtered view can be bookmarked or shared. |
| F2 | **Employee management** | Create and edit an employee. Deactivation sets status to `terminated` and keeps the record (no hard delete). Employee number is unique, and validation errors are shown inline. |
| F3 | **Salary history and audit** | A salary change is a new effective-dated record with a **reason** (hire, annual review, promotion, market adjustment, correction) and optional notes. The previous record is closed in the **same transaction**, and history is never overwritten. Every create/update of an employee or salary is also written to an append-only **audit log** (who, when, old → new). |
| F4 | **Pay insights (tables)** | Headcount, plus min / max / average / median salary by country, department and job title for **active** employees. Filterable by country, department and job title. Figures are **always grouped by currency**, never summed across currencies. |
| F4b | **Visual dashboard** | KPI tiles (active headcount, countries, currencies in use) and six charts: headcount by country, headcount by department, hires by year, salary distribution, median and range by department, median by job title. Each chart's **type can be switched** (e.g. bar, column or pie) and every chart has a table view. The charts follow the same filters. Salary charts show **one currency at a time**, so currencies are never mixed. Built on a GraphQL API with query limits, plus GraphiQL for exploration. |
| F5 | **Access** | One authenticated HR Manager role protects every salary endpoint. |
| F6 | **Seed** | A deterministic script creates exactly 10,000 synthetic employees and is safe to re-run. |

**Phase 2 (only after F1–F6 are done and tested):** indicative **FX conversion**. The HR Manager chooses a reporting currency and sees converted figures with the rate, rate date and source (Frankfurter). Source salaries are never changed.

## Key definitions and assumptions (details in `scope-and-assumptions.md`)
- **Salary** means *annual base salary*, stored as `decimal(14,2)` together with an ISO-4217 currency.
- **Current salary** is the compensation record with no `effective_to`. Future-dated changes are not allowed in the MVP.
- **Insights population:** active employees, using their current salary.

## Deliberately out of scope, and why
| Excluded | Reason |
|----------|--------|
| Payroll run, tax, payslips, benefits, statutory filing | A different product with legal liability. The ask is *managing and understanding* pay. |
| Bonus, equity, allowances (total comp) | Mixing components without a policy misleads. Base salary answers the stated questions. |
| Approval workflows, multiple roles, SSO | That would invent a business process nobody asked for. One trusted HR role is enough to protect the data. |
| Gender or demographic pay-equity analysis | Needs sensitive data and legal input. Too high-stakes to approximate. |
| Spreadsheet bulk import / export | High value, but parsing and error-reporting are a feature in their own right. First follow-up candidate. |
| Custom or ad-hoc chart builder, saved dashboards, full-text fuzzy search | Fixed charts answer the four questions above. Substring search covers names and IDs at 10k scale. |
| Cross-currency totals in the MVP | Adding INR to USD is meaningless. This waits for the explicit FX policy in Phase 2. |
| Microservices and Kubernetes services | 10k rows and one team do not justify them. A modular monolith fits (ADR-0001). |

## Quality bar
- Each feature ships as a small, tested slice.
- Backend **and** frontend line coverage of **≥ 90% is enforced in the test run**.
- Tests are fast and deterministic: no network access, frozen time, and fixed seeds.
- Claims are backed by recorded evidence in `docs/evidence/`.
