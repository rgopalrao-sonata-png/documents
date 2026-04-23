# Multi-License Testing via Django Admin
**User:** `rgopalrao`

---

## Step 1 — Create Enterprise Customer (if not exists)
**URL:** `http://localhost:18000/admin/enterprise/enterprisecustomer/add/`

| Field | Example Value |
|---|---|
| `name` | `rgopalrao-enterprise` |
| `slug` | `rgopalrao-enterprise` |
| `uuid` | _(auto-generated, copy it for later)_ |
| `active` | ✅ |

> **Copy the enterprise UUID** — you'll need it in all following steps.

---

## Step 2 — Create Enterprise Customer User
**URL:** `http://localhost:18000/admin/enterprise/enterprisecustomeruser/add/`

| Field | Example Value |
|---|---|
| `enterprise_customer` | `rgopalrao-enterprise` |
| `username` | `rgopalrao` |

---

## Step 3 — Create Customer Agreement
**URL:** `http://localhost:18170/admin/subscriptions/customeragreement/add/`

| Field | Example Value |
|---|---|
| `enterprise_customer_uuid` | _(UUID from Step 1)_ |
| `enterprise_customer_slug` | `rgopalrao-enterprise` |

---

## Step 4 — Create Subscription Plan A (License 1)
**URL:** `http://localhost:18170/admin/subscriptions/subscriptionplan/add/`

| Field | Example Value |
|---|---|
| `title` | `rgopalrao-plan-A` |
| `customer_agreement` | _(from Step 3)_ |
| `enterprise_catalog_uuid` | _(your catalog UUID)_ |
| `start_date` | `2026-01-01` |
| `expiration_date` | `2027-01-01` |
| `num_licenses` | `5` |
| `is_active` | ✅ |

---

## Step 5 — Create Subscription Plan B (License 2 — for Multi-License)
**URL:** `http://localhost:18170/admin/subscriptions/subscriptionplan/add/`

| Field | Example Value |
|---|---|
| `title` | `rgopalrao-plan-B` |
| `customer_agreement` | _(from Step 3)_ |
| `enterprise_catalog_uuid` | _(a different catalog UUID)_ |
| `start_date` | `2026-01-01` |
| `expiration_date` | `2027-01-01` |
| `num_licenses` | `5` |
| `is_active` | ✅ |

---

## Step 6 — Assign License to User (Plan A)
**URL:** `http://localhost:18170/admin/subscriptions/license/`

1. Find an **unassigned** license under `rgopalrao-plan-A`
2. Click on it
3. Set:
   - `user_email` → `rgopalrao@example.com`
   - `status` → `activated`
   - `activation_date` → `2026-04-23`
4. Click **Save**

---

## Step 7 — Assign License to User (Plan B)
Repeat Step 6 but find an unassigned license under `rgopalrao-plan-B`.

> This gives `rgopalrao` **two active licenses** = multi-license scenario ✅

---

## Step 8 — Add Courses to Catalog (linked to Plan A)
**URL:** `http://localhost:18381/admin/catalog/enterprisecatalog/`

1. Find the catalog linked to `rgopalrao-plan-A`
2. Click into it
3. Add courses via **Content Filters** or associate a **CatalogQuery**

---

## Step 9 — Verify Multi-License Setup
**URL:** `http://localhost:18170/admin/subscriptions/license/?q=rgopalrao@example.com`

Confirm:
- ✅ Two licenses with `status=activated`
- ✅ Each license under a different subscription plan
- ✅ Each plan linked to a different catalog

---

## Step 10 — Test Access
**URL:** `http://localhost:18170/api/v1/learner-licenses/?enterprise_customer_uuid=<uuid>`

Expected response: **2 licenses** returned for `rgopalrao` — one per plan.

---

## Summary

```
rgopalrao-enterprise
    └── Customer Agreement
            ├── rgopalrao-plan-A  →  Catalog A  →  License (activated) → rgopalrao
            └── rgopalrao-plan-B  →  Catalog B  →  License (activated) → rgopalrao
```

`rgopalrao` now has **multi-license access** — one per subscription plan. ✅
