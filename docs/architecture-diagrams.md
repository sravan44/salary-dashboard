# Architecture diagrams

All diagrams are Mermaid, so GitHub renders them inline. Rendered SVG copies are in [`diagrams/`](diagrams/). Diagrams marked *(planned)* describe the design before implementation; they are updated if the build differs.

## 1. System context (C4 level 1)

Who uses the system, and what it talks to.

```mermaid
flowchart TB
  HR["👤 HR Manager<br/>ACME People team"]
  SYS["ACME Salary Insights<br/>Manage employee salaries and<br/>understand how ACME pays people"]
  XL["📄 Existing Excel sheets<br/>(replaced; import is future scope)"]
  FX["🌐 Frankfurter<br/>reference FX rates<br/>(Phase 2 only)"]
  HR -->|searches, edits salaries,<br/>views charts| SYS
  XL -.->|future: CSV import| SYS
  SYS -.->|Phase 2: daily rates, cached| FX
```

## 2. Containers (C4 level 2)

The deployable pieces and how they communicate.

```mermaid
flowchart LR
  B["Browser<br/>React 19 + TypeScript SPA<br/>Mantine · TanStack Query · Recharts"]
  subgraph APP["Single app container (production)"]
    direction TB
    STATIC["public/<br/>built SPA assets"]
    API["Rails 8.1 API<br/>/api/v1/*<br/>session cookie auth"]
  end
  DB[("PostgreSQL 16<br/>employees · compensations · users")]
  B -->|GET / , assets| STATIC
  B -->|JSON over HTTPS<br/>same origin| API
  API -->|ActiveRecord / SQL| DB
```

## 3. Backend components (C4 level 3)

How a request flows through the Rails layers. Controllers stay thin: they parse params and choose the status code.

```mermaid
flowchart TB
  subgraph Controllers["Controllers (api/v1)"]
    EC[EmployeesController]
    CC[CompensationsController]
    IC[InsightsController]
    SC[SessionsController]
    RC[ReferenceController]
  end
  subgraph Domain["Use cases & read paths"]
    DQ["Employees::DirectoryQuery<br/>search · filters · sort allowlist · paginate"]
    CE["Employees::Create<br/>employee + initial salary (txn)"]
    RCH["Compensations::RecordChange<br/>lock · validate · close · insert (txn)"]
    PSQ["Insights::PayStatsQuery<br/>min/max/avg/median per group × currency"]
    DSQ["Insights::DistributionQuery<br/>width_bucket histogram, one currency"]
    SUQ["Insights::SummaryQuery<br/>KPI tiles, headcount by country"]
  end
  subgraph Models["Models + DB constraints"]
    EM[Employee]
    CM[Compensation]
    UM[User]
    REF["Acme::Reference<br/>countries · currencies · departments"]
  end
  EC --> DQ & CE
  CC --> RCH
  IC --> PSQ & DSQ & SUQ
  SC --> UM
  RC --> REF
  DQ & CE & RCH & PSQ & DSQ & SUQ --> EM & CM
  EM & CM -. validate against .-> REF
```

## 4. Frontend modules

Feature-first layout: each module owns its pages, hooks, types and tests.

```mermaid
flowchart TB
  APPSHELL["app/<br/>router · layout · QueryClient · auth guard"]
  subgraph modules["src/modules"]
    DASH["dashboard/<br/>KPI tiles · charts · filter bar"]
    EMP["employees/<br/>directory · filters · chips · detail · forms"]
    COMP["compensation/<br/>history list · record-change form"]
    INS["insights/<br/>API hooks + types for summary/pay/distribution"]
    AUTH["auth/<br/>login page · useSession"]
  end
  SHARED["shared/<br/>apiClient · formatMoney (Intl) · useUrlFilters · ChartCard (chart ⇄ table)"]
  APPSHELL --> DASH & EMP & AUTH
  DASH --> INS
  EMP --> COMP
  DASH & EMP & COMP & INS & AUTH --> SHARED
```

## 5. Data model

