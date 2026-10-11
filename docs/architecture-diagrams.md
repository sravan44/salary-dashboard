# Architecture diagrams

All diagrams are Mermaid, so GitHub renders them inline. Rendered SVG copies are in [`diagrams/`](diagrams/). Diagrams marked *(planned)* describe the design before implementation; they are updated if the build differs.

## 1. System context (C4 level 1)

Who uses the system, and what it talks to.

```mermaid
flowchart TB
  HR["👤 HR Manager<br/>ACME People team"]
  SYS["ACME Salary Insights<br/>Manage employee salaries and<br/>understand how ACME pays people"]
  XL["📄 Existing Excel sheets<br/>(replaced; import is future scope)"]
  FX["🌐 Frankfurter<br/>ECB reference FX rates<br/>(fetched by fx:refresh, cached)"]
  HR -->|searches, edits salaries,<br/>views charts| SYS
  XL -.->|future: CSV import| SYS
  SYS -.->|refresh: one request, cached per date| FX
```

## 2. Containers (C4 level 2)

The deployable pieces and how they communicate.

```mermaid
flowchart LR
  B["Browser<br/>React 19 + TypeScript SPA<br/>Mantine · TanStack Query · Highcharts"]
  subgraph APP["Single app container (production)"]
    direction TB
    STATIC["public/<br/>built SPA assets"]
    API["Rails 8.1 API<br/>/api/v1/* · /graphql<br/>session cookie auth"]
    JOBS["Solid Queue (inside Puma)<br/>FxRefreshJob weekdays 16:30 CET"]
  end
  DB[("PostgreSQL 16<br/>employees · compensations · users")]
  B -->|GET / , assets| STATIC
  B -->|JSON over HTTPS<br/>same origin| API
  API -->|ActiveRecord / SQL| DB
  JOBS -->|jobs + fx_rates| DB
  JOBS -.->|HTTPS, once per refresh| FXP["Frankfurter<br/>ECB reference rates"]
```

## 3. Backend components (C4 level 3)

How a request flows through the Rails layers. Controllers stay thin: they parse params and choose the status code.

```mermaid
flowchart TB
  AUTH["Authentication (concern)<br/>session cookie → Current.user · 401<br/>require_permission → 403 · JSON-only writes"]
  subgraph Controllers["Controllers"]
    SC["SessionsController<br/>sign in (rate-limited) · me · sign out"]
    EC["EmployeesController<br/>HR manager"]
    UC["UsersController<br/>Admin"]
    GC["GraphqlController<br/>POST /graphql · any role"]
    RC[ReferencesController]
  end
  subgraph Domain["Use cases & read paths"]
    DQ["Employees::DirectoryQuery<br/>search · filters · sort allowlist · paginate"]
    CE["Employees::Create / Update<br/>employee + first salary (txn) · locked fields"]
    UR["Users::UpdateRoles<br/>never lock out the last admin"]
    GQL["SalaryInsightsSchema<br/>depth 8 · complexity 200 · timeout 5 s"]
    POP["Insights::Population<br/>active + current salary + filters"]
    PSQ["Insights::PayStatsQuery<br/>min/max/avg/exact median per group × currency"]
    DSQ["Insights::DistributionQuery<br/>width_bucket histogram, one currency"]
    SUQ["Insights::SummaryQuery<br/>KPI tiles, headcount by country"]
  end
  subgraph Models["Models + DB constraints"]
    EM[Employee]
    CM[Compensation]
    UM["User<br/>roles[] (check constraint)"]
    SM["Session<br/>token digest · 12 h"]
    REF["Acme::Reference<br/>countries · currencies · departments"]
  end
  AUTH -. guards .-> Controllers
  SC --> UM & SM
  EC --> DQ & CE
  UC --> UR --> UM
  GC --> GQL --> POP
  POP --> PSQ & DSQ & SUQ
  RC --> REF
  DQ & CE & PSQ & DSQ & SUQ --> EM & CM
  EM & CM -. validate against .-> REF
```

