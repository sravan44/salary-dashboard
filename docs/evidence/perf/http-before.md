| Request | status | median ms | p95 ms |
|---|---|---|---|
| GET directory (default page) | 200 | 17.3 | 23.2 |
| GET directory ?q=rao | 200 | 36.1 | 53.9 |
| GET directory 2 countries × dept × active | 200 | 12.5 | 14.2 |
| GET directory USD 100k–150k, salary desc | 200 | 12.3 | 14.4 |
| GET directory page 400 | 200 | 22.6 | 24.9 |
| GET employee profile | 200 | 3.5 | 3.8 |
| GET salary history | 200 | 3.6 | 4.4 |
| GET salary history ?report=USD | 200 | 4.1 | 6.6 |
| GET audit trail | 200 | 11.6 | 14.4 |
| POST /graphql DashboardOverview | 200 | 39.3 | 56.7 |
| POST /graphql DashboardCurrencyDetail (INR) | 200 | 33.7 | 37.8 |
| POST /graphql DashboardConverted (USD) | 200 | 92.1 | 125.4 |
