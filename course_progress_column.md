# Architecture Document: `course_progress` Column in Learner Progress Report

**Author:** Platform Architect  
**Date:** April 1, 2026  
**Status:** Draft for Implementation  
**Ticket:** ENT-11183  
**Repos Affected:**
- `frontend-app-admin-portal` ✅ (frontend — done)
- `edx-analytics-data-api` (backend enrollment API — required)
- `edx-enterprise` / enterprise-data pipeline (data source — required)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Glossary](#2-glossary)
3. [Current State (AS-IS)](#3-current-state-as-is)
   - [3.1 System Overview](#31-system-overview)
   - [3.2 Current Data Flow](#32-current-data-flow)
   - [3.3 Current API Contract](#33-current-api-contract)
   - [3.4 Current Frontend Columns](#34-current-frontend-columns)
   - [3.5 Gaps & Problems](#35-gaps--problems)
4. [To-Be State (TO-BE)](#4-to-be-state-to-be)
   - [4.1 Solution Overview](#41-solution-overview)
   - [4.2 To-Be Data Flow](#42-to-be-data-flow)
   - [4.3 To-Be API Contract](#43-to-be-api-contract)
   - [4.4 To-Be Frontend Columns](#44-to-be-frontend-columns)
   - [4.5 `course_progress` Definition](#45-course_progress-definition)
5. [Component-Level Changes](#5-component-level-changes)
   - [5.1 Frontend: `EnrollmentsTable`](#51-frontend-enrollmentstable)
   - [5.2 Backend: Enterprise Data API (enrollments endpoint)](#52-backend-enterprise-data-api-enrollments-endpoint)
   - [5.3 Data Pipeline: Completion Aggregation](#53-data-pipeline-completion-aggregation)
6. [API Contracts (Detailed)](#6-api-contracts-detailed)
   - [6.1 LMS Progress Tab API (source)](#61-lms-progress-tab-api-source)
   - [6.2 Enterprise Data API Enrollment Endpoint (updated)](#62-enterprise-data-api-enrollment-endpoint-updated)
7. [Sequence Diagrams](#7-sequence-diagrams)
   - [7.1 AS-IS: Admin downloads CSV](#71-as-is-admin-downloads-csv)
   - [7.2 TO-BE: Admin downloads CSV with course_progress](#72-to-be-admin-downloads-csv-with-course_progress)
8. [Data Model Changes](#8-data-model-changes)
9. [Frontend Implementation Details](#9-frontend-implementation-details)
10. [Backend Implementation Details](#10-backend-implementation-details)
11. [CSV Download Behaviour](#11-csv-download-behaviour)
12. [Edge Cases & Business Rules](#12-edge-cases--business-rules)
13. [Testing Plan](#13-testing-plan)
14. [Dependencies & Risks](#14-dependencies--risks)
15. [Rollout Plan](#15-rollout-plan)

---

## 1. Executive Summary

Enterprise admins using the **Learner Progress Report (LPR)** in the Admin Portal currently cannot see **what percentage of a course a learner has completed** — i.e., how much content they have actually viewed, regardless of their grade.

This document describes the AS-IS architecture (where `course_progress` does not exist) and the TO-BE architecture (where `course_progress` is a first-class column in the LPR table and CSV download), including all backend, data pipeline, and frontend changes required.

---

## 2. Glossary

| Term | Definition |
|---|---|
| **LPR** | Learner Progress Report — the main enrollment table in the Admin Portal |
| **course_progress** | % of course content units a learner has **completed** (viewed/interacted with). Range: 0–100%. |
| **current_grade** | The learner's **graded score** as a % (0–100%). Based on assignment points earned/possible. Unrelated to content completion. |
| **completion_summary** | LMS object: `{ complete_count, incomplete_count, locked_count }` — total content units accounted for |
| **progress_status** | Categorical field: `In Progress`, `Passed`, `Failed` |
| **Enterprise Data API** | Backend service serving `/api/v1/{enterprise_uuid}/enrollments/` — the source of LPR data |
| **BlockCompletion** | edx-platform model recording when a learner viewed/completed a content block |
| **CSV download** | The "Download CSV" button in LPR that exports all enrollment rows |

---

## 3. Current State (AS-IS)

### 3.1 System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ADMIN PORTAL (React)                         │
│                                                                     │
│  AdminV2/index.jsx                                                  │
│    └── LearnerReport.jsx                                            │
│          └── EnrollmentsTable/index.jsx  ←── columns defined here  │
│                └── TableContainer                                   │
│                      └── EnterpriseDataApiService                   │
│                            └── GET /api/v1/{id}/enrollments/        │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   ENTERPRISE DATA API (Python/DRF)                  │
│                                                                     │
│  GET /api/v1/{enterprise_uuid}/enrollments/                         │
│  GET /api/v1/{enterprise_uuid}/enrollments.csv   (CSV download)     │
│                                                                     │
│  Source tables (Snowflake / analytics DB):                          │
│    enterprise.fact_enrollment_admin_dash                            │
│    (or equivalent enrollment fact table)                            │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LMS / edx-platform                               │
│                                                                     │
│  GET /api/course_home/progress/{course_key}/                        │
│    └── completion_summary: { complete_count,                        │
│                               incomplete_count,                     │
│                               locked_count }                        │
│    └── course_grade: { percent, is_passing }                        │
│                                                                     │
│  BlockCompletion model  ←── source of completion_summary            │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Current Data Flow

```
BlockCompletion (LMS DB)
        │
        │  ETL / Analytics Pipeline (nightly)
        ▼
enterprise.fact_enrollment_admin_dash  (Snowflake)
        │
        │  Enterprise Data API serializer
        ▼
/api/v1/{id}/enrollments/  →  JSON response (no course_progress)
        │
        │  EnterpriseDataApiService.fetchCourseEnrollments()
        ▼
EnrollmentsTable/index.jsx  →  Table columns (no course_progress)
        │
        │  DownloadCsvButton
        ▼
enrollments.csv  (no course_progress column)
```

### 3.3 Current API Contract

**Endpoint:** `GET /api/v1/{enterprise_uuid}/enrollments/`  
**CSV:** `GET /api/v1/{enterprise_uuid}/enrollments.csv?no_page=true`

**Current response fields per enrollment row:**

| Field | Type | Example |
|---|---|---|
| `id` | integer | `270` |
| `user_email` | string | `abbey@bestrun.com` |
| `user_first_name` | string | `Abbey` |
| `user_last_name` | string | `Smith` |
| `course_title` | string | `Product Management...` |
| `course_list_price` | decimal string | `"200.00"` |
| `course_start_date` | ISO datetime | `2017-10-21T23:47:32Z` |
| `course_end_date` | ISO datetime | `2018-05-13T12:47:27Z` |
| `enrollment_date` | ISO datetime | `2017-10-01T10:00:00Z` |
| `passed_date` | ISO datetime \| null | `null` |
| `current_grade` | float (0–1) | `0.44` |
| `progress_status` | string | `"Failed"` |
| `last_activity_date` | ISO datetime | `2018-08-09T10:59:28Z` |
| ❌ `course_progress` | **MISSING** | — |

### 3.4 Current Frontend Columns

File: `src/components/EnrollmentsTable/index.jsx`

| # | Column Label | API Key | Sortable |
|---|---|---|---|
| 1 | Email | `user_email` | ✅ |
| 2 | First Name | `user_first_name` | ✅ |
| 3 | Last Name | `user_last_name` | ✅ |
| 4 | Course Title | `course_title` | ✅ |
| 5 | Course Price | `course_list_price` | ✅ |
| 6 | Start Date | `course_start_date` | ✅ |
| 7 | End Date | `course_end_date` | ✅ |
| 8 | Passed Date | `passed_date` | ✅ |
| 9 | Current Grade | `current_grade` | ✅ |
| 10 | Progress Status | `progress_status` | ✅ |
| 11 | Last Activity Date | `last_activity_date` | ✅ |

### 3.5 Gaps & Problems

| Problem | Impact |
|---|---|
| No `course_progress` column — admins cannot see how much content a learner has consumed | Admins cannot distinguish a learner who viewed 10% vs 90% of content, both may show "In Progress" with the same grade |
| `current_grade` (graded score %) ≠ content completion % — admins conflate the two | Incorrect learner intervention decisions |
| CSV download does not include completion % | Enterprise admins cannot report on content coverage to stakeholders |
| `completion_summary` exists in the LMS progress API but is never surfaced in the enterprise data pipeline | Data is available at source but not flowing downstream |

---

## 4. To-Be State (TO-BE)

### 4.1 Solution Overview

Add `course_progress` (% of course content units completed) as a **new column** in:
1. The LPR enrollment table (paginated JSON view)
2. The CSV download (`enrollments.csv`)

`course_progress` is computed from `completion_summary` sourced from the LMS `BlockCompletion` records, delivered via the enterprise analytics pipeline into the Enterprise Data API.

### 4.2 To-Be Data Flow

```
BlockCompletion (LMS DB)
        │
        │  ETL / Analytics Pipeline (nightly)
        │  NEW: include complete_count, incomplete_count, locked_count
        ▼
enterprise.fact_enrollment_admin_dash  (Snowflake)
  NEW columns: complete_count, incomplete_count, locked_count
        │
        │  Enterprise Data API serializer
        │  NEW: compute course_progress = complete_count /
        │       (complete_count + incomplete_count + locked_count)
        ▼
/api/v1/{id}/enrollments/  →  JSON response (WITH course_progress)
        │
        │  EnterpriseDataApiService.fetchCourseEnrollments()
        ▼
EnrollmentsTable/index.jsx  →  Table columns (WITH course_progress) ✅
        │
        │  DownloadCsvButton
        ▼
enrollments.csv  (WITH course_progress column) ✅
```

### 4.3 To-Be API Contract

**New field added to enrollment row:**

| Field | Type | Range | Example | Notes |
|---|---|---|---|---|
| `course_progress` | float (0–1) | 0.00–1.00 | `0.01` | `null` if no completion data exists |

Full updated response:

| Field | Type | Change |
|---|---|---|
| `user_email` | string | unchanged |
| `user_first_name` | string | unchanged |
| `user_last_name` | string | unchanged |
| `course_title` | string | unchanged |
| `course_list_price` | decimal string | unchanged |
| `course_start_date` | ISO datetime | unchanged |
| `course_end_date` | ISO datetime | unchanged |
| `enrollment_date` | ISO datetime | unchanged |
| `passed_date` | ISO datetime \| null | unchanged |
| `current_grade` | float (0–1) | unchanged |
| **`course_progress`** | **float (0–1)** | **🆕 NEW** |
| `progress_status` | string | unchanged |
| `last_activity_date` | ISO datetime | unchanged |

### 4.4 To-Be Frontend Columns

| # | Column Label | API Key | Sortable | Change |
|---|---|---|---|---|
| 1 | Email | `user_email` | ✅ | — |
| 2 | First Name | `user_first_name` | ✅ | — |
| 3 | Last Name | `user_last_name` | ✅ | — |
| 4 | Course Title | `course_title` | ✅ | — |
| 5 | Course Price | `course_list_price` | ✅ | — |
| 6 | Start Date | `course_start_date` | ✅ | — |
| 7 | End Date | `course_end_date` | ✅ | — |
| 8 | Passed Date | `passed_date` | ✅ | — |
| 9 | Current Grade | `current_grade` | ✅ | — |
| **10** | **Course Progress** | **`course_progress`** | **✅** | **🆕 NEW** |
| 11 | Progress Status | `progress_status` | ✅ | — |
| 12 | Last Activity Date | `last_activity_date` | ✅ | — |

### 4.5 `course_progress` Definition

```
course_progress (%) =
    complete_count
    ─────────────────────────────────────────────────  × 100
    complete_count + incomplete_count + locked_count
```

Where:
- `complete_count` = number of content blocks the learner has completed (from `BlockCompletion`)
- `incomplete_count` = number of content blocks not yet completed
- `locked_count` = number of content blocks inaccessible (e.g. audit track paywall)

This is the **identical formula** used by `frontend-app-learning` in:
> `src/course-home/progress-tab/course-completion/CompletionDonutChart.jsx`

**Example (from live API response):**
```json
"completion_summary": {
    "complete_count": 1,
    "incomplete_count": 83,
    "locked_count": 0
}
```
→ `course_progress = 1 / (1 + 83 + 0) = 1/84 ≈ 0.0119 → displayed as 1%`

---

## 5. Component-Level Changes

### 5.1 Frontend: `EnrollmentsTable`

**File:** `src/components/EnrollmentsTable/index.jsx`  
**Status:** ✅ DONE

**Changes:**
1. New column entry in `enrollmentTableColumns[]`:
```jsx
{
  label: intl.formatMessage({
    id: 'adminPortal.enrollmentsTable.courseProgress',
    defaultMessage: 'Course Progress',
    description: 'Percentage of course content units completed by the learner.',
  }),
  key: 'course_progress',
  columnSortable: true,
},
```

2. New formatter in `formatEnrollmentData()`:
```jsx
course_progress: formatPercentage({ decimal: enrollment.course_progress }),
```

**No changes needed** to:
- `EnterpriseDataApiService.js` — `fetchCourseEnrollments` is already field-agnostic; it passes through whatever the API returns
- `DownloadCsvButton.jsx` — CSV is generated server-side; any new field in the API response is automatically included
- `AdminV2/index.jsx` — `csvFetchMethod` already calls `fetchCourseEnrollments` with `{ csv: true }`

### 5.2 Backend: Enterprise Data API (enrollments endpoint)

**Repo:** `edx-analytics-data-api` or enterprise-data service  
**Status:** 🔴 REQUIRED — not yet done

**Changes needed:**

1. **Serializer** — add `course_progress` field:
```python
class EnterpriseEnrollmentSerializer(serializers.Serializer):
    # ... existing fields ...
    course_progress = serializers.FloatField(
        allow_null=True,
        help_text="Fraction (0-1) of course content units the learner has completed."
    )
```

2. **View / QuerySet** — compute or pass through `course_progress`:
```python
# Option A: compute in serializer from completion columns
def get_course_progress(self, obj):
    complete = obj.complete_count or 0
    total = complete + (obj.incomplete_count or 0) + (obj.locked_count or 0)
    if total == 0:
        return None
    return round(complete / total, 4)

# Option B: store pre-computed in DB/fact table and just expose it
return obj.course_progress  # pre-computed decimal
```

3. **CSV renderer** — no change needed if using DRF's CSV renderer; the field will be included automatically.

### 5.3 Data Pipeline: Completion Aggregation

**Repo:** analytics pipeline (Snowflake DBT / Spark jobs)  
**Status:** 🔴 REQUIRED — not yet done

**Changes needed:**

The Snowflake fact table `enterprise.fact_enrollment_admin_dash` (or equivalent) must include three new columns:

| New Column | Source | Type |
|---|---|---|
| `complete_count` | `completion_api_completionaggregate` or `BlockCompletion` aggregation | integer |
| `incomplete_count` | derived: `total_blocks - complete_count - locked_count` | integer |
| `locked_count` | blocks with `learner_has_access = false` | integer |

**Pipeline source:** LMS `BlockCompletion` table (one row per learner per block per course), aggregated at enrollment level.

**Alternative (lower effort):** Call the LMS Progress API `GET /api/course_home/progress/{course_key}/` per enrollment during the ETL job to get `completion_summary` directly and store `complete_count`, `incomplete_count`, `locked_count`.

---

## 6. API Contracts (Detailed)

### 6.1 LMS Progress Tab API (source)

**Endpoint:** `GET https://courses.edx.org/api/course_home/progress/{course_key}/`  
**Auth:** Learner JWT  
**Key fields for `course_progress`:**

```json
{
  "completion_summary": {
    "complete_count": 1,
    "incomplete_count": 83,
    "locked_count": 0
  },
  "course_grade": {
    "percent": 0.0,
    "is_passing": false
  }
}
```

> ⚠️ Note: This endpoint requires **learner-scoped** auth — it cannot be called with a service user for all learners. Bulk extraction must happen via the analytics pipeline using the `completion_aggregation` data in the LMS database directly.

### 6.2 Enterprise Data API Enrollment Endpoint (updated)

**Endpoint:** `GET /api/v1/{enterprise_uuid}/enrollments/`  
**Auth:** Enterprise admin JWT  
**Full updated response example:**

```json
{
  "count": 330,
  "current_page": 1,
  "num_pages": 7,
  "results": [
    {
      "id": 270,
      "user_email": "abbey@bestrun.com",
      "user_first_name": "Abbey",
      "user_last_name": "Smith",
      "course_title": "Product Management with Lean, Agile and System Design Thinking",
      "course_list_price": "200.00",
      "course_start_date": "2017-10-21T23:47:32.738Z",
      "course_end_date": "2018-05-13T12:47:27.534Z",
      "enrollment_date": "2017-10-01T10:00:00.000Z",
      "passed_date": null,
      "current_grade": 0.44,
      "course_progress": 0.3214,
      "progress_status": "Failed",
      "last_activity_date": "2018-08-09T10:59:28.628Z"
    }
  ]
}
```

**CSV endpoint:** `GET /api/v1/{enterprise_uuid}/enrollments.csv?no_page=true`

CSV header row (updated):
```
id,user_email,user_first_name,user_last_name,course_title,course_list_price,
course_start_date,course_end_date,enrollment_date,passed_date,current_grade,
course_progress,progress_status,last_activity_date
```

---

## 7. Sequence Diagrams

### 7.1 AS-IS: Admin downloads CSV

```
Admin Browser          Admin Portal FE         Enterprise Data API       Analytics DB
     │                      │                          │                      │
     │─── clicks Download ──▶│                          │                      │
     │                      │─── GET /enrollments.csv ─▶│                      │
     │                      │                          │─── SELECT * FROM ────▶│
     │                      │                          │    enrollments        │
     │                      │                          │◀─── rows (no          │
     │                      │                          │     course_progress) ─│
     │                      │◀── CSV (11 columns) ─────│                      │
     │◀── downloads file ───│                          │                      │
     │  [NO course_progress]│                          │                      │
```

### 7.2 TO-BE: Admin downloads CSV with course_progress

```
Admin Browser          Admin Portal FE         Enterprise Data API       Analytics DB
     │                      │                          │                      │
     │─── clicks Download ──▶│                          │                      │
     │                      │─── GET /enrollments.csv ─▶│                      │
     │                      │                          │─── SELECT *,          │
     │                      │                          │    course_progress ──▶│
     │                      │                          │    FROM enrollments   │
     │                      │                          │◀─── rows (WITH        │
     │                      │                          │     course_progress) ─│
     │                      │◀── CSV (12 columns) ─────│                      │
     │◀── downloads file ───│                          │                      │
     │  [WITH course_progress]                         │                      │
```

---

## 8. Data Model Changes

### Analytics Fact Table: `enterprise.fact_enrollment_admin_dash`

| Column | Type | Existing | Change |
|---|---|---|---|
| `enrollment_id` | bigint | ✅ | — |
| `enterprise_customer_uuid` | uuid | ✅ | — |
| `user_email` | varchar | ✅ | — |
| `course_key` | varchar | ✅ | — |
| `course_title` | varchar | ✅ | — |
| `current_grade` | float | ✅ | — |
| `progress_status` | varchar | ✅ | — |
| `passed_date` | timestamp | ✅ | — |
| `last_activity_date` | timestamp | ✅ | — |
| **`complete_count`** | **int** | ❌ | **🆕 ADD** |
| **`incomplete_count`** | **int** | ❌ | **🆕 ADD** |
| **`locked_count`** | **int** | ❌ | **🆕 ADD** |

> Alternatively, store pre-computed `course_progress` (float 0–1) directly in the fact table.

### Source for new columns

```sql
-- LMS: BlockCompletion aggregation per enrollment
SELECT
    lce.id                                        AS enrollment_id,
    SUM(CASE WHEN bc.completion = 1 THEN 1 ELSE 0 END) AS complete_count,
    SUM(CASE WHEN bc.completion < 1 THEN 1 ELSE 0 END) AS incomplete_count,
    0                                              AS locked_count   -- audit track logic handled separately
FROM
    student_courseenrollment lce
LEFT JOIN
    completion_blockcompletion bc
    ON bc.user_id = lce.user_id
    AND bc.course_key = lce.course_id
GROUP BY
    lce.id
```

---

## 9. Frontend Implementation Details

### Files Changed

| File | Change |
|---|---|
| `src/components/EnrollmentsTable/index.jsx` | ✅ New column + formatter |
| `src/components/EnrollmentsTable/EnrollmentsTable.mocks.js` | ✅ Added `course_progress` to mock rows |

### `formatPercentage` utility

The existing utility `formatPercentage({ decimal })` in `src/utils.js` converts a float `0–1` to a display string `"0%"–"100%"`. No changes needed.

```js
// Example
formatPercentage({ decimal: 0.0119 })  // → "1%"
formatPercentage({ decimal: 0.5 })     // → "50%"
formatPercentage({ decimal: 1.0 })     // → "100%"
formatPercentage({ decimal: null })    // → "" (empty string for missing data)
```

### i18n

New message ID added:
```
adminPortal.enrollmentsTable.courseProgress
defaultMessage: "Course Progress"
```

This must be added to the translation files for all supported locales.

---

## 10. Backend Implementation Details

### Enterprise Data API Serializer (pseudocode)

```python
class EnterpriseEnrollmentSerializer(serializers.ModelSerializer):
    course_progress = serializers.SerializerMethodField()

    def get_course_progress(self, obj):
        """
        Returns fraction (0.0–1.0) of course content units completed.
        Returns None if completion data is unavailable.
        """
        complete = getattr(obj, 'complete_count', None)
        incomplete = getattr(obj, 'incomplete_count', None)
        locked = getattr(obj, 'locked_count', None)

        if complete is None or incomplete is None:
            return None

        total = complete + incomplete + (locked or 0)
        if total == 0:
            return None

        return round(complete / total, 4)

    class Meta:
        fields = [
            # ... existing fields ...
            'course_progress',
        ]
```

### CSV Field Ordering

To maintain stable CSV column order (important for downstream consumers):

```python
CSV_FIELD_NAMES = [
    'user_email',
    'user_first_name',
    'user_last_name',
    'course_title',
    'course_list_price',
    'course_start_date',
    'course_end_date',
    'enrollment_date',
    'passed_date',
    'current_grade',
    'course_progress',       # NEW — inserted after current_grade
    'progress_status',
    'last_activity_date',
]
```

---

## 11. CSV Download Behaviour

### AS-IS CSV

```
user_email,user_first_name,...,current_grade,progress_status,...
abbey@bestrun.com,Abbey,...,44%,Failed,...
```

### TO-BE CSV

```
user_email,user_first_name,...,current_grade,course_progress,progress_status,...
abbey@bestrun.com,Abbey,...,44%,32%,Failed,...
```

### Null handling in CSV

| Scenario | `course_progress` value in CSV |
|---|---|
| Completion data available | decimal, e.g. `0.3214` |
| No completion data (new enrollment, never opened course) | empty string `""` |
| Locked course (audit track, 0 accessible units) | `0.0` or empty string |

---

## 12. Edge Cases & Business Rules

| Scenario | Expected Behaviour |
|---|---|
| Learner enrolled but never opened the course | `course_progress = null` / `""` |
| Learner completed every unit | `course_progress = 1.0` → displayed as `100%` |
| All units locked (audit track, no upgrade) | `locked_count = total`, `complete_count = 0` → `0%` |
| `complete_count + incomplete_count + locked_count = 0` | Return `null` — avoid division by zero |
| `course_progress = 100%` but `progress_status = "Failed"` | Possible — learner completed all content but failed graded assessments. Both values are correct and independent. |
| `course_progress = 1%` but `current_grade = 44%` | Possible — learner completed only 1 unit (a high-scoring graded quiz), not yet viewed other content. |
| Audit learner with locked content | `locked_count > 0`; completion % is computed over all units including locked; will be low even if learner completed all accessible content |

---



## 14. Dependencies & Risks

### Dependencies

| Dependency | Owner | Status | Blocking |
|---|---|---|---|
| Analytics pipeline adds `complete_count` / `incomplete_count` / `locked_count` to enrollment fact table | Data Engineering | 🔴 Not started | ✅ Yes |
| Enterprise Data API serializer exposes `course_progress` | Backend (enterprise-data) | 🔴 Not started | ✅ Yes |
| Frontend column + formatter | Frontend | ✅ Done | — |

### Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Analytics pipeline latency — completion data is 24–48h stale | High | Medium | Document in UI tooltip: "Updated every 24 hours" |
| `BlockCompletion` records missing for old enrollments | Medium | Medium | Return `null` / empty; display `—` in UI |
| `course_progress = 100%` for learners who used keyboard shortcuts / auto-complete | Low | Low | This matches the LMS progress page behaviour — consistent |
| Large CSV payloads slow down for enterprises with 100k+ enrollments | Low | High | No change — existing pagination/streaming is unaffected by adding one float field |
| Breaking change to CSV schema for downstream consumers | Medium | High | Announce column addition in changelog; insert column after `current_grade` (not at end) |

---

## 15. Rollout Plan

### Phase 1 — Backend (Data Pipeline)
- Add `complete_count`, `incomplete_count`, `locked_count` to enrollment fact table
- Deploy and validate data in staging

### Phase 2 — Backend (API)
- Add `course_progress` to Enterprise Data API enrollment serializer
- Add to CSV field list
- Deploy to staging; confirm response contains field with correct values

### Phase 3 — Frontend
- ✅ Column + formatter already added to `EnrollmentsTable/index.jsx`
- Add i18n translations
- Update snapshot tests
- Feature-flag behind a waffle flag if preferred: `ENABLE_COURSE_PROGRESS_LPR_COLUMN`
- Deploy to staging; QA the table and CSV

### Phase 4 — Production
- Enable for all customers
- Monitor for errors in Datadog / Sentry

---

## Appendix: Key Files Reference

| File | Repo | Role |
|---|---|---|
| `src/components/EnrollmentsTable/index.jsx` | `frontend-app-admin-portal` | Table column definitions + data formatters |
| `src/components/EnrollmentsTable/EnrollmentsTable.mocks.js` | `frontend-app-admin-portal` | Mock data for tests |
| `src/data/services/EnterpriseDataApiService.js` | `frontend-app-admin-portal` | API service: `fetchCourseEnrollments` |
| `src/components/AdminV2/index.jsx` | `frontend-app-admin-portal` | CSV download wiring |
| `src/utils.js` | `frontend-app-admin-portal` | `formatPercentage` utility |
| `src/course-home/progress-tab/course-completion/CompletionDonutChart.jsx` | `frontend-app-learning` | Reference implementation of `course_progress` formula |
| `analytics_data_api/v0/serializers.py` | `edx-analytics-data-api` | Enrollment serializer (to be updated) |
| `enterprise/models.py` | `edx-enterprise` | `EnterpriseCustomerReportingConfiguration` |
| `lms/.../course_home/progress/` | `edx-platform` | Progress API source: `completion_summary` |
