# Developer Agent — Complete Architecture

This document is the single-source reference for how the Developer Agent is structured,
how its phases chain together, how work is routed by ticket type, and which external
systems each skill talks to.

---

## 1. System Architecture Overview

A layered view of every component and how they connect.

```mermaid
graph TD
    subgraph USER["Developer"]
        DEV["Invoke with Jira ticket ID\n/dev-agent ENG-1234\nor any skill standalone"]
    end

    subgraph AGENT["Claude Code Agent  ─  .claude/skills/"]
        DA["/dev-agent\nMaster Orchestrator"]
        CT["/classify-ticket\nWork-Type Router  ⬡ NEW"]
        AJ["/analyze-jira\nPhase 1"]
        GC["/gather-context\nPhase 2"]
        CP["/create-plan\nPhase 3"]
        IM["/implement\nPhase 4"]
        GT["/generate-tests\nPhase 5"]
        PR["/create-pr\nPhase 6"]
        UD["/update-docs\nPhase 7"]
    end

    subgraph SPEC["Specialized Skills  ─  edx-enterprise-*"]
        subgraph BE["Backend  (edx-enterprise-backend)"]
            BE1["architecture-review"]
            BE2["django-essentials"]
            BE3["unit-tests"]
            BE4["celery-patterns"]
            BE5["security-best-practices"]
            BE6["quality-checks"]
            BE7["review-brief"]
            BE8["system-integration-patterns"]
        end
        subgraph FE["Frontend  (edx-enterprise-frontend-plugin)"]
            FE1["architecture-review"]
            FE2["paragon"]
            FE3["accessibility"]
            FE4["unit-tests"]
            FE5["quality-checks"]
            FE6["review-brief"]
        end
    end

    subgraph STATE["Shared State"]
        IMPL[("impl-plan.md\nTicket Classification\nContext Discovery\nImplementation Plan\nApproval Record\nCompletion Summary")]
    end

    subgraph MCP["MCP Servers  ─  mcp_servers/  (FastMCP)"]
        MJ["jira_server.py\n5 tools"]
        MC["confluence_server.py\n4 tools"]
        MG["github_server.py\n7 tools"]
        MR["rovo_server.py\n3 tools"]
    end

    subgraph EXT["External Services"]
        JIRA["Jira"]
        CONF["Confluence"]
        GH["GitHub"]
        ROVO["Atlassian Rovo"]
    end

    DEV --> DA
    DEV -.standalone.-> CT
    DEV -.standalone.-> AJ
    DEV -.standalone.-> GC
    DEV -.standalone.-> CP

    DA --> CT
    DA --> AJ
    DA --> GC
    DA --> CP
    DA --> IM
    DA --> GT
    DA --> PR
    DA --> UD

    CT --> BE
    CT --> FE
    CT --> IMPL
    AJ --> IMPL
    GC --> IMPL
    CP --> IMPL
    IM -. reads .-> IMPL
    GT -. reads .-> IMPL
    PR -. reads .-> IMPL

    AJ --> MJ
    GC --> MJ
    GC --> MC
    GC --> MG
    GC --> MR
    IM --> MG
    GT --> MG
    PR --> MG
    PR --> MJ
    UD --> MC
    UD --> MJ

    MJ --> JIRA
    MC --> CONF
    MG --> GH
    MR --> ROVO
```

---

## 2. Phase Execution Flow

How `/dev-agent` executes all phases in sequence with human checkpoints and routing gates.

