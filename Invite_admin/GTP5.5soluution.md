
# Admin Invite Registration Activation Issue — Root Cause and Solution
 
Date: 2026-05-07
 
## Reported behavior
 
Flow:
 
1. Anonymous invited admin opens:
   `https://portal.stage.edx.org/edx-inc-stage/admin/register`
2. User completes registration.
3. Portal redirects to:
   `https://portal.stage.edx.org/edx-inc-stage/admin/register/activate`
4. Page hangs on activation.
5. No account confirmation email is received.
6. `EnterpriseCustomerAdmin` / customer admin permission appears to be created before the user clicks the LMS email confirmation link.
 
## Executive summary
 
There are two separate problems that look like one issue:
 
1. **Backend authorization bug:** `edx-enterprise` grants enterprise admin permission during registration while the LMS `User.is_active` flag is still `False`. This is why the customer admin is created before email confirmation. Admin role assignment must wait until the LMS activation email is confirmed.
2. **Email delivery / LMS activation issue:** The `/admin/register/activate` page is expected to wait if the LMS account is inactive. If no confirmation email is sent, the root cause is usually LMS registration email configuration, Celery/email worker delivery, SMTP/ESP suppression, or stage email allow-listing — not the admin portal itself.
 
The correct solution is to **prevent admin activation before LMS email confirmation** and then verify/fix the LMS activation email pipeline.
 
---
 
## Expected correct flow
 
```text
1. Existing enterprise admin invites a new email.
2. edx-enterprise creates PendingEnterpriseCustomerAdminUser.
3. Anonymous user registers through LMS.
4. LMS creates User with is_active=False until email confirmation.
5. Enterprise learner link may be created, but enterprise_admin must NOT be granted yet.
6. LMS sends account activation/confirmation email.
7. User clicks confirmation link.
8. LMS sets User.is_active=True.
9. User post_save signal runs again.
10. edx-enterprise now creates EnterpriseCustomerAdmin and assigns enterprise_admin role.
11. Portal /admin/register/activate detects active user and redirects to admin learners page.
```
 
---
 
## Root cause 1 — admin role is assigned before email confirmation
 
Relevant repository: `openedx/edx-enterprise`
 
Relevant function:
 
- `enterprise/api/__init__.py`
- `activate_admin_permissions(enterprise_customer_user)`
 
Current behavior from the referenced Open edX Enterprise code:
 
```python
def activate_admin_permissions(enterprise_customer_user):
    pending_admin_user = PendingEnterpriseCustomerAdminUser.objects.get(
        user_email=enterprise_customer_user.user.email,
        enterprise_customer=enterprise_customer_user.enterprise_customer,
    )
 
    EnterpriseCustomerAdmin.objects.get_or_create(
        enterprise_customer_user=enterprise_customer_user,
    )
 
    roles_api.assign_admin_role(
        enterprise_customer_user.user,
        enterprise_customer=enterprise_customer_user.enterprise_customer,
    )
 
    pending_admin_user.delete()
```
 
Problem:
 
- The function checks for a pending admin invite.
- It creates `EnterpriseCustomerAdmin`.
- It assigns the `enterprise_admin` role.
- It deletes the pending admin record.
- But it does **not** check `enterprise_customer_user.user.is_active` first.
 
For an anonymous invitee, LMS registration usually creates the user as inactive until email confirmation. Therefore the enterprise admin role is being assigned too early.
 
### Backend fix
 
Add an `is_active` guard before creating `EnterpriseCustomerAdmin`, assigning admin role, or deleting the pending admin invite.
 
Recommended patch:
 
```python
def activate_admin_permissions(enterprise_customer_user):
    """
    Activates admin permissions for an existing PendingEnterpriseCustomerAdminUser.
 
    Admin permission must only be granted after the LMS account is active.
    Anonymous invited admins register with User.is_active=False until they click
    the account activation email, so this function may run once before activation
    and again after activation.
    """
    try:
        pending_admin_user = PendingEnterpriseCustomerAdminUser.objects.get(
            user_email=enterprise_customer_user.user.email,
            enterprise_customer=enterprise_customer_user.enterprise_customer,
        )
    except PendingEnterpriseCustomerAdminUser.DoesNotExist:
        return
 
    if not enterprise_customer_user.user.is_active:
        return
 
    if not enterprise_customer_user.linked:
        roles_api.delete_admin_role_assignment(
            enterprise_customer_user.user,
        )
        return
 
    EnterpriseCustomerAdmin.objects.get_or_create(
        enterprise_customer_user=enterprise_customer_user,
    )
 
    roles_api.assign_admin_role(
        enterprise_customer_user.user,
        enterprise_customer=enterprise_customer_user.enterprise_customer,
    )
 
    pending_admin_user.delete()
```
 
Important detail:
 
- Put the `is_active` check **before** `EnterpriseCustomerAdmin.objects.get_or_create(...)`.
- Otherwise the admin object will still be created before email confirmation.
 
---
 
## Root cause 2 — confirmation email is not received
 
The email required at this step is the **LMS account activation email**, not the enterprise admin invite email.
 
The admin portal `/admin/register/activate` page cannot activate the user by itself. It waits for LMS to mark the user active. If the user never receives/clicks the LMS activation email, the page will keep waiting.
 
### What to check in stage
 
Check the created LMS user:
 
```python
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.get(email='invited-admin@example.com')
print(user.is_active)
```
 
If `is_active=False`, the activate page is correctly waiting.
 
Then verify whether the LMS activation email was generated/sent:
 
