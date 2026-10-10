# API contract (draft, refined per milestone)

Base path: `/api/v1`. JSON only. Every endpoint except `POST /session` and `GET /up` requires an authenticated session (401 otherwise, from M7).

**Error shape:** `{ "error": { "code": "validation_failed", "message": "...", "details": { "field": ["msg"] } } }`
Status codes: 400 for invalid query params (`code: invalid_parameters`, every problem listed in `details`), 404 when not found (`not_found`), 422 for validation failures.

## Employees
`GET /employees`

| Param | Rules |
|-------|-------|
| `q` | Case-insensitive substring match on name, employee number or email |
| `country`, `department`, `job_title`, `status` | Exact match. One value (`country=DE`) or several (`country[]=DE&country[]=FR`): values within a filter combine with **OR**, different filters with **AND**. Blank and repeated values are ignored; more than 50 values for one filter returns 400. An unknown value for an enum-like filter (country, department, status) returns 400. |
| `min_salary`, `max_salary` | Decimal ≥ 0, applied to the current salary. Must be used together with `currency` (otherwise 400), because a range across currencies is meaningless. |
| `currency` | One supported ISO-4217 code (filters on the current salary's currency). Deliberately single-valued: the salary range and salary sort need one currency. |
| `sort` | Allowlist: `full_name`, `employee_number`, `hire_date`, `salary`. Prefix `-` for descending. Default `full_name`. Sorting by `salary` requires `currency` (otherwise 400). Ties are broken by id, so pages are stable. |
| `page` | Integer ≥ 1, default 1 |
| `per_page` | 1–100, default 25. A page past the end returns `data: []` with the real `total`. |

Response: `{ "data": [EmployeeSummary], "meta": { "page", "per_page", "total", "total_pages" } }`
`EmployeeSummary` = id, employee_number, full_name, country_code, department, job_title, status, hire_date, current_salary `{ amount: "120000.00", currency: "USD" }`

Amounts are serialized as **strings** to avoid float precision loss.

- `GET /employees/:id`: summary + email
- `POST /employees` `{ employee: { full_name, email, country_code, department, job_title, hire_date, salary: { amount, currency } } }` → **201** with the employee. The server assigns the next `employee_number` and sets `status: active`. The employee and the first salary (`reason: hire`, `effective_from = hire_date`) are saved in one transaction, or not at all. `hire_date` must be today or earlier.
- `PATCH /employees/:id` `{ employee: { full_name?, email?, country_code?, department?, job_title?, status? } }` → **200**. `status: terminated` deactivates and `status: active` reactivates; the record is never deleted. Sending `hire_date`, `employee_number` or `salary` returns 422 with the reason on that field. Changing the country does not change the salary currency.
- Errors: a missing `employee` object returns **400** `invalid_parameters`. Invalid fields return **422** `{ error: { code: "validation_failed", details: { "email": ["has already been taken"], "salary.amount": ["must be greater than 0"] } } }`, and nothing is saved.
- Every create and update writes an audit `version` in the same transaction (`whodunnit` = the signed-in user's email).

## Sign-in and access
Every `/api/v1/*` and `/graphql` request needs a signed-in user, except `POST /session` (and `/up`, the health check). The session token is in an `HttpOnly`, `SameSite=Lax` cookie (`Secure` over HTTPS) and expires 12 hours after sign-in; only its SHA-256 digest is stored. `POST`/`PATCH` bodies must be `application/json` (otherwise **415** `json_required`), which a form on another site cannot send.

- `POST /session` `{ email, password }` → **201** `{ data: { id, email, roles, permissions: { view_dashboard, manage_employees, manage_users } } }`; **401** `invalid_credentials` (same answer for an unknown email and a wrong password); **429** `too_many_attempts` after 10 attempts in 3 minutes from one IP.
- `GET /session` → the signed-in user, or **401** `unauthenticated`. `DELETE /session` → **204**; the token stops working at once.
- Not signed in → **401** `unauthenticated`. Signed in without the right role → **403** `forbidden`.

| Endpoint | Viewer | HR manager | Admin |
|---|---|---|---|
| `POST /graphql` (dashboard), `GET /reference` | ✓ | ✓ | ✓ |
| `/employees` (list, profile, create, edit) | 403 | ✓ | 403 (unless also HR manager) |
| `/users` (list, create, change roles) | 403 | 403 | ✓ |

### Users (Admin)
- `GET /users` → `{ data: [{ id, email, roles, created_at }] }`, by email. Never includes password data.
- `POST /users` `{ user: { email, roles: [...], password } }` → **201**. The password must be 12–72 characters, and there must be at least one known role. Otherwise **422** with field errors.
- `PATCH /users/:id` `{ user: { roles: [...] } }` → **200**. Only roles change here. **422** `roles` if it would remove your own Admin role, or the last Admin's. Role changes are audited (`whodunnit` = the admin's email); password digests never enter the audit log.

## Compensation (HR manager only)
- `GET /employees/:id/compensations` → full history, newest first: `{ id, amount: "121000.50", currency, effective_from, effective_to (null = current), current, reason, notes, revised_by, change_percent }`. `change_percent` is the % change from the record before (2 dp, half-up, e.g. `"11.11"`), derived at read time and never stored. It is `null` for the first record and when the currency changed.
- `POST /employees/:id/compensations` `{ compensation: { amount, currency, effective_from, reason, notes? } }` → **201** with the new record (with `change_percent`). In one transaction: lock the employee row, check, set the current record's `effective_to` to the day before, insert the new record (`revised_by` = the signed-in user). **422**, with history untouched, if the date is on or before the current start or in the future, the amount is ≤ 0, the currency is unsupported, the reason is not one of `annual_review | promotion | market_adjustment | correction` (`hire` is set automatically when the employee is created), or the employee is deactivated (`employee` error). A currency change is allowed.
- `GET /employees/:id/versions` → the audit trail of the employee and their salary records, newest first: `{ id, item_type: "Employee" | "Compensation", item_id, event: "create" | "update", changes: { field: [old, new] }, whodunnit, created_at }`.

## Insights: GraphQL (`POST /graphql`)
The dashboard uses GraphQL (the employee search stays REST). The schema is in [`frontend/src/graphql/schema.graphql`](../frontend/src/graphql/schema.graphql), generated by `bin/rails graphql:dump_schema` and kept in step by a spec. The definitions are in [`analytics-definitions.md`](analytics-definitions.md).

```graphql
dashboard(filters: DashboardFilters): Dashboard!   # filters (lists, OR within / AND across): country [CountryCode!], department [Department!] (e.g. CUSTOMER_SUPPORT), jobTitle [String!]
  headcount, countriesCount
  currencies { currency headcount }                 # never a combined amount
  headcountByCountry { countryCode countryName headcount }
  headcountByDepartment { department headcount }
  hiresByYear { year headcount }
  payStats(groupBy: COUNTRY|DEPARTMENT|JOB_TITLE, currency: Currency, limit: Int = 50) { group currency headcount min max avg median }
  distribution(currency: Currency!, buckets: Int = 10) { from to count }
reference: Reference!                               # countries, departments, currencies, jobTitles
```

| Limit / setting | Value | Error |
|---|---|---|
| Max depth | 8 | `Query has depth of 9, which exceeds max depth of 8` |
| Max complexity | 200 (`payStats` costs its `limit`, `distribution` 20) | `Query has complexity of 301, which exceeds max complexity of 200` |
| `limit` | 1–100 | `limit must be between 1 and 100` |
| `buckets` | 5–20 | `buckets must be between 5 and 20` |
| Timeout | 5 s per query | `Timeout on Dashboard.<field>` |
| Unknown enum value | rejected by the schema | `Argument 'country' … has an invalid value (XX)` |
| Values per filter | ≤ 50 (a single value is accepted as a one-item list) | `jobTitle is too long (maximum is 50)` |
| Introspection | on when `GRAPHIQL_ENABLED=true` (local/dev default), off otherwise | `Field '__schema' doesn't exist` |
| Methods | `POST` only | `405 Method Not Allowed`, `Allow: POST` |

**GraphiQL:** `GET /graphiql` (only when `GRAPHIQL_ENABLED=true`), bundled from npm, not loaded from a CDN.

## Session
`POST /session` `{ email, password }` · `DELETE /session` · `GET /session` (current user)

## Reference
`GET /reference` → `{ data: { countries: [{code, name, currency}], currencies, departments, statuses, job_titles } }`. Feeds the UI dropdowns; `job_titles` are the distinct titles in use.