```mermaid
flowchart TD
    START(["Developer invokes\n/dev-agent ENG-1234"])

    P05["Phase 0.5 — /classify-ticket\nSignal scoring · Domain classification\nFrontend / Backend / Full-Stack / Ambiguous"]
    CONF_CT{Confidence\n≥ 50%?}
    CLARIFY["Ask 3 clarifying questions\nFrontend? Backend? DB migrations?"]
    RECLASSIFY["Re-classify with\nhuman answers"]

    P1["Phase 1 — /analyze-jira\nFetch ticket · Extract requirements\nAcceptance criteria · Dependency mapping\nWork-type · Affected layers"]
    CONF_P1{Confidence\n≥ 70%?}
    CLARIFY2["Present clarification\nquestions · Wait for answers"]

    P2["Phase 2 — /gather-context\nConfluence architecture docs\nRovo ADRs + coding standards\nGitHub code patterns\nAffected component mapping"]

    P3["Phase 3 — /create-plan\nAtomic task breakdown\nDependency graph · DB impact\nAPI contracts · Risk register\nEdge cases · Estimate"]
    POST_JIRA1[/"Post plan summary to Jira"/]

    CHECKPOINT{{"⏸ HUMAN CHECKPOINT\nAwait approval"}}
    APPROVE{"Response?"}
    REJECT_REVISE["Revise plan with feedback\nShow diff · Re-ask"]
    SKIP_IMPL["Jump to Phase 7\nDocs only — no code"]

    P4["Phase 4 — /implement\nCreate feature branch\nBackend: model → migration → serializer\n→ viewset → URLs → admin\nFrontend: service → hook → component\nCommit each file"]

    P5["Phase 5 — /generate-tests\nBackend: pytest model/serializer\nAPI permission matrix · service tests\nMigration forward + rollback\nFrontend: Jest + RTL component\nhook state transitions"]

    P6["Phase 6 — /create-pr\nWrite reviewer-ready PR description\nOpen draft GitHub PR\nUpdate Jira → In Review\nPost PR link to Jira"]

    P7["Phase 7 — /update-docs\nCreate Confluence implementation page\nGenerate release notes\nUpdate CHANGELOG.md\nWrite completion section to impl-plan.md"]

    POST_JIRA2[/"Post completion summary to Jira"/]
    END_OK(["✅ Done\nPR open · Docs published\nJira updated"])

    START --> P05
    P05 --> CONF_CT
    CONF_CT -- No --> CLARIFY
    CLARIFY --> RECLASSIFY
    RECLASSIFY --> P1
    CONF_CT -- Yes --> P1

    P1 --> CONF_P1
    CONF_P1 -- No --> CLARIFY2
    CLARIFY2 --> P1
    CONF_P1 -- Yes --> P2

    P2 --> P3
    P3 --> POST_JIRA1
    POST_JIRA1 --> CHECKPOINT
    CHECKPOINT --> APPROVE

    APPROVE -- approve --> P4
    APPROVE -- reject + feedback --> REJECT_REVISE
    REJECT_REVISE --> CHECKPOINT
    APPROVE -- skip-impl --> SKIP_IMPL
    SKIP_IMPL --> P7

    P4 --> P5
    P5 --> P6
    P6 --> P7
    P7 --> POST_JIRA2
    POST_JIRA2 --> END_OK
```

---

## 3. classify-ticket — Signal Analysis & Routing

How `/classify-ticket` reads a ticket and decides which skill path to activate.

