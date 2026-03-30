# 0010. Multiplex Subscription Licenses — Technical Architecture

| Field | Value |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-03-30 |
| **Version** | 1.0 |
| **Author** | Architecture Team |
| **Scope** | `enterprise-access` · `enterprise-catalog` · `frontend-app-learner-portal-enterprise` |

---

## Table of Contents

1. [Context and Problem Statement](#1-context-and-problem-statement)
2. [Root Cause Analysis](#2-root-cause-analysis)
3. [Architectural Principles](#3-architectural-principles)
4. [Decision](#4-decision)
5. [System Transformation Overview](#5-system-transformation-overview)
6. [Detailed Component Design](#6-detailed-component-design)
7. [Feature Flags and Rollout Strategy](#7-feature-flags-and-rollout-strategy)
8. [Open edX Events Integration](#8-open-edx-events-integration)
9. [Deterministic License Selection Algorithm](#9-deterministic-license-selection-algorithm)
10. [Test Data Builders](#10-test-data-builders)
11. [Test Implementations](#11-test-implementations)
12. [Test Scenarios Reference](#12-test-scenarios-reference)
13. [Alternatives Considered](#13-alternatives-considered)
14. [Consequences](#14-consequences)
15. [Migration Plan](#15-migration-plan)

---

## 1. Context and Problem Statement

The enterprise platform is required to support **multiple concurrent subscription licenses per learner**. A learner may hold more than one active subscription simultaneously, across:

- different enterprise customers,
- different enterprise catalogs,
- different subscription plans with distinct expiration timelines,
- different assignment and activation timestamps.

### The Core Problem

The BFF layer in `enterprise_access/apps/bffs/handlers.py` collapses multiple licenses to a **single one** at four architectural bottlenecks. The fix requires a **collection-first approach**: preserve all licenses until course-level context can make the correct match.

> **Root cause:** License selection happens too early (in the data layer), losing information needed for downstream decisions.
>
> **Fix:** Defer selection to course context. Pass the full collection through every layer.

### Business Drivers

| Driver | Impact |
|---|---|
| Learner enrolled in multiple enterprise programs | Must access all catalogs simultaneously |
| Enterprise with multiple subscription plans | Different courses may fall under different plans |
| License expiry staggering | Learners need the longest valid window per course |
| Audit and reporting | Full license history required per enrollment event |
| Knotion use case | Learner has 3 licenses across 3 separate catalogs |

---

## 2. Root Cause Analysis

The four bottlenecks in `handlers.py` where information is lost today:

### Bottleneck 1 — Data Transformation Layer (line ~262)

```python
# ❌ CURRENT: Returns FIRST license only — all others are discarded
def _extract_subscription_license(self, subscription_licenses_by_status):
    return next((
        license
        for status in [ACTIVATED, ASSIGNED, REVOKED]
        for license in subscription_licenses_by_status.get(status, [])
    ), None)
```

### Bottleneck 2 — Enrollment Intention Handler

```python
# ❌ CURRENT: Uses single self.current_activated_license for ALL courses
if not self.current_activated_license:
    return

for enrollment_intention in needs_enrollment_enrollable:
    subscription_catalog = self.current_activated_license.get(
        'subscription_plan', {}
    ).get('enterprise_catalog_uuid')

    if subscription_catalog in applicable_catalogs:
        license_uuids_by_course[course_run_key] = self.current_activated_license['uuid']
```

### Bottleneck 3 — MFE Data Service Layer

```javascript
// ❌ CURRENT: Extract first license only — collection is discarded
const applicableSubscriptionLicense = Object.values(
  subscriptionLicensesByStatus
).flat()[0];

subscriptionsData.subscriptionLicense = applicableSubscriptionLicense;
```

### Bottleneck 4 — MFE Course Subsidy Hook

```javascript
// ❌ CURRENT: Checks only a single license
export function determineSubscriptionLicenseApplicable(subscriptionLicense, catalogsWithCourse) {
  return (
    subscriptionLicense?.status === LICENSE_STATUS.ACTIVATED
    && subscriptionLicense?.subscriptionPlan.isCurrent
    && catalogsWithCourse.includes(subscriptionLicense?.subscriptionPlan.enterpriseCatalogUuid)
  );
}
```

---

## 3. Architectural Principles

### Principle 1 — Collection-First Design

Pass the full collection of licenses through every layer. Do not select early.

```python
# ❌ BAD: Early selection loses information
def get_user_license(user_id):
    licenses = fetch_all_licenses(user_id)
    return licenses[0]  # Information loss!

# ✅ GOOD: Preserve collection, defer selection
def get_user_licenses(user_id):
    return fetch_all_licenses(user_id)  # Complete data

def get_applicable_license_for_course(licenses, course_id):
    return find_best_match(licenses, course_id)  # Context-aware selection
```

### Principle 2 — Single Responsibility Per Layer

| Layer | Responsibility |
|---|---|
| **License Manager** | Persist and return license records — no selection logic |
| **BFF** | Fetch, transform, enrich data for frontend — no early selection |
| **MFE** | Display data, handle user interaction — select at course context |
| **Business Logic** | Determine applicability rules — separate and fully testable |

### Principle 3 — Fail-Safe Defaults

```
Feature flag OFF → legacy single-license behavior (safe and unchanged)
Feature flag ON  → new multi-license behavior
Flag read error  → defaults to OFF (safe)
```

### Principle 4 — Key Design Decisions

| Decision | Rationale |
|---|---|
| Collection-first contract | Prevents information loss; enables downstream flexibility |
| Deterministic selection algorithm | Predictable, reproducible, debuggable |
| Feature flags at BFF + MFE independently | Independent rollout; quick rollback per layer |
| Backward-compatible schema | Zero disruption to existing integrations |
| Per-course license matching | Correct entitlements; honors catalog boundaries |
| No License Manager changes | Minimal blast radius; faster delivery |

---

## 4. Decision

We will fix the four bottlenecks using a **collection-first architecture**:

1. The BFF preserves all licenses and passes a full collection plus a pre-computed catalog index to the MFE.
2. The MFE defers license selection to course context, selecting the best matching license per course.
3. All changes are gated behind feature flags for safe, independent rollout.
4. All existing single-license behavior is preserved when flags are off.
5. No changes are required in the License Manager service.

---

## 5. System Transformation Overview

### Before — Single License (Current State)

```
License Manager
  └─ Returns: { results: [lic1, lic2, lic3] }

BFF handlers.py (Bottleneck #1 + #2)
  └─ Collapses to: single_license = lic1   ← WRONG

BFF Response
  └─ { subscription_license: lic1 }        ← Other licenses lost

MFE (Bottleneck #3 + #4)
  └─ applicableSubscriptionLicense = lic1  ← Same wrong license for ALL courses

Course A (cat-A)  →  lic1  ✅ (coincidentally correct)
Course B (cat-B)  →  lic1  ❌ (wrong — should be lic2)
Course C (cat-C)  →  lic1  ❌ (wrong — should be lic3)
```

### After — Collection-First (Proposed State)

```
License Manager
  └─ Returns: { results: [lic1, lic2, lic3] }   (unchanged)

BFF handlers.py (Fixed)
  └─ Preserves all: subscription_licenses = [lic1, lic2, lic3]
  └─ Builds index:  licenses_by_catalog = { cat-A: [lic1], cat-B: [lic2], cat-C: [lic3] }

BFF Response
  └─ { subscription_licenses: [...], licenses_by_catalog: {...} }

MFE (Fixed)
  └─ Per-course selection using catalog context

Course A (cat-A)  →  lic1  ✅ (correctly matched)
Course B (cat-B)  →  lic2  ✅ (correctly matched)
Course C (cat-C)  →  lic3  ✅ (correctly matched)
```

---

## 6. Detailed Component Design

### Component 1 — License Manager (No Changes)

**Status:** ✅ Already works correctly — returns ALL licenses.

The License Manager API contract is unchanged and already returns the full collection:

```json
{
  "count": 3,
  "results": [
    {
      "uuid": "license-uuid",
      "status": "activated|assigned|revoked",
      "activation_date": "ISO-8601",
      "subscription_plan": {
        "uuid": "plan-uuid",
        "enterprise_catalog_uuid": "catalog-uuid",
        "is_current": true,
        "expiration_date": "YYYY-MM-DD"
      }
    }
  ]
}
```

No changes are required in this service.

---

### Component 2 — Enterprise Access BFF

**File:** `enterprise_access/apps/bffs/handlers.py`

#### 2.1 Data Transformation Layer

```python
class SubscriptionLicenseProcessor:
    """
    Handles subscription license data transformation.
    Preserves collection semantics while maintaining backward compatibility.
    """

    def transform_licenses(self, subscription_licenses_by_status, feature_flag_enabled=False):
        """
        Transform license data with collection-first approach.

        Args:
            subscription_licenses_by_status (Dict[str, List]): Licenses grouped by status.
            feature_flag_enabled (bool): ENABLE_MULTI_LICENSE_ENTITLEMENTS_BFF flag state.

        Returns:
            Dict with collection fields (new) and singular fields (deprecated).
        """
        activated_licenses = subscription_licenses_by_status.get(
            LicenseStatuses.ACTIVATED, []
        )

        # Sort: current plans first, then by latest expiration date
        sorted_activated = sorted(
            activated_licenses,
            key=lambda lic: (
                not lic.get('subscription_plan', {}).get('is_current', False),
                lic.get('subscription_plan', {}).get('expiration_date', '')
            )
        )

        return {
            # ✅ NEW: Canonical collection field
            'subscription_licenses': sorted_activated,
            'subscription_licenses_by_status': subscription_licenses_by_status,

            # ✅ NEW: Pre-computed catalog index for O(1) lookups
            'licenses_by_catalog': (
                self._index_by_catalog(sorted_activated) if feature_flag_enabled else None
            ),

            # ⚠️  DEPRECATED: Kept for backward compatibility (remove after migration)
            'subscription_license': sorted_activated[0] if sorted_activated else None,
            'subscription_plan': (
                sorted_activated[0].get('subscription_plan') if sorted_activated else None
            ),

            # ✅ NEW: Schema version for client compatibility detection
            'license_schema_version': 'v2' if feature_flag_enabled else 'v1',
        }

    def _index_by_catalog(self, licenses):
        """Create catalog UUID → licenses mapping for O(1) lookups."""
        catalog_index = {}
        for license in licenses:
            catalog_uuid = license.get('subscription_plan', {}).get('enterprise_catalog_uuid')
            if catalog_uuid:
                catalog_index.setdefault(catalog_uuid, []).append(license)
        return catalog_index
```

#### 2.2 Enrollment Intention Handler

```python
def _map_courses_to_licenses(self, enrollment_intentions):
    """
    ✅ NEW: Map each course to its best-matching license.

    Algorithm:
        1. For each course, find ALL licenses whose catalog contains the course.
        2. If multiple match, apply deterministic tie-breaker:
           a. Latest expiration_date  (maximize access window)
           b. Most recent activation_date  (prefer newer)
           c. UUID lexical order DESC  (stable deterministic fallback)

    Returns:
        Dict[str, str] — course_run_key → license_uuid
    """
    activated_licenses = self._get_current_activated_licenses()
    if not activated_licenses:
        logger.info("No activated licenses found for multi-license enrollment")
        return {}

    licenses_by_catalog = self._build_catalog_index(activated_licenses)
    license_course_mappings = {}

    for intention in enrollment_intentions:
        course_run_key = intention['course_run_key']
        applicable_catalogs = intention.get('applicable_enterprise_catalog_uuids', [])

        matching_licenses = []
        for catalog_uuid in applicable_catalogs:
            matching_licenses.extend(licenses_by_catalog.get(catalog_uuid, []))

        if not matching_licenses:
            logger.debug(
                "No license found for course %s (searched catalogs: %s)",
                course_run_key, applicable_catalogs
            )
            continue

        best_license = self._select_best_license(matching_licenses)
        license_course_mappings[course_run_key] = best_license['uuid']
        logger.info(
            "Mapped course %s → license %s (catalog: %s, expiration: %s)",
            course_run_key,
            best_license['uuid'],
            best_license['subscription_plan']['enterprise_catalog_uuid'],
            best_license['subscription_plan']['expiration_date'],
        )

    return license_course_mappings


def _select_best_license(self, licenses):
    """
    Deterministic tie-breaker for multiple matching licenses.

    Precedence:
        1. Latest expiration_date  (longest access window)
        2. Most recent activation_date  (prefer newer)
        3. UUID DESC  (stable — always reproducible)
    """
    if len(licenses) == 1:
        return licenses[0]

    return max(
        licenses,
        key=lambda lic: (
            lic.get('subscription_plan', {}).get('expiration_date', ''),
            lic.get('activation_date', ''),
            lic.get('uuid', ''),
        )
    )


def _build_catalog_index(self, licenses):
    """Build catalog_uuid → licenses mapping for efficient O(1) lookup."""
    index = {}
    for license in licenses:
        catalog_uuid = license.get('subscription_plan', {}).get('enterprise_catalog_uuid')
        if catalog_uuid:
            index.setdefault(catalog_uuid, []).append(license)
    return index


def _map_courses_to_single_license(self, enrollment_intentions):
    """⚠️  LEGACY: Backward-compatible single-license mapping. Do not extend."""
    current_license = self.current_activated_license
    if not current_license:
        return {}
    subscription_catalog = current_license.get(
        'subscription_plan', {}
    ).get('enterprise_catalog_uuid')
    mappings = {}
    for intention in enrollment_intentions:
        applicable_catalogs = intention.get('applicable_enterprise_catalog_uuids', [])
        if subscription_catalog in applicable_catalogs:
            mappings[intention['course_run_key']] = current_license['uuid']
    return mappings
```

#### 2.3 BFF Response Serializer

**File:** `enterprise_access/apps/bffs/serializers.py`

```python
class SubscriptionsSerializer(BaseBffSerializer):
    """
    Serializer for subscription subsidies.
    Extends existing serializer with multi-license fields.
    """

    customer_agreement = CustomerAgreementSerializer(required=False, allow_null=True)

    # ✅ NEW: Canonical collection fields
    subscription_licenses = SubscriptionLicenseSerializer(many=True, required=False, default=list)
    subscription_licenses_by_status = SubscriptionLicenseStatusSerializer(required=False)

    # ✅ NEW: Pre-computed catalog index (populated when feature flag is ON)
    licenses_by_catalog = serializers.DictField(
        child=serializers.ListField(child=SubscriptionLicenseSerializer()),
        required=False,
        allow_null=True,
        help_text="Pre-computed catalog_uuid → licenses mapping for O(1) lookups.",
    )

    # ✅ NEW: Schema version indicator for client compatibility
    license_schema_version = serializers.CharField(
        required=False,
        default='v1',
        help_text="'v1' = single-license (legacy), 'v2' = multi-license.",
    )

    # ⚠️  DEPRECATED: Keep for backward compatibility only — remove after migration
    subscription_license = SubscriptionLicenseSerializer(required=False, allow_null=True)
    subscription_plan = SubscriptionPlanSerializer(required=False, allow_null=True)

    show_expiration_notifications = serializers.BooleanField(required=False, default=False)
```

---

### Component 3 — Learner Portal MFE

#### 3.1 Data Service Layer

**File:** `src/data/services/userSubsidy.js`

```javascript
/**
 * Transform subscription license data with collection-first approach.
 *
 * @param {SubscriptionLicense[]} subscriptionLicenses
 * @param {CustomerAgreement} customerAgreement
 * @param {string} licenseSchemaVersion - 'v1' (legacy) or 'v2' (multi-license)
 * @returns {Object} Transformed subscription data
 */
export function transformSubscriptionsData({
  subscriptionLicenses,
  customerAgreement,
  licenseSchemaVersion = 'v1',
}) {
  const subscriptionsData = { ...getBaseSubscriptionsData() };

  if (subscriptionLicenses) {
    subscriptionsData.subscriptionLicenses = subscriptionLicenses;
  }
  if (customerAgreement) {
    subscriptionsData.customerAgreement = customerAgreement;
  }

  subscriptionsData.showExpirationNotifications = !(
    customerAgreement?.disableExpirationNotifications
    || customerAgreement?.hasCustomLicenseExpirationMessagingV2
  );

  // Sort: current plans first, then latest expiration date
  subscriptionsData.subscriptionLicenses = [...subscriptionLicenses].sort((a, b) => {
    if (a.subscriptionPlan.isCurrent !== b.subscriptionPlan.isCurrent) {
      return a.subscriptionPlan.isCurrent ? -1 : 1;
    }
    return (
      new Date(b.subscriptionPlan.expirationDate)
      - new Date(a.subscriptionPlan.expirationDate)
    );
  });

  // Group by status
  subscriptionsData.subscriptionLicenses.forEach((license) => {
    if (license.status !== LICENSE_STATUS.UNASSIGNED) {
      subscriptionsData.subscriptionLicensesByStatus = addLicenseToSubscriptionLicensesByStatus({
        subscriptionLicensesByStatus: subscriptionsData.subscriptionLicensesByStatus,
        subscriptionLicense: license,
      });
    }
  });

  // ✅ NEW: Build catalog index for O(1) lookups
  subscriptionsData.licensesByCatalog = buildCatalogIndex(subscriptionsData.subscriptionLicenses);

  // ✅ NEW: Store schema version for downstream decision-making
  subscriptionsData.licenseSchemaVersion = licenseSchemaVersion;

  // ⚠️  BACKWARD COMPAT: Keep singular field for legacy consumers
  const legacyLicense = Object.values(subscriptionsData.subscriptionLicensesByStatus).flat()[0];
  if (legacyLicense) {
    subscriptionsData.subscriptionLicense = legacyLicense;
    subscriptionsData.subscriptionPlan = legacyLicense.subscriptionPlan;
  }

  return subscriptionsData;
}

/**
 * Build catalog UUID → activated-and-current licenses index.
 */
function buildCatalogIndex(licenses) {
  const index = {};
  licenses.forEach((license) => {
    if (license.status !== LICENSE_STATUS.ACTIVATED) return;
    if (!license.subscriptionPlan?.isCurrent) return;
    const catalogUuid = license.subscriptionPlan.enterpriseCatalogUuid;
    if (!catalogUuid) return;
    if (!index[catalogUuid]) index[catalogUuid] = [];
    index[catalogUuid].push(license);
  });
  return index;
}
```

#### 3.2 License Matching Utilities

**File:** `src/utils/licenses.js`

```javascript
/**
 * Filter all licenses applicable to a specific course.
 *
 * @param {SubscriptionLicense[]} subscriptionLicenses
 * @param {string[]} catalogsWithCourse - Catalog UUIDs verified to contain this course
 * @returns {SubscriptionLicense[]}
 */
export function getApplicableLicensesForCourse(subscriptionLicenses, catalogsWithCourse) {
  if (!subscriptionLicenses?.length || !catalogsWithCourse?.length) return [];
  return subscriptionLicenses.filter(license => (
    license?.status === LICENSE_STATUS.ACTIVATED
    && license?.subscriptionPlan?.isCurrent === true
    && catalogsWithCourse.includes(license?.subscriptionPlan?.enterpriseCatalogUuid)
  ));
}

/**
 * Select the best license from multiple applicable licenses.
 *
 * Deterministic precedence:
 *   1. Latest expiration_date  (maximize access window)
 *   2. Most recent activation_date  (prefer newer)
 *   3. UUID descending  (stable deterministic fallback)
 *
 * @param {SubscriptionLicense[]} applicableLicenses
 * @returns {SubscriptionLicense|null}
 */
export function selectBestLicense(applicableLicenses) {
  if (!applicableLicenses?.length) return null;
  if (applicableLicenses.length === 1) return applicableLicenses[0];

  return [...applicableLicenses].sort((a, b) => {
    const expDiff = (
      new Date(b.subscriptionPlan.expirationDate)
      - new Date(a.subscriptionPlan.expirationDate)
    );
    if (expDiff !== 0) return expDiff;

    const actDiff = new Date(b.activationDate) - new Date(a.activationDate);
    if (actDiff !== 0) return actDiff;

    return b.uuid.localeCompare(a.uuid);
  })[0];
}

/**
 * @deprecated Use getApplicableLicensesForCourse + selectBestLicense instead.
 *             Kept only for backward compatibility when feature flag is OFF.
 */
export function determineSubscriptionLicenseApplicable(subscriptionLicense, catalogsWithCourse) {
  return (
    subscriptionLicense?.status === LICENSE_STATUS.ACTIVATED
    && subscriptionLicense?.subscriptionPlan.isCurrent
    && catalogsWithCourse.includes(subscriptionLicense?.subscriptionPlan.enterpriseCatalogUuid)
  );
}
```

#### 3.3 Course Subsidy Hook

**File:** `src/components/app/data/hooks/useUserSubsidyApplicableToCourse.js`

```javascript
import { features } from '@edx/frontend-platform';

/**
 * Enhanced hook with multi-license support.
 * Feature flag controls which execution path runs.
 */
const useUserSubsidyApplicableToCourse = () => {
  const { courseKey } = useParams();

  const {
    data: {
      subscriptionLicenses,   // ✅ NEW canonical collection
      subscriptionLicense,    // ⚠️  DEPRECATED singular — legacy path only
      licensesByCatalog,      // ✅ NEW catalog index for O(1) lookup
    },
  } = useSubscriptions();

  const {
    data: { catalogList: catalogsWithCourse },
  } = useEnterpriseCustomerContainsContentSuspense([courseKey]);

  const multiLicenseEnabled = features.ENABLE_MULTI_LICENSE_ENTITLEMENTS;
  let applicableSubscriptionLicense;

  if (multiLicenseEnabled && subscriptionLicenses) {
    // ✅ NEW: Use catalog index (O(1)) if available, else fall back to linear scan
    if (licensesByCatalog && catalogsWithCourse.length > 0) {
      const matchingLicenses = catalogsWithCourse.flatMap(
        catalogUuid => licensesByCatalog[catalogUuid] || []
      );
      applicableSubscriptionLicense = selectBestLicense(matchingLicenses);
    } else {
      applicableSubscriptionLicense = selectBestLicense(
        getApplicableLicensesForCourse(subscriptionLicenses, catalogsWithCourse)
      );
    }

    if (applicableSubscriptionLicense) {
      logInfo('Multi-license selection', {
        courseKey,
        selectedLicenseUuid: applicableSubscriptionLicense.uuid,
        selectedCatalog: applicableSubscriptionLicense.subscriptionPlan.enterpriseCatalogUuid,
        totalLicenses: subscriptionLicenses.length,
        applicableCatalogs: catalogsWithCourse,
      });
    }
  } else {
    // ⚠️  LEGACY path — unchanged behavior when flag is OFF
    const isApplicable = determineSubscriptionLicenseApplicable(
      subscriptionLicense, catalogsWithCourse
    );
    applicableSubscriptionLicense = isApplicable ? subscriptionLicense : null;
  }

  const userSubsidyApplicableToCourse = getSubsidyToApplyForCourse({
    applicableSubscriptionLicense,
    // ... other subsidies (coupons, enterprise offers, learner credit)
  });

  return { userSubsidyApplicableToCourse };
};

export default useUserSubsidyApplicableToCourse;
```

---

## 7. Feature Flags and Rollout Strategy

Two independent feature flags allow BFF and MFE to be enabled separately.

### Backend — Waffle Flag

**File:** `enterprise_access/enterprise_access/apps/bffs/handlers.py`

```python
import waffle

feature_flag_enabled = waffle.flag_is_active(
    request, 'ENABLE_MULTI_LICENSE_ENTITLEMENTS_BFF'
)

if feature_flag_enabled:
    license_course_mappings = self._map_courses_to_licenses(needs_enrollment_enrollable)
else:
    license_course_mappings = self._map_courses_to_single_license(needs_enrollment_enrollable)
```

### Frontend — Environment Config

```javascript
// frontend-app-learner-portal-enterprise/env.config.js
module.exports = {
  FEATURE_FLAGS: {
    ENABLE_MULTI_LICENSE_ENTITLEMENTS: false,  // set true to enable MFE path
  },
};
```

### Flag Combination Matrix

| BFF Flag | MFE Flag | Behavior |
|---|---|---|
| OFF | OFF | Full legacy single-license behavior — zero risk |
| ON | OFF | BFF sends multi-license data; MFE still uses first license |
| ON | ON | Full multi-license end-to-end — recommended production state |
| OFF | ON | MFE multi-logic runs but falls back to single license |

---

## 8. Open edX Events Integration

Beyond fixing the BFF bottlenecks, the multiplex subscription model should also be reflected in the **Open edX Events** layer. This enables downstream consumers (reporting, analytics, audit) to receive subscription lifecycle changes without tight service coupling.

### Event Naming Convention

Following Open edX event naming conventions:

```
{reverse-dns-name}.{author-service}.{entity}.{action}.{version}

org.openedx.enterprise.subscription.activated.v1
org.openedx.enterprise.subscription.assigned.v1
org.openedx.enterprise.subscription.updated.v1
org.openedx.enterprise.subscription.expired.v1
org.openedx.enterprise.subscription.revoked.v1
```

### Event Data Schema

```python
# openedx_events/enterprise/data.py

@attr.s(auto_attribs=True)
class SubscriptionLicenseData:
    """
    Payload for a single subscription license lifecycle event.
    One event = one business fact for one subscription.
    """
    subscription_uuid: str = attr.ib()
    subscription_plan_uuid: str = attr.ib()
    enterprise_customer_uuid: str = attr.ib()
    enterprise_catalog_uuid: str = attr.ib()
    learner_uuid: str = attr.ib()
    status: str = attr.ib()
    start_date: str = attr.ib()
    expiration_date: str = attr.ib()
    is_current: bool = attr.ib()
    activation_date: Optional[str] = attr.ib(default=None)
    change_reason: Optional[str] = attr.ib(default=None)
    previous_status: Optional[str] = attr.ib(default=None)
```

### Topic Strategy

Multiple subscription lifecycle events share a single bounded-context topic:

```
enterprise.subscription.lifecycle
```

This aligns with the Open edX ADR: [Multiple event types per topic](https://docs.openedx.org/projects/openedx-events/en/latest/).

### Event Example Payload

```json
{
  "event_id": "8b43e9d2-5d2c-4a5d-a0d2-3c65f7e31c8a",
  "occurred_at": "2026-03-30T12:00:00Z",
  "subscription_uuid": "sub-abc-123",
  "subscription_plan_uuid": "plan-def-456",
  "enterprise_customer_uuid": "ent-789",
  "enterprise_catalog_uuid": "cat-321",
  "learner_uuid": "learner-654",
  "status": "activated",
  "start_date": "2026-03-01T00:00:00Z",
  "expiration_date": "2026-12-31T23:59:59Z",
  "is_current": true,
  "change_reason": "learner_activation",
  "previous_status": "assigned"
}
```

### PII Guidelines

| ✅ Use | ❌ Avoid |
|---|---|
| `learner_uuid` | Email address |
| `enterprise_customer_uuid` | Full name |
| `subscription_uuid` | Username |
| `enterprise_catalog_uuid` | Any other personal attributes |

---

## 9. Deterministic License Selection Algorithm

When multiple licenses match a course, the algorithm for selecting the best one:

```
Given: list of matching licenses for a course

Sort by:
  1. expiration_date DESC     → maximize access window for the learner
  2. activation_date DESC     → prefer more recently activated license
  3. uuid DESC                → stable lexical sort as final tiebreaker

Return: first element of sorted list
```

**Properties of this algorithm:**
- **Deterministic** — same inputs always produce the same output
- **Reproducible** — can be replayed for audit or debugging
- **Tie-safe** — UUID fallback guarantees a unique winner every time
- **Input-order independent** — result does not depend on list ordering

---

## 10. Test Data Builders

```python
# enterprise-access/tests/builders.py
import uuid
from django.utils import timezone
from enterprise_access.apps.api_client.constants import LicenseStatuses


class LicenseBuilder:
    """Builder pattern for test license construction."""

    def __init__(self):
        self.uuid = uuid.uuid4()
        self.status = LicenseStatuses.ACTIVATED
        self.catalog_uuid = uuid.uuid4()
        self.expiration_date = '2025-12-31'
        self.activation_date = timezone.now()

    def with_status(self, status):
        self.status = status
        return self

    def with_catalog(self, catalog_uuid):
        self.catalog_uuid = catalog_uuid
        return self

    def with_expiration(self, date):
        self.expiration_date = date
        return self

    def build(self):
        return {
            'uuid': str(self.uuid),
            'status': self.status,
            'activation_date': self.activation_date.isoformat(),
            'subscription_plan': {
                'uuid': str(uuid.uuid4()),
                'enterprise_catalog_uuid': str(self.catalog_uuid),
                'is_current': True,
                'expiration_date': self.expiration_date,
            }
        }


class MultiLicenseScenario:
    """Pre-built multi-license test scenarios."""

    @staticmethod
    def knotion_three_pathways():
        """Knotion use case: 3 licenses across 3 separate catalogs."""
        catalog_a, catalog_b, catalog_c = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
        return {
            'licenses': [
                LicenseBuilder().with_catalog(catalog_a).build(),
                LicenseBuilder().with_catalog(catalog_b).build(),
                LicenseBuilder().with_catalog(catalog_c).build(),
            ],
            'catalogs': {
                'catalog_a': catalog_a,
                'catalog_b': catalog_b,
                'catalog_c': catalog_c,
            }
        }

    @staticmethod
    def overlapping_catalogs():
        """2 licenses covering the same catalog — tests tie-breaker logic."""
        shared_catalog = uuid.uuid4()
        return {
            'license_early': (
                LicenseBuilder().with_catalog(shared_catalog).with_expiration('2025-12-31').build()
            ),
            'license_late': (
                LicenseBuilder().with_catalog(shared_catalog).with_expiration('2026-06-30').build()
            ),
            'catalog': shared_catalog,
        }
```

---

## 11. Test Implementations

### Backend Unit Tests

```python
# enterprise-access/tests/test_multi_license.py
from django.test import TestCase
from unittest import mock
from enterprise_access.apps.bffs.handlers import BaseLearnerPortalHandler
from .builders import LicenseBuilder, MultiLicenseScenario


class TestSelectBestLicense(TestCase):

    def _handler(self):
        return BaseLearnerPortalHandler.__new__(BaseLearnerPortalHandler)

    def test_single_license_returned_directly(self):
        licenses = [LicenseBuilder().build()]
        result = self._handler()._select_best_license(licenses)
        self.assertEqual(result['uuid'], licenses[0]['uuid'])

    def test_latest_expiration_wins(self):
        licenses = [
            LicenseBuilder().with_expiration('2025-06-30').build(),
            LicenseBuilder().with_expiration('2025-12-31').build(),
        ]
        result = self._handler()._select_best_license(licenses)
        self.assertEqual(result['subscription_plan']['expiration_date'], '2025-12-31')

    def test_uuid_fallback_is_deterministic(self):
        catalog = 'cat-x'
        lic_a = LicenseBuilder().with_catalog(catalog).with_expiration('2025-12-31').build()
        lic_b = LicenseBuilder().with_catalog(catalog).with_expiration('2025-12-31').build()
        lic_a['activation_date'] = lic_b['activation_date']   # force identical dates

        handler = self._handler()
        r1 = handler._select_best_license([lic_a, lic_b])
        r2 = handler._select_best_license([lic_b, lic_a])
        self.assertEqual(r1['uuid'], r2['uuid'])  # stable regardless of input order


class TestBuildCatalogIndex(TestCase):

    def test_groups_licenses_by_catalog(self):
        cat_a, cat_b = 'cat-a-uuid', 'cat-b-uuid'
        licenses = [
            LicenseBuilder().with_catalog(cat_a).build(),
            LicenseBuilder().with_catalog(cat_a).build(),
            LicenseBuilder().with_catalog(cat_b).build(),
        ]
        handler = BaseLearnerPortalHandler.__new__(BaseLearnerPortalHandler)
        index = handler._build_catalog_index(licenses)
        self.assertEqual(len(index[cat_a]), 2)
        self.assertEqual(len(index[cat_b]), 1)

    def test_license_without_catalog_is_excluded(self):
        license = LicenseBuilder().build()
        license['subscription_plan'].pop('enterprise_catalog_uuid', None)
        handler = BaseLearnerPortalHandler.__new__(BaseLearnerPortalHandler)
        index = handler._build_catalog_index([license])
        self.assertEqual(index, {})


class TestMapCoursesToLicenses(TestCase):

    @mock.patch.object(BaseLearnerPortalHandler, '_get_current_activated_licenses')
    def test_each_course_mapped_to_correct_catalog_license(self, mock_licenses):
        scenario = MultiLicenseScenario.knotion_three_pathways()
        mock_licenses.return_value = scenario['licenses']
        handler = BaseLearnerPortalHandler.__new__(BaseLearnerPortalHandler)

        intentions = [
            {'course_run_key': 'course-A',
             'applicable_enterprise_catalog_uuids': [str(scenario['catalogs']['catalog_a'])]},
            {'course_run_key': 'course-B',
             'applicable_enterprise_catalog_uuids': [str(scenario['catalogs']['catalog_b'])]},
            {'course_run_key': 'course-C',
             'applicable_enterprise_catalog_uuids': [str(scenario['catalogs']['catalog_c'])]},
        ]
        mappings = handler._map_courses_to_licenses(intentions)

        self.assertEqual(len(mappings), 3)
        self.assertEqual(mappings['course-A'], scenario['licenses'][0]['uuid'])
        self.assertEqual(mappings['course-B'], scenario['licenses'][1]['uuid'])
        self.assertEqual(mappings['course-C'], scenario['licenses'][2]['uuid'])

    @mock.patch.object(BaseLearnerPortalHandler, '_get_current_activated_licenses')
    def test_course_with_no_matching_license_is_omitted(self, mock_licenses):
        scenario = MultiLicenseScenario.knotion_three_pathways()
        mock_licenses.return_value = scenario['licenses']
        handler = BaseLearnerPortalHandler.__new__(BaseLearnerPortalHandler)

        intentions = [
            {'course_run_key': 'course-X',
             'applicable_enterprise_catalog_uuids': ['non-existent-catalog-uuid']},
        ]
        self.assertEqual(handler._map_courses_to_licenses(intentions), {})

    @mock.patch.object(BaseLearnerPortalHandler, '_get_current_activated_licenses')
    def test_overlapping_catalogs_picks_latest_expiration(self, mock_licenses):
        scenario = MultiLicenseScenario.overlapping_catalogs()
        mock_licenses.return_value = [scenario['license_early'], scenario['license_late']]
        handler = BaseLearnerPortalHandler.__new__(BaseLearnerPortalHandler)

        intentions = [
            {'course_run_key': 'course-X',
             'applicable_enterprise_catalog_uuids': [str(scenario['catalog'])]},
        ]
        mappings = handler._map_courses_to_licenses(intentions)
        self.assertEqual(mappings['course-X'], scenario['license_late']['uuid'])
```

### Backend Integration Tests

```python
# enterprise-access/tests/test_bff_multi_license_integration.py
import pytest
from unittest import mock
from rest_framework.test import APIClient


@pytest.mark.integration
class TestBFFMultiLicenseIntegration:

    @mock.patch(
        'enterprise_access.apps.bffs.api.get_and_cache_subscription_licenses_for_learner'
    )
    def test_dashboard_returns_collection_fields_when_flag_on(self, mock_licenses, waffle_flag):
        waffle_flag('ENABLE_MULTI_LICENSE_ENTITLEMENTS_BFF', active=True)
        mock_licenses.return_value = {
            'results': [
                LicenseBuilder().with_catalog('cat-a').build(),
                LicenseBuilder().with_catalog('cat-b').build(),
            ],
            'customer_agreement': None,
        }

        client = APIClient()
        response = client.post('/api/v1/bffs/learner/dashboard/', {
            'enterprise_customer_uuid': str(uuid.uuid4()),
        })

        assert response.status_code == 200
        subscriptions = response.json()['enterprise_customer_user_subsidies']['subscriptions']
        assert len(subscriptions['subscription_licenses']) == 2
        assert 'licenses_by_catalog' in subscriptions
        assert subscriptions['license_schema_version'] == 'v2'

    @mock.patch(
        'enterprise_access.apps.bffs.api.get_and_cache_subscription_licenses_for_learner'
    )
    def test_legacy_behavior_preserved_when_flag_off(self, mock_licenses, waffle_flag):
        waffle_flag('ENABLE_MULTI_LICENSE_ENTITLEMENTS_BFF', active=False)
        mock_licenses.return_value = {
            'results': [LicenseBuilder().build()],
            'customer_agreement': None,
        }

        client = APIClient()
        response = client.post('/api/v1/bffs/learner/dashboard/', {
            'enterprise_customer_uuid': str(uuid.uuid4()),
        })

        subscriptions = response.json()['enterprise_customer_user_subsidies']['subscriptions']
        assert subscriptions['license_schema_version'] == 'v1'
        assert subscriptions['licenses_by_catalog'] is None
```

### Frontend Unit Tests

```javascript
// src/utils/licenses.test.js
import { getApplicableLicensesForCourse, selectBestLicense } from './licenses';
import { LICENSE_STATUS } from '../constants';

const activated = (catalogUuid, expiration = '2025-12-31', activationDate = '2024-01-01') => ({
  uuid: `lic-${Math.random()}`,
  status: LICENSE_STATUS.ACTIVATED,
  activationDate,
  subscriptionPlan: { isCurrent: true, enterpriseCatalogUuid: catalogUuid, expirationDate: expiration },
});

describe('getApplicableLicensesForCourse', () => {
  it('returns only activated licenses whose catalog matches', () => {
    const licenses = [
      activated('cat-a'),
      activated('cat-b'),
      { ...activated('cat-c'), status: 'assigned' },  // excluded
    ];
    const result = getApplicableLicensesForCourse(licenses, ['cat-b']);
    expect(result).toHaveLength(1);
    expect(result[0].subscriptionPlan.enterpriseCatalogUuid).toBe('cat-b');
  });

  it('returns empty array when no catalog match exists', () => {
    expect(getApplicableLicensesForCourse([activated('cat-a')], ['cat-z'])).toEqual([]);
  });

  it('returns empty array for empty inputs without throwing', () => {
    expect(getApplicableLicensesForCourse([], ['cat-a'])).toEqual([]);
    expect(getApplicableLicensesForCourse([activated('cat-a')], [])).toEqual([]);
  });
});

describe('selectBestLicense', () => {
  it('returns null for empty input', () => {
    expect(selectBestLicense([])).toBeNull();
  });

  it('selects license with latest expiration', () => {
    const early = activated('cat-a', '2025-06-30');
    const late  = activated('cat-a', '2025-12-31');
    expect(selectBestLicense([early, late]).subscriptionPlan.expirationDate).toBe('2025-12-31');
  });

  it('falls back to most recent activation when expiration ties', () => {
    const older = activated('cat-a', '2025-12-31', '2023-01-01');
    const newer = activated('cat-a', '2025-12-31', '2024-06-01');
    expect(selectBestLicense([older, newer]).activationDate).toBe('2024-06-01');
  });

  it('is deterministic regardless of input order', () => {
    const a = activated('cat-a', '2025-12-31', '2024-01-01');
    const b = activated('cat-a', '2025-12-31', '2024-01-01');
    expect(selectBestLicense([a, b]).uuid).toBe(selectBestLicense([b, a]).uuid);
  });
});
```

---

## 12. Test Scenarios Reference

| Scenario | Licenses | Expected Behavior | Category |
|---|---|---|---|
| Single license (baseline) | 1 activated (cat-A) | Access to cat-A courses only | Regression |
| Three pathways (Knotion) | 3 activated (A, B, C) | Access to all 3 catalogs correctly | Primary use case |
| Overlapping catalogs | 2 activated, same cat-A | Latest expiration selected | Edge case |
| Mixed status | 2 activated, 1 assigned | Assigned auto-activation works | Workflow |
| No matching license | 1 activated (cat-A), view cat-B course | No access returned | Negative |
| Expired license excluded | 2 licenses, 1 expired | Only current license applies | Boundary |
| Flag OFF regression | 3 licenses, flag OFF | Legacy single-license behavior unchanged | Backward compat |
| Empty license list | 0 licenses | No access — no crash | Safety |

---

## 13. Alternatives Considered

### Alternative A — Aggregate "full subscription list" event per change

**Rejected.** Payload grows without bound. Represents a projection, not a fact. Harder to version and replay. Increases coupling between producer and consumers.

### Alternative B — Keep synchronous API queries as primary mechanism

**Rejected as primary model.** Tight runtime coupling. Weaker resilience. Scales poorly with multiple consumers.

### Alternative C — Daily snapshot batch jobs

**Rejected.** Poor freshness. Weak event semantics. Not useful for real-time enrollment or redemption workflows.

---

## 14. Consequences

### Positive

- ✅ Learners with multiple subscriptions receive correct per-course access
- ✅ Legacy single-license behavior fully preserved when flags are off
- ✅ O(1) catalog lookup improves performance over linear scan
- ✅ Deterministic algorithm is debuggable and auditable
- ✅ No changes required in License Manager service
- ✅ Feature flags enable safe, independent, staged rollout
- ✅ Backward-compatible schema minimizes integration risk

### Negative

- ⚠️  Consumers must be updated to handle the new collection fields
- ⚠️  Deprecated singular fields must be tracked and removed after migration
- ⚠️  Additional complexity in the MFE subsidy selection path

---

## 15. Migration Plan

| Phase | Action | Risk |
|---|---|---|
| Phase 1 | Deploy BFF changes with both flags OFF | Zero — no behavior change |
| Phase 2 | Enable BFF flag ON for 1% of traffic | Low — BFF sends extra fields only |
| Phase 3 | Enable MFE flag ON for 1% of traffic | Low — parallel paths tested side by side |
| Phase 4 | Ramp both flags to 100% | Medium — monitor selection outcomes closely |
| Phase 5 | Remove deprecated singular fields after 6 months | Low — after full migration confirmed |

---

## References

- [Draft Multiplex Subscription — Technical Implementation](https://github.com/rgopalrao-sonata-png/documents/blob/main/Draft_multiplex_subscription.md)
- [Open edX Events ADR: Multiple Event Types Per Topic](https://docs.openedx.org/projects/openedx-events/en/latest/)
- [Open edX Events ADR: Event Design Best Practices](https://docs.openedx.org/projects/openedx-events/en/latest/)
- [Open edX Events ADR: Enable Producing to Event Bus via Settings](https://docs.openedx.org/projects/openedx-events/en/latest/)
- [Open edX Events ADR: Outbox Pattern and Production Modes](https://docs.openedx.org/projects/openedx-events/en/latest/)
- `enterprise_access/apps/bffs/handlers.py`
- `frontend-app-learner-portal-enterprise/src/components/app/data/hooks/useUserSubsidyApplicableToCourse.js`


We need an event model that supports **multiplex subscriptions** while preserving clear event semantics.

For the purposes of this decision, **multiplex subscriptions** means:

> A learner may have multiple independently addressable subscription records, each with its own lifecycle, status, catalog association, and expiration.

The architecture must answer this question:

> Should the producer emit one aggregate event containing a learner's full subscription list, or emit subscription-scoped lifecycle events and allow consumers to build their own projections?

## Decision

We will represent multiplex subscriptions using **subscription-scoped lifecycle events**, not a single aggregate event containing all subscriptions for a learner.

### Chosen model

Each event will represent **one business fact for one subscription**.

Recommended event types include:

- `org.openedx.enterprise.subscription.created.v1`
- `org.openedx.enterprise.subscription.assigned.v1`
- `org.openedx.enterprise.subscription.activated.v1`
- `org.openedx.enterprise.subscription.updated.v1`
- `org.openedx.enterprise.subscription.expired.v1`
- `org.openedx.enterprise.subscription.revoked.v1`

Consumers that require a learner-level or enterprise-level view of all subscriptions will build a **materialized read model** by aggregating these events.

## Architectural Rationale

This decision is preferred for the following reasons.

### 1. One event should represent one domain fact

An event should describe a concrete business occurrence, not a periodically reconstructed view of state. A subscription activation event is a fact. A full list of all current subscriptions is a projection.

This keeps event intent clear and easier to govern.

### 2. Multiplicity is handled naturally

If a learner has three subscriptions, the system does not need a special "multiplex" payload shape. It simply emits facts for three distinct `subscription_uuid` values.

This avoids inventing a special aggregate contract for a common domain concept.

### 3. Consumer projections remain independent

Different consumers need different views:

- learner portal needs a learner-facing entitlement summary,
- enterprise reporting needs historical and operational data,
- catalog services need catalog-scoped entitlement applicability,
- enrollment logic needs a best-fit active subscription.

A producer should publish facts. Consumers should own read models.

### 4. Replay and recovery become straightforward

With event-per-subscription lifecycle modeling, a consumer can replay the stream and reconstruct state. This is harder and less reliable when the producer emits large aggregate snapshots.

### 5. Versioning is easier and safer

Small, fact-based events evolve more safely than monolithic payloads. Optional fields can be added with minimal consumer impact. Breaking changes can be isolated to specific event types.

### 6. Payload size and instability are reduced

A full learner subscription list can grow unpredictably and change shape frequently. Single-subscription events remain bounded, understandable, and easier to validate.

## Event Modeling Guidance

### Topic strategy

A single bounded-context topic may carry multiple related subscription lifecycle events, for example:

- `enterprise.subscription.lifecycle`

This follows the Open edX event design principle that related event types may share a topic when they belong to the same domain boundary.

### Common payload fields

Each lifecycle event should include stable identifiers and sufficient context for downstream consumers.

Recommended fields:

- `event_id`
- `occurred_at`
- `subscription_uuid`
- `subscription_plan_uuid`
- `enterprise_customer_uuid`
- `enterprise_catalog_uuid`
- `learner_uuid`
- `status`
- `start_date`
- `expiration_date`
- `is_current`
- `change_reason`
- `producer`

Optional fields where appropriate:

- `previous_status`
- `assignment_uuid`
- `metadata`
- `effective_at`

## Example Event Schema

```json
{
  "event_id": "8b43e9d2-5d2c-4a5d-a0d2-3c65f7e31c8a",
  "occurred_at": "2026-03-30T12:00:00Z",
  "subscription_uuid": "sub-123",
  "subscription_plan_uuid": "plan-456",
  "enterprise_customer_uuid": "ent-789",
  "enterprise_catalog_uuid": "cat-321",
  "learner_uuid": "learner-654",
  "status": "activated",
  "start_date": "2026-03-01T00:00:00Z",
  "expiration_date": "2026-12-31T23:59:59Z",
  "is_current": true,
  "change_reason": "learner_activation",
  "producer": "license-manager"
}
```

## Consumer Projection Model

Consumers should build their own projections from the lifecycle stream.

### Example: learner subscription projection

**Key:**

- `learner_uuid`

**Value:**

- active subscriptions,
- expired subscriptions,
- subscriptions grouped by enterprise catalog,
- subscriptions grouped by enterprise customer,
- preferred subscription for enrollment or redemption.

### Example: catalog applicability projection

A consumer can derive whether a course or catalog is covered by finding subscriptions that satisfy all of the following:

- `status == activated`
- `is_current == true`
- `enterprise_catalog_uuid` matches the course/catalog context

## Ordering, Delivery, and Idempotency

Consumers must assume:

- duplicate event delivery is possible,
- out-of-order delivery is possible,
- replay is possible,
- delayed delivery is possible.

Therefore consumers should:

- deduplicate by `event_id`,
- upsert by `subscription_uuid`,
- compare `occurred_at` or an explicit version before overwriting state,
- make projection updates idempotent.

## PII and Security Guidance

Subscription events should avoid direct PII unless explicitly required and approved.

Prefer:

- `learner_uuid`
- `enterprise_customer_uuid`
- `subscription_uuid`

Avoid unless required by policy:

- learner email address,
- learner full name,
- username,
- other unnecessary personal attributes.

If sensitive data becomes necessary, it should follow the stricter Open edX event governance guidance for events containing PII.

## Alternatives Considered

### Alternative A: Publish one aggregate “learner subscriptions changed” event

**Rejected.**

Reasons:

- payload size grows with learner state,
- difficult to evolve safely,
- represents a projection rather than a fact,
- increases coupling between producer and consumers,
- replay semantics are weaker,
- partial updates are harder to reason about.

### Alternative B: Keep synchronous APIs as the primary integration mechanism

**Rejected as the primary model.**

Reasons:

- tight runtime coupling,
- weaker resilience,
- repeated cross-service reads,
- poorer fit for multiple consumers,
- more difficult long-term scaling.

### Alternative C: Publish scheduled snapshots only

**Rejected.**

Reasons:

- low freshness,
- poor support for real-time workflows,
- less useful for audit and replay,
- weak event semantics.

## Consequences

### Positive consequences

- clean support for multiple subscriptions,
- reduced producer-consumer coupling,
- easier schema governance,
- better replay and recovery,
- clearer bounded-context ownership,
- alignment with Open edX event best practices.

### Negative consequences

- consumers must build and maintain projection logic,
- eventual consistency must be accepted,
- more event definitions must be documented and governed.

## Implementation Guidance

1. Introduce lifecycle event definitions for subscription domain changes.
2. Emit events from the source-of-truth service responsible for subscription state.
3. Use an outbox-based production pattern where available.
4. Define versioned schemas for each event type.
5. Build consumer-owned projections for portal, reporting, and catalog applicability.
6. Add idempotency and replay-safe handling in all consumers.

## Recommendation Statement

The recommended architecture is:

> Represent multiplex subscriptions as multiple subscription lifecycle events rather than a single aggregate subscription payload. The producer owns facts; consumers own projections.

This is the most scalable, evolvable, and architecturally sound model for supporting multiple subscriptions in an Open edX ecosystem.

## Follow-up Work

- Define canonical subscription lifecycle vocabulary.
- Identify the authoritative producer service.
- Draft Open edX event schemas for each lifecycle event.
- Define consumer projections for learner portal and enterprise catalog use cases.
- Review payload fields for privacy classification.
