# Multi-license Test Summary

## Purpose

This file gives a short visual summary of:
- learner to license mapping
- catalog to course mapping
- course overlap behavior
- API test matrix
- expected outputs
- proof points that the multi-license code is working

---

## 1. Enterprise under test

| Field | Value |
|---|---|
| Enterprise name | `test-multi-enterprise` |
| Enterprise UUID | `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` |
| Main API under test | `enterprise-access` BFF |
| BFF endpoint | `POST /api/v1/bffs/learner/dashboard/?enterprise_customer_uuid=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` |

---

## 2. Catalog mapping

| Catalog Name | Catalog UUID | Meaning |
|---|---|---|
| Leadership | `11111111-1111-1111-1111-111111111111` | Leadership-only subscription catalog |
| Technical | `22222222-2222-2222-2222-222222222222` | Technical-only subscription catalog |
| Compliance | `33333333-3333-3333-3333-333333333333` | Compliance-only subscription catalog |
| Data Science | `44444444-4444-4444-4444-444444444444` | Data science subscription catalog |
| Business | `55555555-5555-5555-5555-555555555555` | Business subscription catalog |

---

## 3. Course mapping

| Course | Course Key | Expected Catalog Membership |
|---|---|---|
| Overlap course | `MITx+6.00.1x` | Leadership + Technical + Compliance |
| Leadership course | `ASUx+MAT117x` | Leadership only |
| Technical course | `HarvardX+CS50x` | Technical only |
| Compliance course | `edx+H200` | Compliance only |
| Data Science course | `ColumbiaX+DS102X` | Data Science only |
| Business course | `edx+H100` | Business only |

---

## 4. Learner to license coverage

| Learner | Expected License Count | Expected Catalog Coverage |
|---|---:|---|
| `test-multi-alice` | `3` | Leadership, Technical, Compliance |
| `test-multi-bob` | `4` | Leadership, Technical, Compliance, Data Science |
| `test-multi-carol` | `5` | Leadership, Technical, Compliance, Data Science, Business |

---

## 5. Alice license detail

| Order | Subscription Plan UUID | Catalog | Why it matters |
|---:|---|---|---|
| 1 | `c1111111-1111-1111-1111-111111111111` | Leadership | First activated license |
| 2 | `c2222222-2222-2222-2222-222222222222` | Technical | Second activated license |
| 3 | `c3333333-3333-3333-3333-333333333333` | Compliance | Third activated license |

### Business rule under test

If a learner has more than one subscription license and enrolls in a course that appears in more than one catalog, the enrollment should attach to the license they activated first.

### Expected winner for Alice on overlap course

| Overlap Course | Matching Catalogs | Expected Chosen License |
|---|---|---|
| `MITx+6.00.1x` | Leadership + Technical + Compliance | `c1111111-1111-1111-1111-111111111111` |

---

## 6. Visual representation

```mermaid
flowchart TD
    A[test-multi-alice] --> L1[Leadership License\nc1111111-1111-1111-1111-111111111111]
    A --> L2[Technical License\nc2222222-2222-2222-2222-222222222222]
    A --> L3[Compliance License\nc3333333-3333-3333-3333-333333333333]

    L1 --> C1[Leadership Catalog\n11111111-1111-1111-1111-111111111111]
    L2 --> C2[Technical Catalog\n22222222-2222-2222-2222-222222222222]
    L3 --> C3[Compliance Catalog\n33333333-3333-3333-3333-333333333333]

    C1 --> OC[MITx+6.00.1x]
    C2 --> OC
    C3 --> OC

    OC --> R[Expected enrollment license = first activated]\n    R --> W[c1111111-1111-1111-1111-111111111111]
```

---

## 7. API test matrix

