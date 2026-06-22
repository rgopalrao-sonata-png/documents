# Doc Chunker — How It Works

> **Who this is for:** Anyone curious about what this tool does — product managers, technical writers, and engineers alike. No coding experience required to understand this document.

---

## The Big Picture

Imagine you have a very long technical document — maybe a 50-page API specification or an architecture design doc. You want an AI assistant to help you answer questions about it, but AI tools can only read a limited amount of text at once (like fitting pages into a short-term memory slot).

**Doc Chunker solves this by:**

1. Breaking your large document into small, self-contained pieces called **chunks**
2. Labelling each chunk with a summary, keywords, and relationships to other parts of the document
3. Saving everything in a format that AI tools and search systems can use directly

Think of it like a librarian who reads your entire book, cuts it into relevant chapters, writes a summary card for each chapter, notes which chapters reference each other, and files them in a searchable index — all automatically.

---

## What Is a "Chunk"?

A chunk is one meaningful piece of your document. It contains:

| Part | What it means |
|------|---------------|
| **Content** | The actual text from the document |
| **Summary** | A plain-English description of what this section is about |
| **Tags** | Keywords like `authentication`, `api`, `database` |
| **Dependencies** | Other systems or services this section mentions (e.g. "JWT", "Snowflake") |
| **Quality score** | A 0–100 rating of how well-formed this chunk is for AI retrieval |
| **Context carryover** | A few lines from the previous chunk, so the AI understands where we are in the document |

---

## Step-by-Step: What the Tool Does

### Step 1 — Read and recognise the document

The tool reads your file and figures out what kind of document it is based on the file extension:

| File type | Example extensions |
|-----------|-------------------|
| Documentation / specs | `.md`, `.txt`, `.rst` |
| Python code | `.py` |
| JavaScript or TypeScript | `.js`, `.ts`, `.jsx`, `.tsx` |
| Data formats | `.json`, `.yaml`, `.yml` |
| Database queries | `.sql` |

---

### Step 2 — Build a map of the document's structure

Before splitting anything, the tool scans the document to find its natural structure — headings, section breaks, function definitions, class declarations, and so on.

**Analogy:** Like reading a book's table of contents before deciding where to put bookmarks.

For each file type, it finds structure differently:

- **Markdown / text docs** → looks for headings (`# Title`, `## Section`, `### Subsection`)
- **Python files** → uses Python's own code parser to find where each function and class starts and ends
- **JSON / YAML files** → finds the top-level sections (the main "keys" at the root of the file)
- **SQL files** → finds each database statement (`CREATE TABLE`, `SELECT`, etc.)

---

### Step 3 — Identify safe split points

Using the structure map from Step 2, the tool marks all the line numbers where it is *safe* to start a new chunk — for example, at the beginning of a new heading or the start of a new function.

It will never split a document in the middle of a sentence, mid-way through a code block, or inside a function that is too large to move.

---

### Step 4 — Create the initial chunks

The tool slices the document at the safe split points from Step 3, creating one chunk per major section.

For **documentation files** (`.md`, `.txt`): every major heading (`##`) becomes its own chunk, keeping related content together regardless of size.

For **code files** (`.py`, `.js`, etc.): chunks accumulate lines until they reach a target size (default: 400 lines), then start fresh at the next safe boundary.

---

### Step 5 — Merge chunks that are too small

Some sections of a document are naturally short — for example, a "Future Plans" section that is only three bullet points. A chunk this small is not very useful on its own for AI retrieval.

The tool automatically combines neighbouring small chunks into a single, more useful chunk, as long as the combined result is not too large.

**Example:** "Monitoring", "Configuration", and "Future Enhancements" sections — each only 50 words — are merged into one 150-word chunk rather than being three near-empty entries.

> Threshold: chunks below ~120 tokens (roughly 90 words) are merge candidates.

---

### Step 5b — Add context carryover (overlap)

