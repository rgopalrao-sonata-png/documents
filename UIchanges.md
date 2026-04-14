# Multi-License Change Review — Frontend Learner Portal Enterprise

> **Branch:** `rgopalrao/11683` vs `master`
> **Repo:** `frontend-app-learner-portal-enterprise`
> **Jira:** ENT-11683
> **Review date:** 2026-04-14
> **Total change:** 33 files, +3,452 / −85 lines

---

## Table of Contents
1. [Commits in Branch](#1-commits-in-branch)
2. [Full File Change Summary](#2-full-file-change-summary)
3. [Architecture: Before vs After](#3-architecture-before-vs-after)
4. [Change 1 — Type & Schema Extensions](#4-change-1--type--schema-extensions)
5. [Change 2 — Base Data Shape (`constants.js` + `bffs.ts`)](#5-change-2--base-data-shape-constantsjs--bffsts)
6. [Change 3 — Feature Flag Normalization in `useSubscriptions.ts`](#6-change-3--feature-flag-normalization-in-usesubscriptionsts)
7. [Change 4 — New Multi-License Utility Functions (`utils.js`)](#7-change-4--new-multi-license-utility-functions-utilsjs)
8. [Change 5 — `getSearchCatalogs` Multi-License Support (`utils.js`)](#8-change-5--getsearchcatalogs-multi-license-support-utilsjs)
9. [Change 6 — `useSearchCatalogs.js` Hook Update](#9-change-6--usesearchcatalogsjs-hook-update)
10. [Change 7 — `useCourseRedemptionEligibility.ts`](#10-change-7--usecourseredemptioneligibilityts)
11. [Change 8 — `useUserSubsidyApplicableToCourse.js`](#11-change-8--useusersubsidyapplicabletocoursejs)
12. [Change 9 — `courseLoader.ts`](#12-change-9--courseloaderts)
13. [Change 10 — `externalCourseEnrollmentLoader.ts`](#13-change-10--externalcourseenrollmentloaderts)
14. [Change 11 — `course/data/utils.jsx`](#14-change-11--coursedatautilsjsx)
15. [Change 12 — `queries/utils.ts` — BFF Route Expansion + BFF-First Subscriptions](#15-change-12--queriesutilsts--bff-route-expansion--bff-first-subscriptions)
16. [Change 13 — `routes/data/utils.js`](#16-change-13--routesdatautilsjs)
17. [Change 14 — `services/subsidies/subscriptions.js`](#17-change-14--servicessubsidiessubscriptionsjs)
18. [Change 15 — `services/course.ts`](#18-change-15--servicescoursests)
19. [Test Coverage Changes](#19-test-coverage-changes)
20. [Activation Flow Fix](#20-activation-flow-fix)
21. [Risks & Review Findings](#21-risks--review-findings)
22. [Expert Recommendations](#22-expert-recommendations)

---

## 1. Commits in Branch

| SHA | Message |
|-----|---------|
| `92cb5119` | feat: ENT-11683 multi-license subscription support |
| `d7ee3861` | Gate multi-license behavior on licenseSchemaVersion |
| `560f2a45` | set licenseSchemaVersion v2 for multi-license users |
| `b6b01f89` | WIP: multi-license v2 logic and bugfixes |
| `e8006264` | unify/correct multi-license eligibility logic |
| `7bcd363d` | remove licenseSchemaVersion dependency and restore flag-off behavior |

---

## 2. Full File Change Summary

```
 .env.development                                                     |    6 +-
 .python-version                                                      |    1 +
 MULTI-LICENSE-COURSE-ACCESS-COMPARISON.md                            |  367 +++++
 MULTI-LICENSE-TESTING-ANALYSIS.md                                    |  438 +++++
 src/components/app/data/constants.js                                 |    1 +
 src/components/app/data/hooks/useAlgoliaSearch.ts                    |    4 +-
 src/components/app/data/hooks/useCourseRedemptionEligibility.ts      |   17 +-
 src/components/app/data/hooks/useSearchCatalogs.js                   |   29 +-
 src/components/app/data/hooks/useSearchCatalogs.test.jsx             |   51 +-
 src/components/app/data/hooks/useSubscriptions.test.jsx              |  119 ++
 src/components/app/data/hooks/useSubscriptions.ts                    |   52 +-
 src/components/app/data/queries/utils.ts                             |   40 +
 src/components/app/data/services/bffs.ts                             |    1 +
 src/components/app/data/services/course.test.js                      |   34 +
 src/components/app/data/services/course.ts                           |   25 +
 src/components/app/data/services/subsidies/browseAndRequest.test.js  |    6 +
 src/components/app/data/services/subsidies/browseAndRequest.ts       |   12 +-
 src/components/app/data/services/subsidies/subscriptions.js         |   38 +-
 src/components/app/data/services/subsidies/subscriptions.test.js    |   46 +
 src/components/app/data/utils.js                                     |  139 +-
 src/components/app/data/utils.test.js                               |   12 +
 src/components/app/routes/data/utils.js                             |    6 +-
 src/components/app/routes/data/utils.test.js                        |   23 +
 src/components/course/data/courseLoader.ts                          |   19 +-
 src/components/course/data/hooks/tests/useUserSubsidyApplicableToCourse.test.jsx | 62 +
 src/components/course/data/hooks/useUserSubsidyApplicableToCourse.js |   16 +-
 src/components/course/data/tests/utils.test.jsx                     |  124 ++
 src/components/course/data/utils.jsx                                |   48 +-
 src/components/course/routes/externalCourseEnrollmentLoader.ts      |   17 +-
 src/types/enterprise-access.openapi.d.ts                            |    4 +
 src/types/types.d.ts                                                |    1 +
 test.md                                                             | 1726 ++++++++++++++++++++
 test.txt                                                            |   53 +

33 files changed, 3452 insertions(+), 85 deletions(-)
```

---

## 3. Architecture: Before vs After

### Before (master) — Single-License Model

```
BFF Response
  └── subscriptions
        ├── customerAgreement
        ├── subscriptionLicenses[]          ← list, but only first is used
        ├── subscriptionLicense             ← single resolved license (global)
        └── subscriptionPlan

Per-course check (boolean):
  determineSubscriptionLicenseApplicable(subscriptionLicense, catalogsWithCourse)
    → checks if single license plan UUID is in course catalogs
    → returns true/false

Search catalogs:
  getSearchCatalogs({ subscriptionLicense, ... })
    → if license activated & current: add its catalog UUID
```

### After (branch) — Multi-License Model

```
BFF Response
  └── subscriptions
        ├── customerAgreement
        ├── subscriptionLicenses[]          ← all licenses (may be multiple)
        ├── licensesByCatalog               ← NEW: { catalogUuid → License[] }
        ├── license_schema_version          ← NEW: 'v1' or 'v2'
        ├── subscriptionLicense             ← still present for backward compat
        └── subscriptionPlan

Feature flag: enterpriseFeatures.enableMultiLicenseEntitlementsBff
  ├── true  → keep licensesByCatalog, use multi-license resolution
  ├── false → strip licensesByCatalog, fall back to single-license
  └── absent → infer from data (hasLicensesByCatalog)

Per-course resolution (returns License object or null):
  resolveApplicableSubscriptionLicense({
    subscriptionLicense,    ← backward compat fallback
    subscriptionLicenses,   ← list path
    licensesByCatalog,      ← catalog-index path (preferred)
    catalogsWithCourse,
  })

Resolution priority:
  1. findSubscriptionLicenseForCourseCatalogs(catalogsWithCourse, licensesByCatalog)
     → intersects course catalogs with index keys
     → deduplicates by license UUID
     → calls selectBestLicense for deterministic tie-break
  2. Falls back to getApplicableSubscriptionLicenses(subscriptionLicenses, catalogs)
     → filters activated+current licenses whose plan catalog is in course catalogs
     → calls selectBestLicense

Search catalogs:
  useSearchCatalogs → if licensesByCatalog non-empty: Object.keys(licensesByCatalog)
                    → else: getSearchCatalogs({ subscriptionLicenses, ... })
```

---

## 4. Change 1 — Type & Schema Extensions

### `src/types/types.d.ts` — Feature Flag Type

**Added at line 139:**
```diff
  type EnterpriseFeatures = {
    enterpriseLearnerBffEnabled?: boolean;
+   enableMultiLicenseEntitlementsBff?: boolean;   // NEW: controls multi-license behavior
  };
```

### `src/types/enterprise-access.openapi.d.ts` — OpenAPI Schema Extension

**Added lines 2544–2547:**
```diff
  subscription_plan?: components["schemas"]["SubscriptionPlan"] | null;
  /** @default false */
  show_expiration_notifications?: boolean;
+ /** @description Map of catalog UUID to list of subscription licenses covering that catalog. */
+ licenses_by_catalog?: Record<string, components["schemas"]["SubscriptionLicense"][]>;
+ /** @description Schema version for the subscription licenses payload ('v1' or 'v2'). */
+ license_schema_version?: string;
```

**Impact:** TypeScript now knows `licenses_by_catalog` and `license_schema_version` are valid BFF response fields. All consumers that destructure the response get proper typing.

---

## 5. Change 2 — Base Data Shape (`constants.js` + `bffs.ts`)

### `src/components/app/data/constants.js` — `getBaseSubscriptionsData`

**Added `licensesByCatalog: {}` at line 84:**
```diff
  const baseSubscriptionsData = {
    subscriptionLicenses: [],
+   licensesByCatalog: {},    // NEW: default empty catalog index
    customerAgreement: null,
    subscriptionLicense: null,
    subscriptionPlan: null,
```

**Why:** Ensures all downstream destructuring with `licensesByCatalog = {}` default never throws when the field is absent from older API paths.

### `src/components/app/data/services/bffs.ts` — `baseLearnerBFFResponse`

**Added `licensesByCatalog: {}` in BFF response stub:**
```diff
  subscriptions: {
    customerAgreement: null,
    subscriptionLicenses: [],
+   licensesByCatalog: {},
    subscriptionLicensesByStatus: {
      activated: [],
      assigned: [],
```

**Why:** The stub used for test/fallback BFF responses also needs the new field so tests with `baseLearnerBFFResponse` don't fail destructuring.

---

## 6. Change 3 — Feature Flag Normalization in `useSubscriptions.ts`

**File:** `src/components/app/data/hooks/useSubscriptions.ts`
**Lines changed:** 27–89 (52 lines net in the select transforms)

### BFF Path (`bffQueryOptions.select`)

**Before:**
```typescript
select: (data) => {
  const transformedData = data?.enterpriseCustomerUserSubsidies?.subscriptions;
  if (select) {
    return select({ original: data, transformed: transformedData });
  }
  return transformedData;
},
```

**After:**
```typescript
select: (data) => {
  const transformedData = data?.enterpriseCustomerUserSubsidies?.subscriptions;
  const multiLicenseFlag = data?.enterpriseFeatures?.enableMultiLicenseEntitlementsBff;

  const normalizedData = (() => {
    if (!transformedData) { return transformedData; }

    const hasLicensesByCatalog = Object.keys(transformedData.licensesByCatalog || {}).length > 0;
    const isMultiLicenseEnabled = multiLicenseFlag === false
      ? false
      : (multiLicenseFlag === true || hasLicensesByCatalog);

    // When flag is ON → pass licensesByCatalog through for multi-license behaviour.
    // When flag is OFF → strip licensesByCatalog; downstream falls back to single-license.
    if (isMultiLicenseEnabled) {
      return transformedData;
    }

    return {
      ...transformedData,
      licensesByCatalog: {},
      subscriptionLicenses: transformedData.subscriptionLicense
        ? [transformedData.subscriptionLicense]
        : [],
    };
  })();

  if (select) {
    return select({ original: data, transformed: normalizedData });
  }
  return normalizedData;
},
```

### Fallback (Non-BFF) Path (`fallbackQueryConfig`)

**Before:**
```typescript
fallbackQueryConfig: {
  ...querySubscriptions(enterpriseCustomer.uuid),
  select,
},
```

**After:**
```typescript
fallbackQueryConfig: {
  ...querySubscriptions(enterpriseCustomer.uuid),
  select: (data) => {
    const normalizedData = (() => {
      if (!data) return data;
      // Direct API never carries multi-license data → always use single-license behaviour.
      const typedData = data as { subscriptionLicense?: unknown };
      return {
        ...(data as object),
        licensesByCatalog: {},
        subscriptionLicenses: typedData.subscriptionLicense
          ? [typedData.subscriptionLicense]
          : [],
      };
    })();

    if (select) {
      return select({ original: data, transformed: normalizedData });
    }
    return normalizedData;
  },
},
```

**Key Design Decisions:**
- Flag `false` → always single-license (explicit opt-out).
- Flag `true` OR data contains non-empty `licensesByCatalog` → multi-license mode.
- Direct (non-BFF) API path always strips `licensesByCatalog` (it never has it).
- Backward compatible: single-license consumers still get `subscriptionLicense` from this hook.

---

## 7. Change 4 — New Multi-License Utility Functions (`utils.js`)

**File:** `src/components/app/data/utils.js`
**Lines added:** ~1077–1205 (131 new lines replacing 8 lines of old `determineSubscriptionLicenseApplicable`)

### 7.1 `normalizeCatalogUuid(catalogUuid)`

```js
export function normalizeCatalogUuid(catalogUuid) {
  return (catalogUuid || '').toString().replace(/-/g, '').toLowerCase();
}
```
**Purpose:** Strip hyphens and lowercase UUID strings so comparisons are format-tolerant. Prevents mismatches when one source uses `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` and another uses `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.

---

### 7.2 `getActivatedCurrentSubscriptionLicenses(subscriptionLicenses)`

```js
export function getActivatedCurrentSubscriptionLicenses(subscriptionLicenses = []) {
  return subscriptionLicenses.filter((subscriptionLicense) => (
    subscriptionLicense?.status === LICENSE_STATUS.ACTIVATED
    && subscriptionLicense?.subscriptionPlan?.isCurrent
  ));
}
```
**Purpose:** Filter to only `ACTIVATED` and current-plan licenses. This is the eligibility gate for all multi-license logic.

---

### 7.3 `buildCatalogIndex(subscriptionLicenses)`

```js
export function buildCatalogIndex(subscriptionLicenses = []) {
  return getActivatedCurrentSubscriptionLicenses(subscriptionLicenses).reduce((catalogIndex, license) => {
    const catalogUuid = license?.subscriptionPlan?.enterpriseCatalogUuid;
    if (!catalogUuid) {
      return catalogIndex;
    }
    if (!catalogIndex[catalogUuid]) {
      catalogIndex[catalogUuid] = [];
    }
    catalogIndex[catalogUuid].push(license);
    return catalogIndex;
  }, {});
}
```
**Purpose:** Build a local `licensesByCatalog`-shaped index from a flat list of licenses. Used in the direct API path (routes/data/utils.js) to populate `licensesByCatalog` after auto-activation.

---

### 7.4 `getApplicableSubscriptionLicenses(subscriptionLicenses, catalogsWithCourse)`

```js
export function getApplicableSubscriptionLicenses(subscriptionLicenses = [], catalogsWithCourse = []) {
  const normalizedCatalogsWithCourse = new Set(catalogsWithCourse.map(normalizeCatalogUuid));
  return getActivatedCurrentSubscriptionLicenses(subscriptionLicenses).filter((subscriptionLicense) => (
    normalizedCatalogsWithCourse.has(normalizeCatalogUuid(subscriptionLicense?.subscriptionPlan?.enterpriseCatalogUuid))
  ));
}
```
**Purpose:** From a list of licenses, return only those whose plan catalog UUID intersects the course's catalogs. Uses normalized UUID comparison.

---

### 7.5 `selectBestLicense(applicableLicenses)`

```js
export function selectBestLicense(applicableLicenses = []) {
  if (!applicableLicenses.length) { return null; }
  if (applicableLicenses.length === 1) { return applicableLicenses[0]; }

  return [...applicableLicenses].sort((a, b) => {
    // 1. Earlier activation date first (oldest activation wins)
    const activationA = a?.activationDate || '9999-12-31';
    const activationB = b?.activationDate || '9999-12-31';
    const activationDiff = activationA.localeCompare(activationB);
    if (activationDiff !== 0) return activationDiff;

    // 2. Later expiration date first (longest-living plan wins)
    const expirationA = a?.subscriptionPlan?.expirationDate || '0000-00-00';
    const expirationB = b?.subscriptionPlan?.expirationDate || '0000-00-00';
    const expirationDiff = expirationB.localeCompare(expirationA);
    if (expirationDiff !== 0) return expirationDiff;

    // 3. Lexicographically higher UUID wins (stable tie-break)
    const uuidA = a?.uuid || '';
    const uuidB = b?.uuid || '';
    return uuidB.localeCompare(uuidA);
  })[0];
}
```
**Purpose:** Deterministic tie-breaking when multiple licenses apply to the same course. Priority: earliest activation → longest running plan → highest UUID. Ensures same license always selected regardless of input order.

---

### 7.6 `findSubscriptionLicenseForCourseCatalogs(catalogsWithCourse, licensesByCatalog)`

```js
export function findSubscriptionLicenseForCourseCatalogs(catalogsWithCourse = [], licensesByCatalog = {}) {
  if (!catalogsWithCourse.length || !Object.keys(licensesByCatalog).length) {
    return null;
  }

  const matchingLicensesByUuid = new Map();
  const normalizedCatalogsWithCourse = new Set(catalogsWithCourse.map(normalizeCatalogUuid));

  Object.entries(licensesByCatalog).forEach(([catalogUuid, licenses]) => {
    if (!normalizedCatalogsWithCourse.has(normalizeCatalogUuid(catalogUuid))) {
      return;
    }
    licenses.forEach((license) => {
      if (license?.uuid) {
        matchingLicensesByUuid.set(license.uuid, license);  // dedup by UUID
      }
    });
  });

  return selectBestLicense(Array.from(matchingLicensesByUuid.values()));
}
```
**Purpose:** The **primary** resolver when `licensesByCatalog` (catalog index from BFF) is available. Intersects course catalogs with the index keys, deduplicates licenses by UUID, then calls `selectBestLicense`.

---

### 7.7 `resolveApplicableSubscriptionLicense({ subscriptionLicense, subscriptionLicenses, licensesByCatalog, catalogsWithCourse })`

```js
export function resolveApplicableSubscriptionLicense({
  subscriptionLicense = null,
  subscriptionLicenses = [],
  licensesByCatalog = {},
  catalogsWithCourse = [],
}) {
  const hasCatalogIndex = Object.keys(licensesByCatalog || {}).length > 0;
  const isMultiLicenseMode = hasCatalogIndex;

  // Path 1: Catalog index available (BFF multi-license mode)
  const indexedLicense = isMultiLicenseMode
    ? findSubscriptionLicenseForCourseCatalogs(catalogsWithCourse, licensesByCatalog)
    : null;
  if (indexedLicense) {
    console.debug('[multi-license] resolveApplicableSubscriptionLicense (indexed):', ...);
    return indexedLicense;
  }

  // Path 2: Fallback — evaluate from flat list or single license
  const licensesToEvaluate = isMultiLicenseMode
    ? (subscriptionLicenses.length > 0 ? subscriptionLicenses : [subscriptionLicense].filter(Boolean))
    : [subscriptionLicense].filter(Boolean);

  const resolved = selectBestLicense(getApplicableSubscriptionLicenses(licensesToEvaluate, catalogsWithCourse));
  console.debug('[multi-license] resolveApplicableSubscriptionLicense (fallback):', ...);
  return resolved;   // null if no applicable license found
}
```
**Purpose:** The **central entry point** for all course-level license resolution. Returns the best applicable `License` object (or `null`). Callers replace their boolean `isSubscriptionLicenseApplicable` with this return value and null-check it.

### 7.8 `determineSubscriptionLicenseApplicable` — Refactored (Backward Compat Shim)

**Before** (master) — direct boolean check:
```js
export function determineSubscriptionLicenseApplicable(subscriptionLicense, catalogsWithCourse) {
  return (
    subscriptionLicense?.status === LICENSE_STATUS.ACTIVATED
    && subscriptionLicense?.subscriptionPlan.isCurrent
    && catalogsWithCourse.includes(subscriptionLicense?.subscriptionPlan.enterpriseCatalogUuid)
  );
}
```

**After** — delegates to `resolveApplicableSubscriptionLicense`:
```js
export function determineSubscriptionLicenseApplicable(
  subscriptionLicense,
  catalogsWithCourse = [],
  licensesByCatalog = {},
  subscriptionLicenses = [],
) {
  return !!resolveApplicableSubscriptionLicense({
    subscriptionLicense,
    subscriptionLicenses,
    licensesByCatalog,
    catalogsWithCourse,
  });
}
```
**Why kept:** Any callers not yet migrated to `resolveApplicableSubscriptionLicense` still work. New signature is backward compatible (extra args default to empty).

---

## 8. Change 5 — `getSearchCatalogs` Multi-License Support (`utils.js`)

**File:** `src/components/app/data/utils.js`
**Lines changed:** 675–700

**Before:**
```js
export function getSearchCatalogs({
  redeemablePolicies,
  subscriptionLicense,
  couponCodeAssignments,
  currentEnterpriseOffers,
  catalogsForSubsidyRequests,
}) {
  // ...
  if (subscriptionLicense?.subscriptionPlan.isCurrent && subscriptionLicense?.status === LICENSE_STATUS.ACTIVATED) {
    catalogUUIDs.add(subscriptionLicense.subscriptionPlan.enterpriseCatalogUuid);
  }
```

**After:**
```js
export function getSearchCatalogs({
  redeemablePolicies,
  subscriptionLicense,
  subscriptionLicenses = [],      // NEW parameter
  couponCodeAssignments,
  currentEnterpriseOffers,
  catalogsForSubsidyRequests,
}) {
  // ...
  const licensesForSearchCatalogs = subscriptionLicenses.length > 0
    ? subscriptionLicenses
    : [subscriptionLicense].filter(Boolean);  // ← backward compat

  getActivatedCurrentSubscriptionLicenses(licensesForSearchCatalogs).forEach((license) => {
    catalogUUIDs.add(license.subscriptionPlan.enterpriseCatalogUuid);
  });
```

**Impact:** All activated+current licenses contribute their catalog UUIDs to Algolia search filters instead of just the single primary license.

---

## 9. Change 6 — `useSearchCatalogs.js` Hook Update

**File:** `src/components/app/data/hooks/useSearchCatalogs.js`
**Lines changed:** 17–46 (net +29 lines)

**Before:**
```js
export default function useSearchCatalogs() {
  const { data: { subscriptionLicense } } = useSubscriptions();
  // ...

  return useMemo(() => getSearchCatalogs({
    redeemablePolicies,
    catalogsForSubsidyRequests,
    couponCodeAssignments,
    currentEnterpriseOffers,
    subscriptionLicense,
  }), [redeemablePolicies, catalogsForSubsidyRequests, couponCodeAssignments, currentEnterpriseOffers, subscriptionLicense]);
}
```

**After:**
```js
export default function useSearchCatalogs() {
  const { data: { subscriptionLicense, subscriptionLicenses, licensesByCatalog = {} } } = useSubscriptions();
  // ...

  const searchCatalogs = useMemo(() => {
    // FAST PATH: if catalog-indexed licenses are present, use their keys directly
    if (Object.keys(licensesByCatalog).length > 0) {
      return Object.keys(licensesByCatalog);
    }

    return getSearchCatalogs({
      redeemablePolicies,
      catalogsForSubsidyRequests,
      couponCodeAssignments,
      currentEnterpriseOffers,
      subscriptionLicense,
      subscriptionLicenses,
    });
  }, [
    licensesByCatalog,
    redeemablePolicies, catalogsForSubsidyRequests,
    couponCodeAssignments, currentEnterpriseOffers,
    subscriptionLicense, subscriptionLicenses,
  ]);

  return searchCatalogs;
}
```

**Key behavior:** When BFF returns `licensesByCatalog`, Algolia is filtered to exactly those catalog UUIDs — no recomputation needed. Falls back to computed result for non-BFF path.

---

## 10. Change 7 — `useCourseRedemptionEligibility.ts`

**File:** `src/components/app/data/hooks/useCourseRedemptionEligibility.ts`
**Lines changed:** L9, L103–L132 (17 lines net)

**Import change (line 9):**
```diff
-import { determineSubscriptionLicenseApplicable, findCouponCodeForCourse, getCourseRunsForRedemption } from '../utils';
+import { findCouponCodeForCourse, getCourseRunsForRedemption, resolveApplicableSubscriptionLicense } from '../utils';
```

**Destructuring change (line 103–109):**
```diff
  const {
-   // @ts-expect-error
-   data: { subscriptionLicense },
+   data: {
+     subscriptionLicense,
+     subscriptionLicenses = [],
+     licensesByCatalog = {},
+   } = {},
  } = useSubscriptions();
```

**Resolution change (lines 124–132):**
```diff
- const isSubscriptionLicenseApplicable = determineSubscriptionLicenseApplicable(
+ const applicableSubscriptionLicense = resolveApplicableSubscriptionLicense({
    subscriptionLicense,
+   subscriptionLicenses,
+   licensesByCatalog,
    catalogsWithCourse,
- );
- const hasSubsidyPrioritizedOverLearnerCredit = isSubscriptionLicenseApplicable
+ });
+ const hasSubsidyPrioritizedOverLearnerCredit = !!applicableSubscriptionLicense
    || applicableCouponCode?.couponCodeRedemptionCount > 0;
```

**Also fixed:** Removed `// @ts-expect-error` — proper typing now handles the optional chain.

---

## 11. Change 8 — `useUserSubsidyApplicableToCourse.js`

**File:** `src/components/course/data/hooks/useUserSubsidyApplicableToCourse.js`
**Lines changed:** L1–L9, L51–L59, L88–L100, L123–L143 (16 lines net)

**Import change:**
```diff
-import { determineSubscriptionLicenseApplicable, ... } from ...
+import { resolveApplicableSubscriptionLicense, ... } from ...
```

**Destructuring (line 51–59):**
```diff
  data: {
    customerAgreement,
    subscriptionLicense,
+   subscriptionLicenses = [],
+   licensesByCatalog = {},
  },
```

**Core resolution (lines 88–100):**
```diff
- const isSubscriptionLicenseApplicable = determineSubscriptionLicenseApplicable(
+ const applicableSubscriptionLicense = resolveApplicableSubscriptionLicense({
    subscriptionLicense,
+   subscriptionLicenses,
+   licensesByCatalog,
    catalogsWithCourse,
- );
+ });

  const userSubsidyApplicableToCourse = getSubsidyToApplyForCourse({
-   applicableSubscriptionLicense: isSubscriptionLicenseApplicable ? subscriptionLicense : null,
+   applicableSubscriptionLicense,   // directly the resolved object (or null)
```

**Memo deps updated (lines 123–143):** Added `subscriptionLicenses` and `licensesByCatalog` to both `getMissingApplicableSubsidyReason` call and `useMemo` dependency array.

---

## 12. Change 9 — `courseLoader.ts`

**File:** `src/components/course/data/courseLoader.ts`
**Lines changed:** L5–L14, L80, L91–L99, L132–L147 (19 lines net)

**Import change (line 14):**
```diff
-  determineSubscriptionLicenseApplicable,
+  resolveApplicableSubscriptionLicense,
```

**`safeEnsureQueryDataSubscriptions` call (line 80):**
```diff
  safeEnsureQueryDataSubscriptions({
    queryClient,
    enterpriseCustomer,
+   enterpriseSlug,        // NEW: needed for BFF-first subscription fetch
  }),
```

**Destructuring (lines 91–99):**
```diff
  const [
    { catalogList: catalogsWithCourse },
    { couponsOverview, couponCodeAssignments, couponCodeRedemptionCount },
-   { customerAgreement, subscriptionLicense, subscriptionPlan },
+   {
+     customerAgreement,
+     subscriptionLicense,
+     subscriptionLicenses = [],
+     licensesByCatalog = {},
+     subscriptionPlan,
+   },
    redeemableLearnerCreditPolicies,
  ] = prerequisiteQueries;
```

**Resolution (lines 132–147):**
```diff
- const isSubscriptionLicenseApplicable = determineSubscriptionLicenseApplicable(
+ const applicableSubscriptionLicense = resolveApplicableSubscriptionLicense({
    subscriptionLicense,
+   subscriptionLicenses,
+   licensesByCatalog,
    catalogsWithCourse,
- );
- const hasSubsidyPrioritizedOverLearnerCredit = isSubscriptionLicenseApplicable
+ });
+ const hasSubsidyPrioritizedOverLearnerCredit = !!applicableSubscriptionLicense
    || applicableCouponCode?.couponCodeRedemptionCount > 0;
```

---

## 13. Change 10 — `externalCourseEnrollmentLoader.ts`

**File:** `src/components/course/routes/externalCourseEnrollmentLoader.ts`
**Lines changed:** L3–L16, L77–L108 (17 lines net)

Mirrors the exact same pattern as `courseLoader.ts`:
- **Import:** `determineSubscriptionLicenseApplicable` → `resolveApplicableSubscriptionLicense`
- **`safeEnsureQueryDataSubscriptions` call:** adds `enterpriseSlug`
- **Destructuring:** adds `subscriptionLicenses = []`, `licensesByCatalog = {}`
- **Resolution:** `isSubscriptionLicenseApplicable` (boolean) → `applicableSubscriptionLicense` (object)

---

## 14. Change 11 — `course/data/utils.jsx`

**File:** `src/components/course/data/utils.jsx`
**Lines changed:** L26–L29, L447–L510, L635–L663 (48 lines net)

### New imports (line 26–29):
```diff
+  normalizeCatalogUuid,
+  resolveApplicableSubscriptionLicense,
```

### Removed `determineLicenseApplicableToCourse` (lines 447–465 removed):

**Before** — private function:
```js
function determineLicenseApplicableToCourse({ catalogsWithCourse, subscriptionLicense }) {
  if (!subscriptionLicense) return false;
  return catalogsWithCourse.includes(subscriptionLicense.subscriptionPlan.enterpriseCatalogUuid);
}
```

**After** — replaced entirely by `resolveApplicableSubscriptionLicense` in caller.

### `getSubscriptionDisabledEnrollmentReasonType` (lines 447–510):

**Signature change:**
```diff
  export const getSubscriptionDisabledEnrollmentReasonType = ({
    customerAgreement,
    catalogsWithCourse,
    subscriptionLicense,
+   subscriptionLicenses = [],
+   licensesByCatalog,
    hasEnterpriseAdminUsers,
  }) => {
```

**Normalized UUID comparison for `hasSubscriptionPlanApplicableToCourse`:**
```diff
- const hasSubscriptionPlanApplicableToCourse = !!customerAgreement?.availableSubscriptionCatalogs.some(
-   subscriptionCatalogUuid => catalogsWithCourse.includes(subscriptionCatalogUuid),
- );
+ const normalizedCatalogsWithCourse = new Set(catalogsWithCourse.map(normalizeCatalogUuid));
+ const hasSubscriptionPlanApplicableToCourse = !!customerAgreement?.availableSubscriptionCatalogs.some(
+   subscriptionCatalogUuid => normalizedCatalogsWithCourse.has(normalizeCatalogUuid(subscriptionCatalogUuid)),
+ );
```

**License resolution replacing `determineLicenseApplicableToCourse`:**
```diff
+ const applicableSubscriptionLicense = resolveApplicableSubscriptionLicense({
+   subscriptionLicense,
+   subscriptionLicenses,
+   licensesByCatalog,
+   catalogsWithCourse,
+ });

- const isLicenseApplicableToCourse = determineLicenseApplicableToCourse({ catalogsWithCourse, subscriptionLicense });
- if (!isLicenseApplicableToCourse) {
+ if (!applicableSubscriptionLicense) {
    return parseReasonTypeBasedOnEnterpriseAdmins(...);
  }

- const hasExpiredSubscriptionLicense = !subscriptionLicense.subscriptionPlan.isCurrent;
+ const hasExpiredSubscriptionLicense = !applicableSubscriptionLicense.subscriptionPlan?.isCurrent;

- if (subscriptionLicense.status === LICENSE_STATUS.REVOKED) {
+ if (applicableSubscriptionLicense.status === LICENSE_STATUS.REVOKED) {
```

### `getMissingApplicableSubsidyReason` (lines 635–663):

```diff
  export const getMissingApplicableSubsidyReason = ({
    couponsOverview,
    customerAgreement,
    subscriptionLicense,
+   subscriptionLicenses,
+   licensesByCatalog,
    containsContentItems,
    ...
  }) => {
    // ...
    const subscriptionDisabledEnrollmentReasonType = getSubscriptionDisabledEnrollmentReasonType({
      customerAgreement,
      catalogsWithCourse,
      subscriptionLicense,
+     subscriptionLicenses,
+     licensesByCatalog,
      hasEnterpriseAdminUsers,
    });
```

---

## 15. Change 12 — `queries/utils.ts` — BFF Route Expansion + BFF-First Subscriptions

**File:** `src/components/app/data/queries/utils.ts`
**Lines added:** L44–L66 (route patterns), L258–L289 (BFF-first fetch logic)

### New BFF Route Patterns (lines 44–66):

These ensure the dashboard BFF query is triggered for course and enrollment pages (not just the dashboard route):

```diff
  {
    pattern: '/:enterpriseSlug',
    query: queryEnterpriseLearnerDashboardBFF,
  },
+ {
+   pattern: '/:enterpriseSlug/course/:courseKey',
+   query: queryEnterpriseLearnerDashboardBFF,
+ },
+ {
+   pattern: '/:enterpriseSlug/course/:courseKey/enroll/:courseRunKey',
+   query: queryEnterpriseLearnerDashboardBFF,
+ },
+ {
+   pattern: '/:enterpriseSlug/:courseType/course/:courseKey',
+   query: queryEnterpriseLearnerDashboardBFF,
+ },
+ {
+   pattern: '/:enterpriseSlug/:courseType/course/:courseKey/enroll/:courseRunKey',
+   query: queryEnterpriseLearnerDashboardBFF,
+ },
+ {
+   pattern: '/:enterpriseSlug/:courseType/course/:courseKey/enroll/:courseRunKey/complete',
+   query: queryEnterpriseLearnerDashboardBFF,
+ },
```

**Why critical:** `licensesByCatalog` is only present in the BFF response. Without these patterns, course pages would not trigger the BFF and would always fall back to the non-BFF single-license path.

### `safeEnsureQueryDataSubscriptions` — BFF-First (lines 258–289):

**Before:**
```typescript
export async function safeEnsureQueryDataSubscriptions({ queryClient, enterpriseCustomer }) {
  return safeEnsureQueryData({
    queryClient,
    query: querySubscriptions(enterpriseCustomer.uuid),
  });
}
```

**After:**
```typescript
export async function safeEnsureQueryDataSubscriptions({ queryClient, enterpriseCustomer, enterpriseSlug }) {
  const resolvedEnterpriseSlug = enterpriseSlug || enterpriseCustomer.slug;

  // Try BFF first — it may carry licensesByCatalog for multi-license users
  if (resolvedEnterpriseSlug) {
    const bffResponse = await safeEnsureQueryData<DashboardBFFResponse | null>({
      queryClient,
      query: {
        ...queryEnterpriseLearnerDashboardBFF({ enterpriseSlug: resolvedEnterpriseSlug }),
        retry: false,
      },
      shouldLogError: false,
      fallbackData: null,
    });
    const bffSubscriptions = bffResponse?.enterpriseCustomerUserSubsidies?.subscriptions;

    if (bffSubscriptions) {
      return bffSubscriptions;  // ← returns multi-license aware data
    }
  }

  // Fall back to direct subscriptions API (single-license path)
  return safeEnsureQueryData({
    queryClient,
    query: querySubscriptions(enterpriseCustomer.uuid),
  });
}
```

**Impact:** All loaders that call `safeEnsureQueryDataSubscriptions` now automatically get BFF multi-license data when the BFF is available, without each loader needing to implement it independently.

---

## 16. Change 13 — `routes/data/utils.js`

**File:** `src/components/app/routes/data/utils.js`
**Lines changed:** L9–L12, L50–L54, L94–L99, L415–L422 (6 lines net)

### Import (line 9–12):
```diff
+  buildCatalogIndex,
```

### `ensureEnterpriseAppData` — `safeEnsureQueryDataSubscriptions` call (lines 50–54):
```diff
  safeEnsureQueryDataSubscriptions({
    queryClient,
    enterpriseCustomer,
+   enterpriseSlug: enterpriseCustomer.slug,   // NEW: enables BFF-first fetch
  })
```

### Post-activation `setQueryData` update (lines 94–99):
```diff
  queryClient.setQueryData(subscriptionsQuery.queryKey, (oldData) => ({
    ...oldData,
+   licensesByCatalog: buildCatalogIndex(updatedSubscriptionLicenses),   // NEW: build catalog index after activation
    subscriptionLicensesByStatus: updatedLicensesByStatus,
    subscriptionPlan: activatedOrAutoAppliedLicense.subscriptionPlan,
    subscriptionLicense: activatedOrAutoAppliedLicense,
  }));
```

### Algolia null-guard (lines 415–422):
```diff
  const { algolia } = bffResponse;
+ if (!algolia) { return; }   // NEW: guard against missing algolia object
  const invalidateQuery = () => queryClient.invalidateQueries({ ... });
- if (algolia.validUntil) {
+ if (algolia?.validUntil) {   // optional chain for safety
    await algoliaQueryCacheValidator(...);
  }
```

---

## 17. Change 14 — `services/subsidies/subscriptions.js`

**File:** `src/components/app/data/services/subsidies/subscriptions.js`
**Lines changed:** L158–L164, L196–L249 (38 lines net)

### Activation Early-Return Fix (lines 158–164):

**Before:**
```js
// Check if learner already has activated license. If so, return early.
if (hasActivatedSubscriptionLicense) {
  return checkLicenseActivationRouteAndRedirectToDashboard();
}
```

**After:**
```js
// Return early only when learner has an activated license AND no pending assigned license.
// In multi-license scenarios, a learner may have an activated license from one subscription
// and an assigned (unactivated) license from a different subscription that still needs activation.
if (hasActivatedSubscriptionLicense && !subscriptionLicenseToActivate) {
  return checkLicenseActivationRouteAndRedirectToDashboard();
}
```

**Why important:** Previously, a learner with any activated license would never activate their second assigned license. Now they can.

### `transformSubscriptionsData` — Normalized Sorting (lines 196–249):

**Before** — simple sort by `isCurrent`:
```js
subscriptionsData.subscriptionLicenses = [...subscriptionLicenses].sort((a, b) => {
  const aIsCurrent = a.subscriptionPlan.isCurrent;
  const bIsCurrent = b.subscriptionPlan.isCurrent;
  if (aIsCurrent && bIsCurrent) { return 0; }
  return aIsCurrent ? -1 : 1;
});
```

**After** — deterministic multi-key sort:
```js
const normalizedSubscriptionLicenses = subscriptionLicenses || [];  // null-safe
subscriptionsData.subscriptionLicenses = normalizedSubscriptionLicenses;

subscriptionsData.subscriptionLicenses = [...normalizedSubscriptionLicenses].sort((a, b) => {
  const aIsCurrent = a.subscriptionPlan.isCurrent;
  const bIsCurrent = b.subscriptionPlan.isCurrent;
  // 1. Current plans first
  if (aIsCurrent !== bIsCurrent) { return aIsCurrent ? -1 : 1; }
  // 2. Earlier activation date
  const activationDiff = (a.activationDate || '9999-12-31').localeCompare(b.activationDate || '9999-12-31');
  if (activationDiff !== 0) { return activationDiff; }
  // 3. Later expiration date (longer-running plan wins)
  const expirationDiff = (b.subscriptionPlan?.expirationDate || '0000-00-00').localeCompare(a.subscriptionPlan?.expirationDate || '0000-00-00');
  if (expirationDiff !== 0) { return expirationDiff; }
  // 4. Stable UUID tie-break
  return (b.uuid || '').localeCompare(a.uuid || '');
});

// Direct API path never has multi-license data → always empty catalog index
subscriptionsData.licensesByCatalog = {};
```

---

## 18. Change 15 — `services/course.ts`

**File:** `src/components/app/data/services/course.ts`
**Lines added:** L4–L30 (25 lines)

### New `isCourseRunKey` Helper:
```typescript
function isCourseRunKey(contentKey: string) {
  return contentKey.startsWith('course-v1:');
}
```

### New `transformCourseRunMetadataAsCourseMetadata`:
```typescript
function transformCourseRunMetadataAsCourseMetadata(courseRunMetadata) {
  return {
    ...courseRunMetadata,
    owners: courseRunMetadata.owners || [],
    subjects: courseRunMetadata.subjects || [],
    programs: courseRunMetadata.programs || [],
    staff: courseRunMetadata.staff || [],
    entitlements: courseRunMetadata.entitlements || [],
    advertisedCourseRunUuid: courseRunMetadata.uuid,
    courseRuns: [courseRunMetadata],
    availableCourseRuns: [courseRunMetadata],
    activeCourseRun: courseRunMetadata,
    courseEntitlementProductSku: findHighestLevelEntitlementSku(courseRunMetadata.entitlements),
  };
}
```

### Modified `fetchCourseMetadata` — course-run key detection:
```typescript
export async function fetchCourseMetadata(courseKey): Promise<CourseMetadata> {
  // NEW: if given a course run key (not a course key), fetch run metadata and reshape it
  if (isCourseRunKey(courseKey)) {
    const courseRunMetadata = await fetchCourseRunMetadata(courseKey);
    return transformCourseRunMetadataAsCourseMetadata(courseRunMetadata);
  }

  // Original course metadata fetch path
  const contentMetadataUrl = `${getConfig().DISCOVERY_API_BASE_URL}/api/v1/courses/${courseKey}/`;
  ...
}
```

**Why:** When navigating directly to a course run URL (e.g., `course-v1:edX+DemoX+Demo_Course`), the service now returns properly shaped `CourseMetadata` instead of raw run data, preventing downstream shape errors.

---

## 19. Test Coverage Changes

| Test File | Change | What It Tests |
|-----------|--------|---------------|
| `useSubscriptions.test.jsx` | +119 lines | BFF flag normalization, multi-license vs. single-license fallback |
| `useSearchCatalogs.test.jsx` | +51 lines | `licensesByCatalog`-first catalog derivation |
| `course/data/tests/utils.test.jsx` | +124 lines | `getSubscriptionDisabledEnrollmentReasonType` multi-license paths |
| `course/data/hooks/tests/useUserSubsidyApplicableToCourse.test.jsx` | +62 lines | Multi-license subsidy resolution |
| `services/subsidies/subscriptions.test.js` | +46 lines | Sorting, activation early-return, `licensesByCatalog: {}` on direct path |
| `app/routes/data/utils.test.js` | +23 lines | `ensureEnterpriseAppData` with BFF-first subscription fetch |
| `app/data/utils.test.js` | +12 lines | `buildCatalogIndex`, `resolveApplicableSubscriptionLicense` |
| `services/course.test.js` | +34 lines | `isCourseRunKey`, `transformCourseRunMetadataAsCourseMetadata` |
| `services/subsidies/browseAndRequest.test.js` | +6 lines | Minor B&R updates |

---

## 20. Activation Flow Fix

### Before (master) — Blocks second license activation:
```
User has: License A (ACTIVATED, Plan X)
          License B (ASSIGNED, Plan Y)

→ hasActivatedSubscriptionLicense = true
→ early return: "already activated"
→ License B NEVER activates ✗
```

### After (branch) — Allows second license activation:
```
User has: License A (ACTIVATED, Plan X)
          License B (ASSIGNED, Plan Y)

→ hasActivatedSubscriptionLicense = true
→ subscriptionLicenseToActivate = License B  (found by key match)
→ condition: true && !!License B = false  → does NOT early return
→ continues to activate License B ✓
```

---

## 21. Risks & Review Findings

### 🔴 HIGH — Debug logging in production code path
**File:** `src/components/app/data/utils.js` — `resolveApplicableSubscriptionLicense`
```js
// eslint-disable-next-line no-console
console.debug('[multi-license] resolveApplicableSubscriptionLicense (indexed):', ...);
// eslint-disable-next-line no-console
console.debug('[multi-license] resolveApplicableSubscriptionLicense (fallback):', ...);
```
**Recommendation:** Remove both `console.debug` calls or replace with a proper debug utility gated by `process.env.NODE_ENV !== 'production'`.

### 🔴 HIGH — Environment credentials committed
**File:** `.env.development` — contains concrete-looking Algolia app ID and API key values.
**Recommendation:** Revert to placeholder values (e.g., `your_algolia_app_id`). Do not commit development credentials.

### 🟡 MEDIUM — Accidental files in commit
| File | Size | Impact |
|------|------|--------|
| `test.md` | +1,726 lines | Likely scratch notes from development |
| `test.txt` | +53 lines | Scratch file |
| `.python-version` | +1 line | pyenv artifact, not needed in JS repo |
**Recommendation:** Remove from branch before merge.

### 🟡 MEDIUM — `determineSubscriptionLicenseApplicable` signature changed silently
The function now accepts two additional optional params (`licensesByCatalog`, `subscriptionLicenses`). Any existing callers passing positional args to the old 2-param signature are unaffected but won't benefit from multi-license resolution unless updated.
**Recommendation:** Audit all remaining callers and migrate them to `resolveApplicableSubscriptionLicense` directly.

### 🟢 LOW — `buildCatalogIndex` vs `licensesByCatalog` from BFF
When the direct API path is used (non-BFF), `licensesByCatalog` is built locally from `buildCatalogIndex(activatedLicenses)` after activation. This is a client-side approximation that may differ from the server-computed index in edge cases (e.g., race conditions around plan expiry).
**Recommendation:** Acceptable, but document this behavior for future maintainers.

---

## 22. Expert Recommendations

| Priority | Action |
|----------|--------|
| **P0 (Block merge)** | Remove `console.debug` statements from `resolveApplicableSubscriptionLicense` production code path |
| **P0 (Block merge)** | Revert `.env.development` to placeholder values |
| **P0 (Block merge)** | Remove `test.md`, `test.txt`, `.python-version` files |
| **P1 (Before merge)** | Audit remaining callers of old `determineSubscriptionLicenseApplicable` and migrate to `resolveApplicableSubscriptionLicense` |
| **P1 (Before merge)** | Add explicit unit tests for `selectBestLicense` tie-breaking edge cases: same activation date, same expiration date |
| **P2 (Follow-up)** | Add integration tests for BFF-first vs fallback subscription flow in `safeEnsureQueryDataSubscriptions` |
| **P2 (Follow-up)** | Extract multi-license utility functions into a dedicated `src/components/app/data/utils/subscriptions.js` module (current `utils.js` is large) |

---

## Appendix: Call Hierarchy for Multi-License Resolution

```
useSearchCatalogs()
  ├── licensesByCatalog non-empty → Object.keys(licensesByCatalog)
  └── getSearchCatalogs({ subscriptionLicenses, ... })
        └── getActivatedCurrentSubscriptionLicenses(licenses)

useCourseRedemptionEligibility()
  └── resolveApplicableSubscriptionLicense({ subscriptionLicense, subscriptionLicenses, licensesByCatalog, catalogsWithCourse })
        ├── findSubscriptionLicenseForCourseCatalogs(catalogsWithCourse, licensesByCatalog)  [if index present]
        │     └── selectBestLicense(deduped matching licenses)
        └── selectBestLicense(getApplicableSubscriptionLicenses(licenses, catalogs))         [fallback]

useUserSubsidyApplicableToCourse()
  └── resolveApplicableSubscriptionLicense(...)  [same as above]
        └── → applicableSubscriptionLicense passed to getSubsidyToApplyForCourse()

courseLoader / externalCourseEnrollmentLoader
  ├── safeEnsureQueryDataSubscriptions({ enterpriseSlug, ... })
  │     ├── BFF path → returns licensesByCatalog from BFF response
  │     └── Direct path → returns standard subscriptions data
  └── resolveApplicableSubscriptionLicense(...)
        └── hasSubsidyPrioritizedOverLearnerCredit = !!applicableSubscriptionLicense || couponApplicable
```
