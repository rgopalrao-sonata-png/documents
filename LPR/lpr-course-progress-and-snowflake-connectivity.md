# Learner Progress Report — `course_progress` Field: Full Technical History & Current State

> **Audience:** Engineering, Product, Data Platform, Snowflake Admins  
> **Related tickets:** [ENT-9207](https://2u-internal.atlassian.net/browse/ENT-9207) (discovery), [ENT-11183](https://2u-internal.atlassian.net/browse/ENT-11183) (implementation), [DPSD-8550](https://2u-internal.atlassian.net/browse/DPSD-8550) (Data Platform — Snowflake table), ENT0-9531 (caching)  
> **Data Platform PR:** [warehouse-transforms#7163](https://github.com/edx/warehouse-transforms/pull/7163/changes)  
> **Status as of May 2026:** `course_progress` is live in production, reading from `PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL`. Snowflake auth migration to key pair is pending (deadline: end of August 2026).  
> **Origin:** Slack thread initiated by Dave Wolf (Snowflake team) regarding `ENTERPRISE_SERVICE_USER` still authenticating via username/password.

---

## Table of Contents

1. [Business Context & Customer Need](#1-business-context--customer-need)
2. [Previous Discovery Attempts & Why They Failed](#2-previous-discovery-attempts--why-they-failed)
3. [How We Solved It — Current Implementation (ENT-11183)](#3-how-we-solved-it--current-implementation-ent-11183)
4. [Architecture & Data Flow](#4-architecture--data-flow)
5. [Code Walkthrough](#5-code-walkthrough)
6. [Query Frequency Explained](#6-query-frequency-explained)
7. [Graceful Degradation](#7-graceful-degradation)
8. [Summary for Snowflake Admin (Dave Wolf)](#8-summary-for-snowflake-admin-dave-wolf)

---

## 1. Business Context & Customer Need

For several years, enterprise customers — including GoLearning and others — have requested the ability to see **how far a learner has progressed through a course** in the Learner Progress Report (LPR).

The existing `current_grade` field does not satisfy this need because:

- Grade only reflects graded assignments. If a course's assessed work is concentrated at the end, all learners will show `0%` grade until they reach those assignments — even if they have consumed 80% of the course content.
- Learners **can** see their own course progress percentage in the LMS learning experience (powered by the Completion API). Enterprise admins cannot see the same data. This mismatch frustrates customers and leads to escalations, because from their perspective the data exists but is being withheld.
- In the past, workarounds included learners sending screenshots of their progress to their enterprise admin — clearly not scalable.

**Customer expectation:** The LPR should expose the same completion percentage that learners already see inside the LMS.

---

## 2. Previous Discovery Attempts & Why They Failed

A discovery effort was carried out (tracked in **[ENT-9207](https://2u-internal.atlassian.net/browse/ENT-9207)**). The original acceptance criteria asked:

1. Can we replicate the Completion API representation of course progress that learners see in the LMS?
2. Can we call the API directly that generates the progress visualization, so we stay in sync with the numbers learners see?
3. If not, can we calculate it from Completion API data and match the results? (Harder — even minor errors would cause headaches.)
4. If none of the above, can we document what architectural work would be required to become consumers of that API?

Two approaches were explored:

| Approach | What We Tried | Why It Failed |
|---|---|---|
| **Calculate it ourselves** | Derive the progress % from raw Completion API data already in our pipeline | Could not reliably match the numbers learners see in the LMS. Even minor discrepancies would cause ongoing support burden. |
| **Call the LMS API directly** | Fetch the same endpoint that renders the progress visualization in the LMS | Architecturally not feasible — our data pipeline runs as a batch process and cannot call user-context LMS endpoints at scale. |

**Outcome of ENT-9207:** The effort was suspended. The problems were documented and a shared understanding was reached that the feature would need Data Platform involvement to surface the already-calculated value from within the warehouse.

**Key grooming discussion (documented for posterity):**

> *Ammar: LPR data lags real time by one day. So if we add the progress into the LPR pipeline, it can create confusion — the data in the LPR is a day old, but the learner sees the latest progress in the LMS.*
>
> *NR: We can defend a data lag as long as the data provenance is good. It would be preferable if we can inherit the progress calculated in the LMS chart rather than recalculating it ourselves.*
>
> *Clarification from NR: We do NOT want to show the course completion percentage visualization in the LPR table. We want the % value as a field. Any references to the "visual API" should be read as: "is there a way to fetch this value from the same API that renders the progress image in the LMS, so we skip trying to calculate it ourselves?"*

---

## 3. How We Solved It — Current Implementation (ENT-11183)

The breakthrough came when the Data Platform team (ticket **[DPSD-8550](https://2u-internal.atlassian.net/browse/DPSD-8550)**) confirmed they could surface the pre-calculated `COURSE_PROGRESS` value — the same value the LMS exposes to learners — directly in a Snowflake table: `PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL`. The Data Platform's work was delivered via [warehouse-transforms#7163](https://github.com/edx/warehouse-transforms/pull/7163/changes).

This bypassed both failed approaches from ENT-9207:
- We no longer need to recalculate the value ourselves.
- We no longer need to call the LMS API. The Data Platform pipeline does that work, and we consume the result.

**ENT-11183** implemented the integration:

- Added a `course_progress` field to the LPR API response and CSV download.
- The field is populated at request time by querying Snowflake's internal table.
- All other LPR fields continue to come from the Django ORM (application database) — only `course_progress` comes from Snowflake.
- If Snowflake is unavailable, the API degrades gracefully: `course_progress` is `null` but the full LPR response is still returned.

---

## 4. Architecture & Data Flow

### 4.1 High-Level System Architecture

```mermaid
graph TB
    subgraph UPSTREAM["UPSTREAM SYSTEMS"]
        LMS["LMS / edX Platform\n(Completion API)"]
        DP["Data Platform Pipeline\n(DPSD-8550)\n~daily batch refresh"]
    end

    subgraph SNOWFLAKE["SNOWFLAKE"]
        SF_TABLE["PROD.ENTERPRISE\n.LEARNER_PROGRESS_REPORT_INTERNAL\n\nColumns used:\n• ENTERPRISE_CUSTOMER_UUID\n• USER_EMAIL\n• COURSERUN_KEY\n• COURSE_PROGRESS ← only field read"]
    end

    subgraph APP["edx-enterprise-data (this repo)"]
        subgraph VIEWSET["EnterpriseLearnerEnrollmentViewSet\n(enterprise_learner.py)"]
            ORM["Django ORM\nEnterpriseLearnerEnrollment table\n\nALL other LPR fields:\ngrades, dates, enrollment info,\nuser details, offer info…"]
            SFC["SnowflakeCourseProgressSource\n(lpr_data_source_snowflake.py)\n\ncourse_progress ONLY"]
            MERGE(("merge"))
            RESULT["Serialized enrollment row\n(all fields including course_progress)"]
        end
    end

    subgraph CONSUMERS["DOWNSTREAM CONSUMERS"]
        PORTAL["Admin Portal\n(JSON, paginated)\nGET /enrollments/?format=json"]
        CSV["CSV Download\n(StreamingHttpResponse)\nGET /enrollments/?format=csv"]
    end

    LMS -- "batch\n(completion events)" --> DP
    DP -- "writes\nCOURSE_PROGRESS" --> SF_TABLE
    SF_TABLE -- "SELECT (read-only)\nper API request" --> SFC
    ORM --> MERGE
    SFC --> MERGE
    MERGE --> RESULT
    RESULT --> PORTAL
    RESULT --> CSV

    style UPSTREAM fill:#e8f4fd,stroke:#1a73e8,color:#000
    style SNOWFLAKE fill:#fff3e0,stroke:#e65100,color:#000
    style APP fill:#e8f5e9,stroke:#2e7d32,color:#000
    style CONSUMERS fill:#f3e5f5,stroke:#7b1fa2,color:#000
    style SF_TABLE fill:#fff8e1,stroke:#f57f17,color:#000
    style ORM fill:#c8e6c9,stroke:#388e3c,color:#000
    style SFC fill:#c8e6c9,stroke:#388e3c,color:#000
    style MERGE fill:#a5d6a7,stroke:#2e7d32,color:#000
    style RESULT fill:#a5d6a7,stroke:#2e7d32,color:#000
    style PORTAL fill:#e1bee7,stroke:#7b1fa2,color:#000
    style CSV fill:#e1bee7,stroke:#7b1fa2,color:#000
```

### 4.2 Request-Time Sequence

```mermaid
sequenceDiagram
    participant AP as Admin Portal
    participant VS as EnterpriseLearnerEnrollment<br/>ViewSet
    participant DB as Application DB<br/>(Django ORM)
    participant SF as Snowflake<br/>(LEARNER_PROGRESS_REPORT_INTERNAL)

    AP->>VS: GET /enrollments/?enterprise_id=UUID
    activate VS

    VS->>DB: filter queryset by enterprise UUID<br/>+ apply query param filters
    activate DB
    DB-->>VS: enrollment rows<br/>(all fields EXCEPT course_progress)
    deactivate DB

    VS->>VS: serialize ORM rows<br/>(course_progress = NULL placeholder)

    VS->>SF: get_course_progress_map(uuid, rows)<br/>SELECT USER_EMAIL, COURSERUN_KEY, COURSE_PROGRESS<br/>WHERE enterprise_uuid = ? AND (email, key) IN (...)
    activate SF
    SF-->>VS: {(email, courserun_key): progress_value}
    deactivate SF

    VS->>VS: merge: row['course_progress'] = value<br/>for each matching (email, courserun_key)

    VS-->>AP: JSON response (paginated)<br/>or CSV stream (page-by-page)<br/>ALL fields including course_progress
    deactivate VS

    Note over VS,SF: If Snowflake fails → course_progress = null<br/>All other fields still returned (graceful degradation)
```

**Key design properties:**
- **Data lag:** `COURSE_PROGRESS` reflects a ~daily refresh by the Data Platform pipeline — consistent with the rest of the LPR.
- **Read-only:** The application never writes to Snowflake. Data flows strictly one-way: Snowflake → application → API response.
- **Single field from Snowflake:** Only `course_progress` comes from Snowflake. Every other LPR field comes from the application database.
- **Tight query scope:** Each Snowflake call is scoped to one enterprise UUID and only the `(user_email, courserun_key)` pairs on the current page — no full-table scans.

---

## 5. Code Walkthrough

### 5.1 View — `EnterpriseLearnerEnrollmentViewSet`

File: `enterprise_data/api/v1/views/enterprise_learner.py`

The `list()` method handles both JSON API responses and streaming CSV downloads. In both paths, after fetching enrollment records from the ORM, it calls `_enrich_course_progress_rows()`.

```python
def list(self, request, *args, **kwargs):
    if request.accepted_renderer.format == 'csv':
        return StreamingHttpResponse(
            EnrollmentsCSVRenderer().render(self._stream_serialized_data()),
            ...
        )
    response = super().list(request, *args, **kwargs)
    self._enrich_course_progress(response)
    return response
```

The enrichment method calls Snowflake and merges the result:

```python
def _enrich_course_progress_rows(self, rows):
    try:
        enterprise_uuid = self.kwargs['enterprise_id']
        progress_map = SnowflakeCourseProgressSource().get_course_progress_map(enterprise_uuid, rows)
        for row in rows:
            key = (row.get('user_email', '').strip(), row.get('courserun_key', '').strip())
            if key in progress_map:
                row['course_progress'] = progress_map[key]
        return rows
    except Exception:
        LOGGER.warning('Could not enrich course_progress from Snowflake', exc_info=True)
        return rows  # graceful degradation: return rows unchanged, course_progress stays null
```

A synthetic `NULL` placeholder is added to the ORM queryset so the serializer shape always includes the field:

```python
enrollments = EnterpriseLearnerEnrollment.objects.filter(
    enterprise_customer_uuid=enterprise_customer_uuid
).extra(select={'course_progress': 'NULL'})
```

### 5.2 Snowflake Client — `SnowflakeCourseProgressSource`

File: `enterprise_data/api/v1/views/lpr_data_source_snowflake.py`

Executes a single, parameterised SQL query scoped to the enterprise UUID and the exact `(user_email, courserun_key)` pairs on the current page:

```sql
SELECT USER_EMAIL, COURSERUN_KEY, COURSE_PROGRESS
FROM PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL
WHERE LOWER(REPLACE(TO_VARCHAR(ENTERPRISE_CUSTOMER_UUID), '-', '')) = ?
  AND (USER_EMAIL, COURSERUN_KEY) IN ((?, ?), (?, ?), ...)
```

Returns a `{ (user_email, courserun_key): course_progress }` dict. Connections are opened and closed per call (no persistent connection pool at this time).

### 5.3 Shared Contracts — `LPRSerializerShapeMixin`

File: `enterprise_data/api/v1/views/lpr_data_source_base.py`

Defines the canonical list of LPR API fields (`SERIALIZER_FIELDS`), including `course_progress`. Any future Snowflake or ORM-backed source should conform to this contract.

### 5.4 Separate Reporting Client — `SnowflakeClient`

File: `enterprise_reporting/clients/snowflake.py`

An **independent** Snowflake client used by scheduled batch reporting jobs in `enterprise_reporting/`. It uses separate credentials (`SNOWFLAKE_USERNAME` / `SNOWFLAKE_PASSWORD` env vars) and is unrelated to the LPR enrichment flow described above.

---

## 6. Query Frequency Explained

### 6.1 Who triggers the queries?

The Snowflake queries Dave Wolf observed in the query history are triggered by **enterprise admin users** (employees of enterprise customers like GoLearning) using the **Admin Portal** web application. When an admin navigates to the Learner Progress Report page, the frontend calls our API, and our API calls Snowflake.

These are **not** automated batch jobs or cron-triggered exports. They are real-time, user-initiated API requests.

### 6.2 Why so frequent?

The current implementation queries Snowflake on every LPR API request to ensure enterprise admins always receive the **most up-to-date** `course_progress` values available in the warehouse. Each query is scoped tightly to one enterprise UUID and only the exact `(user_email, courserun_key)` pairs on the current page — no full-table scans.

| Trigger | When it fires |
|---|---|
| Admin Portal loads the LPR table | Once per page load, once per pagination event |
| Admin Portal CSV export | Once per `ENROLLMENTS_PAGE_SIZE` rows streamed |
| API integrations / automated tooling | Depends on the polling interval of the client |

**Planned improvement — `ENT0-9531`:** We have already identified and scoped a caching layer to sit in front of the Snowflake call. Since `COURSE_PROGRESS` data refreshes only ~daily, a short-lived cache keyed per enterprise will eliminate redundant queries within the same refresh window — significantly reducing the query volume Dave Wolf observed, while keeping the data as fresh as the underlying pipeline allows. 

---

## 7. Graceful Degradation

If the Snowflake call fails for any reason — wrong credentials, network timeout, table unavailable — the application **does not return an error to the caller**. Instead:

- All other LPR fields are served from the application database as normal.
- `course_progress` is `null` for all rows on that response.
- A `WARNING` is logged with full traceback for observability.

This design means:
- Any future auth or connectivity change (including the key pair migration) can be deployed and validated in staging without risking the production LPR API.
- Any Snowflake outage has a bounded, predictable impact — `course_progress` degrades to `null` for the duration, nothing else breaks.
- The caching improvement (`ENT0-9531`) can be introduced safely because the fallback path already exists.

---

## 8. Summary for Dave Wolf

### 8.1 Answers to Dave's questions

| Question | Answer |
|---|---|
| **Is this flow still needed?** | Yes. It powers the `course_progress` field in the LPR — a top customer request. Disabling it would regress the feature to `null` for all enterprises. |
| **Is this a reverse ETL?** | No. The application is strictly read-only. It SELECTs one column (`COURSE_PROGRESS`) and never writes back. |
| **Who requests these reports?** | Enterprise admin users (employees of enterprise customers) using the Admin Portal. Each page load or CSV export triggers a Snowflake query. |
| **Why so frequently?** | Queries fire per API request with no caching layer today. Every page load and every CSV page triggers a new connection + SELECT. |
| **Who would do the key pair migration?** | The Lakshy team (this repo). The code change is straightforward — swap `password` for `private_key` in the connector call. We need respective team to generate the RSA key pair and register the public key against `ENTERPRISE_SERVICE_USER` first. |


