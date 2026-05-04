
# Manual Braze Email Test — `send_enterprise_provision_signup_confirmation_email`

## Step 1 — Shell into the container

```bash
docker exec -it edx.devstack.enterprise-access bash
```

## Step 2 — Open Django shell

```bash
cd /edx/app/enterprise-access/enterprise_access
python manage.py shell_plus
```

## Step 3 — Paste this into the shell

Fill in the 3 values marked `# ← FILL IN` before running.

```python
from datetime import datetime
from django.conf import settings
from enterprise_access.apps.api_client.braze_client import BrazeApiClient
from enterprise_access.apps.customer_billing.tasks import (
    send_campaign_message,
    prepare_admin_braze_recipients,
)
from enterprise_access.apps.customer_billing.constants import (
    BRAZE_DATE_FORMAT_2,
    BRAZE_TIMESTAMP_FORMAT,
)
from enterprise_access.apps.customer_billing.utils import datetime_from_timestamp
from enterprise_access.utils import cents_to_dollars, format_datetime_obj

# ── Braze credentials (get from 1Password) ────────────────────────────────────
settings.BRAZE_API_KEY = 'YOUR_BRAZE_API_KEY'           # ← FILL IN
settings.BRAZE_API_URL = 'https://rest.iad-06.braze.com'
settings.BRAZE_APP_ID  = 'YOUR_BRAZE_APP_ID'            # ← FILL IN

# ── Campaign + portal (staging) ───────────────────────────────────────────────
settings.BRAZE_ENTERPRISE_PROVISION_SIGNUP_CONFIRMATION_CAMPAIGN = '3335d9f3-9b0c-47e2-9916-51b1b0658d90'
settings.ENTERPRISE_ADMIN_PORTAL_URL = 'https://portal.stage.edx.org'

# ── Test data ─────────────────────────────────────────────────────────────────
subscription_start_date = datetime(2026, 5, 1)
subscription_end_date   = datetime(2027, 5, 1)
number_of_licenses      = 5
organization_name       = 'Test Essentials Org'
enterprise_slug         = 'test-essentials-org'
subscription_plan_type  = 'essentials'   # change to 'teams' to test Teams flow
plan_amount_cents       = 2000           # $20.00 per license

trial_start_date = datetime_from_timestamp(1746316800)   # 2026-05-04
trial_end_date   = datetime_from_timestamp(1748995200)   # 2026-06-04
total_cost_cents = plan_amount_cents * number_of_licenses

# ── Build trigger properties ──────────────────────────────────────────────────
braze_trigger_properties = {
    'subscription_start_date': format_datetime_obj(subscription_start_date, output_pattern=BRAZE_DATE_FORMAT_2),
    'subscription_end_date':   format_datetime_obj(subscription_end_date,   output_pattern=BRAZE_DATE_FORMAT_2),
    'number_of_licenses':      number_of_licenses,
    'activation_link':         None,
    'organization':            organization_name,
    'enterprise_admin_portal_url': f'{settings.ENTERPRISE_ADMIN_PORTAL_URL}/{enterprise_slug}/admin/subscriptions',
    'trial_start_datetime':    format_datetime_obj(trial_start_date, output_pattern=BRAZE_TIMESTAMP_FORMAT),
    'trial_end_datetime':      format_datetime_obj(trial_end_date,   output_pattern=BRAZE_TIMESTAMP_FORMAT),
    'plan_amount':             float(cents_to_dollars(plan_amount_cents)),
    'total_amount':            float(cents_to_dollars(total_cost_cents)),
    'subscription_plan_type':  subscription_plan_type,
}

# ── Recipient (your email) ────────────────────────────────────────────────────
admin_users = [{'email': 'YOUR_EMAIL@edx.org', 'lms_user_id': None}]  # ← FILL IN

# ── Send ──────────────────────────────────────────────────────────────────────
braze_client = BrazeApiClient()
recipients   = prepare_admin_braze_recipients(braze_client, admin_users, enterprise_slug, raise_if_empty=True)

send_campaign_message(
    braze_client,
    settings.BRAZE_ENTERPRISE_PROVISION_SIGNUP_CONFIRMATION_CAMPAIGN,
    recipients=recipients,
    trigger_properties=braze_trigger_properties,
    organization_name=organization_name,
    email_description='signup confirmation email',
)

print('Done! Check your inbox and Braze campaign activity log.')
```

## What to verify after running

- Email arrives at `YOUR_EMAIL@edx.org`
- `subscription_plan_type = 'essentials'` renders Essentials-specific content in the email
- Change to `'teams'` and re-run to verify Teams content renders correctly
- Check Braze dashboard → Campaigns → staging campaign → Activity Log for send confirmation