1. Check LMS logs around registration time for activation email creation.
2. Check Celery worker logs for email tasks.
3. Check SMTP/ESP logs, for example Braze/SendGrid/AWS SES depending on stage configuration.
4. Check whether stage suppresses emails to non-allowlisted domains.
5. Check spam/junk/quarantine.
6. Check whether the same email address is already registered, inactive, or suppressed/bounced in the email provider.
 
Typical configuration areas to verify in LMS stage:
 
```python
FEATURES['ENABLE_ACCOUNT_ACTIVATION_EMAIL']
FEATURES['ENABLE_COMBINED_LOGIN_REGISTRATION']
EMAIL_BACKEND
DEFAULT_FROM_EMAIL
ACTIVATION_EMAIL_SUPPORT_LINK
```
 
Also verify that Celery workers responsible for email are running and processing the correct queues.
 
---
 
## Root cause 3 — portal page can hang if user hydration/polling is stale
 
The admin portal activation page commonly checks the authenticated user state and waits until `isActive=True`.
 
If the page uses a stale authenticated user object or does not hydrate on mount, it may remain on a skeleton/loading state even after activation.
 
Recommended frontend fix in `frontend-app-admin-portal`:
 
1. On `UserActivationPage` mount, call `hydrateAuthenticatedUser()` immediately.
2. Store the user in component state.
3. Poll until `user.isActive === true`.
4. Redirect only after the hydrated user is active.
 
Example logic:
 
```jsx
const [user, setUser] = useState(getAuthenticatedUser());
 
useEffect(() => {
  hydrateAuthenticatedUser().then(() => setUser(getAuthenticatedUser()));
}, []);
 
useInterval(() => {
  if (user && !user.isActive) {
    hydrateAuthenticatedUser().then(() => setUser(getAuthenticatedUser()));
  }
}, USER_ACCOUNT_POLLING_TIMEOUT);
```
 
---
 
## Root cause 4 — stale JWT / race during `/admin/register`
 
After registration or activation, the browser may still have a stale JWT without the new `enterprise_admin` role.
 
If `getEnterpriseBySlug()` runs before `loginRefresh()` and user hydration complete, the portal may incorrectly decide that the user is not an enterprise admin and enter a proxy-login/redirect loop.
 
Recommended frontend fix in `AdminRegisterPage`:
 
```jsx
await LmsApiService.loginRefresh();
await hydrateAuthenticatedUser();
await getEnterpriseBySlug();
```
 
Do not call `getEnterpriseBySlug()` in parallel with `loginRefresh()`.
 
---
 
## Test cases to add in `edx-enterprise`
 
Add/adjust tests for `activate_admin_permissions()`.
 
### Test 1 — inactive anonymous user must not become admin
 
Expected assertions:
 
- `EnterpriseCustomerAdmin` is not created.
- `enterprise_admin` role is not assigned.
- `PendingEnterpriseCustomerAdminUser` remains.
 
Pseudo-test:
 
```python
def test_activate_admin_permissions_does_not_activate_inactive_user(self):
    user = UserFactory(email='new-admin@example.com', is_active=False)
    enterprise_customer_user = EnterpriseCustomerUserFactory(
        user_id=user.id,
        user_fk=user,
        enterprise_customer=self.enterprise_customer,
    )
    pending_admin = PendingEnterpriseCustomerAdminUserFactory(
        user_email=user.email,
        enterprise_customer=self.enterprise_customer,
    )
 
    activate_admin_permissions(enterprise_customer_user)
 
    assert not EnterpriseCustomerAdmin.objects.filter(
        enterprise_customer_user=enterprise_customer_user,
    ).exists()
    assert PendingEnterpriseCustomerAdminUser.objects.filter(id=pending_admin.id).exists()
```
 
### Test 2 — active confirmed user becomes admin
 
Expected assertions:
 
- `EnterpriseCustomerAdmin` is created.
- `enterprise_admin` role is assigned.
- `PendingEnterpriseCustomerAdminUser` is deleted.
 
---
 
## Production/stage verification checklist
 
### Database checks before clicking activation email
 
For the invited email:
 
- `auth_user.is_active` should be `False`.
- `PendingEnterpriseCustomerAdminUser` should exist.
- `EnterpriseCustomerAdmin` should **not** exist.
- `SystemWideEnterpriseUserRoleAssignment` with `enterprise_admin` should **not** exist.
 
### Database checks after clicking activation email
 
For the same email:
 
- `auth_user.is_active` should be `True`.
- `EnterpriseCustomerAdmin` should exist.
- `SystemWideEnterpriseUserRoleAssignment` with `enterprise_admin` should exist.
- `PendingEnterpriseCustomerAdminUser` should be deleted.
 
### Email checks
 
- Confirm LMS sends account activation email at registration time.
- Confirm email task reaches Celery.
- Confirm SMTP/ESP accepts the message.
- Confirm recipient/domain is not blocked or suppressed.
- Confirm stage environment allows outbound mail to the test recipient domain.
 
---
 
## Recommended final solution
 
1. Patch `edx-enterprise/enterprise/api/__init__.py` so `activate_admin_permissions()` returns immediately when `enterprise_customer_user.user.is_active` is `False`.
2. Ensure the `EnterpriseCustomerAdmin.objects.get_or_create(...)` call happens only after the `is_active` check.
3. Add backend regression tests for inactive and active invited admins.
4. Verify LMS account activation email settings and Celery/email provider delivery in stage.
5. Patch the admin portal activation/register pages to hydrate the user after `loginRefresh()` and poll fresh user state before redirecting.
 
This resolves both observed symptoms:
 
- Customer admin is no longer created before email confirmation.
- `/admin/register/activate` only completes after the LMS user is actually active.
 
If the page still hangs after this backend fix, the remaining issue is almost certainly in the LMS activation email delivery pipeline or stale frontend authentication hydration.