```mermaid
erDiagram
  EMPLOYEE ||--|{ COMPENSATION : "history (exactly 1 current)"
  EMPLOYEE {
    string employee_number UK
    string full_name
    string email UK
    string country_code
    string department
    string job_title
    string status "active | terminated"
    date hire_date
  }
  COMPENSATION {
    decimal amount "numeric(14,2) > 0"
    string currency "ISO-4217"
    date effective_from
    date effective_to "NULL = current (partial unique index)"
  }
  USER {
    string email UK
    string password_digest
  }
```

## 6. Sequence: record a salary change (the critical write)

```mermaid
sequenceDiagram
  actor HR as HR Manager
  participant UI as React (record-change form)
  participant API as CompensationsController
  participant S as Compensations::RecordChange
  participant DB as PostgreSQL
  HR->>UI: amount 125000 USD, effective 2026-10-01
  UI->>API: POST /api/v1/employees/42/compensations
  API->>S: call(employee_id, params)
  S->>DB: BEGIN
  S->>DB: SELECT employee FOR UPDATE (row lock)
  S->>DB: SELECT current compensation (effective_to IS NULL)
  alt invalid (date ≤ current start, future date, amount ≤ 0, bad currency)
    S->>DB: ROLLBACK
    S-->>API: failure(errors)
    API-->>UI: 422 {error: validation_failed, details}
    UI-->>HR: inline errors, history unchanged
  else valid
    S->>DB: UPDATE current SET effective_to = 2026-09-30
    S->>DB: INSERT new (125000 USD, from 2026-10-01, to NULL)
    S->>DB: COMMIT
    Note over DB: partial unique index guarantees<br/>only one current record
    S-->>API: success(new record)
    API-->>UI: 201 {data: compensation}
    UI-->>HR: history refreshed (old row closed, new row current)
  end
```

## 7. Sequence: filtered dashboard and charts (the critical read)

```mermaid
sequenceDiagram
  actor HR as HR Manager
  participant UI as Dashboard
  participant URL as URL query string
  participant API as InsightsController
  participant DB as PostgreSQL
  HR->>UI: choose Country = DE, chart currency = EUR
  UI->>URL: ?country=DE&currency=EUR
  par same filters to every widget
    UI->>API: GET /insights/summary?country=DE
    API->>DB: COUNT … GROUP BY country, currency
  and
    UI->>API: GET /insights/distribution?country=DE&currency=EUR
    API->>DB: width_bucket(amount, min, max, 10) GROUP BY bucket
  and
    UI->>API: GET /insights/pay?group_by=department&country=DE&currency=EUR
    API->>DB: percentile_cont(0.5), min, max, avg GROUP BY department, currency
  end
  API-->>UI: a few dozen aggregate rows (never 10k salaries)
  UI-->>HR: KPI tiles + 3 charts (each with table view)
```

## 8. Deployment *(planned; host chosen in M9)*

```mermaid
flowchart LR
  subgraph DEV["Local development (compose.yaml)"]
    direction TB
    FE["frontend<br/>Vite dev server :5173<br/>proxy /api → backend"]
    BE["backend<br/>rails s :3000"]
    PG[("postgres:16<br/>internal network only")]
    FE --> BE --> PG
  end
  subgraph PROD["Production (host TBD at M9)"]
    direction TB
    IMG["One Docker image<br/>stage 1: npm run build<br/>stage 2: Rails + public/ SPA"]
    MPG[("Managed PostgreSQL")]
    IMG -->|DATABASE_URL secret| MPG
  end
  GIT["GitHub repo<br/>sravan44/salary-dashboard"] -->|build| IMG
```

## 9. Seed data flow

```mermaid
flowchart LR
  R["Random.new(42)<br/>+ Faker seeded"] --> G["Generate 10,000 employees<br/>country weights · dept · level"]
  G --> B["Salary band per<br/>country × level (local currency)"]
  B --> H["1–4 history records each<br/>last one current"]
  H --> I["insert_all in batches of 1,000<br/>inside one transaction"]
  I --> V["Verify: exactly 10,000 employees,<br/>10,000 current salaries, 0 duplicates"]
  X["Re-run"] -->|"truncate seeded tables first<br/>→ identical result"| G
```
