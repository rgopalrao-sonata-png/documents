# feat: Multi-License Subscription Support for Enterprise BFF

## Tickets

- **ENT-11683** – Backend: Multi-license subscription support (preserve all active licenses per learner)
- **ENT-11685** – API response structure + comprehensive test coverage for multi-license scenarios
- **ENT-11672** – Business rule: first-activated license wins when a course appears in multiple catalogs

---

## Problem We Resolved

### Before This Change

The BFF (Backend for Frontend) returned only **one** `subscription_license` per learner. The selection
strategy was "latest expiration date wins", which caused two problems:

1. **Wrong license selected**: For a learner like Alice who holds three licenses (Leadership, Compliance,
   Data Science) across separate catalog UUIDs, the backend incorrectly selected the _Compliance_ license
   (357 days remaining) instead of the _Leadership_ license that was activated first.

2. **No catalog-to-license mapping**: Consumers had no way to determine which license applied to a given
   catalog/course, forcing them to guess or implement their own resolution logic.

3. **Incorrect Algolia key scoping**: The secured Algolia key was scoped to a single catalog query UUID,
   so learners with licenses in multiple catalogs could only search content from one catalog.

### After This Change

- All active licenses are preserved in the `subscription_licenses` array.
- A new `licenses_by_catalog` dictionary maps each catalog UUID to its corresponding license — enabling
  O(1) per-catalog lookups for frontend consumers.
- `license_schema_version: "v2"` signals the new response format to API consumers.
- `subscription_license` (singular, backward-compat) now selects by **first activation date ASC** — the
  learner's earliest-activated license wins (ENT-11672 business rule).
- Algolia key scoping now covers **all** catalog UUIDs from all active licenses.
- A WaffleFlag controls the rollout — when OFF, the v1 legacy response is returned unchanged.

---

## API Response Changes

### Feature Flag

```
enterprise_access.enable_multi_license_entitlements_bff
```

Namespace: `enterprise_access` | Type: `WaffleFlag`

When **OFF** → `license_schema_version: "v1"`, no `licenses_by_catalog`, single-license behavior.  
When **ON** → `license_schema_version: "v2"`, `licenses_by_catalog` dict included, first-activated selection.

---

### Old Response (flag OFF / v1)

```json
{
  "subscription_license": {
    "uuid": "cccccccc-...",            // Compliance license (latest expiry — WRONG)
    "status": "activated",
    "subscription_plan": {
      "title": "Compliance Catalog Plan",
      "enterprise_catalog_uuid": "cat-compliance-uuid",
      "is_current": true
    }
  },
  "subscription_licenses": [
    { "uuid": "aaaa...", "status": "activated", ... },  // Leadership
    { "uuid": "bbbb...", "status": "activated", ... },  // Data Science
    { "uuid": "cccc...", "status": "activated", ... }   // Compliance
  ]
  // NO licenses_by_catalog
  // NO license_schema_version
}
```

### New Response (flag ON / v2)

```json
{
  "license_schema_version": "v2",
  "subscription_license": {
    "uuid": "aaaa...",          // Leadership license (first-activated — CORRECT)
    "status": "activated",
    "activated_at": "2024-01-15T00:00:00Z",
    "subscription_plan": {
      "title": "Leadership Catalog Plan",
      "enterprise_catalog_uuid": "cat-leadership-uuid",
      "is_current": true
    }
  },
  "subscription_licenses": [
    { "uuid": "aaaa...", "status": "activated", ... },  // Leadership
    { "uuid": "bbbb...", "status": "activated", ... },  // Data Science
    { "uuid": "cccc...", "status": "activated", ... }   // Compliance
  ],
  "licenses_by_catalog": {
    "cat-leadership-uuid": { "uuid": "aaaa...", "status": "activated", ... },
    "cat-datascience-uuid": { "uuid": "bbbb...", "status": "activated", ... },
    "cat-compliance-uuid": { "uuid": "cccc...", "status": "activated", ... }
  }
}
```

---

## Code Changes

### Modified Files

| File | Change |
|------|--------|
| `enterprise_access/apps/bffs/handlers.py` | Updated `transform_subscriptions_result()` to build `licenses_by_catalog` and apply first-activated selection rule when flag is ON; updated `_scope_secured_algolia_by_flag()` to scope across all catalog UUIDs |
| `enterprise_access/apps/bffs/serializers.py` | Added `license_schema_version` (CharField) and `licenses_by_catalog` (DictField) to `LearnerDashboardBFFResponseSerializer` |
| `enterprise_access/apps/bffs/context.py` | Updated BFF context to pass feature flag state through to handler methods |
| `enterprise_access/toggles.py` | Added `ENABLE_MULTI_LICENSE_ENTITLEMENTS_BFF` WaffleFlag definition |

### New Test Files

| File | Purpose |
|------|---------|
| `enterprise_access/apps/bffs/tests/test_multi_license.py` | Dedicated multi-license test suite (all scenarios below) |
| `enterprise_access/tests/test_toggles.py` | WaffleFlag unit tests (flag ON / flag OFF) |

