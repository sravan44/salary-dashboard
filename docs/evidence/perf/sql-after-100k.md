| Case | SQL statements | median ms | p95 ms | DB execution ms (EXPLAIN) | Seq scans |
|---|---|---|---|---|---|
| Directory: default page (name order) | 2 | 30.3 | 31.1 | 47.1 | — |
| Directory: search "rao" | 2 | 10.4 | 22.7 | 8.7 | — |
| Directory: 2 countries × 1 dept × active | 2 | 24.2 | 26.3 | 26.0 | employees |
| Directory: USD 100k–150k, salary desc | 2 | 48.3 | 58.9 | 53.0 | — |
| Directory: deep page (400 of 400) | 2 | 55.0 | 61.9 | 68.4 | — |
| Employee: salary history | 1 | 1.2 | 5.3 | 0.0 | — |
| Employee: history in USD | 3 | 2.1 | 2.5 | 0.0 | fx_rates |
| Employee: audit trail | 1 | 1.7 | 4.1 | 0.1 | — |
| Dashboard: overview (summary) | 1 | 103.7 | 147.3 | 123.8 | employees |
| Dashboard: pay by department (INR) | 1 | 88.3 | 98.0 | 110.7 | employees |
| Dashboard: pay by job title (INR) | 1 | 88.5 | 90.5 | 105.9 | employees |
| Dashboard: distribution (INR) | 2 | 93.0 | 108.9 | 103.7 | employees |
| Dashboard: filtered (India) pay by dept | 1 | 62.1 | 69.6 | 97.7 | employees |
| Converted (USD): pay by department | 3 | 380.2 | 431.6 | 424.0 | fx_rates, employees |
| Converted (USD): distribution | 4 | 301.1 | 338.1 | 323.0 | fx_rates, employees |

Plans: tmp/perf/plans-after-100k.txt (10 timed runs per case)
