# Analytics definitions

Every dashboard number is defined here. The hand-calculated fixture in `backend/spec/support/insights_fixture.rb` checks each one.

| Term | Definition |
|------|------------|
| **Population** | Active employees (`status = active`) with their **current** salary (the record with no end date), narrowed by the dashboard filters (country, department, job title). Terminated employees and past salaries are excluded. |
| **Headcount** | Number of employees in the population. |
| **Countries / Currencies** | Distinct countries / current-salary currencies in the population. |
| **Headcount by country / department / currency** | Counts, largest first; ties alphabetical. No money involved. |
| **Hires by year** | Employees in the population grouped by the year of their hire date, oldest year first. People who already left are not counted, so this is "hires who are still here", not total hiring. The last year is partial (the data runs to 2026-10-01). |
| **Pay statistics** | Per **(group, currency)**: amounts in different currencies are **never** combined. Min and max are exact. Average is the mean rounded to 2 dp, half up. **Median** is exact: the middle value for an odd count, the mean of the two middle values for an even count, computed in numeric arithmetic (not Postgres' floating-point `percentile_cont`). Rows are ordered by headcount (descending), then group, then currency. |
| **Salary distribution** | One currency only. The range min..max is split into N equal-width buckets (5–20, default 10). Bucket *i* covers [from, to); the last bucket includes the maximum, so the bucket counts always add up to the headcount for that currency. If everyone earns the same, there is one bucket. If nobody earns in that currency, there are no buckets. |
| **Converted (reporting currency)** | Indicative. Every current salary is converted **first**, at the latest cached rate date on or before today, and **then** aggregated, so a group spanning INR and GBP gets a real median. Cross rates come from the ECB's EUR-based rates (1 A = EUR→B ÷ EUR→A), computed in exact decimals. Min, max, average and median follow the definitions above (2 dp, half up). Employees whose currency has no rate are left out and named. Each rate is shown with its date and source; rates older than 7 days are flagged. |
| **Chart currency** | The salary charts show the currency chosen in the UI, or by default the most common one in the current selection. |

Amounts cross the API as exact strings with two decimals (for example `"103333.33"`).
