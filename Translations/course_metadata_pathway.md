# Credit Pathway Translation Status — Spanish

## Summary
Spanish translations are **not available** for credit pathways in the Dashboard API response. The `credit_pathways` array contains pathway data from the `course_metadata_pathway` table, which does not support multi-language content.

## Problem Statement
When viewing the Dashboard API endpoint (`/api/dashboard/v0/programs/{uuid}/progress_details/`) with `Accept-Language: es`, the following pathway fields remain in English:

- `name`: "Master of Science in Professional Studies, Rochester Institute of Technology"
- `org_name`: "Rochester Institute of Technology"  
- `description`: "27%"

**Expected behavior**: These fields should be translated to Spanish when the user's language preference is Spanish.

**Actual behavior**: All pathway fields are returned in English only, regardless of the `Accept-Language` header.

---

## Root Cause Analysis

### 1. Database Schema — No Translation Support
The `Pathway` model in the Discovery service (`course_discovery/apps/course_metadata/models.py`) stores text fields as plain strings:

```python
class Pathway(TimeStampedModel):
    uuid = models.UUIDField(...)
    name = models.CharField(max_length=255)
    org_name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    # ... other fields
```

**Key Issue**: Unlike `Course`, `Program`, or `Academy` models, the `Pathway` model:
- ❌ Does **not** inherit from `TranslatableModel` (django-parler)
- ❌ Does **not** have a companion `PathwayTranslation` table
- ❌ Is **excluded** from the existing translation infrastructure

### 2. API Serialization — No Translation Logic
The `PathwaySerializer` in Discovery (`course_discovery/apps/api/serializers.py`) returns fields as-is:

```python
class PathwaySerializer(serializers.ModelSerializer):
    class Meta:
        model = Pathway
        fields = ('id', 'uuid', 'name', 'org_name', 'email', 
                  'description', 'destination_url', ...)
```

**Key Issue**: The serializer:
- ❌ Does **not** check the `Accept-Language` header
- ❌ Does **not** include a `translations` field or map
- ❌ Returns the same English text for all requests

### 3. LMS Cache — English-Only Payload
The LMS caches pathway data from Discovery using the `cache_programs` management command. The cached JSON stored in Redis/Memcached contains only English strings:

```json
"credit_pathways": [
  {
    "id": 196,
    "name": "Master of Science in Professional Studies, Rochester Institute of Technology",
    "org_name": "Rochester Institute of Technology",
    "description": "27%",
    ...
  }
]
```

**Key Issue**: The cache:
- ❌ Does **not** store multi-language versions
- ❌ Is used directly by the Dashboard API without translation selection

### 4. Dashboard API — No Runtime Translation
The `ProgramProgressDetailView` in the LMS (`edx-platform/openedx/core/djangoapps/programs/rest_api/v1/views.py`) serves the pathway data from cache:

```python
def get(self, request, program_uuid):
    # ... fetch program_data from cache
    return Response({
        'program_data': program_data,
        'credit_pathways': get_industry_and_credit_pathways(program_data, site),
        ...
    })
```

**Key Issue**: The view:
- ❌ Does **not** inspect `request.LANGUAGE_CODE` or `Accept-Language`
- ❌ Does **not** perform runtime selection of translated pathway fields
- ❌ Returns cached English strings directly

---

## Comparison with Organizations

**Organizations** in the same API response **do have** Spanish translations:

```json
"authoring_organizations": [
  {
    "name": "Rochester Institute of Technology",
    "description": "<p>Rochester Institute of Technology is home to...</p>",
    "description_es": "<p>Rochester Institute of Technology (Instituto Tecnológico de Rochester)...</p>"
  }
]
```

**Why organizations work but pathways don't:**

| Feature | Organizations | Pathways |
|---------|--------------|----------|
| Translation table | ✅ `OrganizationTranslation` | ❌ None |
| Parler integration | ✅ Yes | ❌ No |
| API includes `*_es` fields | ✅ Yes | ❌ No |
| Discovery serializer handles translations | ✅ Yes | ❌ No |

---

## Impact

### User Experience
- Spanish-speaking learners see English pathway names/descriptions in their learner dashboard
- Inconsistent experience: Programs, courses, and organizations are translated, but pathways are not
- Reduced trust and engagement for non-English learners

