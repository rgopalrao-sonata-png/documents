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

---

---

# Part 2: Backend (enterprise-access BFF) — Multi-License Implementation

> **Repo:** `enterprise-access`
> **Commit:** `6959455` — `feat: Multilicense subscription feature`
> **Branch:** `rgopalrao/ENT-11726`
> **Compared against:** `main`
> **Files changed:** 15 files, +1,779 / −125 lines

---

## A. Data Model Relationship: License → Plan → Catalog → Course

### Complete Entity Relationship

```
EnterpriseCustomer (UUID)
  │
  ├── CustomerAgreement
  │     └── one CustomerAgreement per Enterprise
  │
  └── SubscriptionPlan (many per CustomerAgreement)
        ├── enterprise_catalog_uuid   ← FK linking the plan to ONE Catalog
        ├── is_current                ← True if plan is within active dates
        ├── start_date / expiration_date
        │
        └── License (many per SubscriptionPlan)
              ├── uuid
              ├── user_email
              ├── lms_user_id
              ├── status: UNASSIGNED | ASSIGNED | ACTIVATED | REVOKED
              ├── activation_date
              └── subscription_plan   ← FK back to SubscriptionPlan

EnterpriseCatalog (UUID)
  ├── enterprise_catalog_uuid         ← referenced by SubscriptionPlan
  ├── catalog_query_id                ← FK to CatalogQuery
  └── CatalogQuery
        └── content_filter            ← JSONField defining what's in the catalog

ContentMetadata (Course / CourseRun / Program)
  ├── content_key                     ← e.g. "edX+DemoX"
  └── Many-to-Many → CatalogQuery    ← via catalog_contentmetadata_catalog_queries table
```

### SQL: Course → Catalog → Plan → License → User

```sql
-- Given a course key, find all licenses that grant access to it, and which users hold them

SELECT
    cm.content_key                                 AS course_key,
    ec.uuid                                        AS catalog_uuid,
    sp.uuid                                        AS subscription_plan_uuid,
    sp.title                                       AS plan_title,
    sp.is_current,
    sp.expiration_date,
    lic.uuid                                       AS license_uuid,
    lic.status                                     AS license_status,
    lic.user_email,
    lic.activation_date
FROM catalog_contentmetadata cm
JOIN catalog_contentmetadata_catalog_queries cmcq
    ON cm.id = cmcq.contentmetadata_id
JOIN catalog_enterprisecatalog ec
    ON ec.catalog_query_id = cmcq.catalogquery_id
JOIN subscription_subscriptionplan sp
    ON sp.enterprise_catalog_uuid = ec.uuid
JOIN subscription_license lic
    ON lic.subscription_plan_id = sp.uuid
WHERE cm.content_key = 'edX+DemoX'          -- replace with your course key
  AND lic.status      = 'activated'
  AND sp.is_current   = 1;
```

### Key Cardinality Rules

| Relationship | Cardinality | Notes |
|---|---|---|
| Enterprise → CustomerAgreement | 1:1 | One agreement per enterprise |
| CustomerAgreement → SubscriptionPlan | 1:N | Multiple plans (e.g., "Data Science", "Leadership") |
| SubscriptionPlan → EnterpriseCatalog | N:1 | Each plan covers exactly one catalog |
| EnterpriseCatalog → Course | N:M | Via `catalog_contentmetadata_catalog_queries` join table |
| SubscriptionPlan → License | 1:N | Many seats per plan |
| License → User | N:1 | One user per license (enforced; **pre-multi-license**: also 1 per enterprise) |
| **User → License (new)** | **1:N** | **Multi-license: one user can now have licenses from multiple plans** |

---

## B. Multi-License Backend Implementation — commit `6959455`

### What Changed (15 files, 1,779 insertions)

```
enterprise_access/apps/api/v1/tests/test_bff_views.py            |  32 +
enterprise_access/apps/api/v1/views/bffs/common.py               |  35 +-
enterprise_access/apps/api/v1/views/bffs/learner_portal.py       |   4 +
enterprise_access/apps/api_client/enterprise_catalog_client.py   |   9 +-
enterprise_access/apps/bffs/api.py                               |  21 +-
enterprise_access/apps/bffs/context.py                           | 133 +-
enterprise_access/apps/bffs/handlers.py                          | 334 +++++++--
enterprise_access/apps/bffs/serializers.py                       |  31 +
enterprise_access/apps/bffs/tests/test_context.py                | 209 +++++++
enterprise_access/apps/bffs/tests/test_handlers.py               |  92 ++-
enterprise_access/apps/bffs/tests/test_multi_license.py          | 686 +++++++++++++++++++++
enterprise_access/apps/bffs/tests/test_serializers.py            | 167 +++++
enterprise_access/tests/test_toggles.py                          |  19 +
enterprise_access/toggles.py                                     |  27 +
```

