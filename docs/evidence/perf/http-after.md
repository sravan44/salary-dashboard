| Request | status | median ms | p95 ms |
|---|---|---|---|
| GET directory (default page) | 200 | 8.7 | 9.5 |
| GET directory ?q=rao | 200 | 7.9 | 10.8 |
| GET directory 2 countries × dept × active | 200 | 8.2 | 9.3 |
| GET directory USD 100k–150k, salary desc | 200 | 11.7 | 14.0 |
| GET directory page 400 | 200 | 21.3 | 25.9 |
| GET employee profile | 200 | 3.5 | 4.2 |
| GET salary history | 200 | 4.0 | 4.4 |
| GET salary history ?report=USD | 200 | 5.5 | 6.4 |
| GET audit trail | 200 | 4.4 | 5.3 |
| POST /graphql DashboardOverview | 200 | 15.1 | 17.8 |
| POST /graphql DashboardCurrencyDetail (INR) | 200 | 30.7 | 33.5 |
| POST /graphql DashboardConverted (USD) | 200 | 89.6 | 103.2 |
