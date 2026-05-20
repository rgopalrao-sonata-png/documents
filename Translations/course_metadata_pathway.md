# Pathway Translation Status — Spanish

Summary
-------
Based on research across the Discovery and LMS codebases, Spanish translations are not currently available for the `course_metadata_pathway` table. Pathways are not included in the existing Discovery/Algolia translation pipeline.

Findings
--------
- The Discovery `Pathway` model stores `name`, `org_name`, and `description` as plain text in the `course_metadata_pathway` table: [course_discovery/apps/course_metadata/models.py](course_discovery/apps/course_metadata/models.py).
- The translation pipeline and models currently cover three content types only:
  - `CourseTranslation`
  - `ProgramTranslation`
  - `AcademyTranslation`
  These are the types included in the dynamic/Algolia translation processes (Discovery: Translation of Dynamic Algolia Content).
- There is no `PathwayTranslation` model or translation table for pathways; Pathways are explicitly excluded from the translation infra.
- Because Discovery returns pathway fields in English only, the LMS `cache_programs` flow stores the English JSON and the Dashboard API surfaces those values directly (hence no Spanish in `credit_pathways`).

Key references
--------------
- Discovery model: [course_discovery/apps/course_metadata/models.py](course_discovery/apps/course_metadata/models.py)
- Discovery API serializer (pathways): [course_discovery/apps/api/serializers.py](course_discovery/apps/api/serializers.py)
- Discovery viewset: [course_discovery/apps/api/v1/views/pathways.py](course_discovery/apps/api/v1/views/pathways.py)
- LMS cache and programs flow: [openedx/core/djangoapps/catalog/management/commands/cache_programs.py](openedx/core/djangoapps/catalog/management/commands/cache_programs.py) and [openedx/core/djangoapps/programs/utils.py](openedx/core/djangoapps/programs/utils.py)
- Learner Recommendations tech spec (MVP decisions): multi-language pathway rationale listed as a No-Go.

Diagram — data & translation flow
---------------------------------
Inline SVG flow diagram illustrating where translations are missing (Pathway):

<svg xmlns="http://www.w3.org/2000/svg" width="900" height="240" viewBox="0 0 900 240">
  <style>
    .box { fill:#f8f9fb; stroke:#34495e; stroke-width:1; }
    .label { font:14px sans-serif; fill:#111827; }
    .small { font:12px sans-serif; fill:#334155; }
    .arrow { stroke:#34495e; stroke-width:2; marker-end:url(#arrowhead); }
  </style>
  <defs>
    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#34495e" />
    </marker>
  </defs>

  <!-- Discovery DB -->
  <rect x="20" y="30" width="200" height="70" rx="6" class="box" />
  <text x="30" y="55" class="label">Discovery DB</text>
  <text x="30" y="75" class="small">course_metadata_pathway (EN only)</text>

  <!-- Discovery API -->
  <rect x="260" y="20" width="220" height="90" rx="6" class="box" />
  <text x="275" y="48" class="label">Discovery API</text>
  <text x="275" y="68" class="small">/api/pathways/ → JSON (no PathwayTranslation)</text>

  <!-- LMS cache -->
  <rect x="520" y="20" width="240" height="90" rx="6" class="box" />
  <text x="540" y="48" class="label">LMS cache</text>
  <text x="540" y="68" class="small">cache key: pathway-{id} (EN JSON)</text>

  <!-- Dashboard API & Client -->
  <rect x="260" y="140" width="320" height="70" rx="6" class="box" />
  <text x="275" y="165" class="label">Dashboard API / Client</text>
  <text x="275" y="185" class="small">/api/dashboard/v0/programs/{uuid}/progress_details/</text>

  <!-- arrows -->
  <line x1="220" y1="65" x2="260" y2="65" class="arrow" />
  <line x1="480" y1="65" x2="520" y2="65" class="arrow" />
  <line x1="395" y1="110" x2="395" y2="140" class="arrow" />

  <!-- note about translation gaps -->
  <rect x="560" y="130" width="300" height="70" rx="6" fill="#fff3cd" stroke="#856404" />
  <text x="575" y="155" class="label" fill="#856404">Translation gap</text>
  <text x="575" y="175" class="small" fill="#856404">No PathwayTranslation model; responses are English-only</text>
</svg>

Implications
------------
- Because Discovery stores pathways as plain text, the Discovery API returns English-only pathway fields. The LMS caches that JSON and the Dashboard displays the same English strings.
- Adding translation support requires changes in Discovery (data model + API) and a cache refresh so LMS receives translation-aware JSON.

Recommended changes (MVP path)
-----------------------------
1. Add a `PathwayTranslation` model (parler-style) and keep the existing `Pathway` model fields for backwards compatibility.
2. Create a migration to add the translation table and backfill `language_code='en'` rows from existing `name/org_name/description` values.
3. Update the Discovery `PathwaySerializer` to include a `translations` map and to respect `Accept-Language` when returning top-level fields.
4. Ensure `cache_programs` stores the full translations payload (so `pathway-{id}` includes `translations`).
5. Update the LMS `get_industry_and_credit_pathways` (or equivalent) to select the best translation from cached JSON at request time.
6. Backfill additional languages via a controlled MT pipeline (management command) and mark translations for human QA.

Commands & quick run notes
--------------------------
- Apply migrations in Discovery:

```bash
./manage.py migrate course_metadata
```

- Run a backfill (example):

```bash
./manage.py backfill_pathway_translations --languages=es --mt-endpoint=https://mt.example/translate --mt-key=$MT_KEY
```

Risks & operational notes
-------------------------
- Migration and backfill can be heavy for large catalogs: run during maintenance windows or in small batches.
- Caching: after deploying Discovery changes, you must refresh the LMS cache (re-run `cache_programs`) so LMS serves translated payloads.
- MT outputs need QA before publishing to learners; consider a review workflow or staging flag that gates MT translations.

Conclusion
----------
Spanish (and other) translations are currently unavailable for `course_metadata_pathway` because there is no `PathwayTranslation` model or pipeline. The minimal, production-safe path is to add a parler-style translation model, backfill English, expose translations in the API, refresh caches, and then optionally backfill other languages via MT with human review.

If you want, I can:
- produce the exact migration PR (models + migration + data migration) for Discovery,
- wire the backfill command to a specific MT provider (DeepL/Google) with batching and retries,
- add tests for the serializer and the LMS selection logic.