---

## C. Backend Change 1 — Feature Flag (`toggles.py`)

**New file:** `enterprise_access/toggles.py`

```python
from edx_toggles.toggles import WaffleFlag

ENABLE_MULTI_LICENSE_ENTITLEMENTS_BFF = WaffleFlag(
    'enterprise_access.enable_multi_license_entitlements_bff',
    __name__,
)

def enable_multi_license_entitlements_bff():
    """Return whether multi-license BFF behavior is enabled."""
    return ENABLE_MULTI_LICENSE_ENTITLEMENTS_BFF.is_enabled()
```

**Behaviour when flag:**
- **OFF (default):** Single-license response shape. `licenses_by_catalog` field absent. Algolia scoped to one license catalog only. Enrollment mapped to single license.
- **ON:** Multi-license response includes `licenses_by_catalog`. Algolia scoped to all activated license catalogs. Enrollment mapped per-course to best-matching license.

---

## D. Backend Change 2 — `SubscriptionLicenseProcessor` Class (`handlers.py`)

New mixin class added to `BaseLearnerPortalHandler` providing two private helpers:

### `_build_catalog_index(licenses)` → `{ catalog_uuid: [License, ...] }`

```python
def _build_catalog_index(self, licenses):
    """Build catalog_uuid → licenses mapping for O(1) lookups."""
    catalog_index = {}
    for lic in licenses:
        catalog_uuid = lic.get('subscription_plan', {}).get('enterprise_catalog_uuid')
        if catalog_uuid:
            catalog_index.setdefault(catalog_uuid, []).append(lic)
    return catalog_index
```

**Example input (two plans, two catalogs):**
```python
licenses = [
    {
        'uuid': 'lic-A',
        'status': 'activated',
        'activation_date': '2025-01-01',
        'subscription_plan': {
            'enterprise_catalog_uuid': 'cat-data-science',
            'expiration_date': '2026-12-31',
            'is_current': True,
        }
    },
    {
        'uuid': 'lic-B',
        'status': 'activated',
        'activation_date': '2025-03-01',
        'subscription_plan': {
            'enterprise_catalog_uuid': 'cat-leadership',
            'expiration_date': '2026-12-31',
            'is_current': True,
        }
    },
]
```

**Output:**
```python
{
    'cat-data-science': [{ 'uuid': 'lic-A', ... }],
    'cat-leadership':   [{ 'uuid': 'lic-B', ... }],
}
```

---

### `_select_best_license(licenses)` — Deterministic Tie-Breaker (ENT-11672)

**Business rule:** When a course is in multiple catalogs, the enrollment record goes on the license the learner **first activated** that has the course in its catalog.

```python
def _select_best_license(self, licenses):
    if len(licenses) == 1:
        return licenses[0]

    # Sort by UUID desc (stable fallback)
    ranked = sorted(licenses, key=lambda l: l.get('uuid') or '', reverse=True)
    # Then expiration_date desc (longest access window wins)
    ranked = sorted(ranked, key=lambda l: l.get('subscription_plan', {}).get('expiration_date') or '0000-00-00', reverse=True)
    # Then activation_date asc (first activated wins) — primary criterion
    ranked = sorted(ranked, key=lambda l: l.get('activation_date') or '9999-12-31')
    return ranked[0]
```

**Example:**
```
Course "AI Fundamentals" is in both:
  - cat-data-science (License A, activated 2025-01-01, expires 2026-12-31)
  - cat-ml-advanced  (License B, activated 2025-03-01, expires 2027-06-30)

_select_best_license([lic-A, lic-B])
→ lic-A wins (activation_date 2025-01-01 < 2025-03-01)
→ Enrollment record tied to License A
```

---

## E. Backend Change 3 — `transform_subscriptions_result` (handlers.py)

