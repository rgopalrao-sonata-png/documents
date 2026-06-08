# AI Languages / `translation_languages` — Post-PR Merge Next Steps

> **Audience:** Any engineer picking up this feature after the PR lands on `main`.
> **Context:** This PR wires `ai_languages` (from Course Discovery) through
> `ContentMetadata._json_metadata` and surfaces it as a `translation_languages`
> facet in Algolia so learners can filter courses by available subtitle/translation
> languages.

---

## 1. Immediately After Merge

### 1a. Deploy to Staging

```bash
# Tag / promote the image as per your standard release process, then verify:
kubectl rollout status deployment/enterprise-catalog -n enterprise-catalog-staging
```

### 1b. Run the full-metadata sync on Staging

The DB must be populated **before** the Algolia reindex can produce results.

```bash
# Inside the app shell (docker exec or kubectl exec)
./manage.py update_full_content_metadata --force
```

Wait for completion. Check logs for errors like:
- `KeyError: 'ai_languages'`
- HTTP 4xx/5xx from Discovery

### 1c. Run a manual Algolia reindex on Staging

```bash
./manage.py reindex_algolia --force --no-async
```

### 1d. Verify in Algolia

1. Open the Algolia dashboard → **staging** index.
2. Browse any course record — confirm a `translation_languages` array is present.
3. Check **Index Configuration → Facets** — `translation_languages` should be listed.
4. Run a facet query to confirm values like `"Spanish"`, `"French"` appear.

---

## 2. Production Rollout

### 2a. Deploy to Production

Follow the standard deployment runbook. No Django migrations are needed for this
change (the field was already a JSON column).

### 2b. Let the scheduled jobs do the work

| Time (UTC) | Job | What it does |
|---|---|---|
| Multiple times / day | `edx-update-content-metadata` | Phase 1+2: syncs course list, then enriches each course with full metadata **including `ai_languages`** |
| `0 12 * * *` (daily noon) | `edx-reindex-algolia --force --no-async` | Phase 3: atomically rebuilds the entire Algolia index from whatever is in the DB |

> **The 12:00 UTC cron will solve the issue — but only after
> `update_full_content_metadata_task` has run at least once post-deploy.**
> The dependency is: DB first, Algolia second.

### 2c. First-day manual accelerator (optional but recommended)

To avoid waiting up to 24 h for the first fully-populated reindex:

```bash
# 1. Trigger the full-metadata sync immediately after deploy
./manage.py update_full_content_metadata --force

# 2. Once it finishes (check Celery worker logs), trigger Algolia reindex
./manage.py reindex_algolia --force --no-async
```

---

## 3. Smoke Tests

Run these after the first combined sync+reindex cycle completes.

### Quick API check

```bash
# Replace <uuid> with any known enterprise customer UUID
curl -s "https://enterprise-catalog.edx.org/api/v1/enterprise-catalogs/<uuid>/search/?content_type=course" \
  | python -m json.tool | grep -A5 translation_languages
```

Expected output (truncated):
```json
"translation_languages": ["Spanish", "French"]
```

### Algolia facet check (Python snippet)

```python
from algoliasearch.search_client import SearchClient

client = SearchClient.create("YOUR_APP_ID", "YOUR_SEARCH_API_KEY")
index  = client.init_index("enterprise_catalog_courses")

result = index.search("", {
    "facets": ["translation_languages"],
    "hitsPerPage": 0,
})
print(result["facets"].get("translation_languages", {}))
# Expected: {"Spanish": 450, "French": 210, ...}
```

---

## 4. Monitoring & Alerting

| What to watch | Where | Action if broken |
|---|---|---|
| `update_full_content_metadata_task` failures | Celery worker logs / Datadog | Re-run `./manage.py update_full_content_metadata --force` |
| `index_enterprise_catalog_in_algolia_task` failures | Celery worker logs / Datadog | Re-run `./manage.py reindex_algolia --force --no-async` |
| `translation_languages` facet absent in Algolia | Algolia dashboard | Confirm DB has `ai_languages` data, then reindex |
| Discovery API shape change | Any reindex that yields 0 `translation_languages` hits | See "Data shape dependency" in `ai_languages.md` |

---

## 5. Known Gotchas (Quick Reference)

| Gotcha | Impact | Fix |
|---|---|---|
| `ai_languages` not in `/search/all` response | New courses have no `translation_languages` until Phase 2 runs | Wait for next `update_full_content_metadata` cycle |
| Discovery changes key name/nesting | Field silently becomes empty — no exception raised | Add a Datadog monitor on the facet hit count |
| Algolia uses atomic replace | A course missing `ai_languages` in DB at reindex time loses the facet | Ensure Phase 2 always precedes Phase 3 |
| `--force` flag scope | `--force` only bypasses the 1-hour semaphore; it does **not** limit scope to changed records | Still a full rebuild — safe to use |

---

## 6. Rollback Plan

This change is **additive only** (a new read-path through existing data). To
roll back:

1. Revert the PR and redeploy.
2. Run `./manage.py reindex_algolia --force --no-async`.
3. The `translation_languages` field will disappear from Algolia objects within
   one reindex cycle. No data loss — `_json_metadata` still contains `ai_languages`.

---

## 7. Longer-Term Improvements (Backlog)

- [ ] **Incremental Algolia indexing** — index only changed courses instead of a
  full rebuild (see `docs/decisions/0011-search-app-for-incremental-algolia-indexing.rst`).
- [ ] **Alert on empty `translation_languages` facet** — add a Datadog monitor
  that fires if the facet count drops to 0 unexpectedly.
- [ ] **Pluck `ai_languages` from `/search/all`** — if Discovery ever surfaces
  this field in the lightweight endpoint, add it to
  `DEFAULT_COURSE_FIELDS_TO_PLUCK_FROM_SEARCH_ALL` in `constants.py` to reduce
  the Phase 2 dependency.
- [ ] **`dubbing_languages` facet** — the `ai_languages` dict also contains
  `dubbing_languages`; a follow-up PR could expose this as an additional facet.

---

*Document owner: enterprise-catalog team*
*Last updated: 2026-06-08*
