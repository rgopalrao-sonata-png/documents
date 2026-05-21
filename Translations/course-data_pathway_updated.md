# Credit Pathway Translation Design — Spanish

## Executive summary

The API endpoint `/api/dashboard/v0/programs/{uuid}/progress_details/` returns English for `credit_pathways` even when the page is rendered in Spanish because pathway content is English-only from the source, cached in LMS unchanged, and returned without language-aware field selection.

This is not primarily a frontend issue. The translation gap exists in the backend contract across Discovery and LMS.

The most efficient production approach is:

1. Keep English fields on `Pathway` as the default source fields.
2. Add a separate `PathwayTranslation` table in Discovery.
3. Expose a `translations` map in the Discovery API.
4. Cache the full pathway payload, including translations, in LMS.
5. Apply language selection at request time in LMS using `request.LANGUAGE_CODE`.

This avoids runtime machine translation, keeps the API backward-compatible, and scales cleanly to additional locales.

---

## Problem statement

When requesting:

`/api/dashboard/v0/programs/8ac6657e-a06a-4a47-aba7-5c86b5811fa1/progress_details/`

with `Accept-Language: es`, pathway fields inside `credit_pathways` remain in English.

Examples:

- `name`: `Master of Science in Professional Studies, Rochester Institute of Technology`
- `org_name`: `Rochester Institute of Technology`
- `description`: `27%`

Expected behavior:

- these fields should return Spanish values when Spanish translations exist.

Actual behavior:

- these fields are returned in English regardless of the request language.

---

## Current state analysis

### 1. Discovery model stores pathway text only in base fields

The `Pathway` model currently stores pathway text directly in the base table:

- `name`
- `org_name`
- `description`

