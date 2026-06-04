# Snowflake Key Pair Authentication Setup

## Step 1 — Generate an Encryption Password

```bash
openssl rand -base64 30
```

> **Save this password.** You'll need it when running `make` and when storing credentials.
>
> Example output: `IOUItkTPawfXPpolVQG0RkkWiK32i+uwgQ7Ncvnj`

---

## Step 2 — Create the Working Directory

```bash
mkdir /tmp/sf_keys
cd /tmp/sf_keys
```

---

## Step 3 — Create the Makefile

Create `/tmp/sf_keys/Makefile` with the content below.  
**Important:** indents under each target must be real **tabs**, not spaces.

```makefile
# Commands taken from https://docs.snowflake.net/manuals/user-guide/snowsql-start.html#using-key-pair-authentication
#
# Usage: make <username>
.SECONDARY: $(OBJS)
rsa_key_%.p8 : 
	openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out $@
rsa_key_%.pub : rsa_key_%.p8
	openssl rsa -in $< -pubout -out $@
% : rsa_key_%.pub
	@echo ""
	@echo ""
	@echo "Add the following field to the user in terraform:"
	@echo "  rsa_public_key = \"$(shell cat $< | grep -v '\(BEGIN\|END\) PUBLIC KEY' | tr -d '\n')\""
```

---

## Step 4 — Generate the Key Pair

Run `make` with the Snowflake username as the target:

```bash
make automationuser
```

When prompted, enter the encryption password from Step 1 **twice** (once to set, once to verify), then once more to export the public key.

Two files are created:

| File | Description |
|------|-------------|
| `rsa_key_automationuser.p8` | Encrypted private key |
| `rsa_key_automationuser.pub` | Public key |

---

## Step 5 — Note the `rsa_public_key`

The `make` output prints a line like:

```
rsa_public_key = "MIIBIjANBgkqh..."
```

> **Save this value.** It goes into the Terraform config for the Snowflake user.

To extract it manually at any time:

```bash
cat rsa_key_automationuser.pub | grep -v '\(BEGIN\|END\) PUBLIC KEY' | tr -d '\n'
```

---

## Step 6 — Store Credentials Securely

Add to the LastPass note **"Snowflake Automation Users"** (Shared-Data Engineering folder):

- `rsa_key_automationuser.p8` (attach file)
- `rsa_key_automationuser.pub` (attach file)
- The encryption password from Step 1

---

## Non-Interactive Alternative (CI/scripts)

Skip interactive prompts by passing the passphrase on the command line:

```bash
PASSPHRASE="<your-generated-password>"

openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM \
  -out rsa_key_automationuser.p8 -passout pass:"$PASSPHRASE"

openssl rsa -in rsa_key_automationuser.p8 -pubout \
  -out rsa_key_automationuser.pub -passin pass:"$PASSPHRASE"
```