### Changed Test Files

| File | Change |
|------|---------|
| `enterprise_access/apps/bffs/tests/test_handlers.py` | Added `_subscriptions_result` helper; updated `TestScopeSecuredAlgoliaByFlag` to cover multi-catalog scoping |
| `enterprise_access/apps/api_client/tests/test_enterprise_catalog_client.py` | Updated assertions for multi-catalog client calls |

---

## Test Cases Covered

### `test_multi_license.py` — `TestTransformSubscriptionsResult`

| Test | Description |
|------|-------------|
| `test_flag_off_returns_v1_response` | When flag is OFF, response contains no `licenses_by_catalog`, no `license_schema_version: "v2"` |
| `test_flag_on_single_license` | Single license — v2 response, `licenses_by_catalog` has exactly one entry |
| `test_flag_on_alice_three_licenses` | Alice (3 active licenses) — Leadership (activated 2024-01-15) is selected, not Compliance |
| `test_flag_on_bob_four_licenses` | Bob (4 licenses: 2 activated, 1 assigned, 1 revoked) — only activated in `licenses_by_catalog` |
| `test_flag_on_carol_five_licenses` | Carol (5 licenses across 5 catalogs) — all 5 appear in `licenses_by_catalog` |
| `test_flag_on_dave_activation_flow` | Dave (1 activated + 2 assigned) — assigned licenses auto-activate, `licenses_by_catalog` reflects final state |
| `test_flag_on_eve_tiebreaker` | Eve (2 licenses with same activation timestamp) — stable tiebreaker (e.g., UUID sort) applied |
| `test_no_licenses` | Learner with no licenses — empty response, no errors |

### `test_multi_license.py` — `TestScopeSecuredAlgoliaByFlag`

| Test | Description |
|------|-------------|
| `test_flag_off_uses_single_catalog` | Flag OFF — Algolia key scoped to single catalog UUID (legacy) |
| `test_flag_on_scopes_all_catalogs` | Flag ON — Algolia key scoped across all catalog UUIDs from all active licenses |
| `test_no_licenses_no_algolia_scope` | No licenses — Algolia scoping skipped gracefully |

### `test_toggles.py`

| Test | Description |
|------|-------------|
| `test_flag_is_off_by_default` | WaffleFlag `enable_multi_license_entitlements_bff` is disabled by default |
| `test_flag_can_be_enabled` | WaffleFlag can be enabled and handlers respond correctly |

### `test_handlers.py` (updated)

| Test | Description |
|------|-------------|
| `test_scope_secured_algolia_single_license` | Single license — Algolia scoped to its catalog UUID |
| `test_scope_secured_algolia_multi_license` | Multi-license — Algolia scoped to all catalog UUIDs |

---

## Test Learner Profiles (from `test-data/`)

| User | Licenses | Notes |
|------|----------|-------|
| **Alice** (`test-multi-alice@example.com`) | 3 activated (Leadership, Data Science, Compliance) | Primary test persona; Leadership activated first (2024-01-15) |
| **Bob** (`test-multi-bob@example.com`) | 4 total (2 activated, 1 assigned, 1 revoked) | Tests status filtering |
| **Carol** (`test-multi-carol@example.com`) | 5 activated across 5 catalogs | Tests large license counts |
| **Dave** (`test-multi-dave@example.com`) | 1 activated + 2 assigned | Tests auto-activation flow |
| **Eve** (`test-multi-eve@example.com`) | 3 licenses with same activation timestamp | Tests tiebreaker stability |

---

## Acceptance Criteria Checklist

### ENT-11683

- [x] Backend preserves all active subscription licenses for a learner
- [x] When flag is ON, backend identifies correct license per catalog context
- [x] When flag is OFF, legacy single-license behavior is preserved
- [x] Graceful handling when no matching license exists
- [x] Consistent selection rule implemented (first activation date ASC)
- [x] Feature flag defined and documented

### ENT-11685

- [x] API response includes all applicable licenses when flag is ON (`license_schema_version: "v2"`)
- [x] Response structure backward-compatible for existing consumers (`subscription_license` singular preserved)
- [x] Legacy single-license format preserved when flag is OFF
- [x] Single-license regression covered
- [x] Multiple licenses across different catalogs covered
- [x] No matching license scenario covered
- [x] Feature flag ON/OFF behavior tested
- [x] All tests pass

---

## Rollout Plan

1. Deploy code with flag **OFF** — zero behavioral change for all learners.
2. Enable flag for internal QA environments, verify `v2` response shape.
3. Gradually enable for production groups via Waffle.
4. Monitor for regressions using existing `subscription_license` field (unchanged value for single-license learners).

---

## Notes

- `subscription_license` (singular) is preserved in both v1 and v2 for backward compatibility.
- In v1, `subscription_license` selects by **latest expiry** (existing behavior).
- In v2, `subscription_license` selects by **earliest activation date** (ENT-11672 business rule).
- `licenses_by_catalog` contains only **activated** licenses — assigned/revoked licenses are excluded.
- Algolia multi-catalog scoping is gated by the same flag.
