# Multi-license course access: old vs new

## Summary

The old frontend already exposed `subscriptionLicenses`, so a learner could appear to have multiple licenses in the payload.

The main change is **not** that the UI suddenly started receiving multiple licenses.

The real changes are:

1. **Explicit catalog-to-license mapping** via `licensesByCatalog`
2. **Consistent behavior in BFF flag-off mode** by rebuilding `licensesByCatalog` client-side when needed
3. **Correct activation behavior for multiple assigned licenses**, instead of stopping after the first activated license

---

## Old behavior

### Data available
The old flow could already use:
- `subscriptionLicense`
- `subscriptionLicenses`

### Course access resolution
Course access was resolved by checking whether any activated/current subscription license matched one of the course catalogs.

This meant the system could still resolve access from a flat list of licenses.

### Limitations
1. **No explicit catalog index from the BFF in flag-off mode**
   - `licensesByCatalog` came back empty from the backend
   - frontend had to rely on scanning the flat license list

2. **Activation stopped too early**
   - if the learner already had one activated license, activation flow returned early
   - additional assigned licenses were blocked from activation

3. **Course access could look correct only for already-activated licenses**
   - if a learner had another assigned license that never got activated, its catalog was effectively missing from real access

---

## New behavior

### Data available
The new flow uses:
- `subscriptionLicense`
- `subscriptionLicenses`
- `licensesByCatalog`
- `licenseSchemaVersion`

### Course access resolution
The new resolution order is:

1. Try `licensesByCatalog`
2. If that is missing or empty, fall back to scanning `subscriptionLicenses`

This makes course-to-license resolution more explicit and stable.

### Improvements
1. **Catalog mapping is explicit**
   - licenses are grouped by enterprise catalog UUID
   - course access can use direct catalog lookup first

2. **BFF flag-off mode still works correctly**
   - when backend returns `licensesByCatalog: {}` in v1 mode,
   - frontend rebuilds the index from `subscriptionLicenses`

3. **Multiple assigned licenses can now activate properly**
   - having one activated license no longer blocks activation of another current assigned license

---

## What changed functionally

## Before
A course was effectively checked against a flat list of activated/current licenses.

That is roughly:

```text
course catalogs -> scan all active licenses -> choose best matching license
```

## After
A course is first checked against a catalog index.

That is roughly:

```text
course catalogs -> lookup licensesByCatalog[catalogUuid] -> choose best matching license
```

If the index is unavailable, the frontend still falls back to the flat scan.

---

## Metrics

## 1. Access-related fields in the effective frontend model

### Old
- `subscriptionLicense`
- `subscriptionLicenses`

### New
- `subscriptionLicense`
- `subscriptionLicenses`
- `licensesByCatalog`
- `licenseSchemaVersion`

**Metric:** usable access fields increased from **2** to **4**.

---

## 2. BFF flag-off indexed catalog coverage

### Old
- backend returned `licensesByCatalog = {}`
- indexed catalog coverage from BFF = **0**

### New
- frontend rebuilds `licensesByCatalog` from active licenses
- indexed catalog coverage = **all catalogs represented by activated current licenses**

Examples:
- Alice: **3** catalog keys
- Bob: **2** catalog keys
- Carol: **5** catalog keys
- Dave: **1** catalog key

---

## 3. Activation capacity

### Old
- one already-activated license could block activation of additional assigned licenses
- practical learner-flow activation capacity: **1 active license before early exit**

### New
- a learner can continue activating another current assigned license
- practical learner-flow activation capacity: **all current assigned licenses**

---

## 4. License lookup complexity

### Old common path
- scan all active licenses
- approximate complexity: `O(n)`

### New preferred path
- direct catalog lookup in `licensesByCatalog`
- approximate first-step lookup: `O(1)` per catalog bucket, then choose best candidate

This is a performance and clarity improvement, but the larger benefit is correctness and consistency.

---

## Seeded user examples

Known catalog assignments from seeded test users:

- `11111111111111111111111111111111` = Leadership
- `22222222222222222222222222222222` = Technical
- `33333333333333333333333333333333` = Compliance
- `44444444444444444444444444444444` = Data Science
- `55555555555555555555555555555555` = Business Skills

### User license coverage

| User | Covered catalogs |
|---|---|
| Alice | 11, 22, 33 |
| Bob | 11, 22 |
| Carol | 11, 22, 33, 44, 55 |
| Dave | 44 |

---

## Example: `edX+P315`

`edX+P315` belongs to the **Data Science** catalog (`44444444444444444444444444444444`).

### Old vs new outcome

| User | Old behavior | New behavior | Notes |
|---|---|---|---|
| Alice | No access | No access | No Data Science license |
| Bob | No access | No access | No Data Science license |
| Carol | Access | Access | Data Science license exists |
| Dave | Access | Access | Data Science license exists |

### Important interpretation
For already-activated licenses, **the visible course access result may look the same**.

That is why it can feel like “the old one was also showing subscription licenses.”

That observation is correct.

The actual improvement is that:
- the mapping is explicit,
- the BFF flag-off path no longer loses the mapping,
- and later assigned licenses are no longer blocked from activation.

---

## What is materially different now

The meaningful difference is not just payload display.

It is the move from:

```text
"we have a flat list of licenses and try to infer access"
```

to:

```text
"we explicitly know which catalogs map to which licenses, and we do not block further valid license activation"
```

---

## Bottom line

### If the question is:
**Did the old frontend already show subscription licenses?**

Yes.

### If the question is:
**Did the old frontend already always support correct multi-license course access?**

Not reliably.

### The new implementation specifically improves:
1. explicit catalog mapping,
2. flag-off BFF compatibility,
3. multi-license activation flow,
4. consistency between BFF and non-BFF paths.