```mermaid
flowchart TD
    IN(["Input: Jira Ticket ID"])

    FETCH["Fetch via MCP\nmcp__jira__get_ticket\nmcp__jira__get_linked_tickets"]

    SCAN["Scan: summary · description\nlabels · components · linked tickets"]

    subgraph SIGNALS["Signal Extraction  (weighted scoring)"]
        FE_SIG["Frontend Signals\nReact · JSX · Paragon · hooks\nRedux · Jest · RTL · a11y\nCSS · .jsx/.tsx file paths"]
        BE_SIG["Backend Signals\nDjango · DRF · model · migration\nViewSet · serializer · pytest\nCelery · service layer · SQL"]
        IN_SIG["Infra Signals\nDocker · K8s · CI/CD\nenv vars · secrets · Helm"]
        DA_SIG["Data Signals\nSnowflake · dbt · ETL\nanalytics · warehouse · segment"]
    end

    SCORE["Normalise scores\nHIGH×3 + MEDIUM×2 + LOW×1\ndivide by total signal weight"]

    DECIDE{"Classification\ndecision"}

    FE_ONLY["frontend-only\nFE score ≥ 60%\nBE score < 20%"]
    BE_ONLY["backend-only\nBE score ≥ 60%\nFE score < 20%"]
    FS["full-stack\nFE ≥ 30% AND\nBE ≥ 30%"]
    INFRA["infra-only\nInfra score ≥ 50%"]
    DATA["data-only\nData score ≥ 50%"]
    AMB["ambiguous\nAll scores < 20%\nor no clear winner"]

    CONF_CHECK{Confidence\n≥ 50%?}
    QUESTIONS["Ask 3 clarifying questions:\nFrontend / Backend / DB migrations?\nRe-run classification with answers"]

    SAVE["Save classification to impl-plan.md\nPrint domain score breakdown\nPrint key signals found"]

    FE_PATH["Frontend skill chain:\nanalyze-jira → gather-context\n→ FE:architecture-review\n→ FE:paragon → FE:accessibility\n→ create-plan → implement\n→ FE:unit-tests → FE:quality-checks\n→ FE:review-brief → create-pr"]

    BE_PATH["Backend skill chain:\nanalyze-jira → gather-context\n→ BE:architecture-review\n→ BE:django-essentials\n→ BE:celery-patterns (if async)\n→ create-plan → implement\n→ BE:unit-tests\n→ BE:security-best-practices\n→ BE:quality-checks\n→ BE:review-brief → create-pr"]

    FS_PATH["Full-stack skill chain:\nBoth BE + FE chains\nBackend first (API contract before\nfrontend integration)\nParallel quality checks at end"]

    OTHER_PATH["Infra/Data chains:\nanalyze-jira → gather-context\n→ create-plan → implement\n→ BE:security-best-practices\n→ create-pr"]

    PROMPT{"User input?"}
    RUN["Execute\nskill chain"]
    RUN_N["Execute\nskill N only"]
    HANDOFF["/dev-agent uses\nclassification from impl-plan.md"]
    STOP_OK(["Stop — classification\nsaved to impl-plan.md"])

    IN --> FETCH
    FETCH --> SCAN
    SCAN --> FE_SIG & BE_SIG & IN_SIG & DA_SIG
    FE_SIG & BE_SIG & IN_SIG & DA_SIG --> SCORE
    SCORE --> DECIDE

    DECIDE --> FE_ONLY & BE_ONLY & FS & INFRA & DATA & AMB

    FE_ONLY & BE_ONLY & FS & INFRA & DATA --> CONF_CHECK
    AMB --> QUESTIONS
    QUESTIONS --> CONF_CHECK

    CONF_CHECK -- Yes --> SAVE
    CONF_CHECK -- No --> QUESTIONS

    SAVE --> FE_ONLY --> FE_PATH
    SAVE --> BE_ONLY --> BE_PATH
    SAVE --> FS --> FS_PATH
    SAVE --> INFRA & DATA --> OTHER_PATH

    FE_PATH & BE_PATH & FS_PATH & OTHER_PATH --> PROMPT
    PROMPT -- run --> RUN
    PROMPT -- run-phase N --> RUN_N
    PROMPT -- dev-agent --> HANDOFF
    PROMPT -- stop --> STOP_OK
```

---

## 4. MCP Server & Tool Integration

Which skill calls which MCP tool, and which external service it hits.

```mermaid
graph LR
    subgraph SKILLS["Skills"]
        AJ["/analyze-jira"]
        GC["/gather-context"]
        IM["/implement"]
        GT["/generate-tests"]
        PR["/create-pr"]
        UD["/update-docs"]
    end

    subgraph JIRA_SRV["jira_server.py"]
        J1["get_ticket"]
        J2["get_linked_tickets"]
        J3["search_tickets"]
        J4["post_comment"]
        J5["update_status"]
    end

    subgraph CONF_SRV["confluence_server.py"]
        C1["search"]
        C2["get_page"]
        C3["create_page"]
        C4["update_page"]
    end

    subgraph GH_SRV["github_server.py"]
        G1["search_code"]
        G2["get_file"]
        G3["list_files"]
        G4["create_branch"]
        G5["commit_file"]
        G6["create_pr"]
    end

    subgraph ROVO_SRV["rovo_server.py"]
        R1["query_knowledge"]
        R2["search_architecture"]
        R3["get_coding_standards"]
    end

    AJ --> J1 & J2 & J3
    PR --> J4 & J5
    UD --> J4

    GC --> C1 & C2
    UD --> C3 & C4

    GC --> G1 & G2
    IM --> G2 & G3 & G4 & G5
    GT --> G5
    PR --> G6

    GC --> R1 & R2 & R3

    subgraph EXT["External Services"]
        JIRA[("Jira")]
        CONF[("Confluence")]
        GH[("GitHub")]
        ROVO[("Atlassian Rovo")]
    end

    J1 & J2 & J3 & J4 & J5 --> JIRA
    C1 & C2 & C3 & C4 --> CONF
    G1 & G2 & G3 & G4 & G5 & G6 --> GH
    R1 & R2 & R3 --> ROVO
```

---

## 5. impl-plan.md — Shared State Lifecycle

`impl-plan.md` is the single file written and read across all phases. Each phase
appends its own section; no phase overwrites a prior section.

