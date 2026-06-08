# AI Languages → `translation_languages` — Full Architecture

> **Purpose:** Visual reference for how `ai_languages` from Course Discovery becomes
> the `translation_languages` search facet in Algolia.
> **Last updated:** 2026-06-08

---

## Architecture Diagram

```mermaid
flowchart TD
    classDef discovery fill:#4A90D9,color:#fff,stroke:#2c5f8a
    classDef db        fill:#27AE60,color:#fff,stroke:#1a7a42
    classDef task      fill:#E67E22,color:#fff,stroke:#b35a00
    classDef algolia   fill:#8E44AD,color:#fff,stroke:#5d2d72
    classDef cron      fill:#C0392B,color:#fff,stroke:#7b1b1b
    classDef warn      fill:#FEF9C3,color:#333,stroke:#D4AC0D

    %% ── External: Course Discovery ──────────────────────────────────
    subgraph DISCOVERY["☁️  Course Discovery Service  (external)"]
        D1["🔍 /api/v1/search/all/\n─────────────────────\nLightweight course list\n❌ ai_languages NOT present"]:::discovery
        D2["📚 /api/v1/courses/\n─────────────────────\nFull course metadata\n✅ ai_languages INCLUDED\n{\n  translation_languages: [\n    {code:'es', label:'Spanish'},\n    {code:'fr', label:'French'}\n  ],\n  dubbing_languages: []\n}"]:::discovery
    end

    %% ── Django App ───────────────────────────────────────────────────
    subgraph CATALOG["🐍  enterprise-catalog  (Django / Celery)"]

        subgraph PHASE1["Phase 1 — Course List Sync"]
            T1["⚙️ update_catalog_metadata_task\napi/tasks.py\n─────────────────────\nCalls /search/all\nCreates ContentMetadata rows\n❌ ai_languages NOT stored here"]:::task
        end

        subgraph PHASE2["Phase 2 — Full Metadata Enrichment"]
            T2A["⚙️ update_full_content_metadata_task\napi/tasks.py\n─────────────────────\nBatches course keys (50/request)\nCalls DiscoveryApiClient\n.fetch_courses_by_keys()"]:::task
            T2B["⚙️ _update_single_full_course_record()\napi/tasks.py\n─────────────────────\nmerges full course dict\ninto _json_metadata\n✅ ai_languages NOW in DB"]:::task
        end

        subgraph DB_LAYER["Database  (MySQL)"]
            DB["🗄️ ContentMetadata._json_metadata\ncatalog/models.py\n─────────────────────\n{\n  'ai_languages': {\n    'translation_languages': [\n      {'code':'es','label':'Spanish'},\n      {'code':'fr','label':'French'}\n    ]\n  }\n}"]:::db
        end

        subgraph PHASE3["Phase 3 — Algolia Reindex"]
            AU["🔧 get_course_translation_languages()\ncatalog/algolia_utils.py\n─────────────────────\ncourse.get('ai_languages',{})\n       .get('translation_languages',[])\n→ [lang['label'] for lang in ...]\n→ ['Spanish', 'French', ...]"]:::task
            T3["⚙️ index_enterprise_catalog_in_algolia_task\napi/tasks.py\n─────────────────────\n_algolia_object_from_product()\nadds 'translation_languages' key\nalgolia_client.replace_all_objects()\n⚠️ FULL atomic rebuild — not incremental"]:::task
        end

    end

    %% ── Cron Scheduler ──────────────────────────────────────────────
    subgraph CRON["🕐  Scheduled Jobs  (argocd / prod-config.yaml)"]
        C1["📅 edx-update-content-metadata\n─────────────────────\nRuns MULTIPLE TIMES per day\nTriggers Phase 1 + Phase 2\n✅ Populates ai_languages in DB"]:::cron
        C2["📅 edx-reindex-algolia\n─────────────────────\ncron: 0 12 * * *\nRuns DAILY at 12:00 UTC\nreindex_algolia --force --no-async\nTriggers Phase 3 only\n⚠️ Reads DB — no Discovery calls"]:::cron
    end

    %% ── Algolia ──────────────────────────────────────────────────────
    subgraph ALGOLIA["🔎  Algolia Search Index"]
        A1["📦 Algolia Course Object\n─────────────────────\n{\n  'objectID': 'course-v1:edX+...',\n  'translation_languages': [\n    'Spanish',\n    'French',\n    'Portuguese (Brazil)'\n  ]\n}\n─────────────────────\n🏷️ Facet: translation_languages\nShown in learner course search UI"]:::algolia
    end

    %% ── Warning box ──────────────────────────────────────────────────
    WARN["⚠️  CRITICAL DEPENDENCY\n─────────────────────────────────────────\nThe 12:00 UTC cron (Phase 3) ALONE\ndoes NOT populate translation_languages.\n\nPhase 2 MUST run first to store\nai_languages into the database.\n\nCron at 12 rebuilds Algolia only from\nwhatever is already in the DB.\n\nFix if empty:\n  1. Run update_full_content_metadata --force\n  2. Then run reindex_algolia --force --no-async"]:::warn

    %% ── Edges ────────────────────────────────────────────────────────
    D1 -->|"course keys + basic fields\n(no ai_languages)"| T1
    D2 -->|"full course dict\n(ai_languages included)"| T2A
    T1 -->|"creates/updates\nContentMetadata rows"| DB
    T2A -->|"passes course dict"| T2B
    T2B -->|"_json_metadata.update(course_dict)\nai_languages persisted"| DB
    DB  -->|"course dict read\nduring reindex"| AU
    AU  -->|"flat label list\n['Spanish','French',...]"| T3
    T3  -->|"replace_all_objects()"| A1

    C1  -->|"triggers"| T1
    C1  -->|"triggers"| T2A
    C2  -->|"triggers --force\nbypasses 1-hr semaphore"| T3

    DB  -. "must be populated\nBEFORE 12:00 cron" .-> WARN
    WARN -. "then Phase 3\nreads fresh data" .-> T3
```

