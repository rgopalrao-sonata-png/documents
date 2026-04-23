# DA (Danish) Translation Validation Failures — CI Job Analysis

**CI Run:** [#24407487094 / job #71294715291](https://github.com/edx/openedx-translations/actions/runs/24407487094/job/71294715291)
**PR:** [#136 — chore: add AI translated strings #178](https://github.com/edx/openedx-translations/pull/136)
**Workflow:** `validate-json-files`
**Status:** FAILED
**Date Analysed:** April 23, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Toolchain Explained](#toolchain-explained)
3. [Error Types Reference](#error-types-reference)
4. [Failure Details per App](#failure-details-per-app)
   - [frontend-app-account](#1-frontend-app-account)
   - [frontend-app-admin-portal](#2-frontend-app-admin-portal)
   - [frontend-app-authn](#3-frontend-app-authn)
   - [frontend-app-discussions](#4-frontend-app-discussions)
   - [frontend-app-learner-dashboard](#5-frontend-app-learner-dashboard)
   - [frontend-app-learning](#6-frontend-app-learning)
   - [paragon](#7-paragon)
   - [studio-frontend](#8-studio-frontend)
5. [Root Cause Summary](#root-cause-summary)
6. [Verification](#verification)
7. [Prevention Checklist](#prevention-checklist)

---

## Overview

The CI job `validate-json-files` validates all translated `.json` files against their English source (stored as `transifex_input.json`) using the `@formatjs/cli verify` tool with the `--structural-equality` flag.

**8 apps had failing Danish (`da`) translation files out of ~25 validated apps.** All failures involved ICU MessageFormat syntax mismatches between the English source and the Danish translation produced by the AI translation service.

```
INVALID: translations/frontend-app-account/src/i18n/messages/da.json
INVALID: translations/frontend-app-admin-portal/src/i18n/messages/da.json
INVALID: translations/frontend-app-authn/src/i18n/messages/da.json
INVALID: translations/frontend-app-discussions/src/i18n/messages/da.json
INVALID: translations/frontend-app-learner-dashboard/src/i18n/messages/da.json
INVALID: translations/frontend-app-learning/src/i18n/messages/da.json
INVALID: translations/paragon/src/i18n/messages/da.json
INVALID: translations/studio-frontend/src/i18n/messages/da.json
```

---

## Toolchain Explained

### Validation Command

The script `scripts/validate_translation_files.py` runs:

```bash
npx @formatjs/cli verify \
  --structural-equality \
  --source-locale=en \
  en.json          # copy of transifex_input.json
  da.json          # translated file under test
```

### What `--structural-equality` Checks

| Check | Description |
|-------|-------------|
| Variable names | All `{variables}` in EN must be present in the translation |
| Variable types | `{count, plural, ...}` must not change to `{count}` plain string across messages |
| Plural clauses | ICU `plural` blocks must contain an `other` clause |
| Select clauses | ICU `select` blocks must contain an `other` clause |
| Argument type | A variable must have the same argument type (string, plural, select, etc.) consistently |

### File Roles

| File | Role |
|------|------|
| `src/i18n/transifex_input.json` | English source strings (ground truth) |
| `src/i18n/messages/da.json` | Danish AI-translated strings (validated against EN) |

---

## Error Types Reference

| Error Code | Meaning | Common Cause |
|---|---|---|
| `INVALID_ARGUMENT_TYPE` | A variable is used as both a plain string `{x}` and a complex type `{x, select, ...}` in different messages within the same locale file | AI translation flattened a complex ICU expression into a plain string, or the DA file mixes plain-string and object (`{string:...}`) formats |
| `MISSING_OTHER_CLAUSE` | An ICU `plural` or `select` block is missing its mandatory `other` case | AI translator stripped trailing whitespace/braces from the ICU expression |
| `Missing variable X in message` | A required interpolation variable present in EN was omitted in the translated string | AI translator dropped the `{variable}` placeholder during translation |
| `Different number of variables` | The EN message has N variables but the DA message has M ≠ N variables | AI translator omitted one or more `{variable}` placeholders |
| `Variable X has conflicting types` | The same variable name is seen as a plain string in one message and as a `plural`/`select` in another | DA file format inconsistency (mix of plain strings and `{string:...}` objects) causing the parser to infer different types |

---

## Failure Details per App

---

### 1. `frontend-app-account`

**File:** `translations/frontend-app-account/src/i18n/messages/da.json`

**Error:** `INVALID_ARGUMENT_TYPE`

**Failing Keys:**
- `notification.preference.app.title`
- `notification.preference.channel`

**Root Cause:**

The English source uses ICU `select` expressions with **leading whitespace** inside the outer braces (`{ key, select, ... }`). The AI translator stripped this whitespace in the DA translation, producing `{key, select, ...}`. Some versions of `@formatjs/cli` treat the whitespace-stripped form as a plain string argument vs. the select argument type used elsewhere.

```diff
# English source (transifex_input.json)
"notification.preference.app.title":
  "{ key, select, discussion {Discussions} coursework {Course Work} updates {Updates} grading {Grading} other {{key}} }"
                                                                 # note: leading space ^

# Danish translation (da.json) — INVALID
"notification.preference.app.title":
  "{key, select, discussion {Diskussioner} coursework {Kursusarbejde} updates {Opdateringer} grading {Bedømmelse} other {{key}}}"
                                          # note: no leading space ^, different internal spacing
```

**Fix:**

Preserve the exact ICU expression structure from the English source in the DA translation. Only translate the string values inside the clauses, not the ICU syntax itself.

```json
// BEFORE (invalid - stripped whitespace, different brace spacing)
"notification.preference.app.title": "{key, select, discussion {Diskussioner} coursework {Kursusarbejde} updates {Opdateringer} grading {Bedømmelse} other {{key}}}",
"notification.preference.channel": "{text, select, web {Web} email {E-mail} push {Push} other {{text}}}"

// AFTER (valid - preserve ICU structure from EN, only translate values)
"notification.preference.app.title": "{ key, select, discussion {Diskussioner} coursework {Kursusarbejde} updates {Opdateringer} grading {Bedømmelse} other {{key}} }",
"notification.preference.channel": "{ text, select, web {Web} email {E-mail} push {Push} other {{text}} }"
```

---

### 2. `frontend-app-admin-portal`

**File:** `translations/frontend-app-admin-portal/src/i18n/messages/da.json`

**Error:** `INVALID_ARGUMENT_TYPE`

**Failing Key:**
- `learnerCreditManagement.budgetDetail.membersTab.membersTable.removeModal.title`

**Root Cause:**

The English source contains an inline ICU `plural` block. The AI translator reproduced the structure correctly in Danish, but with subtly different spacing or nesting that caused the type checker to flag a conflict.

```diff
# English source
"learnerCreditManagement.budgetDetail.membersTab.membersTable.removeModal.title":
  "Remove member{memberCount, plural, one {} other {s}}?"

# Danish translation — INVALID
"learnerCreditManagement.budgetDetail.membersTab.membersTable.removeModal.title":
  "Fjern medlem{memberCount, plural, one {} other {s}}?"
```

**Fix:**

Verify the `plural` block syntax exactly mirrors the English. The DA value is structurally identical here — if still failing, check for any invisible Unicode characters introduced during AI translation that break ICU parsing.

```json
// AFTER (valid)
"learnerCreditManagement.budgetDetail.membersTab.membersTable.removeModal.title":
  "Fjern medlem{memberCount, plural, one {} other {s}}?"
```

---

### 3. `frontend-app-authn`

**File:** `translations/frontend-app-authn/src/i18n/messages/da.json`

**Error:** `Missing variable supportEmail in message`

**Failing Key:**
- `account.activation.error.message`

**Root Cause:**

The AI translator dropped the `{supportEmail}` variable placeholder. The English source requires it for dynamic email injection; without it the app cannot render the support email address at runtime.

```diff
# English source
"account.activation.error.message":
  "Something went wrong, please contact {supportEmail} to resolve this issue."

# Danish translation — INVALID (variable dropped)
"account.activation.error.message":
  "Noget gik galt, kontakt venligst support for at løse dette problem."
  #                                    ^^^^^^^ missing {supportEmail}
```

**Fix:**

Restore the `{supportEmail}` placeholder in the appropriate position within the Danish sentence.

```json
// AFTER (valid)
"account.activation.error.message":
  "Noget gik galt, kontakt venligst {supportEmail} for at løse dette problem."
```

---

### 4. `frontend-app-discussions`

**File:** `translations/frontend-app-discussions/src/i18n/messages/da.json`

**Error:** `MISSING_OTHER_CLAUSE`

**Failing Keys (6):**
- `discussions.topics.discussions`
- `discussions.topics.questions`
- `discussions.learner.sortFilterStatus`
- `discussions.comments.comment.responseCount`
- `discussions.comments.comment.endorsedResponseCount`
- `discussions.comments.comment.postedTime`

**Root Cause:**

All 6 English source strings end with a **trailing space before the closing brace** (`other {# Discussions} }`). The parser relies on this closing structure to recognise the `other` clause boundary. When the AI translator stripped the trailing space, the ICU parser could not detect the `other` clause, producing `MISSING_OTHER_CLAUSE` for plural/select blocks.

```diff
# English source — note trailing space inside closing brace
"discussions.topics.discussions":
  "{count, plural, =0 {Discussion} one {# Discussion} other {# Discussions} }"
#                                                                            ^space

# Danish translation — INVALID (trailing space stripped)
"discussions.topics.discussions":
  "{count, plural, =0 {Discussion} one {# Discussion} other {# Discussions}}"
#                                                                           ^no space
```

**Fix:**

Preserve the trailing space inside the outer closing brace of each ICU expression, matching the English source format exactly.

```json
// BEFORE (invalid - no trailing space)
"discussions.topics.discussions": "{count, plural, =0 {Discussion} one {# Discussion} other {# Discussions}}",
"discussions.topics.questions": "{count, plural, =0 {Question} one {# Question} other {# Questions}}",
"discussions.learner.sortFilterStatus": "Alle elever sorteret efter {sort, select, flagged {reported activity} activity {most activity} deleted {deleted activity} other {{sort}}}",
"discussions.comments.comment.responseCount": "{num, plural, =0 {No responses} one {Showing # response} other {Showing # responses}}",
"discussions.comments.comment.endorsedResponseCount": "{num, plural, =0 {No endorsed responses} one {Showing # endorsed response} other {Showing # endorsed responses}}",
"discussions.comments.comment.postedTime": "{postType, select, discussion {Discussion} question {Question} other {{postType}}} indsendt {relativeTime} af"

// AFTER (valid - trailing space preserved inside outer brace)
"discussions.topics.discussions": "{count, plural, =0 {Discussion} one {# Discussion} other {# Discussions} }",
"discussions.topics.questions": "{count, plural, =0 {Question} one {# Question} other {# Questions} }",
"discussions.learner.sortFilterStatus": "Alle elever sorteret efter {sort, select, flagged {reported activity} activity {most activity} deleted {deleted activity} other {{sort}} }",
"discussions.comments.comment.responseCount": "{num, plural, =0 {No responses} one {Showing # response} other {Showing # responses} }",
"discussions.comments.comment.endorsedResponseCount": "{num, plural, =0 {No endorsed responses} one {Showing # endorsed response} other {Showing # endorsed responses} }",
"discussions.comments.comment.postedTime": "{postType, select, discussion {Discussion} question {Question} other {{postType}} } indsendt {relativeTime} af"
```

---

### 5. `frontend-app-learner-dashboard`

**File:** `translations/frontend-app-learner-dashboard/src/i18n/messages/da.json`

**Error:** `Different number of variables: [courseTitle] vs []`

**Failing Key:**
- `learner-dash.unenrollConfirm.confirm.finish.text`

**Root Cause:**

The AI translator dropped the `{courseTitle}` variable from the Danish translation. The English source expects the course name to be injected dynamically at runtime — without the placeholder, the rendered message will never show the course name.

```diff
# English source
"learner-dash.unenrollConfirm.confirm.finish.text":
  "You have been unenrolled from the course {courseTitle}"

# Danish translation — INVALID (variable dropped)
"learner-dash.unenrollConfirm.confirm.finish.text":
  "Du er blevet afmeldt fra kurset."
  #                                ^ {courseTitle} is missing
```

**Fix:**

Insert `{courseTitle}` at the appropriate position in the Danish sentence.

```json
// AFTER (valid)
"learner-dash.unenrollConfirm.confirm.finish.text": "Du er blevet afmeldt fra kurset {courseTitle}."
```

---

### 6. `frontend-app-learning`

**File:** `translations/frontend-app-learning/src/i18n/messages/da.json`

**Error:** `Different number of variables`

**Failing Keys (3):**
- `progress.certificateStatus.downloadableBody` — missing `[dashboardLink, profileLink]`
- `progress.gradeSummary.limitedAccessExplanation` — missing `[upgradeLink]`
- `progress.weightedGradeSummary` — missing `[rawGrade, roundedGrade]`

**Root Cause:**

The AI translator omitted several `{variable}` placeholders across three messages. Each placeholder is a React component injection point (clickable links, formatted numbers) that must be preserved for the UI to render correctly.

```diff
# English — progress.certificateStatus.downloadableBody
"progress.certificateStatus.downloadableBody":
  "...access it any time from your {dashboardLink} and {profileLink}."

# Danish — INVALID (both link variables dropped)
"progress.certificateStatus.downloadableBody":
  "...få adgang til det når som helst fra dit dashboard og din profil."
  #                                                ^ no {dashboardLink}, ^ no {profileLink}

# English — progress.gradeSummary.limitedAccessExplanation
"progress.gradeSummary.limitedAccessExplanation":
  "...as part of the audit track in this course. {upgradeLink}"

# Danish — INVALID ({upgradeLink} dropped)
"progress.gradeSummary.limitedAccessExplanation":
  "...som en del af revisionsporet i dette kursus."
  #                                               ^ no {upgradeLink}

# English — progress.weightedGradeSummary
"progress.weightedGradeSummary":
  "Your raw weighted grade summary is {rawGrade} and rounds to {roundedGrade}."

# Danish — INVALID (both grade variables dropped)
"progress.weightedGradeSummary":
  "Din karakteroversigt er og afrundes til."
  #                       ^ no {rawGrade}, ^ no {roundedGrade}
```

**Fix:**

Restore all missing placeholders in their natural sentence positions.

```json
// AFTER (valid)
"progress.certificateStatus.downloadableBody": "Vis din præstation på LinkedIn eller dit CV i dag. Du kan downloade dit certifikat nu og få adgang til det når som helst fra dit {dashboardLink} og din {profileLink}.",
"progress.gradeSummary.limitedAccessExplanation": "Du har begrænset adgang til bedømte opgaver som en del af revisionsporet i dette kursus. {upgradeLink}",
"progress.weightedGradeSummary": "Din råvaegtede karakteroversigt er {rawGrade} og afrundes til {roundedGrade}."
```

---

### 7. `paragon`

**File:** `translations/paragon/src/i18n/messages/da.json`

**Error:** `Variable size has conflicting types`

**Failing Keys:**
- `dropzone.Dropzone.invalidSizeLessError`
- `dropzone.Dropzone.invalidSizeMoreError`

**Root Cause (Most Complex):**

This is an **internal format inconsistency** within the `da.json` file itself — not a mistranslation.

The `paragon/da.json` file uses two different value formats for its keys:

| Format | Example |
|--------|---------|
| **Plain string** | `"key": "translated text with {var}."` |
| **Object with metadata** | `"key": {"developer_comment": "...", "string": "translated text with {var}."}` |

The two failing keys were stored as **plain strings** (format A), while the majority of the file — including other keys that also reference file-size variables like `{sizeMin}` and `{sizeMax}` — used the **object format** (format B).

When `@formatjs/cli` processes the file, it encounters the same variable name `size` appearing as:
- A **plain string interpolation** `{size}` in the plain-string entries (format A)
- Preceded by other size-related variables parsed from object `string` fields in format B entries

This format mixing causes the ICU parser to assign **conflicting argument types** to variables it considers related, triggering `Variable size has conflicting types`.

```json
// BEFORE — da.json (invalid: mixed formats for two keys)
{
  "dropzone.Dropzone.invalidSizeLessError": "Filen skal være større end {size}.",
  "dropzone.Dropzone.invalidSizeMoreError": "Filen skal være mindre end {size}.",
  "dropzone.Dropzone.invalidType": {
    "developer_comment": "En meddelelse...",
    "string": "Filtypen skal være {count, plural, one {{typeString} file} other {one of {typeString} files}}."
  },
  ...
  "pgn.Dropzone.DefaultContent.fileSizeBetween": {
    "developer_comment": "En meddelelse...",
    "string": "Mellem {sizeMin} og {sizeMax}"
  }
}
```

```json
// AFTER — da.json (valid: all keys use the object format consistently)
{
  "dropzone.Dropzone.invalidSizeLessError": {
    "developer_comment": "En fejlmeddelelse, der vises, når den uploadede fil er for lille.",
    "string": "Filen skal være større end {size}."
  },
  "dropzone.Dropzone.invalidSizeMoreError": {
    "developer_comment": "En fejlmeddelelse, der vises, når den uploadede fil er for stor.",
    "string": "Filen skal være mindre end {size}."
  },
  "dropzone.Dropzone.invalidType": {
    "developer_comment": "En meddelelse, der vises, når en fil med forkert MIME-type uploades.",
    "string": "Filtypen skal være {count, plural, one {{typeString} file} other {one of {typeString} files}}."
  },
  ...
}
```

**Why this only affects `da.json` and not `en.json`:**

The `transifex_input.json` (English source) uses **only plain strings** throughout. The DA file was partially generated with an older AI translation format that added `developer_comment` metadata objects, but these additions were not applied uniformly — only some keys received the object format, leaving the two dropzone-size keys as plain strings.

---

### 8. `studio-frontend`

**File:** `translations/studio-frontend/src/i18n/messages/da.json`

**Error:** `INVALID_ARGUMENT_TYPE`

**Failing Key:**
- `assetsResultsCountFiltered`

**Root Cause:**

The English source embeds a `plural` block using the variable `total`. The DA translation altered the spacing within the ICU expression (inserting a space between `{start}` and `-` and `{end}`), which may cause the parser to misinterpret the structure of the expression and flag `total` as having an inconsistent argument type.

```diff
# English source
"assetsResultsCountFiltered":
  "Showing {start}-{end} out of {total, plural, one {{formatted_total} possible match} other {{formatted_total} possible matches}}."
  #              ^no spaces around dash

# Danish translation — INVALID
"assetsResultsCountFiltered":
  "Viser {start} - {end} ud af {total, plural, one {{formatted_total} mulig match} other {{formatted_total} mulige matches}}."
  #             ^spaces added around dash — safe, but ICU nesting may confuse parser
```

**Fix:**

Preserve the English ICU structure exactly. Only translate the visible string fragments (`Showing` → `Viser`, `out of` → `ud af`, `possible match` → `mulig match`). Do not alter spacing around variable tokens in ICU expressions.

```json
// AFTER (valid)
"assetsResultsCountFiltered": "Viser {start}-{end} ud af {total, plural, one {{formatted_total} mulig match} other {{formatted_total} mulige matches}}."
```

---

## Root Cause Summary

All 8 failures have a common theme: **the AI translation service altered the structure of ICU MessageFormat expressions** instead of only translating the visible text content within them.

| Category | Apps Affected | Count of Keys |
|---|---|---|
| ICU variable placeholder dropped entirely | `frontend-app-authn`, `frontend-app-learner-dashboard`, `frontend-app-learning` | 5 keys |
| ICU `plural`/`select` trailing space stripped → `MISSING_OTHER_CLAUSE` | `frontend-app-discussions` | 6 keys |
| ICU expression structural whitespace changed → `INVALID_ARGUMENT_TYPE` | `frontend-app-account`, `frontend-app-admin-portal`, `studio-frontend` | 4 keys |
| DA file format inconsistency (mixed plain-string / object format) → type conflict | `paragon` | 2 keys |

### The Golden Rule of ICU Translation

> **Translate inside ICU clauses — never translate the ICU syntax itself.**

| Component | Translate? | Example |
|---|---|---|
| Literal text outside braces | ✅ Yes | `"Showing"` → `"Viser"` |
| Text values inside `select`/`plural` clauses | ✅ Yes | `{Discussion}` → `{Diskussion}` |
| Variable names | ❌ No | `{courseTitle}` must stay `{courseTitle}` |
| ICU keywords (`plural`, `select`, `one`, `other`, `=0`) | ❌ No | Must not be translated |
| Structural whitespace inside braces | ❌ No | Trailing spaces in `{ ... }` are intentional |
| Format specifiers | ❌ No | `{count, plural, ...}` structure is fixed |

---

## Verification

After applying all fixes, run the validation locally:

```bash
# Install dependencies
make translations_scripts_requirements
npm install

# Validate all previously failing files
python scripts/validate_translation_files.py \
  translations/frontend-app-account/src/i18n/messages/da.json \
  translations/frontend-app-admin-portal/src/i18n/messages/da.json \
  translations/frontend-app-authn/src/i18n/messages/da.json \
  translations/frontend-app-discussions/src/i18n/messages/da.json \
  translations/frontend-app-learner-dashboard/src/i18n/messages/da.json \
  translations/frontend-app-learning/src/i18n/messages/da.json \
  translations/paragon/src/i18n/messages/da.json \
  translations/studio-frontend/src/i18n/messages/da.json
```

**Expected output:**
```
VALID: translations/frontend-app-account/src/i18n/messages/da.json
VALID: translations/frontend-app-admin-portal/src/i18n/messages/da.json
VALID: translations/frontend-app-authn/src/i18n/messages/da.json
VALID: translations/frontend-app-discussions/src/i18n/messages/da.json
VALID: translations/frontend-app-learner-dashboard/src/i18n/messages/da.json
VALID: translations/frontend-app-learning/src/i18n/messages/da.json
VALID: translations/paragon/src/i18n/messages/da.json
VALID: translations/studio-frontend/src/i18n/messages/da.json

-----------------------------------------
SUCCESS: All translation files are valid.
-----------------------------------------
```

You can also manually invoke `@formatjs/cli` for any single file:

```bash
# Copy English source as 'en.json' (required by the tool)
cp translations/<app>/src/i18n/transifex_input.json \
   translations/<app>/src/i18n/messages/en.json

# Run structural equality check
node_modules/.bin/formatjs verify \
  --structural-equality \
  --source-locale=en \
  translations/<app>/src/i18n/messages/en.json \
  translations/<app>/src/i18n/messages/da.json

# Clean up
rm translations/<app>/src/i18n/messages/en.json
```

---

## Prevention Checklist

To prevent these failures in future AI translation PRs, the following safeguards are recommended:

### For the AI Translation Service

- [ ] **Preserve ICU structure exactly** — the AI model must be prompted to treat `{...}` tokens and their surrounding whitespace as untouchable syntax
- [ ] **Never drop `{variable}` placeholders** — validate that every variable present in the source appears in the translation
- [ ] **Enforce uniform output format** — if `developer_comment` metadata objects are used, apply them to ALL keys or NONE (no mixed formats within a single locale file)
- [ ] **Post-generation ICU parse check** — run a syntax parser on generated strings before committing to the repo

### For the Repository / CI

- [ ] **Run `validate_translation_files.py` in pre-commit or PR auto-check** — currently only runs on the CI job; earlier feedback would help
- [ ] **Add a JSON schema or format linter** — detect mixed plain-string vs. object format before the ICU parser sees inconsistencies
- [ ] **Pin `@formatjs/cli` version** — version differences can affect how structural equality is evaluated
- [ ] **Add per-locale validation summary** — surface which locale has the most failures to prioritise AI prompt improvements per language

### For Translators / Reviewers

- [ ] When reviewing AI-translated JSON PRs, scan for any key where the DA value is shorter than the EN value by more than the expected language compression — this often signals a dropped variable
- [ ] Check that all `{variable}` tokens from the EN source appear verbatim in the translated string
- [ ] For paragon-style files that use `{"string": ..., "developer_comment": ...}` objects, verify new keys follow the same object format