### Business Impact
- Lower conversion rates for credit pathway programs in Spanish-speaking markets
- Difficulty scaling edX offerings to international learners

---

## Recommended Solution

To enable Spanish translations for credit pathways, the following changes are required across **two services** (Discovery and LMS):

### Phase 1: Discovery Service (Backend Data Model)

#### Step 1.1: Add Translation Model
Modify `course_discovery/apps/course_metadata/models.py`:

```python
from parler.models import TranslatableModel, TranslatedFieldsModel

class Pathway(TranslatableModel, TimeStampedModel):
    uuid = models.UUIDField(...)
    # Keep existing fields for backward compatibility
    name = models.CharField(max_length=255)
    org_name = models.CharField(max_length=255) 
    description = models.TextField(blank=True)
    # ... other fields
    
    translations = TranslatedFields(
        name_t=models.CharField(max_length=255),
        org_name_t=models.CharField(max_length=255),
        description_t=models.TextField(blank=True),
    )
    
    def __str__(self):
        return self.safe_translation_getter('name_t', any_language=True) or self.name
```

#### Step 1.2: Create Database Migration
Create `course_discovery/apps/course_metadata/migrations/0XXX_add_pathway_translation.py`:

```python
from django.db import migrations

def backfill_english_translations(apps, schema_editor):
    Pathway = apps.get_model('course_metadata', 'Pathway')
    PathwayTranslation = apps.get_model('course_metadata', 'PathwayTranslation')
    
    for pathway in Pathway.objects.all():
        PathwayTranslation.objects.get_or_create(
            master_id=pathway.id,
            language_code='en',
            defaults={
                'name_t': pathway.name,
                'org_name_t': pathway.org_name,
                'description_t': pathway.description,
            }
        )

class Migration(migrations.Migration):
    operations = [
        # Add PathwayTranslation table
        migrations.CreateModel(...),
        # Backfill English from existing data
        migrations.RunPython(backfill_english_translations, migrations.RunPython.noop),
    ]
```

#### Step 1.3: Update API Serializer
Modify `course_discovery/apps/api/serializers.py`:

```python
class PathwaySerializer(serializers.ModelSerializer):
    class Meta:
        model = Pathway
        fields = ('id', 'uuid', 'name', 'org_name', 'email', 
                  'description', 'destination_url', 'translations', ...)
    
    def to_representation(self, instance):
        data = super().to_representation(instance)
        
        # Add translations map for all available languages
        data['translations'] = {}
        for translation in instance.translations.all():
            data['translations'][translation.language_code] = {
                'name': translation.name_t,
                'org_name': translation.org_name_t,
                'description': translation.description_t,
            }
        
        # Override top-level fields based on Accept-Language header
        request = self.context.get('request')
        if request:
            lang = get_language_from_request(request)  # e.g., 'es'
            if lang in data['translations']:
                data['name'] = data['translations'][lang]['name']
                data['org_name'] = data['translations'][lang]['org_name']
                data['description'] = data['translations'][lang]['description']
        
        return data
```

### Phase 2: LMS Service (Cache & API)

#### Step 2.1: Cache Translations
Ensure `cache_programs` command stores the full `translations` payload in the cached program JSON.

#### Step 2.2: Update Dashboard API
Modify `edx-platform/openedx/core/djangoapps/programs/utils.py`:

```python
def get_industry_and_credit_pathways(program_data, site, request=None):
    pathways = program_data.get('pathways', [])
    # ... existing logic
    
    # NEW: Runtime translation selection
    if request and hasattr(request, 'LANGUAGE_CODE'):
        lang = request.LANGUAGE_CODE  # e.g., 'es'
        for pathway in pathways:
            translations = pathway.get('translations', {})
            if lang in translations:
                pathway['name'] = translations[lang]['name']
                pathway['org_name'] = translations[lang]['org_name']
                pathway['description'] = translations[lang]['description']
    
    return pathways
```

Update `ProgramProgressDetailView` to pass `request`:

```python
def get(self, request, program_uuid):
    # ...
    return Response({
        'credit_pathways': get_industry_and_credit_pathways(program_data, site, request),
        ...
    })
```

