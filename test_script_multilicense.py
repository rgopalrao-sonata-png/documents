import json, urllib.request, urllib.parse, urllib.error

SLUG = "test-multi-enterprise"
BFF_URL = f"http://localhost:18270/api/v1/bffs/learner/dashboard/?enterprise_customer_slug={SLUG}"
TOKEN_URL = "http://localhost:18000/oauth2/access_token/"

USERS = [
    ("test-multi-alice",  "edx"),
    ("test-multi-bob",    "edx"),
    ("test-multi-carol",  "edx1234"),
    ("test-multi-dave",   "edx"),
    ("test-multi-eve",    "edx"),
]

def get_token(username, password):
    data = urllib.parse.urlencode({
        "client_id": "login-service-client-id",
        "grant_type": "password",
        "username": username,
        "password": password,
        "token_type": "jwt",
    }).encode()
    resp = urllib.request.urlopen(TOKEN_URL, data=data)
    return json.loads(resp.read())["access_token"]

def call_bff(token):
    req = urllib.request.Request(BFF_URL, data=b"", method="POST",
        headers={"Authorization": f"JWT {token}", "Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req).read())

print("=" * 72)
print(f"{'USER':<22} {'SCHEMA':<5} {'LICENSES':<9} {'CATALOGS':<9} {'BEST LICENSE (subscription_license)'}")
print("=" * 72)

for username, password in USERS:
    try:
        token = get_token(username, password)
        data = call_bff(token)
        subs = data["enterprise_customer_user_subsidies"]["subscriptions"]
        schema   = subs.get("license_schema_version", "?")
        lic_list = subs.get("subscription_licenses", [])
        catalog_keys = sorted(subs.get("licenses_by_catalog", {}).keys())
        best     = subs.get("subscription_license") or {}
        best_plan = (best.get("subscription_plan") or {}).get("title", "none")
        best_uuid = best.get("uuid", "none")
        best_date = best.get("activation_date", "?")[:10]
        print(f"\n{username}")
        print(f"  Schema version : {schema}")
        print(f"  Total licenses : {len(lic_list)}")
        print(f"  Catalog keys   : {len(catalog_keys)} → {[k[:8]+'…' for k in catalog_keys]}")
        print(f"  Best license   : {best_uuid}")
        print(f"  Best plan      : {best_plan}")
        print(f"  Activated      : {best_date}  ← first-activated rule")
        print(f"  All licenses (sorted by activation_date):")
        for lic in sorted(lic_list, key=lambda x: x.get("activation_date", "")):
            p = (lic.get("subscription_plan") or {})
            marker = " ← WINNER" if lic.get("uuid") == best.get("uuid") else ""
            print(f"    {lic.get('activation_date','?')[:10]}  {lic.get('uuid')}  {p.get('title','?')}{marker}")
    except urllib.error.HTTPError as e:
        print(f"\n{username}  ERROR {e.code}: {e.read().decode()[:200]}")
    except Exception as ex:
        print(f"\n{username}  EXCEPTION: {ex}")

print("\n" + "=" * 72)
