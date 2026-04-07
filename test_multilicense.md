# User Course Access Table

> Generated: April 7, 2026  
> Enterprise: `test-multi-enterprise` (`aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`)

---

## Catalog → Course Mapping

| Catalog UUID | Catalog Name | Courses |
|---|---|---|
| `11111111...` | Leadership Training Catalog | `edX+DemoX` (Demonstration Course), `edX+M12` (Differential Equations) |
| `22222222...` | Technical Skills Catalog | `edX+DemoX` (Demonstration Course), `SONATA+123` (Python datascience) |
| `33333333...` | Compliance Training Catalog | `edX+DemoX` (Demonstration Course) |
| `44444444...` | Data Science Catalog | `edX+P315` (Quantum Entanglement) |
| `55555555...` | Business & Strategy Catalog | `edX+M12` (Differential Equations) |

---

## Subscription Plan → Catalog → Courses (Quick Reference)

| Plan Title | Catalog | edX+DemoX | edX+M12 | edX+P315 | SONATA+123 |
|---|---|:---:|:---:|:---:|:---:|
| Test Multi: Leadership Training | `11111111...` | ✅ | ✅ | ❌ | ❌ |
| Test Multi: Technical Training  | `22222222...` | ✅ | ❌ | ❌ | ✅ |
| Test Multi: Compliance Training | `33333333...` | ✅ | ❌ | ❌ | ❌ |
| Test Multi: Data Science        | `44444444...` | ❌ | ❌ | ✅ | ❌ |
| Test Multi: Business Skills     | `55555555...` | ❌ | ✅ | ❌ | ❌ |

---

## User License Assignments

| User | Plans Assigned |
|---|---|
| test-multi-alice | Leadership, Technical, Compliance |
| test-multi-bob | Leadership, Technical |
| test-multi-carol | Leadership, Technical, Compliance, Data Science, Business |
| test-multi-dave | Data Science |
| test-multi-eve | *(no license found)* |
| test-dual-analyst01 | Leadership, Data Science |
| test-dual-engineer01 | Technical, Business |
| test-dual-manager01 | Leadership, Compliance |
| test-dual-bizanalyst01 | Data Science, Business |
| test-dual-itpro01 | Technical, Compliance |
| test-dual-exec01 | Leadership, Business |
| test-dual-mlengineer01 | Technical, Data Science |
| test-dual-compliance01 | Compliance, Business |
| test-dual-techlead01 | Leadership, Technical |
| test-dual-datascientist01 | Compliance, Data Science |
| test-dual-dataleader01 | Leadership, Data Science |
| test-dual-producteng01 | Technical, Business |

---

## Course Access — OLD Code (Single License / `main` branch)

> **Old behavior:** enterprise-access on `main` calls `_extract_subscription_license()` which returns **only one** activated license.  
> For users with multiple licenses, whichever license happened to be returned first from the license-manager API was used — the others were silently ignored.  
> ⚠️ = Access depends on which single license the API happened to return first (non-deterministic for test data with same activation dates).

| User | Effective Plan (Old) | edX+DemoX | edX+M12 | edX+P315 | SONATA+123 |
|---|---|:---:|:---:|:---:|:---:|
| test-multi-alice | ⚠️ Leadership OR Technical OR Compliance | ✅ | ⚠️ | ❌ | ⚠️ |
| test-multi-bob | ⚠️ Leadership OR Technical | ✅ | ⚠️ | ❌ | ⚠️ |
| test-multi-carol | ⚠️ Any one of 5 plans | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| test-multi-dave | Data Science (only) | ❌ | ❌ | ✅ | ❌ |
| test-multi-eve | *(no license)* | ❌ | ❌ | ❌ | ❌ |
| test-dual-analyst01 | ⚠️ Leadership OR Data Science | ⚠️ | ⚠️ | ⚠️ | ❌ |
| test-dual-engineer01 | ⚠️ Technical OR Business | ⚠️ | ⚠️ | ❌ | ⚠️ |
| test-dual-manager01 | ⚠️ Leadership OR Compliance | ✅ | ⚠️ | ❌ | ❌ |
| test-dual-bizanalyst01 | ⚠️ Data Science OR Business | ❌ | ⚠️ | ⚠️ | ❌ |
| test-dual-itpro01 | ⚠️ Technical OR Compliance | ✅ | ❌ | ❌ | ⚠️ |
| test-dual-exec01 | ⚠️ Leadership OR Business | ⚠️ | ✅ | ❌ | ❌ |
| test-dual-mlengineer01 | ⚠️ Technical OR Data Science | ⚠️ | ❌ | ⚠️ | ⚠️ |
| test-dual-compliance01 | ⚠️ Compliance OR Business | ⚠️ | ⚠️ | ❌ | ❌ |
| test-dual-techlead01 | ⚠️ Leadership OR Technical | ✅ | ⚠️ | ❌ | ⚠️ |
| test-dual-datascientist01 | ⚠️ Compliance OR Data Science | ⚠️ | ❌ | ⚠️ | ❌ |
| test-dual-dataleader01 | ⚠️ Leadership OR Data Science | ⚠️ | ⚠️ | ⚠️ | ❌ |
| test-dual-producteng01 | ⚠️ Technical OR Business | ⚠️ | ⚠️ | ❌ | ⚠️ |

