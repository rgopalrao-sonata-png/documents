# Admin Invite Activation Fix

## Problem Summary

When an admin is invited to an enterprise, after registration they get stuck in a redirect loop at `/admin/register` and never reach the admin portal. No activation toast is shown. This contrasts with invited **learners** who are linked and can access the portal immediately.

---

## Root Cause Analysis

### Why Learner Invite Works

```
1. Admin sends invite → PendingEnterpriseCustomerUser created
2. User registers → User.post_save fires
3. link_pending_enterprise_user() creates EnterpriseCustomerUser
4. enterprise_learner role assigned immediately (no is_active guard)
5. User visits learner portal → JWT has role → access granted ✅
```

### Why Admin Invite Was Broken (3 separate bugs)

#### Bug 1: Backend — `activate_admin_permissions()` ran BEFORE email confirmation
**File:** `edx-enterprise/enterprise/api/__init__.py`

```
1. Admin invite → PendingEnterpriseCustomerAdminUser created
2. User registers → User.post_save fires
3. activate_admin_permissions() called immediately
4. enterprise_admin role assigned while is_active=False (no email confirmed yet)
5. User is admin before clicking confirmation link ← WRONG
```

**Fix:** Added `is_active` guard — admin role is only assigned after email confirmation:
```python
if not enterprise_customer_user.user.is_active:
    return  # wait until the invited admin confirms their email
```

---

#### Bug 2: Frontend — `AdminRegisterPage` race condition caused infinite proxy login loop
**File:** `frontend-app-admin-portal/src/components/AdminRegisterPage/index.jsx`

`loginRefresh()` and `getEnterpriseBySlug()` were fired **in parallel**:
```js
// BROKEN — race condition
loginRefresh().then(data => { ...reload once... });  // async, not awaited
getEnterpriseBySlug();                               // reads STALE JWT roles immediately
```

`getEnterpriseBySlug` finished first with a **stale JWT** (no `enterprise_admin` role yet) → `isEnterpriseAdmin=false` → redirected to proxy login → infinite loop.

**Fix:** `getEnterpriseBySlug` now runs **after** `loginRefresh` + `hydrateAuthenticatedUser`:
```js
// FIXED — sequential
LmsApiService.loginRefresh().then(async (data) => {
  if (firstVisit) { reload(); return; }
  await hydrateAuthenticatedUser();  // updates in-memory JWT roles
  await getEnterpriseBySlug();       // now reads fresh enterprise_admin role
});
```

---

#### Bug 3: Frontend — Activation toast never displayed
**File:** `frontend-app-admin-portal/src/components/UserActivationPage/index.jsx`

The `<Toast>` was rendered alongside `<Navigate replace />` in the same return block:
```jsx
// BROKEN — Navigate unmounts the page before Toast can render
return (
  <>
    <Navigate to={`/${enterpriseSlug}/admin/learners`} replace />
    <Toast show={showToast}>...</Toast>  {/* never painted */}
  </>
);
```

**Fix:** Pass a flag via router state to the destination page instead:
```jsx
// UserActivationPage — pass flag on redirect
<Navigate
  to={`/${enterpriseSlug}/admin/learners`}
  replace
  state={{ showActivationToast: true }}
/>
```
```jsx
// AdminV2/index.jsx (learners page) — read flag and show toast there
const [showActivationToast, setShowActivationToast] = useState(
  () => !!(location?.state?.showActivationToast),
);
// ...
<Toast show={showActivationToast} onClose={() => setShowActivationToast(false)}>
  Your edX administrator account was successfully activated.
</Toast>
```

---

#### Bug 4: Frontend — `UserActivationPage` stuck on skeleton (no hydration on mount)
**File:** `frontend-app-admin-portal/src/components/UserActivationPage/index.jsx`

`getAuthenticatedUser()` is synchronous and non-reactive. The old code called `hydrateAuthenticatedUser()` only inside the polling interval (every 5s), so on first render `isActive=undefined` → skeleton shown indefinitely if polling never triggered a re-render.

**Fix:** Hydrate immediately on mount and store result in `useState`:
```jsx
const [user, setUser] = useState(getAuthenticatedUser());

// Hydrate immediately on mount
useEffect(() => {
  hydrateAuthenticatedUser().then(() => setUser(getAuthenticatedUser()));
}, []);

// Keep polling every 5s until is_active=true
useInterval(() => {
  if (user && !user.isActive) {
    hydrateAuthenticatedUser().then(() => setUser(getAuthenticatedUser()));
  }
}, USER_ACCOUNT_POLLING_TIMEOUT);
```

---

## Files Changed

| File | Change |
|------|--------|
| `edx-enterprise/enterprise/api/__init__.py` | Added `is_active` guard in `activate_admin_permissions()` |
| `frontend-app-admin-portal/src/components/AdminRegisterPage/index.jsx` | Await `loginRefresh` + `hydrateAuthenticatedUser` before calling `getEnterpriseBySlug` |
| `frontend-app-admin-portal/src/components/UserActivationPage/index.jsx` | Hydrate on mount, store user in state, pass toast flag via router state |
| `frontend-app-admin-portal/src/components/AdminV2/index.jsx` | Read `location.state.showActivationToast` and render `<Toast>` on learners page |

---

## Corrected End-to-End Flow (devstack)

```
1. Existing admin sends invite → PendingEnterpriseCustomerAdminUser + PendingEnterpriseCustomerUser created

2. Invited user registers at:
   http://localhost:18000/register?next=/dashboard

3. User.post_save fires:
   - enterprise_learner role assigned immediately (no is_active guard)
   - activate_admin_permissions() called → is_active=False → returns early (no admin role yet)

4. User clicks activation link in email:
   http://localhost:18000/activate/<key>
   - LMS sets is_active=True on User
   - User.post_save fires again
   - activate_admin_permissions() called → is_active=True → enterprise_admin role assigned ✅
   - PendingEnterpriseCustomerAdminUser deleted

5. User visits:
   http://localhost:1991/<enterprise-slug>/admin/register
   - loginRefresh() called → page reloads (first visit)
   - On second load: loginRefresh() → hydrateAuthenticatedUser() → getEnterpriseBySlug()
   - JWT now has enterprise_admin role → isEnterpriseAdmin=true
   - Navigates to: /admin/register/activate

6. UserActivationPage:
   - hydrateAuthenticatedUser() fires immediately on mount
   - isActive=true detected
   - Redirects to: /admin/learners with state { showActivationToast: true }

7. Learners page (AdminV2):
   - Reads location.state.showActivationToast
   - Toast displayed: "Your edX administrator account was successfully activated." ✅
```

---

## Testing Checklist

- [ ] Invite a new user as admin via Django admin or People Management UI
- [ ] User registers via LMS — verify they do NOT appear as admin yet in Django admin (`EnterpriseCustomerAdmin` table should be empty for this user)
- [ ] User clicks activation email link
- [ ] After activation, verify `EnterpriseCustomerAdmin` record exists in Django admin
- [ ] User visits `/<slug>/admin/register` — should NOT loop, should proceed to `/admin/register/activate`
- [ ] Should be redirected to `/admin/learners`
- [ ] Toast message "Your edX administrator account was successfully activated." appears
- [ ] Refresh `/admin/learners` — toast should NOT appear again (one-shot via router state)
