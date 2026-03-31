# Multi-License Testing Checklist

## Purpose

This checklist helps validate multi-license behavior for these learners:

- `test-multi-alice@example.com`
- `test-multi-bob@example.com`
- `test-multi-carol@example.com`
- `test-multi-dave@example.com`
- `test-multi-eve@example.com`

It covers:

1. Support Tools license verification
2. Learner Portal course access verification
3. Pass/fail recording

---

## Important Notes

- Support Tools only shows raw license records.
- Support Tools does **not** prove course-level applicability.
- Learner Portal is where course-to-license access is validated.
- Use **admin login** for Support Tools.
- Use **learner login** for Learner Portal.
- Use separate browser sessions/incognito windows to avoid cookie conflicts.

---

## URLs

- Support Tools: `http://localhost:18450`
- Learner Portal: `http://localhost:8734/<enterprise-slug>`
- LMS Login: `http://localhost:18000/login`
- LMS Logout: `http://localhost:18000/logout`

---

## One-Time Setup Checklist

- [ ] Local devstack services are running
- [ ] `enterprise-access` is reachable
- [ ] `license-manager` is reachable
- [ ] multi-license seed data is loaded
- [ ] admin user can access Support Tools
- [ ] learner portal loads without BFF errors

---

## Testing Flow

### A. Support Tools Verification

1. Open Support Tools at `http://localhost:18450`
2. Log in as an admin user
3. Search for the learner by email
4. Open **Learner Information**
5. Open **SSO/License Info**
6. Record:
	- total license count
	- status of each license
	- activation date
	- expiration date
	- plan title

### B. Learner Portal Verification

1. Open a separate browser session
2. Log in as the learner
3. Open `http://localhost:8734/<enterprise-slug>`
4. Go to Search
5. Search for a course from each expected licensed catalog
6. Open each course page
7. Confirm whether license-based access is shown
8. Test one negative course outside the learner's license coverage

### C. Expected Result Pattern

- matching licensed catalog course => license access available
- non-matching course => no subscription license access

---

## User-by-User Checklist

## Direct Course URLs

Enterprise slug used by the seed data:

- `test-multi-enterprise`

### Shared direct course URLs

- Leadership: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+LEADER101+2024`
- Leadership 2: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+LEADER201+2024`
- Technical: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+TECH101+2024`
- Technical 2: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+TECH201+2024`
- Compliance: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+COMP101+2024`
- Data Science: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+DS101+2024`
- Data Science 2: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+DS201+2024`
- Business: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+BUS101+2024`
- Multi-catalog: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+MULTI101+2024`
- Universal: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+UNIVERSAL+2024`

### Course coverage by learner

#### Alice

- Leadership: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+LEADER101+2024`
- Technical: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+TECH101+2024`
- Compliance: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+COMP101+2024`
- Negative case: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+DS101+2024`
- Tie-break case: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+MULTI101+2024`

#### Bob

- Technical: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+TECH101+2024`
- Compliance: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+COMP101+2024`
- Data Science: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+DS101+2024`
- Business: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+BUS101+2024`
- Universal: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+UNIVERSAL+2024`

#### Carol

- Leadership: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+LEADER101+2024`
- Technical: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+TECH101+2024`
- Compliance: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+COMP101+2024`
- Data Science: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+DS101+2024`
- Business: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+BUS101+2024`
- Universal: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+UNIVERSAL+2024`

#### Dave

- Activated path: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+LEADER101+2024`
- Assigned path 1: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+TECH101+2024`
- Assigned path 2: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+COMP101+2024`

#### Eve

- Overlap / tie-break: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+MULTI101+2024`
- Universal: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+UNIVERSAL+2024`
- Leadership: `http://localhost:8734/test-multi-enterprise/course/course-v1:TestOrg+LEADER101+2024`

---

## 1. Alice

**User**

- `test-multi-alice@example.com`

**Expected licenses**

- 3 total
- 3 activated
- Coverage: Leadership, Technical, Compliance

### Support Tools

- [ ] User found
- [ ] SSO/License Info tab opens
- [ ] 3 license records visible
- [ ] all 3 licenses are activated
- [ ] plan titles look correct

### Learner Portal

- [ ] Leadership course found
- [ ] Leadership course shows license access
- [ ] Technical course found
- [ ] Technical course shows license access
- [ ] Compliance course found
- [ ] Compliance course shows license access
- [ ] non-matching course found
- [ ] non-matching course does **not** show license access