### Phase 3: Backfill Spanish Translations

#### Create Management Command
Create `course_discovery/apps/course_metadata/management/commands/backfill_pathway_translations.py`:

```python
from django.core.management.base import BaseCommand
from course_metadata.models import Pathway
import requests

class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument('--languages', nargs='+', default=['es'])
        parser.add_argument('--mt-endpoint', required=True)
        parser.add_argument('--mt-key', required=True)
    
    def handle(self, *args, **options):
        for pathway in Pathway.objects.all():
            for lang in options['languages']:
                # Translate via MT API
                translations = self.translate_fields(pathway, lang, options)
                
                # Save to PathwayTranslation table
                pathway.set_current_language(lang)
                pathway.name_t = translations['name']
                pathway.org_name_t = translations['org_name']
                pathway.description_t = translations['description']
                pathway.save()
```

Run: `./manage.py backfill_pathway_translations --languages=es --mt-endpoint=https://api.deepl.com/v2/translate --mt-key=$KEY`

---

## Alternative: Hardcoded Translations (Quick Fix)

If a full translation infrastructure is not feasible for MVP, hardcode Spanish translations for the specific pathway:

```python
# In LMS utils.py
PATHWAY_TRANSLATIONS = {
    196: {  # Pathway ID
        'es': {
            'name': 'Maestría en Ciencias en Estudios Profesionales, Instituto Tecnológico de Rochester',
            'org_name': 'Instituto Tecnológico de Rochester',
            'description': '27%',
        }
    }
}

def get_industry_and_credit_pathways(program_data, site, request=None):
    pathways = program_data.get('pathways', [])
    
    if request and hasattr(request, 'LANGUAGE_CODE'):
        lang = request.LANGUAGE_CODE
        for pathway in pathways:
            pathway_id = pathway.get('id')
            if pathway_id in PATHWAY_TRANSLATIONS and lang in PATHWAY_TRANSLATIONS[pathway_id]:
                trans = PATHWAY_TRANSLATIONS[pathway_id][lang]
                pathway['name'] = trans['name']
                pathway['org_name'] = trans['org_name']
                pathway['description'] = trans['description']
    
    return pathways
```

**Pros**: Fast, no DB changes, no migration  
**Cons**: Not scalable, requires code deployment for each new translation

---

## Risks & Considerations

1. **Migration Downtime**: Adding `PathwayTranslation` table and backfilling data may lock the `course_metadata_pathway` table. Run during maintenance window.

2. **Cache Invalidation**: After deploying Discovery changes, you **must** re-run `cache_programs` to refresh the LMS cache with the new `translations` payload.

3. **MT Quality**: Machine-translated pathway names may require human review before publishing. Consider a staging/QA workflow.

4. **API Compatibility**: Ensure existing API clients can handle the new `translations` field (should be backward-compatible if you keep top-level `name`, `org_name`, `description` fields).

---

## Next Steps

1. **Decision**: Choose between full translation infrastructure (Phase 1-3) or hardcoded translations (quick fix).
2. **Estimation**: Full implementation ~3-5 days (backend changes + migration + backfill + testing).
3. **Approval**: Get Product/UX approval for translated pathway names.
4. **Implementation**: Follow phases above, test in staging, deploy to production.
5. **Cache Refresh**: Run `./manage.py cache_programs` after deploying Discovery changes.

---

## Related Documentation

- [Pathway Translation Status (Course/Program)](PATHWAY_TRANSLATION_STATUS.md) - Same issue, different content type
- Discovery Translation Pipeline: `course_discovery/apps/course_metadata/algolia_models.py`
- LMS Cache Management: `edx-platform/openedx/core/djangoapps/catalog/management/commands/cache_programs.py`

---

## Conclusion

Credit pathway translations are **not available** because:
1. The `Pathway` model lacks translation infrastructure (no parler, no translation table)
2. The Discovery API does not support `Accept-Language` for pathways
3. The LMS cache stores and serves English-only pathway data

**To fix**: Add `PathwayTranslation` model, update serializer, backfill Spanish translations, and refresh LMS cache. Estimated effort: 3-5 days for full implementation.
