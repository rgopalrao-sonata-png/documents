# Snowflake ENTERPRISE_SERVICE_USER — Key Pair Authentication Migration

**Deadline:** August 31, 2026

## Purpose

End-to-end runbook for migrating `ENTERPRISE_SERVICE_USER` from Snowflake username/password authentication to RSA key pair authentication. Covers discovery, coordination, implementation, validation, and rollout.

## Why This Matters

Snowflake has flagged `ENTERPRISE_SERVICE_USER` as still using password authentication. Failure to migrate before the deadline may cause dependent services to lose access or fail compliance requirements.

---

## Summary

Replaces password-based Snowflake login with RSA key pair authentication for `ENTERPRISE_SERVICE_USER`, which supports LPR queries and downstream API responses. Work includes identifying all current usages, coordinating with the Snowflake/Data Platform team, updating secrets and application configuration, validating in staging, and confirming the authentication method switch in Snowflake.

---

## Primary References

| Reference | Description |
|-----------|-------------|
| [OCM Snowflake](https://openedx.atlassian.net/wiki/spaces/AT/pages/snowflake) | Internal runbook for generating and using key pair credentials |
| [ENT-11804](https://openedx.atlassian.net/browse/ENT-11804) | Migrate `ENTERPRISE_SERVICE_USER` to key pair authentication |
| [ENT-11803](https://openedx.atlassian.net/browse/ENT-11803) | Document and identify LPR data flow and usage points |
| [DPSD-11928](https://openedx.atlassian.net/browse/DPSD-11928) | Parent tracking ticket for service-user authentication migrations |
| [DOS-6253][(https://2u-internal.atlassian.net/browse/DOS-6253)] | Prior example of a service-user key pair migration |
| [DPSD-9693][(https://2u-internal.atlassian.net/browse/DPSD-9693)] | Prior example from Data Platform |

---

## Roles and Ownership

| Role | Responsibility |
|------|----------------|
| Application team | Identify all usages, update code/configuration, test in staging, deploy safely |
| Snowflake / Data Platform team | Register the public key, validate authentication method, confirm query history |
| Dave Wolf | Primary coordination point with Data Platform for user registration and validation |

---

## Definition of Done

- [ ] **Discovery complete** — every consumer of `ENTERPRISE_SERVICE_USER` identified
- [ ] **Key registered** — Snowflake user has an RSA public key configured
- [ ] **Application updated** — all services use private key auth, not password auth
- [ ] **Staging validated** — LPR and dependent API paths are working
- [ ] **Production validated** — no disruption observed after rollout
- [ ] **Snowflake confirmed** — authentication method is key pair
- [ ] **Password removed** — no environment still depends on password login

---

## Migration Steps

### Step 1 — Discovery: find every usage of the service user

Before changing credentials, identify all services, jobs, and configuration files that reference `ENTERPRISE_SERVICE_USER`. Hidden usage in scheduled jobs or background workers can cause unexpected failures.

**Search terms:**
- `ENTERPRISE_SERVICE_USER`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD`
- `snowflake.connector.connect`
- `private_key`
- LPR table or query references

**Locations to inspect:**
- Application repo(s) that execute Snowflake queries
- Deployment/config repo (e.g. `edx-internal`)
- Terraform or infra repo where Snowflake users are managed
- Secrets storage definitions
- Scheduled jobs or reporting workers

**Checklist:**
- [ ] Search application code for Snowflake connection setup
- [ ] Search config for `ENTERPRISE_SERVICE_USER` and password-based auth settings
- [ ] Identify all environments using this service user
- [ ] Identify every query path touching LPR data
- [ ] Identify secret names and where they are injected
- [ ] Confirm whether any shared libraries also construct Snowflake connections

---

### Step 2 — Coordinate with Data Platform to register a key pair

Work with Dave Wolf and the Snowflake/Data Platform team to generate or approve a key pair for `ENTERPRISE_SERVICE_USER`. The public key must be registered in Snowflake before the application can authenticate with the private key.

> **Note:** User registration may be managed via Terraform rather than direct SQL. Confirm the team's preferred path before proceeding.

**Likely infra location:** `edx/terraform` — `plans/snowflake/us_east_1/users.tf` (verify if still the active source of truth).

**Options:**
1. Generate the key pair locally and provide the public key to Data Platform
2. Update the Snowflake user definition in Terraform
3. Apply the change and verify that the user now has an RSA public key registered

---

### Step 3 — Generate the RSA key pair

Follow the [OCM Snowflake runbook](https://openedx.atlassian.net/wiki/spaces/AT/pages/snowflake). Basic flow:

```bash
brew install openssl
openssl rand -base64 30
mkdir /tmp/sf_keys && cd /tmp/sf_keys
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -v1 PBE-SHA1-RC4-128 -out rsa_key.p8
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

> **Security reminder:** The private key and passphrase are secrets. Do not commit them to source control, paste them into tickets, or store them in local shell history.

---

### Step 4 — Store the private key and passphrase securely

After the public key is registered in Snowflake, store the private key and passphrase in your approved secret store.

**Expected secret values:**
- **Private key** — contents of `rsa_key.p8`
- **Passphrase** — the passphrase used to encrypt the private key

**Actions:**
- [ ] Create or update application secrets in AWS Secrets Manager, Vault, or the active secret management system
- [ ] Update deployment configuration so the service can access the private key and passphrase at runtime

---

### Step 5 — Update application code or configuration

Replace password-based Snowflake connection logic with key pair authentication. This may occur in application code, a shared library, or environment-based connection builder logic.

```python
from cryptography.hazmat.primitives import serialization
import snowflake.connector

private_key_text = settings.SNOWFLAKE_PRIVATE_KEY
private_key_passphrase = settings.SNOWFLAKE_PRIVATE_KEY_PASSPHRASE.encode()

p_key = serialization.load_pem_private_key(
    private_key_text.encode(),
    password=private_key_passphrase,
)

conn = snowflake.connector.connect(
    user=settings.SNOWFLAKE_USER,
    account=settings.SNOWFLAKE_ACCOUNT,
    private_key=p_key,
    warehouse=settings.SNOWFLAKE_WAREHOUSE,
    database=settings.SNOWFLAKE_DATABASE,
    schema=settings.SNOWFLAKE_SCHEMA,
)
```

**What to remove:**
- Direct dependency on `SNOWFLAKE_PASSWORD` for this user
- Any fallback logic that silently uses password auth when a private key is absent

> Do not deploy a mixed implementation where some environments still depend on password auth unless it is a deliberate, documented temporary transition. Hidden fallback behavior makes validation difficult.

---

### Step 6 — Validate in staging

Test in staging before any production rollout.

**Validation checklist:**
- [ ] Application starts successfully and establishes a Snowflake connection
- [ ] LPR queries still run successfully
- [ ] Dependent API responses match expected results
- [ ] Scheduled jobs or async workers using Snowflake still function
- [ ] No new errors in logs related to credentials, key parsing, or Snowflake auth

**Process:**
1. Deploy updated secrets and config to staging
2. Restart all relevant services and workers
3. Execute a known-good LPR query path
4. Verify downstream API responses
5. Check application logs for auth or cryptography errors
6. Confirm with Data Platform that Snowflake shows key pair auth

---

### Step 7 — Deploy to production

After staging is verified, roll out production using the normal deployment path (GoCD, ArgoCD, or the standard flow managed through `edx-internal`).

**Recommendations:**
- Deploy during a window where logs and metrics can be actively monitored
- Confirm all runtime components (web, worker, cron, jobs) have the updated secrets
- Check a live query path immediately after deployment
- Coordinate with Dave Wolf for post-deploy verification in Snowflake

---

### Step 8 — Confirm key pair auth in Snowflake

Ask Dave Wolf or the Snowflake team to verify authentication via Snowflake-side inspection (not app logs alone).

**Verification goals:**
- [ ] The user has an RSA public key registered
- [ ] Recent query history shows key pair authentication
- [ ] Password auth is no longer being used

---

### Step 9 — Remove password authentication

Once staging and production are confirmed stable and Snowflake confirms key pair usage:

- [ ] Unset or remove the password from Snowflake (coordinate with platform team)
- [ ] Delete obsolete password secrets from secret storage
- [ ] Remove no-longer-used config values from deployment manifests and application settings
- [ ] Update related runbooks and onboarding docs

---

## Configuration Changes to Expect

| Change | Direction |
|--------|-----------|
| Secret for private key (`SNOWFLAKE_PRIVATE_KEY`) | Add |
| Secret for private key passphrase (`SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`) | Add |
| Password-based secret (`SNOWFLAKE_PASSWORD`) | Remove |
| Connection initialization code | Update |
| Worker/cron job configuration (if connecting separately) | Update |

---

## Common Failure Modes

| Issue | Likely Cause | What to Check |
|-------|-------------|---------------|
| Authentication still fails | Public key not registered or wrong key pair used | Confirm public key in Snowflake matches the private key in secrets |
| Key parsing error | Private key format or passphrase is incorrect | Validate PEM content, line breaks, and passphrase encoding |
| Staging works but prod fails | Secrets not updated consistently across all workloads | Check web, worker, cron, and job runtimes separately |
| App still uses password auth | Fallback code path or old secret still present | Search code/config for password-based connection setup |

---

## Open Questions (Resolve Early)

- Which exact service(s) currently own the LPR Snowflake connection?
- Where are the current Snowflake secrets stored for each environment?
- Is Snowflake user management still Terraform-backed for this account?
- Do any background jobs or scripts use a separate connection path?
- Who will perform final Snowflake-side verification and signoff?

---

## Recommended Work Breakdown

- [ ] Complete discovery of every usage of `ENTERPRISE_SERVICE_USER`
- [ ] Confirm owner and source of truth for Snowflake user registration
- [ ] Generate RSA key pair using the OCM Snowflake process
- [ ] Coordinate with Dave Wolf to register the public key
- [ ] Store private key and passphrase in the approved secret store
- [ ] Update service code/config to use key pair authentication
- [ ] Validate in staging, including LPR query flows
- [ ] Deploy to production and monitor
- [ ] Confirm key pair auth in Snowflake query history
- [ ] Remove password auth and clean up old secrets
