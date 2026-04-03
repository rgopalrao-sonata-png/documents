---
title: ENT-11672 Multi-License — Concepts & Live User Data (flag ON / v2)
---
flowchart TD

    %% ─────────────────────────────────────────────────────────────────────
    %% CONCEPT NOTE
    %% SubscriptionPlan  = a contract the enterprise admin buys (100 seats)
    %%                     Like: a company buying 100 gym memberships
    %% License           = one seat assigned to a specific learner
    %%                     Like: the individual gym membership card
    %% Catalog           = a named list of courses tied to a plan
    %%                     Like: Gym-A's full class schedule
    %% Course            = one specific course inside a catalog
    %%                     Like: one yoga class in the gym schedule
    %%
    %% ENT-11672 RULE: when a learner has multiple licenses,
    %% subscription_license must be the one activated FIRST (not latest-expiry)
    %% ─────────────────────────────────────────────────────────────────────

    %% ── ENTERPRISE ────────────────────────────────────────────────────────
    subgraph ENT["🏢 Enterprise  |  slug: test-multi-enterprise  |  uuid: aaaaaaaa-…"]
        A["👤 Alice\nusername: test-multi-alice  pw: edx"]
        B["👤 Bob\nusername: test-multi-bob  pw: edx"]
        C["👤 Carol\nusername: test-multi-carol  pw: edx1234"]
        D["👤 Dave\nusername: test-multi-dave  pw: edx"]
        E["👤 Eve\nusername: test-multi-eve  pw: edx"]
    end

    %% ── SUBSCRIPTION PLANS ────────────────────────────────────────────────
    subgraph PLANS["📋 Subscription Plans  (License Manager)\nA plan = enterprise contract with N seats, tied to exactly one catalog"]
        SP1["SubscriptionPlan\n'Leadership Training'\nuuid: c1111111-…\nexpires: 2026-06-25\ncatalog → 11111111-…"]
        SP2["SubscriptionPlan\n'Technical Training'\nuuid: c2222222-…\nexpires: 2026-09-23\ncatalog → 22222222-…"]
        SP3["SubscriptionPlan\n'Compliance Training'\nuuid: c3333333-…\nexpires: 2027-03-27\ncatalog → 33333333-…"]
        SP4["SubscriptionPlan\n'Data Science'\nuuid: c4444444-…\nexpires: 2026-09-23\ncatalog → 44444444-…"]
        SP5["SubscriptionPlan\n'Business Skills'\nuuid: c5555555-…\nexpires: 2026-07-25\ncatalog → 55555555-…"]
    end

    %% ── LICENSES ──────────────────────────────────────────────────────────
    subgraph LICENSES["🎫 Licenses  (one activated seat per learner per plan)\nA license = the individual membership card handed to one employee"]

        subgraph LA["Alice — 3 licenses ✅"]
            LA1["807a65cd  Leadership\nactivated: 2024-01-15\n⭐ WINNER — first-activated rule"]
            LA2["807bba77  Technical\nactivated: 2024-03-10"]
            LA3["807bbd3e  Compliance\nactivated: 2024-06-01  ← latest expiry\nbut does NOT win under ENT-11672"]
        end

        subgraph LB["Bob — 2 licenses ✅  (4 expected — 2 missing from DB)"]
            LB1["9bb7e913  Leadership\nactivated: 2024-02-01\n⭐ WINNER"]
            LB2["9bb7ed7c  Technical\nactivated: 2024-07-15"]
        end

        subgraph LC["Carol — 5 licenses ✅  (covers all 5 catalogs)"]
            LC0["ab207c87  Compliance\nactivated: 2024-05-01\n⭐ WINNER — oldest in DB"]
            LC1["d3333333-1111  Leadership\nactivated: 2026-02-07"]
            LC2["d3333333-2222  Technical\nactivated: 2026-02-20"]
            LC4["d3333333-4444  Data Science\nactivated: 2026-03-15"]
            LC5["d3333333-5555  Business Skills\nactivated: 2026-03-25"]
        end

        subgraph LD["Dave — 1 license ⚠️  (2 assigned licenses missing from DB)"]
            LD1["b2a157a1  Data Science\nactivated: 2023-01-01\n⭐ WINNER (only one)"]
        end

        subgraph LE["Eve — 0 licenses ❌  (no data loaded yet)"]
            LE0["(none)"]
        end
    end

    %% ── CATALOGS ──────────────────────────────────────────────────────────
    subgraph CATALOGS["📚 Enterprise Catalogs  (Catalog Service)\nA catalog = named list of courses — holding a license gives access to ALL courses inside it"]
        CAT1["Catalog 11111111\nLeadership"]
        CAT2["Catalog 22222222\nTechnical"]
        CAT3["Catalog 33333333\nCompliance"]
        CAT4["Catalog 44444444\nData Science"]
        CAT5["Catalog 55555555\nBusiness Skills"]
    end

    %% ── COURSES ───────────────────────────────────────────────────────────
    subgraph COURSES["🎓 Courses  (one specific class inside a catalog)"]
        CR1["course-v1:edX+Lead+2024\nLeadership 101"]
        CR2["course-v1:edX+Tech+2024\nTech Fundamentals"]
        CR3["course-v1:edX+Comp+2024\nCompliance Basics"]
        CR4["course-v1:edX+Data+2024\nData Science Intro"]
        CR5["course-v1:edX+Biz+2024\nBusiness Essentials"]
    end

    %% ── BFF RESPONSE (flag ON / v2) ───────────────────────────────────────
    subgraph BFF["⚡ BFF /api/v1/bffs/learner/dashboard/  —  waffle flag ON → license_schema_version: v2"]
        BFF_A["Alice ✅\nsubscription_licenses: 3\nlicenses_by_catalog: 3 keys\nsubscription_license → 807a65cd Leadership ⭐\nactivation_date: 2024-01-15"]
        BFF_B["Bob ✅⚠️\nsubscription_licenses: 2  (expected 4)\nlicenses_by_catalog: 2 keys\nsubscription_license → 9bb7e913 Leadership ⭐\nactivation_date: 2024-02-01"]
        BFF_C["Carol ✅\nsubscription_licenses: 5\nlicenses_by_catalog: 5 keys\nsubscription_license → ab207c87 Compliance ⭐\nactivation_date: 2024-05-01"]
        BFF_D["Dave ⚠️\nsubscription_licenses: 1  (expected 3)\nlicenses_by_catalog: 1 key\nsubscription_license → b2a157a1 Data Science ⭐\nactivation_date: 2023-01-01"]
        BFF_E["Eve ❌\nsubscription_licenses: 0\nlicenses_by_catalog: empty\nsubscription_license → none"]
    end

    %% ── EDGES: plans own catalogs ─────────────────────────────────────────
    SP1 -- "enterprise_catalog_uuid" --> CAT1
    SP2 -- "enterprise_catalog_uuid" --> CAT2
    SP3 -- "enterprise_catalog_uuid" --> CAT3
    SP4 -- "enterprise_catalog_uuid" --> CAT4
    SP5 -- "enterprise_catalog_uuid" --> CAT5

    %% catalogs contain courses
    CAT1 --> CR1
    CAT2 --> CR2
    CAT3 --> CR3
    CAT4 --> CR4
    CAT5 --> CR5

    %% plans allocate license seats to learners
    SP1 --> LA1 & LB1 & LC1
    SP2 --> LA2 & LB2 & LC2
    SP3 --> LA3 & LC0
    SP4 --> LD1 & LC4
    SP5 --> LC5

    %% users hold licenses
    A --> LA1 & LA2 & LA3
    B --> LB1 & LB2
    C --> LC0 & LC1 & LC2 & LC4 & LC5
    D --> LD1

    %% activated license grants access to its plan's catalog
    LA1 -- "access to" --> CAT1
    LA2 -- "access to" --> CAT2
    LA3 -- "access to" --> CAT3
    LB1 -- "access to" --> CAT1
    LB2 -- "access to" --> CAT2
    LC0 -- "access to" --> CAT3
    LC1 -- "access to" --> CAT1
    LC2 -- "access to" --> CAT2
    LC4 -- "access to" --> CAT4
    LC5 -- "access to" --> CAT5
    LD1 -- "access to" --> CAT4

    %% BFF response per user
    A --> BFF_A
    B --> BFF_B
    C --> BFF_C
    D --> BFF_D
    E --> BFF_E

    %% ── STYLES ────────────────────────────────────────────────────────────
    style LA1 fill:#d4edda,stroke:#28a745,color:#000
    style LB1 fill:#d4edda,stroke:#28a745,color:#000
    style LC0 fill:#d4edda,stroke:#28a745,color:#000
    style LD1 fill:#d4edda,stroke:#28a745,color:#000
    style LE0 fill:#f8d7da,stroke:#dc3545,color:#000
    style BFF_A fill:#d4edda,stroke:#28a745,color:#000
    style BFF_B fill:#fff3cd,stroke:#ffc107,color:#000
    style BFF_C fill:#d4edda,stroke:#28a745,color:#000
    style BFF_D fill:#fff3cd,stroke:#ffc107,color:#000
    style BFF_E fill:#f8d7da,stroke:#dc3545,color:#000