```mermaid
timeline
    title impl-plan.md sections written per phase
    Phase 0.5  : Ticket Classification
              : Domain scores · Classification · Routing recommendation
    Phase 1    : Ticket Analysis
              : Requirements · Acceptance criteria · Confidence score
    Phase 2    : Context Discovery
              : Confluence docs · Rovo insights · Code patterns · Affected components
    Phase 3    : Implementation Plan
              : Task breakdown · Dependency graph · DB impact · API contracts · Risk register
    Checkpoint : Plan Approval
              : Human decision recorded  approve / reject / skip-impl
    Phase 4    : Implementation Log
              : Files committed · Branch name · Commit SHAs
    Phase 5    : Test Checklist
              : Test files committed · Coverage summary
    Phase 6    : Pull Request
              : PR URL · Branch · Jira transition
    Phase 7    : Completion
              : Confluence URL · Release notes · Final summary
```

---

## 6. Skill Inventory

| Skill | Phase | Invocation | Writes to impl-plan.md | Key MCP Tools |
|-------|-------|------------|------------------------|---------------|
| `/classify-ticket` | 0.5 | `/classify-ticket ENG-1234` | ✅ Ticket Classification | `get_ticket`, `get_linked_tickets` |
| `/analyze-jira` | 1 | `/analyze-jira ENG-1234` | ✅ Ticket Analysis | `get_ticket`, `get_linked_tickets`, `search_tickets` |
| `/gather-context` | 2 | `/gather-context ENG-1234` | ✅ Context Discovery | All Confluence, Rovo, GitHub read tools |
| `/create-plan` | 3 | `/create-plan ENG-1234` | ✅ Implementation Plan | `post_comment` |
| `/implement` | 4 | `/implement ENG-1234 repo:org/repo` | ✅ Implementation Log | `create_branch`, `get_file`, `commit_file` |
| `/generate-tests` | 5 | `/generate-tests ENG-1234` | ✅ Test Checklist | `commit_file` |
| `/create-pr` | 6 | `/create-pr ENG-1234` | ✅ Pull Request | `create_pr`, `update_status`, `post_comment` |
| `/update-docs` | 7 | `/update-docs ENG-1234` | ✅ Completion | `create_page`, `update_page`, `post_comment` |
| `/dev-agent` | all | `/dev-agent ENG-1234 repo:org/repo` | orchestrates all above | all |

### Backend specialized skills (`edx-enterprise-backend:*`)

| Skill | When activated |
|-------|---------------|
| `architecture-review` | Before planning — verify service design |
| `django-essentials` | Model / serializer / view implementation |
| `unit-tests` | After implement — pytest generation |
| `celery-patterns` | Only when ticket involves async tasks |
| `security-best-practices` | Before PR — PII, permissions, UUID exposure |
| `quality-checks` | Before PR — isort, pycodestyle, PII annotations |
| `review-brief` | PR description — structured reviewer summary |
| `system-integration-patterns` | When touching external service boundaries |

### Frontend specialized skills (`edx-enterprise-frontend-plugin:*`)

| Skill | When activated |
|-------|---------------|
| `architecture-review` | Before planning — verify plugin architecture |
| `paragon` | Implementation — enforce Paragon UI components |
| `accessibility` | Implementation — WCAG 2.1 AA compliance plan |
| `unit-tests` | After implement — Jest + RTL generation |
| `quality-checks` | Before PR — lint, type-check, a11y audit |
| `review-brief` | PR description — structured reviewer summary |

---

## 7. Standalone vs Orchestrated Execution

Every skill can be run standalone (by the developer directly) or orchestrated
(called automatically by `/dev-agent`). When called standalone, the skill reads
`impl-plan.md` for prior context and skips any section already populated.

```mermaid
flowchart LR
    SOLO["Standalone\n/classify-ticket ENG-1234\n/create-plan ENG-1234"]
    ORCH["Orchestrated\n/dev-agent ENG-1234"]

    SOLO -- reads existing sections --> IMPL[("impl-plan.md")]
    ORCH -- writes all sections in sequence --> IMPL

    IMPL -- provides context to --> AJ["/analyze-jira"]
    IMPL -- provides context to --> GC["/gather-context"]
    IMPL -- provides context to --> CP["/create-plan"]
    IMPL -- plan read by --> IM["/implement"]
    IMPL -- plan read by --> GT["/generate-tests"]
```