This is the central method that produces the BFF subscription payload.

### Before (main) — Single-License Output

```python
return {
    'customer_agreement': customer_agreement,
    'subscription_licenses': subscription_licenses,
    'subscription_licenses_by_status': subscription_licenses_by_status,
    'subscription_license': subscription_license,     # singular: first by priority order
    'subscription_plan': subscription_plan,
    'show_expiration_notifications': show_expiration_notifications,
}
```

### After (branch) — Multi-License Output (flag ON)

```python
# Build catalog index from activated+current licenses only
activated_licenses = subscription_licenses_by_status.get('activated', [])
current_activated_licenses = [
    lic for lic in activated_licenses
    if lic.get('subscription_plan', {}).get('is_current')
]

licenses_by_catalog = {}
if multi_license_flag_enabled and current_activated_licenses:
    licenses_by_catalog = self._build_catalog_index(current_activated_licenses)
    # ENT-11672: singular subscription_license also uses first-activated rule
    best_activated = self._select_best_license(current_activated_licenses)
    subscription_license = best_activated
    subscription_plan = best_activated.get('subscription_plan')

response_data = {
    'customer_agreement': customer_agreement,
    'subscription_licenses': subscription_licenses,        # all licenses (unchanged)
    'subscription_licenses_by_status': subscription_licenses_by_status,
    'subscription_license': subscription_license,          # now = first-activated
    'subscription_plan': subscription_plan,
    'show_expiration_notifications': show_expiration_notifications,
}

# Only included when flag is ON
if multi_license_flag_enabled:
    response_data['licenses_by_catalog'] = licenses_by_catalog
```

### Full Example BFF Response (flag ON)

```json
{
  "enterprise_customer_user_subsidies": {
    "subscriptions": {
      "customer_agreement": {
        "uuid": "agreement-uuid-001",
        "enterprise_customer_uuid": "enterprise-uuid-001",
        "default_enterprise_catalog_uuid": null
      },
      "subscription_licenses": [
        {
          "uuid": "lic-A",
          "status": "activated",
          "activation_date": "2025-01-01",
          "subscription_plan": {
            "uuid": "plan-data-science",
            "title": "Data Science Essentials",
            "enterprise_catalog_uuid": "cat-data-science",
            "is_current": true,
            "expiration_date": "2026-12-31"
          }
        },
        {
          "uuid": "lic-B",
          "status": "activated",
          "activation_date": "2025-03-01",
          "subscription_plan": {
            "uuid": "plan-leadership",
            "title": "Managerial Leadership",
            "enterprise_catalog_uuid": "cat-leadership",
            "is_current": true,
            "expiration_date": "2026-12-31"
          }
        }
      ],
      "subscription_licenses_by_status": {
        "activated": ["lic-A", "lic-B"],
        "assigned": [],
        "revoked": []
      },
      "subscription_license": { "uuid": "lic-A", "..." },
      "subscription_plan": { "uuid": "plan-data-science", "..." },
      "licenses_by_catalog": {
        "cat-data-science": [{ "uuid": "lic-A", "..." }],
        "cat-leadership":   [{ "uuid": "lic-B", "..." }]
      },
      "show_expiration_notifications": false
    }
  }
}
```

---

## F. Backend Change 4 — `refresh_subscription_data` Helper (`handlers.py`)

Before multi-license, after activation/auto-apply the handler would manually patch individual keys in `context.data`. This was error-prone and didn't update `licenses_by_catalog`.

**Old pattern (removed):**
```python
self.context.data['enterprise_customer_user_subsidies']['subscriptions'].update({
    'subscription_licenses': updated_licenses,
    'subscription_license': activated_license,
    'subscription_plan': activated_license.get('subscription_plan'),
})
```

**New public method:**
```python
def refresh_subscription_data(self, subscription_licenses):
    """Rebuilds the full subscription payload in context from a flat license list."""
    subscriptions_data = self.transform_subscriptions_result({
        'results': subscription_licenses,
        'customer_agreement': self.customer_agreement,
    })
    self.context.data['enterprise_customer_user_subsidies']['subscriptions'].update(subscriptions_data)
```

**Used by:**
1. `activate_subscription_license()` — after learner activates a license via link
2. `check_and_auto_apply_license()` — after auto-assignment
3. Any code that mutates the license list

