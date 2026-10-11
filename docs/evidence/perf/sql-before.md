| Case | SQL statements | median ms | p95 ms | DB execution ms (EXPLAIN) | Seq scans |
|---|---|---|---|---|---|
| Directory: default page (name order) | 2 | 12.0 | 12.4 | 14.0 | employees |
| Directory: search "rao" | 2 | 29.3 | 32.7 | 28.6 | employees |
| Directory: 2 countries × 1 dept × active | 2 | 8.5 | 9.2 | 8.2 | employees |
| Directory: USD 100k–150k, salary desc | 2 | 8.6 | 10.6 | 11.1 | employees |
| Directory: deep page (400 of 400) | 2 | 17.7 | 18.8 | 21.1 | employees |
| Employee: salary history | 1 | 1.2 | 1.5 | 0.0 | — |
| Employee: history in USD | 3 | 2.2 | 3.3 | 0.0 | fx_rates |
| Employee: audit trail | 1 | 8.5 | 10.1 | 6.7 | — |
| Dashboard: overview (summary) | 6 | 32.8 | 54.1 | 39.2 | employees |
| Dashboard: pay by department (INR) | 1 | 8.0 | 8.9 | 8.3 | employees |
| Dashboard: pay by job title (INR) | 1 | 8.1 | 9.0 | 9.1 | employees |
| Dashboard: distribution (INR) | 2 | 10.0 | 10.7 | 9.2 | employees |
| Dashboard: filtered (India) pay by dept | 1 | 8.9 | 12.8 | 12.8 | employees |
| Converted (USD): pay by department | 3 | 34.8 | 54.5 | 58.5 | fx_rates, employees |
| Converted (USD): distribution | 4 | 30.2 | 37.8 | 33.6 | fx_rates, employees |

Plans: tmp/perf/plans-before.txt (20 timed runs per case)