---

## Sequence Diagram — One Full Nightly Cycle

```mermaid
sequenceDiagram
    autonumber
    participant Cron  as 🕐 Cron Scheduler
    participant Task1 as ⚙️ update_catalog_metadata_task
    participant Task2 as ⚙️ update_full_content_metadata_task
    participant Disc  as ☁️ Course Discovery
    participant MySQL as 🗄️ MySQL (ContentMetadata)
    participant Task3 as ⚙️ index_enterprise_catalog_in_algolia_task
    participant Alg   as 🔎 Algolia

    Note over Cron,Alg: Runs multiple times per day (Phase 1 + 2)
    Cron  ->>  Task1: trigger edx-update-content-metadata
    Task1 ->>  Disc:  GET /api/v1/search/all/ (lightweight)
    Disc  -->> Task1: course list (❌ no ai_languages)
    Task1 ->>  MySQL: upsert ContentMetadata rows (minimal fields)

    Task1 ->>  Task2: trigger update_full_content_metadata_task
    loop  every 50 course keys
        Task2 ->> Disc:  GET /api/v1/courses/?keys=course-v1:...
        Disc  -->> Task2: full course dicts (✅ ai_languages included)
        Task2 ->> MySQL: _json_metadata.update(course_dict)\nai_languages now persisted
    end

    Note over Cron,Alg: Runs once daily at 12:00 UTC (Phase 3)
    Cron  ->>  Task3: trigger edx-reindex-algolia --force
    Task3 ->>  MySQL: read all ContentMetadata._json_metadata
    MySQL -->> Task3: course dicts (ai_languages already stored)
    Task3 ->>  Task3: get_course_translation_languages()\n→ extract label strings
    Task3 ->>  Alg:   replace_all_objects(products_generator)
    Alg   -->> Task3: ✅ index updated
    Note over Alg: translation_languages facet now live for learners
```

---

## Data Shape at Each Stage

```mermaid
flowchart LR
    classDef stage fill:#1A1A2E,color:#E0E0E0,stroke:#4A90D9
    classDef arrow fill:none,stroke:none

    S1["**Stage 1 — Discovery API**\n/api/v1/courses/ response\n─────────────────────────\nai_languages: {\n  translation_languages: [\n    { code: 'es', label: 'Spanish' },\n    { code: 'fr', label: 'French'  },\n    { code: 'pt-br', label: 'Portuguese (Brazil)' }\n  ],\n  dubbing_languages: []\n}"]:::stage

    S2["**Stage 2 — Database**\nContentMetadata._json_metadata\n─────────────────────────\nai_languages: {\n  translation_languages: [\n    { code: 'es', label: 'Spanish' },\n    { code: 'fr', label: 'French'  },\n    { code: 'pt-br', label: 'Portuguese (Brazil)' }\n  ]\n}  ← stored verbatim"]:::stage

    S3["**Stage 3 — Algolia Object**\ntranslation_languages field\n─────────────────────────\ntranslation_languages: [\n  'Spanish',\n  'French',\n  'Portuguese (Brazil)'\n]  ← labels only, flat list"]:::stage

    S1 -->|"merged verbatim\ninto _json_metadata"| S2
    S2 -->|"get_course_translation_languages()\nextracts label strings only"| S3
```

---

## Component Ownership Map

