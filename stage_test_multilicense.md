# Multiplex Subscription Testing Guide

**Enterprise:** `alberto-company-test-10`  
**Enterprise UUID:** `19aaee56-e2f8-46e6-aa35-7f1db205a6ff`  
**Learner:** `rgopalrao-sonata@2u.com`  
**Customer Agreement UUID:** `c771feb0-4de5-4319-a9f3-fb7e42a8b202`

---

## Active Licenses & Catalogs

| # | Plan Title | Plan UUID | Catalog UUID | Type | Auto-Apply |
|---|---|---|---|---|---|
| 1 | Multilicense subscription test plan | `8e5c18a0-d9e1-4cb5-a6fc-1a664e45bf0b` | `d9d84c82-2b7f-4bab-94bd-8514ced3e5ad` | Test | ✅ Yes |
| 2 | Multilicense sibscription plan | `75c92c53-5fdc-4c38-9100-17aabd2e3b00` | `7a495a16-55c3-43f7-b846-2440f52837df` | Test | No |
| 3 | Alberto Company Test 10 TRIAL (Teams) | `dec37e15-b3b2-45d9-a97f-073ed335772b` | `b772212c-cbb6-43dc-bbc2-aa19f4b48277` | Trial | No |

**All 3 licenses expire:** `2026-06-30`

---

## Frontend URL

```
https://learner.stage.edx.org/alberto-company-test-10/
```

---

## Test Scenarios

### Scenario 1: Single License Behavior

Verify the system correctly identifies the "primary" license.

- The `subscription_license` field returns **Plan 3 (Trial)** as the primary license
- **Expected:** Learner portal shows Trial plan as the active subscription in the UI

**Steps:**
1. Log in as `rgopalrao-sonata@2u.com`
2. Go to `https://learner.stage.edx.org/alberto-company-test-10/`
3. Check the subscription banner/sidebar — should show active subscription
4. Verify expiry date shown is `June 30, 2026`

---

### Scenario 2: Multi-License — All 3 Catalogs Accessible

Verify courses from all 3 catalogs are accessible (no payment wall).

**Steps:**
1. Go to `https://learner.stage.edx.org/alberto-company-test-10/search`
2. The search results should include courses from **all 3 catalogs combined**
3. Pick one course from each catalog (see API calls below to find courses)
4. Click **Enroll** on each → should enroll without a payment prompt

**Get courses per catalog:**
```
# Catalog 1 — Plan 3 (Trial)
GET https://enterprise-catalog-internal.stage.edx.org/api/v1/enterprise-catalogs/b772212c-cbb6-43dc-bbc2-aa19f4b48277/get_content_metadata?content_type=course&limit=5

# Catalog 2 — Plan 2
GET https://enterprise-catalog-internal.stage.edx.org/api/v1/enterprise-catalogs/7a495a16-55c3-43f7-b846-2440f52837df/get_content_metadata?content_type=course&limit=5

# Catalog 3 — Plan 1 (Auto-apply)
GET https://enterprise-catalog-internal.stage.edx.org/api/v1/enterprise-catalogs/d9d84c82-2b7f-4bab-94bd-8514ced3e5ad/get_content_metadata?content_type=course&limit=5
```

---

### Scenario 3: Course NOT in Any Catalog

Verify a course outside all 3 catalogs shows a payment/upgrade prompt.

**Steps:**
1. Find a course key that does NOT appear in catalogs `b772212c`, `7a495a16`, or `d9d84c82`
2. Navigate directly to the course page
3. **Expected:** Payment prompt or "Not available" message — no free enroll button

**Check if course is in a catalog:**
```
GET https://enterprise-catalog-internal.stage.edx.org/api/v1/enterprise-catalogs/b772212c-cbb6-43dc-bbc2-aa19f4b48277/contains_content_items/?course_run_ids=course-v1:<ORG>+<COURSE>+<RUN>
```

---

### Scenario 4: Auto-Apply License (Plan 1)

Verify that a new learner joining the enterprise automatically gets a license from Plan 1.

- Plan 1 (`8e5c18a0`) has `should_auto_apply_licenses: true`
- `subscription_for_auto_applied_licenses` on the Customer Agreement = `8e5c18a0`

