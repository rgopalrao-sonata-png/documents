# Management (Enterprise) — Architecture Diagrams

> Generated: 2026-06-30 09:04 UTC | Source: `enterprise-architect/skills/arch-review/archdocument.txt`

Copy and paste any diagram block into [Mermaid Live Editor](https://mermaid.live/) to render.

---

## System Context Diagram

C4 Context diagram for Management (Enterprise) showing external actors and dependencies.

```mermaid
C4Context
    title System Context — Management (Enterprise)
    Person(1, "Admin", "Primary user")
    Person(2, "Administrator", "Primary user")
    Person(3, "Analyst", "Primary user")
    System(sys, "Management (Enterprise)", "Core platform")
    System_Ext(ext1, "[Extract external dependencies from requirements]", "External dependency")
    Rel(1, sys, "Uses")
    Rel(2, sys, "Uses")
    Rel(3, sys, "Uses")
    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Container Diagram

Major deployable containers and communication paths.

```mermaid
graph TB
    Client([Client Browser / Mobile])
    API["API Service\n(REST/HTTP)"]
    Worker["Background Worker\n(Async)"]
    DB[("Primary Database")]
    Client -->|HTTPS| API
    API --> DB
```

---

## Main User Flow — Sequence Diagram

End-to-end sequence for the primary Analytics operation.

```mermaid
sequenceDiagram
    autonumber
    actor Admin
    participant API as API Service
    participant Auth as Auth Service
    participant DB as Database
    participant Cache as Cache

    Admin->>API: Request (Analytics)
    API->>Auth: Validate JWT token
    Auth-->>API: Token valid + claims
    API->>Cache: Check cached response
    alt Cache hit
        Cache-->>API: Cached data
    else Cache miss
        API->>DB: Query data
        DB-->>API: Result set
        API->>Cache: Store result (TTL=300s)
    end
    API-->>Admin: 200 OK (response)
```

---

## Authentication Flow — Sequence Diagram

Login, token issuance, and token refresh sequence.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Client
    participant API as API Gateway
    participant AuthSvc as Auth Service
    participant IDP as Identity Provider

    User->>Client: Submit credentials
    Client->>API: POST /auth/login
    API->>AuthSvc: Validate credentials
    AuthSvc->>IDP: Authenticate (OAuth2/OIDC)
    IDP-->>AuthSvc: ID token + claims
    AuthSvc-->>API: Access token (JWT) + Refresh token
    API-->>Client: 200 OK {access_token, refresh_token}
    Client->>Client: Store tokens securely

    Note over Client,API: Token Refresh Flow
    Client->>API: POST /auth/refresh {refresh_token}
    API->>AuthSvc: Validate refresh token
    AuthSvc-->>API: New access token
    API-->>Client: 200 OK {access_token}
```

---

## Entity Relationship Diagram

Core domain entities and their relationships.

```mermaid
erDiagram
    User {
        uuid id PK
        string email UK
        string name
        string role
        datetime created_at
        datetime updated_at
    }
    Analytics {
        uuid id PK
        string name
        string status
        uuid owner_id FK
        datetime created_at
        datetime updated_at
    }
    Audit {
        uuid id PK
        string type
        json payload
        uuid analytics_id FK
        datetime occurred_at
    }
    Billing {
        uuid id PK
        string action
        string actor_id
        string resource_type
        uuid resource_id
        json changes
        datetime logged_at
    }

    User ||--o{ Analytics : "owns"
    Analytics ||--o{ Audit : "generates"
    User ||--o{ Billing : "creates"
    Analytics ||--o{ Billing : "tracks" 
```

---