This guarantees `licenses_by_catalog` is always rebuilt consistently.

---

## G. Backend Change 5 — Scoped Algolia Key (`context.py` + `api.py`)

### Problem (before)
The secured Algolia key was fetched once on context setup with **all enterprise catalogs**, giving learners search access to everything.

### Solution (branch)
For multi-license users, the Algolia key is scoped to **only the catalogs their activated licenses cover**.

**New method `refresh_secured_algolia_api_keys(catalog_uuids=None)`:**
```python
def refresh_secured_algolia_api_keys(self, catalog_uuids=None):
    scoped_catalog_uuids = None
    if catalog_uuids is not None:
        scoped_catalog_uuids = sorted(catalog_uuids)
        if not scoped_catalog_uuids:
            # no scope → no Algolia key
            self.data.update({
                'catalog_uuids_to_catalog_query_uuids': {},
                'algolia': {'secured_algolia_api_key': None, 'valid_until': None}
            })
            return

    secured_algolia_api_key_data = get_and_cache_secured_algolia_search_keys(
        self.request,
        self._enterprise_customer_uuid,
        catalog_uuids=scoped_catalog_uuids,  # ← new param
    )
```

**Handler call after loading subscriptions:**
```python
def scope_secured_algolia_api_keys_to_activated_licenses(self):
    if enable_multi_license_entitlements_bff():
        # Multi-license: scope to ALL activated license catalogs
        scoped_licenses = self.current_activated_licenses
    else:
        # Single-license: scope to the one selected activated license
        scoped_licenses = [self.current_activated_license] if self.current_activated_license else []

    activated_catalog_uuids = {
        lic.get('subscription_plan', {}).get('enterprise_catalog_uuid')
        for lic in scoped_licenses
        if lic.get('subscription_plan', {}).get('enterprise_catalog_uuid')
    }
    self.context.refresh_secured_algolia_api_keys(catalog_uuids=activated_catalog_uuids)
```

**Example (Knotion scenario):**
```
User has:
  License A → cat-data-science  (5 courses)
  License B → cat-leadership    (3 courses)

Algolia key scoped to: {cat-data-science, cat-leadership}
→ Search returns ONLY those 8 courses (not the 500+ in the full catalog)
```

### Cache Key Update (`api.py`)

Scoped keys need separate cache slots. SHA-256 hashing keeps the key bounded (Memcached 250-byte limit):

```python
def secured_algolia_api_key_cache_key(enterprise_customer_uuid, request_user_id, catalog_uuids=None):
    if catalog_uuids is None:
        catalog_scope = 'all'
    else:
        digest = hashlib.sha256(
            ','.join(sorted(str(u) for u in catalog_uuids)).encode()
        ).hexdigest()[:16]
        catalog_scope = f'catalogs:{digest}'
    return versioned_cache_key('secured_algolia_api_key', enterprise_customer_uuid, request_user_id, catalog_scope)
```

---

## H. Backend Change 6 — `_map_courses_to_licenses` (handlers.py)

**Problem (before):** Enrollment intentions (default auto-enrollment) used the single activated license for every course, failing when a course was only in a secondary license's catalog.

**New method for multi-license path:**
```python
def _map_courses_to_licenses(self, enrollment_intentions):
    """
    Map each course to the best matching license.
    Algorithm:
      1. Build catalog index from all current activated licenses.
      2. For each enrollment intention:
         a. Collect all licenses whose catalog covers the course.
         b. Deduplicate by license UUID.
         c. Apply _select_best_license() tie-breaker (ENT-11672).
    """
    licenses_by_catalog = self._build_catalog_index(self.current_activated_licenses)

    license_uuids_by_course_run_key = {}
    for enrollment_intention in enrollment_intentions:
        course_run_key = enrollment_intention.get('course_run_key')
        applicable_catalog_uuids = enrollment_intention.get('applicable_enterprise_catalog_uuids', [])

        matching_licenses = []
        for catalog_uuid in applicable_catalog_uuids:
            matching_licenses.extend(licenses_by_catalog.get(catalog_uuid, []))

        unique_licenses = {lic['uuid']: lic for lic in matching_licenses}.values()
        if unique_licenses:
            best = self._select_best_license(list(unique_licenses))
            license_uuids_by_course_run_key[course_run_key] = best['uuid']

    return license_uuids_by_course_run_key
```

