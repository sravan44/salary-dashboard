| Case | SQL statements | median ms | p95 ms | DB execution ms (EXPLAIN) | Seq scans |
|---|---|---|---|---|---|
| Directory: default page (name order) | 2 | 5.6 | 7.5 | 4.9 | employees |
| Directory: search "rao" | 2 | 5.7 | 6.9 | 1.9 | — |
| Directory: 2 countries × 1 dept × active | 2 | 5.2 | 7.7 | 6.0 | employees |
| Directory: USD 100k–150k, salary desc | 2 | 9.7 | 15.1 | 7.4 | employees |
| Directory: deep page (400 of 400) | 2 | 17.9 | 18.5 | 22.9 | employees |
| Employee: salary history | 1 | 1.0 | 1.4 | 0.0 | — |
| Employee: history in USD | 3 | 2.0 | 2.8 | 0.0 | fx_rates |
| Employee: audit trail | 1 | 2.2 | 3.2 | 0.0 | — |
| Dashboard: overview (summary) | 1 | 9.6 | 10.2 | 10.6 | employees |
| Dashboard: pay by department (INR) | 1 | 8.5 | 14.0 | 8.1 | employees |
| Dashboard: pay by job title (INR) | 1 | 7.9 | 8.1 | 8.2 | employees |
| Dashboard: distribution (INR) | 2 | 9.5 | 10.6 | 9.4 | employees |
| Dashboard: filtered (India) pay by dept | 1 | 8.1 | 8.3 | 7.7 | employees |
| Converted (USD): pay by department | 3 | 34.4 | 36.3 | 37.4 | fx_rates, employees |
| Converted (USD): distribution | 4 | 30.4 | 38.9 | 33.5 | fx_rates, employees |

Plans: tmp/perf/plans-after.txt (20 timed runs per case)