---

## Course Access — NEW Code (Multi-License / `rgopalrao/ENT-11683` branch)

> **New behavior:** enterprise-access on `rgopalrao/ENT-11683` returns **all activated licenses**.  
> The frontend builds `licensesByCatalog` index and resolves the applicable license per course via `resolveApplicableSubscriptionLicense()`.  
> A user can access a course if **any** of their activated licenses covers a catalog that contains the course.

| User | Active Plans | edX+DemoX | edX+M12 | edX+P315 | SONATA+123 |
|---|---|:---:|:---:|:---:|:---:|
| test-multi-alice | Leadership ✚ Technical ✚ Compliance | ✅ | ✅ | ❌ | ✅ |
| test-multi-bob | Leadership ✚ Technical | ✅ | ✅ | ❌ | ✅ |
| test-multi-carol | Leadership ✚ Technical ✚ Compliance ✚ Data Science ✚ Business | ✅ | ✅ | ✅ | ✅ |
| test-multi-dave | Data Science | ❌ | ❌ | ✅ | ❌ |
| test-multi-eve | *(no license)* | ❌ | ❌ | ❌ | ❌ |
| test-dual-analyst01 | Leadership ✚ Data Science | ✅ | ✅ | ✅ | ❌ |
| test-dual-engineer01 | Technical ✚ Business | ✅ | ✅ | ❌ | ✅ |
| test-dual-manager01 | Leadership ✚ Compliance | ✅ | ✅ | ❌ | ❌ |
| test-dual-bizanalyst01 | Data Science ✚ Business | ❌ | ✅ | ✅ | ❌ |
| test-dual-itpro01 | Technical ✚ Compliance | ✅ | ❌ | ❌ | ✅ |
| test-dual-exec01 | Leadership ✚ Business | ✅ | ✅ | ❌ | ❌ |
| test-dual-mlengineer01 | Technical ✚ Data Science | ✅ | ❌ | ✅ | ✅ |
| test-dual-compliance01 | Compliance ✚ Business | ✅ | ✅ | ❌ | ❌ |
| test-dual-techlead01 | Leadership ✚ Technical | ✅ | ✅ | ❌ | ✅ |
| test-dual-datascientist01 | Compliance ✚ Data Science | ✅ | ❌ | ✅ | ❌ |
| test-dual-dataleader01 | Leadership ✚ Data Science | ✅ | ✅ | ✅ | ❌ |
| test-dual-producteng01 | Technical ✚ Business | ✅ | ✅ | ❌ | ✅ |

---

## Key Differences Summary

| User | Old Code Issue | New Code Fix |
|---|---|---|
| test-multi-alice | Only 1 of 3 plans used — may miss edX+M12 or SONATA+123 | All 3 plans → full access |
| test-multi-bob | Only 1 of 2 plans used — may miss edX+M12 or SONATA+123 | Both plans → full access |
| test-multi-carol | Only 1 of 5 plans used — significant restriction | All 5 plans → full access |
| test-dual-analyst01 | May miss edX+DemoX if Data Science picked first | Leadership covers DemoX ✅ |
| test-dual-engineer01 | May miss edX+DemoX if Business picked first | Technical covers DemoX ✅ |
| test-dual-bizanalyst01 | May miss edX+P315 if Business picked first | Data Science covers P315 ✅ |
| test-dual-mlengineer01 | May miss edX+P315 or SONATA+123 | Both catalogs accessible ✅ |
| test-dual-datascientist01 | May miss edX+DemoX if Data Science picked first | Compliance covers DemoX ✅ |
| Single-license users (dave, eve) | No change — single license is deterministic | Same result |