## 4. Frontend modules

Feature-first layout: each module owns its pages, hooks, types and tests.

```mermaid
flowchart TB
  APPSHELL["app/<br/>router · layout (nav by permission, signed-in user) · QueryClient"]
  subgraph modules["src/modules"]
    AUTH["auth/<br/>login page · useSession · RequireAuth(permission) · session-expiry watcher"]
    DASH["dashboard/<br/>KPI tiles · 6 Highcharts charts · filter bar"]
    EMP["employees/<br/>directory · filters · chips · profile · create/edit forms"]
    USERS["users/<br/>Admin: add user · roles multi-select"]
  end
  SHARED["shared/<br/>apiClient · graphqlRequest · formatMoney (Intl) · retry policy"]
  APPSHELL --> AUTH
  AUTH -->|guards| DASH & EMP & USERS
  DASH & EMP & USERS & AUTH --> SHARED
```

## 5. Data model

```mermaid
erDiagram
  EMPLOYEE ||--|{ COMPENSATION : "history (exactly 1 current)"
  EMPLOYEE ||--o{ VERSION : "audit log"
  COMPENSATION ||--o{ VERSION : "audit log"
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
    string reason "hire | annual_review | promotion | market_adjustment | correction"
    string revised_by
    text notes
  }
  VERSION {
    string item_type "Employee | Compensation | User"
    bigint item_id
    string event "create | update"
    jsonb object_changes "field => [old, new]"
    string whodunnit
    datetime created_at "append-only"
  }
  USER ||--o{ SESSION : "signed-in browsers"
  USER ||--o{ VERSION : "audit log (roles)"
  USER {
    string email UK
    string password_digest "bcrypt; never logged"
    string_array roles "viewer | hr_manager | admin (1+)"
  }
  SESSION {
    string token_digest UK "SHA-256 of the cookie token"
    datetime expires_at "12 h after sign-in"
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
  participant API as POST /graphql
  participant DB as PostgreSQL
  HR->>UI: choose Country = DE
  UI->>URL: ?country=DE
  UI->>API: DashboardOverview(filters: {country: DE})
  Note over API: depth, complexity, limits and<br/>5 s timeout checked before running
  API->>DB: counts by country, department, hire year, currency
  API-->>UI: tiles + headcount charts + currencies in use (EUR)
  UI->>API: DashboardCurrencyDetail(filters, currency: EUR)
  API->>DB: WIDTH_BUCKET histogram + ROW_NUMBER exact median, one currency
  API-->>UI: a few dozen aggregate rows (never 10k salaries)
  UI-->>HR: KPI tiles + 6 charts (type switchable, each with a table view)
```

## 8. Build and deployment (one container; host chosen in M9)

```mermaid
flowchart LR
  subgraph BUILD["Dockerfile (multi-stage)"]
    direction TB
    S1["1 · node:22-slim<br/>npm ci + npm run build"]
    S2["2 · ruby:3.3.6-slim<br/>bundle install (no dev/test)"]
    S3["3 · runtime<br/>Rails + public/assets + frontend/index.html<br/>non-root user, HEALTHCHECK /up"]
    S1 -->|dist/assets, index.html| S3
    S2 -->|gems + app| S3
  end
  subgraph LOCAL["docker compose up (http://localhost:3000)"]
    direction TB
    APP["app<br/>one container :3000<br/>/ → React app · /api/v1 → JSON"]
    PG[("db: postgres:16<br/>internal network only")]
    APP --> PG
  end
  subgraph PROD["Production (host TBD at M9)"]
    direction TB
    IMG["same image<br/>FORCE_SSL=true behind TLS proxy"]
    MPG[("Managed PostgreSQL")]
    IMG -->|DATABASE_URL secret| MPG
  end
  S3 --> APP
  S3 --> IMG
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
