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
| F1 | **Search and filter employees** | Search by name, employee number or email (case-insensitive, partial match). Filters for country, department, job title, status and salary range. Country, department, job title and status take **several values** (OR within a filter), and different filters **combine** (AND). The salary range stays within one currency. Allowlisted sorting and server-side pagination across all 10,000 records. Active filters appear as removable chips with a "clear all" option, and they live in the URL so a filtered view can be bookmarked or shared. |
| F2 | **Employee management** | Create and edit an employee. Deactivation sets status to `terminated` and keeps the record (no hard delete). Employee number is unique, and validation errors are shown inline. |
| F3 | **Salary history and audit** | A salary change is a new effective-dated record with a **reason** (hire, annual review, promotion, market adjustment, correction) and optional notes. The previous record is closed in the **same transaction**, and history is never overwritten. Every create/update of an employee or salary is also written to an append-only **audit log** (who, when, old → new). |
| F4 | **Pay insights (tables)** | Headcount, plus min / max / average / median salary by country, department and job title for **active** employees. Filterable by country, department and job title. Figures are **always grouped by currency**, never summed across currencies. |
| F4b | **Visual dashboard** | KPI tiles (active headcount, countries, currencies in use) and six charts: headcount by country, headcount by department, hires by year, salary distribution, median and range by department, median by job title. Each chart's **type can be switched** (e.g. bar, column or pie) and every chart has a table view. The charts follow the same filters (multi-select: country, department, job title). Salary charts show **one currency at a time**, so currencies are never mixed. Built on a GraphQL API with query limits, plus GraphiQL for exploration. |
| F5 | **Access** | Sign-in is required for everything. Roles combine (a user may hold several): **Viewer** sees only the dashboard (no individual employees or salaries); **HR manager** also manages employees and sees their salaries; **Admin** also manages users and their roles (multi-select). The server enforces every rule; the UI only shows what a role allows. |
| F7 | **Reporting currency (indicative FX)** | The HR Manager picks a reporting currency on the dashboard. Each salary is converted at cached ECB reference rates (via Frankfurter) and **then** aggregated, so groups that span currencies get real medians and ranges. Every converted chart shows the rate, rate date and source of each currency it used. Employees whose currency has no rate are left out and named; rates older than 7 days are flagged; with no rates, nothing is converted. Stored salaries are never changed, and the provider is never called while a page loads. The employee page can show its amounts (current salary and history) in a reporting currency too, with the same provenance. |
| F6 | **Seed** | A deterministic script creates exactly 10,000 synthetic employees and is safe to re-run. |

FX conversion (F7) was first planned as Phase 2. It was brought forward (M10) because converting analytics into a reporting currency, with rate provenance, is one of the assessment's core workflows.

## Key definitions and assumptions (details in `scope-and-assumptions.md`)
- **Salary** means *annual base salary*, stored as `decimal(14,2)` together with an ISO-4217 currency.
- **Current salary** is the compensation record with no `effective_to`. Future-dated changes are not allowed in the MVP.
- **Insights population:** active employees, using their current salary.

## Deliberately out of scope, and why
| Excluded | Reason |
|----------|--------|
| Payroll run, tax, payslips, benefits, statutory filing | A different product with legal liability. The ask is *managing and understanding* pay. |
| Bonus, equity, allowances (total comp) | Mixing components without a policy misleads. Base salary answers the stated questions. |
| Approval workflows, SSO, self sign-up | That would invent a business process nobody asked for. Three fixed roles (Viewer, HR manager, Admin) cover who may see and change what. |
| Gender or demographic pay-equity analysis | Needs sensitive data and legal input. Too high-stakes to approximate. |
| Spreadsheet bulk import / export | High value, but parsing and error-reporting are a feature in their own right. First follow-up candidate. |
| Custom or ad-hoc chart builder, saved dashboards, full-text fuzzy search | Fixed charts answer the four questions above. Substring search covers names and IDs at 10k scale. |
| Cross-currency totals without conversion | Adding INR to USD is meaningless. Figures across currencies exist only in the reporting-currency view (F7), at named rates. |
| Microservices and Kubernetes services | 10k rows and one team do not justify them. A modular monolith fits (ADR-0001). |

## Quality bar
- Each feature ships as a small, tested slice.
- Backend **and** frontend line coverage of **≥ 90% is enforced in the test run**.
- Tests are fast and deterministic: no network access, frozen time, and fixed seeds.
- Claims are backed by recorded evidence in `docs/evidence/`.