**Legacy fallback (flag OFF):** `_map_courses_to_single_license()` — maps all enrollable courses to the single `current_activated_license` if its catalog overlaps, preserving original behavior.

**Example (Knotion Learning Pathways):**
```
Default enrollment intentions:
  - course-v1:edX+DS101+2025 → applicable_catalog_uuids: [cat-data-science]
  - course-v1:edX+DS102+2025 → applicable_catalog_uuids: [cat-data-science]
  - course-v1:edX+LDR101+2025 → applicable_catalog_uuids: [cat-leadership, cat-data-science]
  - course-v1:edX+LDR102+2025 → applicable_catalog_uuids: [cat-leadership]

Learner's licenses:
  - lic-A → cat-data-science (activated 2025-01-01)
  - lic-B → cat-leadership   (activated 2025-03-01)

Result of _map_courses_to_licenses():
  {
    'course-v1:edX+DS101+2025':  'lic-A',   # only in cat-data-science
    'course-v1:edX+DS102+2025':  'lic-A',   # only in cat-data-science
    'course-v1:edX+LDR101+2025': 'lic-A',   # in both catalogs → lic-A wins (activated earlier)
    'course-v1:edX+LDR102+2025': 'lic-B',   # only in cat-leadership
  }
```

---

## I. Backend Change 7 — Serializer (`serializers.py`)

**New `licenses_by_catalog` field in `SubscriptionsSerializer`:**

```python
class SubscriptionsSerializer(BaseBffSerializer):
    # Collection-first fields (canonical for multi-license support)
    subscription_licenses = SubscriptionLicenseSerializer(many=True, required=False)
    subscription_licenses_by_status = SubscriptionLicenseStatusSerializer(required=False)

    # Pre-computed catalog index — only present when flag is ON
    licenses_by_catalog = serializers.DictField(
        child=serializers.ListField(child=SubscriptionLicenseSerializer()),
        required=False,
        allow_null=True,
        help_text="Pre-computed mapping of catalog UUID to licenses (multi-license flag ON only).",
    )

    # Legacy singular fields (backward compatibility)
    subscription_license = SubscriptionLicenseSerializer(required=False, allow_null=True)
    subscription_plan = SubscriptionPlanSerializer(required=False, allow_null=True)
    show_expiration_notifications = serializers.BooleanField(required=False, default=False)

    _MULTI_LICENSE_ONLY_FIELDS = ('licenses_by_catalog',)

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        # Drop multi-license-only fields if the handler did not include them
        if isinstance(instance, dict):
            for field in self._MULTI_LICENSE_ONLY_FIELDS:
                if field not in instance:
                    ret.pop(field, None)
        return ret
```

**Backward compatibility:** When flag is OFF, `licenses_by_catalog` is never in the source dict → `to_representation` removes it from output → old frontend clients see the same response shape as before.

---

## J. Backend Change 8 — `EnterpriseCatalogUserV1ApiClient` (`enterprise_catalog_client.py`)

Adds `catalog_uuids` query param support to the secured Algolia key endpoint:

```python
def get_secured_algolia_api_key(self, enterprise_customer_uuid, catalog_uuids=None):
    query_params = {'catalog_uuids': catalog_uuids} if catalog_uuids is not None else None
    response = self.get(
        self.secured_algolia_api_key_endpoint(enterprise_customer_uuid),
        params=query_params,
    )
    response.raise_for_status()
    return response.json()
```

**Effect:** `enterprise-catalog` service scopes the returned Algolia key to only the specified catalog UUIDs, so learners cannot search courses outside their licensed catalogs.

---

## K. Backend Change 9 — Deferred Algolia Init (`context.py` + `views`)

**Problem (before):** `HandlerContext.__init__` always fetched an unscoped Algolia key on context creation. For multi-license, this wasted a network call since the key would be immediately replaced with a scoped one.

**Solution:** New `initialize_secured_algolia_api_keys=True` constructor parameter.

```python
class HandlerContext(BaseHandlerContext):
    def __init__(self, request, initialize_secured_algolia_api_keys=True):
        # ...
        self._initialize_secured_algolia_api_keys_on_context_setup = initialize_secured_algolia_api_keys
        self._initialize_common_context_data()  # skips Algolia init if flag is False
```

