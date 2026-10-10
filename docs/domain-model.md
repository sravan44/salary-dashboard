# Domain model

```mermaid
erDiagram
  EMPLOYEE ||--o{ COMPENSATION : "has history"
  EMPLOYEE ||--o{ VERSION : "audited by"
  COMPENSATION ||--o{ VERSION : "audited by"
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
    string reason "hire|annual_review|promotion|market_adjustment|correction"
    string revised_by "who recorded it (user from M7)"
    text notes "optional, <= 1000 chars"
  }
  VERSION {
    bigint id PK
    string item_type "Employee | Compensation"
    bigint item_id
    string event "create | update"
    jsonb object_changes "field => [old, new]"
    string whodunnit "actor"
    datetime created_at
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
| Every salary record says why it exists (reason) | enum | `CHECK reason IN (...)` | model |
| Every create/update of an employee or salary is audited, in the same transaction | `Versioned` concern | `CHECK event IN (...)` | version spec |
| Audit entries are never edited or deleted by the app | `Version#readonly?` | — | version spec |

## Two kinds of history
Why and how this helps HR: [ADR-0002](decisions/ADR-0002-salary-history-and-audit-trail.md).

- **`compensations`** is the *business* history: what an employee was paid, from when to when, and **why** (reason, notes, revised_by). This is what HR reads and what the salary-change rules govern.
- **`versions`** is the *technical* audit log: every create/update of an employee **or** a salary record, with who did it and each changed field's old and new value. It also captures profile edits (department, job title, status) that are not salary history.
