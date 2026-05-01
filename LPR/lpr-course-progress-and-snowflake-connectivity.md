# Learner Progress Report — `course_progress` Field: Full Technical History & Current State

> **Audience:** Engineering, Product, Data Platform, Snowflake Admins  
> **Related tickets:** ENT-9207 (discovery), ENT-11183 (implementation), DPSD-8550 (Data Platform — Snowflake table), ENT0-9531 (caching)  
> **Data Platform PR:** [warehouse-transforms#7163](https://github.com/edx/warehouse-transforms/pull/7163/changes)  
> **Status as of May 2026:** `course_progress` is live in production, reading from `PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL`. Snowflake auth migration to key pair is **in progress** (deadline: end of August 2026).

---

## Table of Contents

1. [Business Context & Customer Need](#1-business-context--customer-need)
2. [Previous Discovery Attempts & Why They Failed](#2-previous-discovery-attempts--why-they-failed)
3. [How We Solved It — Current Implementation (ENT-11183)](#3-how-we-solved-it--current-implementation-ent-11183)
4. [Architecture & Data Flow](#4-architecture--data-flow)
5. [Code Walkthrough](#5-code-walkthrough)
6. [Collaboration Agreement with Data Platform (DPSD-8550)](#6-collaboration-agreement-with-data-platform-dpsd-8550)
7. [Snowflake Authentication — Key Pair Migration](#7-snowflake-authentication--key-pair-migration)
8. [Query Frequency Explained](#8-query-frequency-explained)
9. [Graceful Degradation](#9-graceful-degradation)
10. [Tickets to Be Created (Naveen)](#10-tickets-to-be-created-naveen)
11. [Summary for Snowflake Admin (Dave Wolf)](#11-summary-for-snowflake-admin-dave-wolf)

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

A discovery effort was carried out (tracked in **ENT-9207**). Two approaches were explored:

| Approach | What We Tried | Why It Failed |
|---|---|---|
| **Calculate it ourselves** | Derive the progress % from raw completion API data we already have in our pipeline | Could not reliably match the numbers learners see in the LMS. Even minor discrepancies would cause ongoing support burden. |
| **Call the LMS API directly** | Fetch the same endpoint that renders the progress visualization in the LMS | Architecturally not feasible at the time — our data pipeline runs as a batch process and cannot call user-context LMS endpoints at scale. |

**Outcome of ENT-9207:** The effort was suspended. The problems were documented and a shared understanding was reached that the feature would need Data Platform involvement to surface the already-calculated value from within the warehouse.

**Key grooming discussion (documented for posterity):**

> *Ammar: LPR data lags real time by one day. So if we add the progress into the LPR pipeline, it can create confusion — the data in the LPR is a day old, but the learner sees the latest progress in the LMS.*
>
> *NR: We can defend a data lag as long as the data provenance is good. It would be preferable if we can inherit the progress calculated in the LMS chart rather than recalculating it ourselves.*

---

## 3. How We Solved It — Current Implementation (ENT-11183)

The breakthrough came when the Data Platform team (ticket **DPSD-8550**) confirmed they could surface the pre-calculated `COURSE_PROGRESS` value — the same value the LMS exposes to learners — directly in a Snowflake table: `PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL`.

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

```
LMS Completion API
        │
        │  (batch, ~daily)
        ▼
Data Platform pipeline (DPSD-8550)
        │
        │  Pre-calculates COURSE_PROGRESS per learner per course run
        ▼
PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL  (Snowflake)
        │
        │  SELECT at request time (read-only)
        ▼
SnowflakeCourseProgressSource  (lpr_data_source_snowflake.py)
        │
        ├── merged with ──►  Django ORM  (EnterpriseLearnerEnrollment table)
        │                         │  (all other LPR fields)
        ▼                         ▼
        EnterpriseLearnerEnrollmentViewSet  (enterprise_learner.py)
                    │
                    ▼
        Admin Portal / API Client
        (JSON response or CSV download)
```

**Important characteristics:**
- **Data lag:** `COURSE_PROGRESS` in Snowflake reflects a ~daily refresh cadence run by the Data Platform pipeline. This is consistent with the rest of the LPR and is acceptable to customers.
- **No reverse ETL:** The application never writes to Snowflake. Data flows strictly one-way: Snowflake → application → API response.
- **Single field from Snowflake:** Only `course_progress` comes from Snowflake. Every other LPR field comes from the application database.

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

## 6. Collaboration Agreement with Data Platform (DPSD-8550)

The Data Platform team owns `PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL`. Our application is a consumer. The agreed contract is:

| Contract Point | Agreement |
|---|---|
| **Column name** | `COURSE_PROGRESS` — value is a completion percentage (e.g. `0.75` for 75%) |
| **Join key** | `ENTERPRISE_CUSTOMER_UUID` + `USER_EMAIL` + `COURSERUN_KEY` |
| **Breaking changes** | Data Platform will not rename or remove `COURSE_PROGRESS`, `USER_EMAIL`, `COURSERUN_KEY`, or `ENTERPRISE_CUSTOMER_UUID` without coordinating with this team first |
| **UUID format** | Stored without hyphens (`LOWER(REPLACE(...))` normalisation applied on our side) |
| **Data lag** | ~daily refresh; consistent with the rest of the LPR |
| **Application writes** | None — our application is read-only |

If the Data Platform team needs to change the table schema or column semantics, they should file a coordination ticket and tag the Lakshy team before merging.

---

## 7. Snowflake Authentication — Key Pair Migration

### 7.1 The problem

`ENTERPRISE_SERVICE_USER` (the account used by `SnowflakeCourseProgressSource`) is currently authenticating with username + password. Snowflake's new account-type policy (`LEGACY_SERVICE`) requires migration to **key pair authentication** by **end of August 2026**.

### 7.2 Two Snowflake clients, two migrations needed

| Client | File | Current auth | Needs migration? |
|---|---|---|---|
| `SnowflakeCourseProgressSource` | `enterprise_data/api/v1/views/lpr_data_source_snowflake.py` | `SNOWFLAKE_SERVICE_USER` + `SNOWFLAKE_SERVICE_USER_PASSWORD` Django settings | **Yes** |
| `SnowflakeClient` | `enterprise_reporting/clients/snowflake.py` | `SNOWFLAKE_USERNAME` + `SNOWFLAKE_PASSWORD` env vars | **Yes** |

### 7.3 What the code change looks like

**Snowflake admin side** (Dave Wolf / Snowflake team):
1. Generate RSA key pair for each service user.
2. Register the public key: `ALTER USER <service_user> SET RSA_PUBLIC_KEY = '...'`.

**Application side — `lpr_data_source_snowflake.py`:**

```python
# BEFORE
connect_kwargs = {
    'user': user,
    'password': password,   # remove this
    'account': account,
}

# AFTER
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_private_key

private_key_pem = getattr(settings, 'SNOWFLAKE_PRIVATE_KEY_PEM', None)
private_key = load_pem_private_key(private_key_pem.encode(), password=None)
private_key_der = private_key.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
)

connect_kwargs = {
    'user': user,
    'private_key': private_key_der,   # replaces 'password'
    'account': account,
}
```

The same pattern applies to `enterprise_reporting/clients/snowflake.py`.

### 7.4 New settings / env vars

| Setting | Purpose | How to store |
|---|---|---|
| `SNOWFLAKE_PRIVATE_KEY_PEM` | PEM-encoded RSA private key for `ENTERPRISE_SERVICE_USER` | Secrets manager (Vault / AWS Secrets Manager) |
| `SNOWFLAKE_REPORTING_PRIVATE_KEY_PEM` | PEM-encoded RSA private key for reporting service user | Secrets manager |

**Do not** commit private keys to git or `.env` files.

### 7.5 Test changes required

`enterprise_data/tests/lpr/test_lpr_data_source_snowflake.py` — `TestGetConnection` class currently mocks `SNOWFLAKE_SERVICE_USER_PASSWORD`. After migration, update tests to:
- Mock `SNOWFLAKE_PRIVATE_KEY_PEM` instead.
- Assert `private_key` (not `password`) is passed to `snowflake.connector.connect()`.

### 7.6 Migration can be zero-downtime

Because of graceful degradation (Section 9), the migration can be done safely:
1. Add new key pair settings to the secrets manager in staging.
2. Deploy the code change to staging and verify Snowflake queries succeed.
3. Promote to production.
4. Remove `SNOWFLAKE_SERVICE_USER_PASSWORD` from secrets manager once confirmed.

---

## 8. Query Frequency Explained

There is no caching layer in front of the Snowflake call today (ticket `ENT0-9531` tracks adding one). The query fires on every LPR API request:

| Trigger | When it fires |
|---|---|
| Admin Portal loads the LPR table | Once per page load, once per pagination event |
| Admin Portal CSV export | Once per `ENROLLMENTS_PAGE_SIZE` rows streamed |
| API integrations / automated tooling | Depends on the polling interval of the client |

Each query is scoped tightly: one enterprise UUID, and only the `(user_email, courserun_key)` pairs on that specific page. No full-table scans.

---

## 9. Graceful Degradation

If the Snowflake call fails for any reason — wrong credentials, network timeout, table unavailable — the application **does not return an error to the caller**. Instead:

- All other LPR fields are served from the application database as normal.
- `course_progress` is `null` for all rows on that response.
- A `WARNING` is logged with full traceback for observability.

This design means:
- The key pair migration (Section 7) can be tested safely without risking the LPR API.
- Any Snowflake outage has a bounded, predictable impact.

---

## 10. Tickets to Be Created (Naveen)

The following tickets should be created and added to the next sprint:

### Ticket 1 — Discovery Documentation ✅ *(this document)*
**Summary:** Document the LPR `course_progress` feature: history, architecture, and Snowflake connectivity.  
**Type:** Task  
**Status:** Done — this document fulfils it.

---

### Ticket 2 — Migrate LPR Snowflake client to key pair authentication
**Summary:** Replace username/password auth with RSA key pair in `SnowflakeCourseProgressSource`.  
**Type:** Engineering task  
**Priority:** Medium (must complete before end of August 2026)  
**Acceptance Criteria:**
- `lpr_data_source_snowflake.py` `_get_connection()` uses `private_key` (DER) instead of `password`.
- Django setting `SNOWFLAKE_PRIVATE_KEY_PEM` is read from secrets manager in all environments.
- `SNOWFLAKE_SERVICE_USER_PASSWORD` setting is removed.
- `TestGetConnection` unit tests updated.
- Verified working in staging before production deploy.

**Dependencies:** Snowflake admin (Dave Wolf) must register the RSA public key for `ENTERPRISE_SERVICE_USER` before this can be validated end-to-end.

---

### Ticket 3 — Migrate enterprise reporting Snowflake client to key pair authentication
**Summary:** Replace username/password auth with RSA key pair in `enterprise_reporting/clients/snowflake.py` (`SnowflakeClient`).  
**Type:** Engineering task  
**Priority:** Medium (must complete before end of August 2026)  
**Acceptance Criteria:**
- `SnowflakeClient.__init__()` supports `private_key` in addition to / instead of `password`.
- `SNOWFLAKE_PASSWORD` env var is removed from all environment configurations.
- Reporting jobs verified working in staging.

---

### Ticket 4 — Add caching in front of Snowflake LPR call (was ENT0-9531)
**Summary:** Add a short-lived cache (e.g. Redis, per enterprise UUID) in front of `SnowflakeCourseProgressSource.get_course_progress_map()` to reduce Snowflake query frequency.  
**Type:** Engineering task / performance improvement  
**Priority:** Low–Medium  
**Acceptance Criteria:**
- Cache TTL aligned with Snowflake data refresh cadence (~1 day or configurable).
- Cache can be bypassed / invalidated on demand.
- Query volume observed in Snowflake query history drops significantly after deploy.

---

### Ticket 5 — Coordinate schema stability agreement with Data Platform (DPSD-8550 follow-up)
**Summary:** Formalise the contract between `edx-enterprise-data` and the Data Platform team for `LEARNER_PROGRESS_REPORT_INTERNAL` (and `_EXTERNAL`).  
**Type:** Coordination / process  
**Priority:** Low  
**Acceptance Criteria:**
- Data Platform team has this document or equivalent context.
- A process is agreed for notifying `edx-enterprise-data` engineers before any breaking schema changes.
- Column names, join keys, and data types are documented jointly.

---

## 11. Summary for Snowflake Admin (Dave Wolf)

> The `ENTERPRISE_SERVICE_USER` queries you see in Snowflake's query history are **read-only SELECT statements** against `PROD.ENTERPRISE.LEARNER_PROGRESS_REPORT_INTERNAL`. They are triggered in real time whenever an enterprise admin loads or exports their Learner Progress Report in the Admin Portal. The application **never writes to Snowflake** — data flows strictly one-way, from Snowflake into our API responses.
>
> You are correct that the current auth method (username + password) needs to be upgraded to key pair auth. We have filed the engineering tickets to make this change (Tickets 2 and 3 above). On our end, the code change is straightforward — we swap `password` for `private_key` in the connector call. We need your team to generate the RSA key pair and register the public key against `ENTERPRISE_SERVICE_USER` (and the reporting service user) as a prerequisite. We are well within the August deadline and will share ticket links once created.