**All learner portal views now pass `initialize_secured_algolia_api_keys=False`:**
```python
# learner_portal.py
self.load_route_data_and_build_response(
    request=request,
    handler_class=DashboardHandler,
    response_builder_class=LearnerDashboardResponseBuilder,
    context_kwargs={'initialize_secured_algolia_api_keys': False},  # NEW
)
```

**Optimization:** Dashboard, Search, Academy, SkillsQuiz routes all skip the redundant unscoped fetch. The handler calls `scope_secured_algolia_api_keys_to_activated_licenses()` later with the correct scoped set.

---

## L. Full Backend Call Flow (Multi-License ON)

```
HTTP GET /api/v1/learner-portal/dashboard/?enterprise_customer_slug=knotion
  │
  └── LearnerPortalBFFViewSet.dashboard()
        │
        └── load_route_data_and_build_response(
              handler_class=DashboardHandler,
              context_kwargs={'initialize_secured_algolia_api_keys': False}
            )
              │
              ├── [1] HandlerContext.__init__(initialize_secured_algolia_api_keys=False)
              │     → context.enterprise_customer resolved
              │     → NO Algolia key fetched yet (deferred)
              │
              ├── [2] BaseLearnerPortalHandler.load_and_process_subsidies()
              │     → fetch subscription_licenses from license-manager (all licenses for user)
              │     → transform_subscriptions_result()
              │         → _build_catalog_index(current_activated_licenses)
              │         → _select_best_license() → sets subscription_license (ENT-11672 rule)
              │         → response_data['licenses_by_catalog'] = { cat-A: [lic-A], cat-B: [lic-B] }
              │     → activate_subscription_license()   [if assigned licenses pending]
              │         → refresh_subscription_data(updated_licenses)  [rebuilds all fields]
              │     → check_and_auto_apply_license()  [if auto-apply eligible]
              │         → refresh_subscription_data(licenses + [auto_applied])
              │
              ├── [3] scope_secured_algolia_api_keys_to_activated_licenses()
              │     → activated_catalog_uuids = { cat-data-science, cat-leadership }
              │     → context.refresh_secured_algolia_api_keys(catalog_uuids={...})
              │         → get_secured_algolia_api_key(enterprise_uuid, catalog_uuids=[...])
              │         → cached under key: hash(sorted(catalog_uuids))
              │
              ├── [4] load_default_enterprise_enrollment_intentions()
              │     → fetch enrollment intentions for learner
              │
              └── [5] enroll_in_redeemable_default_enterprise_enrollment_intentions()
                    → multi_license_flag_enabled=True
                    → _map_courses_to_licenses(needs_enrollment_enrollable)
                        → for each course: find matching licenses by catalog
                        → _select_best_license() → tie-break
                    → _request_default_enrollment_realizations(course → license_uuid map)
                        → POST to LMS: bulk enroll with per-course license UUIDs
```

---

## M. Backend Test Coverage (`test_multi_license.py` — 686 lines)

| Test Class | Cases | What Is Tested |
|---|---|---|
| `TestBuildCatalogIndex` | 6 | Empty, single, multi-catalog, missing UUID, duplicate licenses |
| `TestSelectBestLicense` | 8 | Single license, earlier activation wins, later expiration wins, UUID fallback |
| `TestMapCoursesToLicenses` | 10 | One license, multi-license, course in both catalogs, no activated licenses |
| `TestTransformSubscriptionsResult` | 8 | Flag ON/OFF, `licenses_by_catalog` presence, ENT-11672 selection rule |
| `TestScopeAlgoliaKeys` | 6 | Multi-license scoping, single-license fallback, empty catalogs |
| `TestRefreshSubscriptionData` | 4 | Full rebuild after activation, includes `licenses_by_catalog` |
| `TestActivationEnrollmentFlow` | 6 | End-to-end: activate second license while first is active |

---

## N. Backend vs Frontend Alignment