When you split a long story into chapters, the start of each chapter usually reminds you of what just happened. This tool does the same thing.

A few lines from the end of each chunk are copied onto the beginning of the next chunk. This is called **overlap** or **context carryover**.

- Documentation chunks carry over 7 lines
- Code chunks carry over 15 lines

**Important:** This carryover text is kept separate from the chunk's own content. It is used to help an AI assistant understand context, but it is **not included** in search indexes or summaries — so it never pollutes the chunk's description with content from the previous section.

---

### Step 6–8 — Generate summaries, tags, and dependencies

This is where the AI comes in (if an API key is available).

For each chunk, the tool asks Claude (Anthropic's AI) to read the content and return:

| What | Example |
|------|---------|
| **Tags** | `authentication`, `jwt`, `api-security` |
| **Dependencies** | `JWT Authentication`, `Snowflake Warehouse`, `Progress Aggregator Service` |
| **Executive summary** | "Describes how the Reporting API authenticates users using JWT tokens." |
| **Technical summary** | "Covers the /auth/refresh endpoint, token expiry rules, and error codes 401/403/429." |
| **Retrieval keywords** | "jwt token refresh authentication expiry reporting api bearer" |

**If no API key is available** (offline mode), the tool uses pattern matching instead:
- Tags come from the section headings
- Dependencies are found by scanning for capitalised service names, auth keywords (JWT, OAuth), event names, and database references
- Summaries are built from the first paragraph of the section

---

### Step 9 — Quality check each chunk

The tool inspects every chunk for problems:

| Problem | What it means |
|---------|--------------|
| Unmatched code fences | A code block was opened but never closed — or vice versa |
| Broken JSON | A JSON example in the document was split mid-structure |
| Missing table separator | A markdown table is missing its header divider row |
| Chunk too small | The chunk has fewer than 3 lines — probably a mistake |
| Unresolved placeholders | Template markers like `<<PLACEHOLDER>>` were left in |

Any chunk with a problem is flagged in the validation report.

---

### Step 10–12 — Write the output files

Seven files are written to the output folder. See the **Output Files** section below for what each one contains.

---

## Output Files — Plain English

| File | Who uses it | What it contains |
|------|-------------|-----------------|
| `*_chunks.md` | Humans reviewing the output | All chunks in a readable format — summaries, tags, quality scores, and the content itself |
| `*_chunks.json` | AI systems, vector databases, embedding pipelines | The same information in a structured format that software can load and process |
| `*_manifest.md` | Anyone wanting a quick overview | A one-row-per-chunk table: section name, line range, estimated word count, quality score |
| `*_dependencies.md` | Architects, engineers | A diagram showing which chunks reference which external services, APIs, or databases |
| `*_retrieval_index.md` | Search and AI retrieval systems | An index organised by tag, by section, and by dependency — like a book's index |
| `*_processing_report.md` | Anyone checking quality | Summary statistics: how many chunks, total size, how scores are distributed |
| `*_validation_report.md` | Engineers reviewing problems | A pass/fail list for every chunk, with a description of any issues found |

---

## Quality Scores — What Do They Mean?

Each chunk receives four scores from 0 to 100:

| Score | What it measures | Good sign | Warning sign |
|-------|-----------------|-----------|--------------|
| **Semantic Cohesion** | Does the chunk stay on one topic? | All content relates to one subject | Chunk spans multiple unrelated sections |
| **Boundary Quality** | Does the chunk start and end cleanly? | Starts at a heading, ends at a complete sentence | Starts mid-sentence, unbalanced code block |
| **Dependency Completeness** | Were all referenced systems found? | All services and APIs detected | Service names mentioned but not captured |
| **Retrieval Quality** | Will this chunk answer questions well? | Has a heading, body text, reasonable length | Too short to stand alone, or no heading |

The **Overall** score is the average of the four.

> A score of **90+** means excellent. **75–89** means good. Below 75 means the chunk may need attention.

---

## How to Run It

### Option A — Quick test (no account needed)

This runs the tool without AI enrichment. You get structural chunks with pattern-based summaries, but no Claude-generated descriptions.

```bash
# Install the one required library
pip install anthropic

# Run on any document
python3 doc-chunker/chunk_agent.py your-document.md -o output-folder/ --no-claude
```

### Option B — Full run (requires an Anthropic API key)

This runs with full AI enrichment — richer summaries, better dependency detection, and AI-scored quality.

```bash
# Set your API key (one time)
export ANTHROPIC_API_KEY=sk-ant-...

# Run on your document
python3 doc-chunker/chunk_agent.py your-document.md -o output-folder/
```

### Check the results

```bash
# See the list of output files
ls output-folder/

# Read the summary table
cat output-folder/*_manifest.md

# Read the quality/validation report
cat output-folder/*_validation_report.md
```

---

## Settings You Can Change

| Setting | What it controls | Default |
|---------|-----------------|---------|
| `-o / --output` | Where to save the output files | `chunks_output/` |
| `--target-loc` | How many lines of code per chunk (code files only) | 400 lines |
| `--min-loc` | Preamble sections shorter than this merge into the first section | 30 lines |
| `--max-loc` | Maximum lines before a chunk is forcibly split | 2,000 lines |
| `--prose-overlap` | How many context carryover lines for document chunks | 7 lines |
| `--code-overlap` | How many context carryover lines for code chunks | 15 lines |
| `--no-claude` | Skip AI enrichment — faster, works offline | Off (AI is on by default) |

---

## Example: What a Chunk Looks Like

Here is a simplified example of a single chunk from a technical specification:

```
Chunk ID: MYSPEC_0003

Section: Authentication
Subsection: Token Refresh
Lines: 120–198
Estimated size: ~420 words

Context Carryover (from previous chunk — not indexed):
  "...the initial login flow is described above."

Summary (Executive): Describes how tokens are refreshed after they expire.
Summary (Technical): Covers the /auth/refresh endpoint, JWT rotation strategy,
                     and Redis TTL handling.
Search Keywords: token refresh jwt expiry authentication endpoint redis

Dependencies found:
  - JWT Authentication
  - Redis Cache
  - AuthService

Tags: authentication, api, jwt, token-refresh

Quality Scores:
  Semantic Cohesion:        91/100
  Boundary Quality:         90/100
  Dependency Completeness:  85/100
  Retrieval Quality:        88/100
  Overall:                  88/100
```

---

## Frequently Asked Questions

**Q: What is RAG?**
RAG stands for Retrieval-Augmented Generation. It is a technique where an AI assistant searches a database of document chunks to find relevant information *before* answering your question — rather than relying only on what it was trained on. This tool prepares documents for use in RAG systems.

**Q: What is a vector database?**
A special kind of database designed for AI search. Instead of searching by exact keywords, it finds documents that are *semantically similar* — meaning similar in meaning, even if different words are used. The `*_chunks.json` file produced by this tool can be loaded directly into a vector database.

**Q: Why does the tool add overlap / context carryover?**
Without it, an AI reading chunk 5 would have no idea what happened in chunk 4. The few lines of carryover give the AI a bridge between sections — like "previously on..." at the start of a TV episode. Crucially, the carryover is kept separate so it does not pollute summaries or search indexes with content that belongs to a different section.

**Q: What happens if I do not have an Anthropic API key?**
The tool still works — it uses pattern matching instead of AI to generate tags, summaries, and dependency lists. The results are less detailed, but structurally complete and useful. Run with `--no-claude` to use this mode.

**Q: Why are some sections merged together?**
Very short sections (less than ~120 words) are not useful on their own for AI retrieval — they do not contain enough information to answer a question. The tool automatically combines them with a neighbour so every chunk is a meaningful, standalone unit.