Reference: [course-discovery/course_discovery/apps/course_metadata/models.py](course-discovery/course_discovery/apps/course_metadata/models.py#L4559-L4596)

Current shape:

```python
class Pathway(TimeStampedModel):
  uuid = models.UUIDField(...)
  partner = models.ForeignKey(...)
  name = models.CharField(max_length=255)
  org_name = models.CharField(max_length=255)
  email = models.EmailField(blank=True)
  programs = SortedManyToManyField(Program)
  description = models.TextField(null=True, blank=True)
  destination_url = models.URLField(null=True, blank=True)
  pathway_type = models.CharField(...)
  status = models.CharField(...)
```

There is no translation table for pathways today.

### 2. Discovery serializer returns only top-level English fields

Reference: [course-discovery/course_discovery/apps/api/serializers.py](course-discovery/course_discovery/apps/api/serializers.py#L2343-L2377)

`PathwaySerializer` currently emits the pathway fields directly:

- `name`
- `org_name`
- `description`

There is no:

- `translations` field
- request-language override logic
- fallback mechanism for localized variants

### 3. LMS caches pathway payloads exactly as returned by Discovery

Reference: [edx-platform/openedx/core/djangoapps/catalog/management/commands/cache_programs.py](edx-platform/openedx/core/djangoapps/catalog/management/commands/cache_programs.py#L195-L247)

`cache_programs` fetches published pathways from Discovery, stores them in cache, and links pathways to programs. If Discovery returns English-only JSON, LMS caches English-only JSON.

### 4. Dashboard API reads cached pathway data without localization

Reference: [edx-platform/openedx/core/djangoapps/programs/utils.py](edx-platform/openedx/core/djangoapps/programs/utils.py#L84-L99)

Reference: [edx-platform/openedx/core/djangoapps/programs/rest_api/v1/views.py](edx-platform/openedx/core/djangoapps/programs/rest_api/v1/views.py#L327-L345)

`ProgramProgressDetailView` calls `get_industry_and_credit_pathways(program_data, site)`, and that utility reads pathway JSON from cache and returns it as-is.

There is no check for:

- `request.LANGUAGE_CODE`
- `Accept-Language`
- `translations['es']`

---

## Root cause

The root cause is a missing translation architecture for `Pathway`.

Unlike other entities that support localized output, pathways currently have:

- no translation table,
- no serializer translation payload,
- no cache payload for alternate languages,
- no LMS runtime language selection.

Because of that, the API is behaving correctly according to current backend data, but not according to the desired multilingual product behavior.

---

## Design goals

The solution should be:

1. **Efficient** — no runtime MT calls in learner-facing requests.
2. **Backward-compatible** — existing clients still receive top-level `name`, `org_name`, and `description`.
3. **Low risk** — avoid disruptive changes to existing `Pathway` semantics.
4. **Cache-friendly** — one cached payload can serve multiple locales.
5. **Scalable** — Spanish now, extensible to more locales later.
6. **Operationally safe** — supports backfill, re-run, retries, and partial rollout.

---

## Recommended architecture

### Preferred approach: sidecar translation table

Do **not** translate pathway fields at request time.

Do **not** hardcode translations in LMS except as an emergency hotfix.

Do **not** add one column per language such as `name_es`, `org_name_es`, `description_es` unless the scope is permanently Spanish-only.

Instead, add a sidecar translation table in Discovery:

- `Pathway` remains the base English/default object.
- `PathwayTranslation` stores translated text per locale.
- Discovery API returns a `translations` map.
- LMS caches that full response.
- LMS chooses the best translation at request time.

This is the safest and most efficient design.

---

## Proposed data model

Add a new model in Discovery:

```python
class PathwayTranslation(TimeStampedModel):
  pathway = models.ForeignKey(
    Pathway,
    related_name='translations',
    on_delete=models.CASCADE,
  )
  language_code = models.CharField(max_length=10, db_index=True)
  name = models.CharField(max_length=255, blank=True, default='')
  org_name = models.CharField(max_length=255, blank=True, default='')
  description = models.TextField(blank=True, default='')
  source_hash = models.CharField(max_length=64, blank=True, default='')

  class Meta:
    unique_together = ('pathway', 'language_code')
```

### Why this model

- `Pathway` stays unchanged for existing reads and writes.
- `language_code` supports Spanish now and more locales later.
- `source_hash` allows efficient incremental refresh.
- `unique_together` prevents duplicate language rows.

---

## Discovery service changes

### Step 1: add `PathwayTranslation`

File: [course-discovery/course_discovery/apps/course_metadata/models.py](course-discovery/course_discovery/apps/course_metadata/models.py)

Add the new `PathwayTranslation` model.

### Step 2: create a migration and backfill English

Create a migration that:

1. creates the `PathwayTranslation` table,
2. backfills one `language_code='en'` row per existing `Pathway`.

Suggested migration backfill logic:

```python
def backfill_english_translations(apps, schema_editor):
  Pathway = apps.get_model('course_metadata', 'Pathway')
  PathwayTranslation = apps.get_model('course_metadata', 'PathwayTranslation')

  for pathway in Pathway.objects.iterator():
    PathwayTranslation.objects.get_or_create(
      pathway_id=pathway.id,
      language_code='en',
      defaults={
        'name': pathway.name or '',
        'org_name': pathway.org_name or '',
        'description': pathway.description or '',
      },
    )
```

### Step 3: update `PathwaySerializer`

File: [course-discovery/course_discovery/apps/api/serializers.py](course-discovery/course_discovery/apps/api/serializers.py#L2343-L2377)

Add:

- a `translations` field,
- request-aware top-level field override,
- prefetching for translations.

Recommended serializer pattern:

```python
class PathwaySerializer(BaseModelSerializer):
  translations = serializers.SerializerMethodField()

  def get_translations(self, obj):
    return {
      translation.language_code: {
        'name': translation.name,
        'org_name': translation.org_name,
        'description': translation.description,
      }
      for translation in obj.translations.all()
    }

  @classmethod
  def prefetch_queryset(cls, partner, course_runs=None):
    queryset = Pathway.objects.filter(partner=partner)
    return queryset.prefetch_related(
      'translations',
      Prefetch('programs', queryset=MinimalProgramSerializer.prefetch_queryset(
        partner=partner, course_runs=course_runs
      )),
    )

  def to_representation(self, instance):
    data = super().to_representation(instance)
    request = self.context.get('request')
    language_code = getattr(request, 'LANGUAGE_CODE', None)

    translations = data.get('translations', {})
    localized = translations.get(language_code)

    if localized:
      data['name'] = localized.get('name') or data['name']
      data['org_name'] = localized.get('org_name') or data['org_name']
      data['description'] = localized.get('description') or data['description']

    return data
```

### Step 4: return a stable API contract

Recommended response shape:

```json
{
  "id": 196,
  "uuid": "86b9701a-61e6-48a2-92eb-70a824521c1f",
  "name": "Maestría en Ciencias en Estudios Profesionales, Instituto Tecnológico de Rochester",
  "org_name": "Instituto Tecnológico de Rochester",
  "description": "27%",
  "translations": {
  "en": {
    "name": "Master of Science in Professional Studies, Rochester Institute of Technology",
    "org_name": "Rochester Institute of Technology",
    "description": "27%"
  },
  "es": {
    "name": "Maestría en Ciencias en Estudios Profesionales, Instituto Tecnológico de Rochester",
    "org_name": "Instituto Tecnológico de Rochester",
    "description": "27%"
  }
  }
}
```

### Why localize top-level fields in Discovery as well

This keeps the API intuitive and backward-compatible:

- existing consumers still use `name`, `org_name`, `description`,
- advanced consumers can use `translations` directly,
- LMS can still apply runtime selection from cached data if needed.

---

## LMS changes

### Step 1: keep caching full pathway payloads

File: [edx-platform/openedx/core/djangoapps/catalog/management/commands/cache_programs.py](edx-platform/openedx/core/djangoapps/catalog/management/commands/cache_programs.py)

The cache layer already stores the full pathway payload returned by Discovery. If Discovery starts returning `translations`, those will automatically be cached.

Only minimal or no cache write changes should be necessary.

### Step 2: localize pathway fields at read time

File: [edx-platform/openedx/core/djangoapps/programs/utils.py](edx-platform/openedx/core/djangoapps/programs/utils.py#L84-L99)

Update `get_industry_and_credit_pathways()` so it accepts a language code and applies localized values from cached JSON.

Recommended implementation:

```python
def apply_pathway_translation(pathway, language_code):
  if not pathway or not language_code:
    return pathway

  translations = pathway.get('translations') or {}
  localized = translations.get(language_code)
  if not localized:
    return pathway

  localized_pathway = dict(pathway)
  localized_pathway['name'] = localized.get('name') or pathway.get('name')
  localized_pathway['org_name'] = localized.get('org_name') or pathway.get('org_name')
  localized_pathway['description'] = localized.get('description') or pathway.get('description')
  return localized_pathway


def get_industry_and_credit_pathways(program_data, site, language_code=None):
  industry_pathways = []
  credit_pathways = []
  try:
    for pathway_id in program_data['pathway_ids']:
      pathway = get_pathways(site, pathway_id)
      pathway = apply_pathway_translation(pathway, language_code)
      if pathway and pathway['email']:
        if pathway['pathway_type'] == PathwayType.CREDIT.value:
          credit_pathways.append(pathway)
        elif pathway['pathway_type'] == PathwayType.INDUSTRY.value:
          industry_pathways.append(pathway)
  except KeyError:
    pass

  return industry_pathways, credit_pathways
```

### Step 3: pass request language from the view

File: [edx-platform/openedx/core/djangoapps/programs/rest_api/v1/views.py](edx-platform/openedx/core/djangoapps/programs/rest_api/v1/views.py#L327-L345)

Update the view to pass language context:

```python
industry_pathways, credit_pathways = get_industry_and_credit_pathways(
  program_data,
  site,
  getattr(request, 'LANGUAGE_CODE', None),
)
```

This is the cleanest and lowest-risk integration point.

---

## Translation generation strategy

### Do not translate at request time

Runtime MT should be avoided because it introduces:

- learner-facing latency,
- provider dependency during page loads,
- inconsistent responses,
- higher cost,
- difficult debugging.

### Use an offline backfill/update command

Create a Discovery management command, for example:

- `populate_pathway_translations`

Recommended options:

- `--pathway-ids`
- `--missing-only`
- `--force`
- `--batch-size`
- `--dry-run`
- `--languages es`

Recommended behavior:

1. fetch pathways,
2. compute a source hash from `name`, `org_name`, and `description`,
3. skip unchanged rows,
4. translate only stale or missing language rows,
5. save into `PathwayTranslation`.

Suggested logic:

```python
class Command(BaseCommand):
  def handle(self, *args, **options):
    for pathway in queryset:
      source_hash = compute_pathway_source_hash(pathway)
      translation = PathwayTranslation.objects.filter(
        pathway=pathway,
        language_code='es',
      ).first()

      if translation and translation.source_hash == source_hash and not force:
        continue

      translated = translate_fields({
        'name': pathway.name,
        'org_name': pathway.org_name,
        'description': pathway.description,
      })

      PathwayTranslation.objects.update_or_create(
        pathway=pathway,
        language_code='es',
        defaults={
          'name': translated.get('name', ''),
          'org_name': translated.get('org_name', ''),
          'description': translated.get('description', ''),
          'source_hash': source_hash,
        },
      )
```

### Efficiency note

If `description` is purely numeric or symbol-based, for example `27%`, skip translation for that field and reuse the same value.

---

## Rollout plan

### Phase 1: Discovery schema and API

1. Add `PathwayTranslation` model.
2. Create migration.
3. Backfill English rows.
4. Update serializer to expose `translations`.
5. Add prefetching and tests.

### Phase 2: Translation backfill

1. Run Spanish translation command in staging.
2. QA translated pathway names and organization names.
3. Fix or manually override any poor MT results.

### Phase 3: LMS localization

1. Update `get_industry_and_credit_pathways()`.
2. Pass `request.LANGUAGE_CODE` from `ProgramProgressDetailView`.
3. Add unit tests for Spanish selection and English fallback.

### Phase 4: Cache refresh

After deployment of Discovery changes and translation backfill, re-run the LMS cache refresh:

```bash
./manage.py cache_programs
```

Without cache refresh, LMS may continue to serve stale English-only payloads.

---

## Testing plan

### Discovery tests

Add tests for:

1. `PathwayTranslation` uniqueness by `(pathway, language_code)`.
2. migration backfills `en` rows.
3. serializer emits `translations`.
4. serializer returns Spanish top-level fields when request language is `es`.
5. serializer falls back to English when Spanish is missing.

### LMS tests

Add tests for:

1. `get_industry_and_credit_pathways()` returns English by default.
2. returns Spanish when `translations['es']` exists.
3. falls back cleanly if one localized field is missing.
4. handles missing `pathway_ids` safely.

### End-to-end validation

Validate this flow:

1. Discovery pathway response contains `translations`.
2. LMS cache entry contains `translations`.
3. dashboard API with `Accept-Language: es` returns Spanish `credit_pathways`.

---

## Monitoring and operations

Track the following:

1. number of pathways missing Spanish translations,
2. translation backfill failures,
3. stale translation count based on source hash mismatch,
4. cache refresh completion after translation updates.

Suggested operational query:

```sql
SELECT COUNT(*) AS missing_es
FROM course_metadata_pathway p
LEFT JOIN course_metadata_pathwaytranslation pt
  ON pt.pathway_id = p.id
 AND pt.language_code = 'es'
WHERE pt.id IS NULL;
```

---

## Risks and mitigations

### Risk 1: migration load

Backfilling translation rows could be heavy on large datasets.

**Mitigation:**

- use batched iteration,
- run during low-traffic windows,
- keep migration logic lightweight,
- move large non-essential translation generation to a management command instead of migration.

### Risk 2: stale cache after deployment

LMS may continue to serve old English-only pathway payloads.

**Mitigation:**

- explicitly re-run `cache_programs` after rollout,
- add operational runbook steps.

### Risk 3: MT quality issues

Pathway names may require human review.

**Mitigation:**

- allow manual override in translation rows,
- stage and QA before production publish.

### Risk 4: partial translations

Some translated rows may be incomplete.

**Mitigation:**

- apply field-by-field fallback to English,
- never fail the full response because one localized field is missing.

---

## Alternatives considered

### Option A: hardcoded translations in LMS

**Pros**

- fastest to ship

**Cons**

- not scalable,
- content changes require deploys,
- wrong ownership boundary,
- poor maintainability.

**Verdict:** only acceptable as an emergency hotfix.

### Option B: Spanish-only fields on `Pathway`

Example:

- `name_es`
- `org_name_es`
- `description_es`

**Pros**

- simple for one locale

**Cons**

- poor scalability,
- schema duplication,
- awkward for future locales.

**Verdict:** acceptable only if the product will never support more than one translated locale.

### Option C: convert `Pathway` fully to `TranslatableModel`

**Pros**

- consistent with some Discovery translated models

**Cons**

- more invasive,
- broader regression surface,
- not required for this use case.

**Verdict:** possible, but not the most efficient path.

### Option D: sidecar `PathwayTranslation` model

**Pros**

- low risk,
- scalable,
- cache-friendly,
- clean ownership in Discovery,
- supports incremental rollout.

**Verdict:** best option.

---

## Final recommendation

Implement the pathway translation solution as follows:

1. Add `PathwayTranslation` in Discovery.
2. Backfill English rows.
3. Add a management command to generate Spanish translations offline.
4. Expose `translations` in `PathwaySerializer`.
5. Keep top-level fields backward-compatible.
6. Let LMS cache the full translated payload.
7. Apply language selection in LMS using `request.LANGUAGE_CODE`.
8. Refresh `cache_programs` after translation changes.

This gives the best balance of performance, safety, compatibility, and long-term maintainability.

---

## Implementation summary by file

### Discovery

- Add model in [course-discovery/course_discovery/apps/course_metadata/models.py](course-discovery/course_discovery/apps/course_metadata/models.py)
- Add migration in `course_discovery/apps/course_metadata/migrations/`
- Update serializer in [course-discovery/course_discovery/apps/api/serializers.py](course-discovery/course_discovery/apps/api/serializers.py#L2343-L2377)
- Add management command in `course_discovery/apps/course_metadata/management/commands/`

### LMS

- Reuse cache flow in [edx-platform/openedx/core/djangoapps/catalog/management/commands/cache_programs.py](edx-platform/openedx/core/djangoapps/catalog/management/commands/cache_programs.py)
- Update localization logic in [edx-platform/openedx/core/djangoapps/programs/utils.py](edx-platform/openedx/core/djangoapps/programs/utils.py#L84-L99)
- Pass language from [edx-platform/openedx/core/djangoapps/programs/rest_api/v1/views.py](edx-platform/openedx/core/djangoapps/programs/rest_api/v1/views.py#L327-L345)

---

## Operational commands

Apply migrations in Discovery:

```bash
./manage.py migrate course_metadata
```

Run Spanish backfill:

```bash
./manage.py populate_pathway_translations --missing-only --languages es --batch-size 50
```

Refresh LMS programs cache:

```bash
./manage.py cache_programs
```

---

## Conclusion

Credit pathway translation is currently missing because pathways do not participate in a translation lifecycle. The efficient production-safe fix is to make translations first-class data in Discovery, cache them in LMS, and select the right language at response time.

That design solves the current Spanish issue and provides a foundation for future multilingual pathway support.