| Concern | Backend (enterprise-access) | Frontend (learner-portal) |
|---|---|---|
| Data source | BFF builds `licenses_by_catalog` | Consumes `licenses_by_catalog` from BFF |
| Feature flag | `enterprise_access.enable_multi_license_entitlements_bff` (waffle) | `enterpriseFeatures.enableMultiLicenseEntitlementsBff` (passed in BFF response) |
| Flag location | Django WaffleFlag on backend | Backend includes flag value in `enterpriseFeatures` response field |
| Tie-break rule | `_select_best_license()` (earliest activation) | `selectBestLicense()` (same logic, JS) |
| Catalog index build | `_build_catalog_index()` (on BFF response) | `buildCatalogIndex()` (for direct API path fallback) |
| Algolia scope | Backend scopes the Algolia API key to activated catalogs | Frontend uses `Object.keys(licensesByCatalog)` for Algolia filters |
| Backward compat | Flag OFF → no `licenses_by_catalog` in response | Flag OFF → strips `licensesByCatalog`, falls back to single-license |

---

## O. Knotion Use Case — End-to-End Walkthrough

### Setup
```
Enterprise: Knotion (enterprise-uuid-knotion)

SubscriptionPlan A: "Data Science Essentials"
  enterprise_catalog_uuid: cat-data-science
  Courses in catalog: DS101, DS102, DS103, DS104, DS105

SubscriptionPlan B: "Managerial Leadership"
  enterprise_catalog_uuid: cat-leadership
  Courses in catalog: LDR101, LDR102, LDR103

Learner: maria@knotion.com
  License A (Plan A, activated 2025-01-15) → Data Science access
  License B (Plan B, activated 2025-04-01) → Leadership access
```

### BFF Response (flag ON)

```json
{
  "subscription_licenses": [
    { "uuid": "lic-A", "activation_date": "2025-01-15", "subscription_plan": { "enterprise_catalog_uuid": "cat-data-science", "is_current": true } },
    { "uuid": "lic-B", "activation_date": "2025-04-01", "subscription_plan": { "enterprise_catalog_uuid": "cat-leadership",   "is_current": true } }
  ],
  "subscription_license": { "uuid": "lic-A" },
  "licenses_by_catalog": {
    "cat-data-science": [{ "uuid": "lic-A" }],
    "cat-leadership":   [{ "uuid": "lic-B" }]
  }
}
```

### Algolia Search Result
Scoped to `{cat-data-science, cat-leadership}`:
- Maria sees DS101–DS105 + LDR101–LDR103 → **8 courses total**
- Maria does NOT see the 500+ courses in other enterprise catalogs

### Course Eligibility Check (Frontend)
```
Maria visits course DS102:
  catalogsWithCourse = ['cat-data-science']
  resolveApplicableSubscriptionLicense(...)
    → findSubscriptionLicenseForCourseCatalogs(['cat-data-science'], licensesByCatalog)
    → returns lic-A
  → Eligible: YES (via lic-A)

Maria visits LDR101:
  catalogsWithCourse = ['cat-leadership']
  resolveApplicableSubscriptionLicense(...)
    → returns lic-B
  → Eligible: YES (via lic-B)

Maria tries a course outside her catalogs:
  catalogsWithCourse = ['cat-full-enterprise']
  resolveApplicableSubscriptionLicense(...)
    → returns null
  → Eligible: NO (no license covers this catalog)
```

---

## P. Gaps / Items Verified vs Project Brief

| Project Brief Item | Backend Status | Notes |
|---|---|---|
| Refactor BFF to return all active licenses (not just first) | ✅ Implemented | `subscription_licenses[]` already existed; `licenses_by_catalog` is new |
| `licenses_by_catalog` index for O(1) course-to-license lookup | ✅ Implemented | `_build_catalog_index()` + serializer field |
| Scoped Algolia key to activated license catalogs | ✅ Implemented | `scope_secured_algolia_api_keys_to_activated_licenses()` |
| Per-course enrollment mapped to correct license (ENT-11672) | ✅ Implemented | `_map_courses_to_licenses()` + `_select_best_license()` |
| Activation of second license when first is already active | ✅ Implemented | `activate_subscription_license()` iterates all assigned licenses |
| Feature flag gating for backward compatibility | ✅ Implemented | `enable_multi_license_entitlements_bff` waffle flag |
| `restrict_catalog_access` at platform level | ⚠️ Partial | Algolia scoped; LMS enrollment uses per-license UUID; full restrict_catalog_access flag at LMS level is **out of scope here** |
| Support tool reflects all license statuses | ❓ Not verified | Support tool (django admin) not updated in this commit — needs separate check |
| Multi-enterprise access | ❌ Out of scope | Single enterprise only per PRD |