**Actual Notes**

- Support Tools: __________
- Learner Portal: __________
- Final Result: PASS / FAIL

---

## 2. Bob

**User**

- `test-multi-bob@example.com`

**Expected licenses**

- 4 total
- 4 activated
- Coverage: Technical, Compliance, Data Science, Business

### Support Tools

- [ ] User found
- [ ] 4 license records visible
- [ ] all 4 licenses are activated

### Learner Portal

- [ ] Technical course shows license access
- [ ] Compliance course shows license access
- [ ] Data Science course shows license access
- [ ] Business course shows license access
- [ ] non-matching course does **not** show license access

**Actual Notes**

- Support Tools: __________
- Learner Portal: __________
- Final Result: PASS / FAIL

---

## 3. Carol

**User**

- `test-multi-carol@example.com`

**Expected licenses**

- 5 total
- 5 activated
- Coverage: all seeded catalogs

### Support Tools

- [ ] User found
- [ ] 5 license records visible
- [ ] all 5 licenses are activated

### Learner Portal

- [ ] Catalog 1 course shows license access
- [ ] Catalog 2 course shows license access
- [ ] Catalog 3 course shows license access
- [ ] Catalog 4 course shows license access
- [ ] Catalog 5 course shows license access

**Actual Notes**

- Support Tools: __________
- Learner Portal: __________
- Final Result: PASS / FAIL

---

## 4. Dave

**User**

- `test-multi-dave@example.com`

**Expected licenses**

- 3 total
- 1 activated
- 2 assigned
- Purpose: activation flow testing

### Support Tools

- [ ] User found
- [ ] 3 license records visible
- [ ] 1 activated license visible
- [ ] 2 assigned licenses visible

### Learner Portal

- [ ] activated-catalog course shows license access
- [ ] assigned-license course does not behave like already-activated access
- [ ] activation behavior can be tested if route is available

**Actual Notes**

- Support Tools: __________
- Learner Portal: __________
- Final Result: PASS / FAIL

---

## 5. Eve

**User**

- `test-multi-eve@example.com`

**Expected licenses**

- 3 total
- 3 activated
- Purpose: overlap / tie-break scenario testing

### Support Tools

- [ ] User found
- [ ] 3 license records visible
- [ ] all 3 licenses are activated

### Learner Portal

- [ ] overlapping scenario course found
- [ ] overlapping scenario course shows valid license access
- [ ] no incorrect missing-access state appears

**Actual Notes**

- Support Tools: __________
- Learner Portal: __________
- Final Result: PASS / FAIL

---

## Common Failure Checks

If a test fails, verify these in order:

- [ ] admin user is used for Support Tools
- [ ] learner user is used for Learner Portal
- [ ] learner exists in local LMS
- [ ] learner is linked to the enterprise customer
- [ ] learner licenses were loaded into local License Manager
- [ ] tested course belongs to the expected licensed catalog
- [ ] license is current and activated
- [ ] `enterprise-access` is running
- [ ] `license-manager` is running

---

## Quick Summary Table

| User | Expected Licenses | Support Tools Result | Learner Portal Result | Final |
|---|---|---|---|---|
| Alice | 3 activated | ____ | ____ | PASS / FAIL |
| Bob | 4 activated | ____ | ____ | PASS / FAIL |
| Carol | 5 activated | ____ | ____ | PASS / FAIL |
| Dave | 1 activated + 2 assigned | ____ | ____ | PASS / FAIL |
| Eve | 3 activated | ____ | ____ | PASS / FAIL |

---

## Troubleshooting Notes

### If Support Tools says "You do not have access to this page"

- Log out of LMS
- Log in again as an admin user
- Refresh `http://localhost:18450`

### If Support Tools says "Unable to connect to the service"

- `license-manager` may be down or not connected to MySQL
- restart the local service(s)

### If SSO says "No SSO Records were Found"

- This may be expected in local testing
- It does **not** block license testing

### If learner portal shows a network or BFF error

- verify `enterprise-access` is running
- refresh after login
- verify authenticated learner session

### If learner has licenses but course access does not work

- confirm the course belongs to a licensed catalog
- confirm the license is activated/current
- confirm the enterprise slug is correct

---

## Final Sign-off

- [ ] Alice verified
- [ ] Bob verified
- [ ] Carol verified
- [ ] Dave verified
- [ ] Eve verified
- [ ] multi-license learner portal behavior validated

