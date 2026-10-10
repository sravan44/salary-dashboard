# Domain model

```mermaid
erDiagram
  EMPLOYEE ||--o{ COMPENSATION : "has history"
  EMPLOYEE {
    bigint id PK
    string employee_number UK "e.g. EMP-000001"
    string full_name
    string email UK
    string country_code "ISO-3166 alpha-2, from supported list"
    string department
    string job_title
    string status "active | terminated"
    date hire_date
  }
  COMPENSATION {
    bigint id PK
    bigint employee_id FK
    decimal amount "numeric(14,2) > 0, annual base"
    string currency "ISO-4217, from supported list"
    date effective_from
    date effective_to "NULL = current"
  }
  USER {
    bigint id PK
    string email UK
    string password_digest
  }
```

Countries, currencies and departments are a **small, static, code-level list** (`Acme::Reference`) rather than tables. They change rarely, need no admin UI in the MVP, and the list stays validated in one place. If HR needs to manage them, they get promoted to tables later.

## Invariants (and where each is enforced)
| Invariant | Model validation | DB constraint | Test |
|-----------|------------------|---------------|------|
| Employee number unique | ✓ | unique index | model + request |
| Amount > 0, decimal | ✓ | `CHECK (amount > 0)`, numeric(14,2) | model |
| Currency is supported ISO code | ✓ | `NOT NULL` | model |
| `effective_to` ≥ `effective_from` when present | ✓ | `CHECK` | model |
| **At most one current record per employee** | service | **unique partial index** `WHERE effective_to IS NULL` | service (incl. concurrency-safe lock) |
| New change starts after current start and not in the future | service | — | service |
| Change is atomic | service transaction | — | rollback spec |
| Never aggregate across currencies | query groups by currency | — | insights spec with mixed currencies |