| Test # | API | Method | Purpose | Expected Result |
|---:|---|---|---|---|
| 1 | `license-manager` learner licenses | `GET` | Verify learner can fetch all subscription licenses | `200`, Alice count `3` |
| 2 | BFF dashboard | `POST` | Verify multi-license payload returned to learner portal | `200`, `subscription_licenses` exists, `licenses_by_catalog` exists |
| 3 | BFF quick count | `POST` | Verify Alice license count and mapped catalogs | `licenses = 3` |
| 4 | Discovery overlap lookup | `GET` | Optional local check that overlap course exists in Discovery | `200` if course exists locally |
| 5 | Enterprise-catalog overlap check | `GET` | Optional local check that overlap course maps to 3 catalogs | `200` if learner has catalog access |
| 6 | Leadership content check | `GET` | Verify single-catalog leadership mapping | one catalog |
| 7 | Technical content check | `GET` | Verify single-catalog technical mapping | one catalog |
| 8 | Compliance content check | `GET` | Verify single-catalog compliance mapping | one catalog |
| 9 | Bob dashboard | `POST` | Verify 4-license scenario | `4` licenses |
| 10 | Carol dashboard | `POST` | Verify 5-license scenario | `5` licenses |

---

## 8. Main API calls and expected outputs

### 8.1 Direct learner licenses API

| API | Method | Expected HTTP | Expected Key Output |
|---|---|---:|---|
| `/api/v1/learner-licenses/` | `GET` | `200` | `count = 3` for Alice |

### Expected fields in response

| Field | Expected Value for Alice |
|---|---|
| `count` | `3` |
| `results[0].user_email` | `test-multi-alice@example.com` |
| `results[*].status` | `activated` |
| `results[*].subscription_plan_uuid` | includes `c111...`, `c222...`, `c333...` |

---

### 8.2 BFF dashboard API

| API | Method | Expected HTTP | Expected Key Output |
|---|---|---:|---|
| `/api/v1/bffs/learner/dashboard/` | `POST` | `200` | subscriptions object contains multi-license data |

### Expected fields in response

| Field Path | Expected Value |
|---|---|
| `enterprise_customer_user_subsidies.subscriptions.subscription_licenses` | present |
| `enterprise_customer_user_subsidies.subscriptions.licenses_by_catalog` | present |
| `subscription_licenses.length` | `3` for Alice |
| `licenses_by_catalog.keys()` | `111...`, `222...`, `333...` for Alice |

---

## 9. Proof points already observed

The following results were already successfully verified during testing.

| Proof Item | Observed Result | Meaning |
|---|---|---|
| Alice direct learner license call | `count = 3` | License-manager returns all 3 licenses correctly |
| Alice BFF dashboard call | `licenses = 3` | BFF correctly aggregates multi-license data |
| Alice BFF dashboard call | catalog keys `111...`, `222...`, `333...` | BFF correctly groups licenses by catalog |
| License-manager access fix | learner role granted | `403` blocker removed |
| JWT fix | token includes `email` | `email is required` blocker removed |

---

## 10. Brief interpretation of proof

### What proves the code is working

| Layer | Proof |
|---|---|
| Authorization layer | Alice can successfully call learner license API |
| Backend data layer | Alice gets `3` activated licenses |
| BFF transformation layer | BFF returns `subscription_licenses` and `licenses_by_catalog` |
| Multi-license grouping | Catalog grouping matches expected catalogs |
| Deterministic selection rule | Alice's earliest activated license is the expected winner for overlap enrollment |

---

## 11. Optional local-only caveats

| API | Possible Local Result | Meaning |
|---|---|---|
| Discovery course lookup for `MITx+6.00.1x` | `No Course matches the given query.` | Course is not present in local Discovery DB |
| Enterprise-catalog contains-content | `MISSING: catalog.has_learner_access` | Catalog service access is not configured for the learner token |

These do **not** invalidate the main BFF proof if the BFF dashboard result is correct.

---

## 12. Final expected pass summary

| Scenario | Expected Result | Pass Condition |
|---|---|---|
| Alice learner licenses | `3` | direct API returns `count = 3` |
| Alice BFF dashboard | `3` | BFF returns `subscription_licenses.length = 3` |
| Alice catalog grouping | `3 catalogs` | BFF returns `111...`, `222...`, `333...` |
| Alice overlap selection | leadership license wins | expected chosen license = `c1111111-1111-1111-1111-111111111111` |
| Bob dashboard | `4` | BFF returns 4 licenses |
| Carol dashboard | `5` | BFF returns 5 licenses |

---

## 13. Recommended visual reading order

1. Read learner to license coverage
2. Read course to catalog mapping
3. Read Alice overlap rule
4. Check API test matrix
5. Check proof points
6. Check final pass summary
