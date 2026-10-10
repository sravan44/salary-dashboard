# API contract (draft, refined per milestone)

Base path: `/api/v1`. JSON only. Every endpoint except `POST /session` and `GET /up` requires an authenticated session (401 otherwise, from M7).

**Error shape:** `{ "error": { "code": "validation_failed", "message": "...", "details": { "field": ["msg"] } } }`
Status codes: 400 for invalid query params, 404 when not found, 422 for validation failures.

## Employees
`GET /employees`

| Param | Rules |
|-------|-------|
| `q` | Case-insensitive substring match on name, employee number or email |
| `country`, `department`, `job_title`, `status` | Exact match. Filters combine with AND. An unknown value for an enum-like filter (country, department, status) returns 400. |
| `min_salary`, `max_salary` | Decimal ≥ 0, applied to the current salary. Must be used together with `currency` (otherwise 400), because a range across currencies is meaningless. |
| `currency` | Supported ISO-4217 code (filters on the current salary's currency) |
| `sort` | Allowlist: `full_name`, `employee_number`, `hire_date`, `salary`. Prefix `-` for descending. Default `full_name`. |
| `page` | Integer ≥ 1, default 1 |
| `per_page` | 1–100, default 25 |

Response: `{ "data": [EmployeeSummary], "meta": { "page", "per_page", "total", "total_pages" } }`
`EmployeeSummary` = id, employee_number, full_name, country_code, department, job_title, status, current_salary `{ amount: "120000.00", currency: "USD" }`

Amounts are serialized as **strings** to avoid float precision loss.

- `GET /employees/:id`: summary + email + hire_date
- `POST /employees`: create, with the initial salary (amount, currency, effective_from = hire_date)
- `PATCH /employees/:id`: edit profile fields and status (salary is never changed here)

## Compensation
- `GET /employees/:id/compensations`: full history, newest first
- `POST /employees/:id/compensations` `{ amount, currency, effective_from, reason, notes? }` → 201 with the new record; 422 if the date is ≤ the current start or in the future, the amount is ≤ 0, the currency is unsupported, or the reason is not one of `annual_review | promotion | market_adjustment | correction` (`hire` is set automatically when the employee is created)
- `GET /employees/:id/versions`: the employee's audit trail and that of their salary records, newest first (from M5)

## Insights
**Shared insight filters:** `country`, `department` and `job_title` are accepted by all insights endpoints, so tables and charts always describe the same population.

`GET /insights/pay?group_by=country|department|job_title&<filters>`
→ `{ "data": [{ "group": "IN", "currency": "INR", "headcount": 1200, "min": "...", "max": "...", "avg": "...", "median": "..." }] }`

One row per **(group, currency)**. Covers active employees and their current salary only.

- `GET /insights/summary?<filters>`: KPI tiles. Returns active headcount, number of countries, headcount by country (bar chart), and the currencies in use with headcount each (populates the chart currency selector).
- `GET /insights/distribution?currency=USD&buckets=10&<filters>`: histogram for **one currency** (`currency` is required, otherwise 400; `buckets` 5–20, default 10). Returns `{ "currency", "buckets": [{ "from": "50000.00", "to": "60000.00", "count": 42 }] }`, computed in SQL with `width_bucket`.
- Department range chart: reuses `GET /insights/pay?group_by=department&currency=USD`, adding a `currency` filter so the chart has a single currency.

## Session
`POST /session` `{ email, password }` · `DELETE /session` · `GET /session` (current user)

## Reference
`GET /reference`: supported countries (with default currency), currencies, departments. Feeds the UI dropdowns.