**Steps:**
1. Create a new test user and add them to enterprise `19aaee56`
2. Log in as that new user at `https://learner.stage.edx.org/alberto-company-test-10/`
3. **Expected:** User automatically gets an activated license under Plan 1 (`d9d84c82` catalog)
4. Verify via License Manager admin:
   ```
   https://license-manager-internal.stage.edx.org/admin/subscriptions/license/?subscription_plan__uuid=8e5c18a0-d9e1-4cb5-a6fc-1a664e45bf0b
   ```

---

### Scenario 5: `licenses_by_catalog` Mapping Verification

Confirm the API correctly maps each license to its catalog.

**Expected `licenses_by_catalog` structure:**
```json
{
  "d9d84c82-2b7f-4bab-94bd-8514ced3e5ad": [ /* license 1b1d1c36 */ ],
  "7a495a16-55c3-43f7-b846-2440f52837df": [ /* license bbff9c8e */ ],
  "b772212c-cbb6-43dc-bbc2-aa19f4b48277": [ /* license 022ba686 */ ]
}
```

**How to verify:**
Call the enterprise learner BFF endpoint and check `enterprise_customer_user_subsidies.subscriptions.licenses_by_catalog` — should contain all 3 catalogs with 1 license each.

---

## Test Checklist

| # | Test | Expected Result | Pass/Fail |
|---|---|---|---|
| 1 | Learner portal loads for `alberto-company-test-10` | Shows active subscription banner | |
| 2 | `subscription_licenses` returns 3 entries | 3 activated licenses | |
| 3 | `licenses_by_catalog` has 3 catalog keys | 3 catalog → license mappings | |
| 4 | Enroll in course from catalog `b772212c` | No payment prompt | |
| 5 | Enroll in course from catalog `7a495a16` | No payment prompt | |
| 6 | Enroll in course from catalog `d9d84c82` | No payment prompt | |
| 7 | Enroll in course NOT in any catalog | Payment/upgrade prompt shown | |
| 8 | New user joins enterprise | Auto-assigned license from Plan 1 | |
| 9 | Search shows courses from all 3 catalogs combined | Combined catalog results visible | |

---

## Known Issue / Warning

The API response contains a serialization warning for **Pied Piper** enterprise's `active_integrations`:

```
active_integrations.created/modified fields use "August 20, 2020" format 
instead of ISO 8601 — causes datetime serialization error.
```

This affects the `all_linked_enterprise_customer_users` list but does **not** block subscription testing.

---

## Useful Admin Links

| Service | URL |
|---|---|
| License Manager — Customer Agreement | `https://license-manager-internal.stage.edx.org/admin/subscriptions/customeragreement/c771feb0-4de5-4319-a9f3-fb7e42a8b202/` |
| License Manager — Plan 1 (Auto-apply) | `https://license-manager-internal.stage.edx.org/admin/subscriptions/subscriptionplan/8e5c18a0-d9e1-4cb5-a6fc-1a664e45bf0b/` |
| License Manager — Plan 2 | `https://license-manager-internal.stage.edx.org/admin/subscriptions/subscriptionplan/75c92c53-5fdc-4c38-9100-17aabd2e3b00/` |
| License Manager — Plan 3 (Trial) | `https://license-manager-internal.stage.edx.org/admin/subscriptions/subscriptionplan/dec37e15-b3b2-45d9-a97f-073ed335772b/` |
| Enterprise Catalog — Catalog 1 | `https://enterprise-catalog-internal.stage.edx.org/admin/catalog/enterprisecatalog/b772212c-cbb6-43dc-bbc2-aa19f4b48277/` |
| Enterprise Catalog — Catalog 2 | `https://enterprise-catalog-internal.stage.edx.org/admin/catalog/enterprisecatalog/7a495a16-55c3-43f7-b846-2440f52837df/` |
| Enterprise Catalog — Catalog 3 | `https://enterprise-catalog-internal.stage.edx.org/admin/catalog/enterprisecatalog/d9d84c82-2b7f-4bab-94bd-8514ced3e5ad/` |