```mermaid
flowchart TD
    classDef file fill:#2D3748,color:#E2E8F0,stroke:#4A5568

    subgraph FILES["📁 Key Files in enterprise-catalog"]
        F1["enterprise_catalog/apps/catalog/algolia_utils.py\n─────────────────────────────────────────────\n• get_course_translation_languages()  ← extracts labels\n• _algolia_object_from_product()      ← adds field to object\n• ALGOLIA_FIELDS list                 ← declares the field\n• ALGOLIA_INDEX_SETTINGS              ← declares the facet"]:::file

        F2["enterprise_catalog/apps/api/tasks.py\n─────────────────────────────────────────────\n• update_catalog_metadata_task        ← Phase 1\n• update_full_content_metadata_task   ← Phase 2 (orchestrator)\n• _update_single_full_course_record() ← Phase 2 (per-course)\n• index_enterprise_catalog_in_algolia_task ← Phase 3"]:::file

        F3["enterprise_catalog/apps/api_client/discovery.py\n─────────────────────────────────────────────\n• DiscoveryApiClient.fetch_courses_by_keys()\n• DiscoveryApiClient.get_courses()\n• DiscoveryApiClient._retrieve_courses()"]:::file

        F4["enterprise_catalog/apps/api_client/constants.py\n─────────────────────────────────────────────\n• DISCOVERY_COURSES_ENDPOINT = '/api/v1/courses/'"]:::file

        F5["enterprise_catalog/apps/catalog/constants.py\n─────────────────────────────────────────────\n• DEFAULT_COURSE_FIELDS_TO_PLUCK_FROM_SEARCH_ALL\n  ← ai_languages intentionally NOT in this list"]:::file

        F6["enterprise_catalog/apps/catalog/models.py\n─────────────────────────────────────────────\n• ContentMetadata._json_metadata  (JSONField)\n  └─ ai_languages stored here verbatim"]:::file

        F7["enterprise_catalog/apps/catalog/management/commands/\n─────────────────────────────────────────────\n• reindex_algolia.py              ← runs Phase 3\n• update_full_content_metadata.py ← runs Phase 2"]:::file
    end
```

---

## Gotchas at a Glance

```mermaid
flowchart TD
    classDef bad  fill:#C0392B,color:#fff,stroke:#7b1b1b
    classDef good fill:#27AE60,color:#fff,stroke:#1a7a42
    classDef tip  fill:#2471A3,color:#fff,stroke:#154360

    G1["❌ GOTCHA 1\nai_languages is NOT in /search/all\n─────────────────────────────\nNew courses have no translation_languages\nuntil Phase 2 (full sync) runs"]:::bad
    G2["❌ GOTCHA 2\nAlgolia uses ATOMIC replace\n─────────────────────────────\nIf a course has no ai_languages in DB\nat reindex time → facet disappears\neven if it was there before"]:::bad
    G3["❌ GOTCHA 3\nSilent failure on shape change\n─────────────────────────────\nIf Discovery renames 'ai_languages'\nor changes nesting → field returns []\nNo exception raised, no alert fired"]:::bad
    G4["❌ GOTCHA 4\n12:00 cron alone is NOT enough\n─────────────────────────────\nPhase 3 reads the DB.\nIf Phase 2 never ran, DB has no\nai_languages → Algolia has none"]:::bad

    F1["✅ FIX for G1 + G4\n─────────────────────────────\n./manage.py update_full_content_metadata --force\nThen:\n./manage.py reindex_algolia --force --no-async"]:::good
    F2["✅ FIX for G2\n─────────────────────────────\nEnsure Phase 2 always runs before\nPhase 3. They are both covered by\nedx-update-content-metadata cron."]:::good
    F3["✅ FIX for G3\n─────────────────────────────\nAdd Datadog monitor: alert if\ntranslation_languages facet count\ndrops to 0 unexpectedly"]:::tip

    G1 --> F1
    G4 --> F1
    G2 --> F2
    G3 --> F3
```

---

## Related Files

| Purpose | File | Symbol |
|---|---|---|
| Extract labels for Algolia | [algolia_utils.py](../../enterprise_catalog/apps/catalog/algolia_utils.py) | `get_course_translation_languages()` |
| Write to Algolia object | [algolia_utils.py](../../enterprise_catalog/apps/catalog/algolia_utils.py) | `_algolia_object_from_product()` |
| Persist `ai_languages` from Discovery | [api/tasks.py](../../enterprise_catalog/apps/api/tasks.py) | `_update_single_full_course_record()` |
| Discovery HTTP client | [api_client/discovery.py](../../enterprise_catalog/apps/api_client/discovery.py) | `DiscoveryApiClient.fetch_courses_by_keys()` |
| Discovery endpoint constant | [api_client/constants.py](../../enterprise_catalog/apps/api_client/constants.py) | `DISCOVERY_COURSES_ENDPOINT` |
| Algolia field + facet declared | [algolia_utils.py](../../enterprise_catalog/apps/catalog/algolia_utils.py) | `ALGOLIA_FIELDS`, `ALGOLIA_INDEX_SETTINGS` |
| Fields plucked from `/search/all` | [catalog/constants.py](../../enterprise_catalog/apps/catalog/constants.py) | `DEFAULT_COURSE_FIELDS_TO_PLUCK_FROM_SEARCH_ALL` |
| Reindex management command | [reindex_algolia.py](../../enterprise_catalog/apps/catalog/management/commands/reindex_algolia.py) | `Command.handle()` |
| Full-metadata management command | [update_full_content_metadata.py](../../enterprise_catalog/apps/catalog/management/commands/update_full_content_metadata.py) | — |

---

*See also: [ai_languages_post_merge_next_steps.md](ai_languages_post_merge_next_steps.md)*
