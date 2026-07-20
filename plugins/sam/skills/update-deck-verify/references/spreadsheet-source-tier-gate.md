# Spreadsheet-source tier gate (cross-repo contract with brain-kit)

**Why this exists.** Spreadsheets are the brain's weakest content. A cheap
headless read (openpyxl sheet + label scan) makes a workbook *findable* but does
NOT verify its cell values — yet in retrieval it looks identical to a full,
verified read. This gate stops a *skim-only* spreadsheet figure from being
quoted in an IC deck as if it were sourced. It is the deck-side half of the
brain-kit xlsx-ingest work (plan `samb-xlsx-ingest-durable-plan-2026-07-16.md`,
T1–T9); brain-kit T1–T7 shipped the tier + the retrieval surface, this is T8.

## The contract

Every document row brain-kit's MCP tools return carries an **`extract_tier`**
field. For a spreadsheet it is one of:

| `extract_tier` | Meaning | Quotable in an IC deck? |
|---|---|---|
| `verified` | Live-Nobie or deterministic cell read — the value was actually read | **YES** |
| `headless_structural` | openpyxl sheet + label skim — findable, values NOT verified | **NO → `[needs source]`** |
| `pointer_only` | Bare stub, no readable workbook data | **NO → `[needs source]`** |
| `null` / absent | Non-spreadsheet doc (PDF/DOCX/email), OR tier not yet populated | see fail-safe below |

**The rule:** a numeric claim whose *only* corpus source is a spreadsheet is
quotable **only when that spreadsheet's `extract_tier == "verified"`**. Any other
tier (`headless_structural`, `pointer_only`) means the number was never verified
— treat it exactly like an unsourced number: TBU box / `[needs source]`.

**Absent-tier fail-safe.** If a figure's spreadsheet source returns `null`/no
tier (and the doc IS a spreadsheet — `file_type == "xlsx"` / `.xlsx` path), treat
it as `headless_structural` → **NOT quotable**. Fail safe (refuse), never
fail-open (quote). A non-spreadsheet source (PDF, transcript, email) is out of
scope for this gate — `extract_tier` is `null` for those by design and they are
governed by the normal Pillar-2 sourcing rules, not this one.

## Which MCP fields carry the tier (all of these, as of brain-kit T8)

- `find_documents(...)` rows → `extract_tier`
- `get_file_pointer(doc_id)` → `extract_tier`
- `rank_project_files_for_question(...)` items → `extract_tier`  ← deck skills' PRIMARY retrieval
- `rank_related_files_for_question(...)` items → `extract_tier`
- `get_related_files(doc_id)` items → `extract_tier`

So no matter which retrieval path surfaced the spreadsheet backing a figure, the
tier is on the row. If you somehow have a doc_id but not the tier, call
`get_file_pointer(doc_id)` and read `extract_tier` before quoting a number from it.

## ACTIVATION GATE — this check is DARK until the go-live reindex verifies

**Current state: `GATE_ACTIVE = false` (dark).**

Rationale (from the plan's release order): the tier only becomes trustworthy
corpus-wide *after* brain-kit runs the go-live `index rebuild --full` (schema
v12) + the `xlsx extract --all-stale` backfill that classifies every existing
pointer. **Before that backfill, most already-readable spreadsheets still read as
`pointer_only`** — enforcing now would flag nearly every spreadsheet figure as
unverified (false positives). So until go-live:

- **While `GATE_ACTIVE = false`:** RECORD each spreadsheet-sourced figure's tier
  in the report as *advisory* (populate `unverified_spreadsheet_sources[]` with
  `"advisory": true`), but do **NOT** fail the figure or force a TBU on tier
  alone. The normal Pillar-2 "is this number in the corpus at all" rule still
  applies unchanged.
- **To flip live (one line):** after brain-kit's go-live reindex + backfill are
  verified complete, set `GATE_ACTIVE = true` here. From then on a
  non-`verified` spreadsheet source is a hard fail (drop `"advisory"`), exactly
  like any other unsourced number.

This is the "shipped dark until backfill verifies" decision — the guardrail is
fully built and testable now; only its enforcement waits on the corpus being
tier-classified.

## Contract example (the skill-side fixture — what "refuse" looks like)

Deck slide 11 claims **"CY26E Adj. EBITDA of $34.7M"**. Verify finds the only
corpus source is the WES Equity Model (`doc_id` `71342cb8…`). Query it:

```
get_file_pointer("71342cb8…") → { ..., "extract_tier": "headless_structural" }
```

- **GATE_ACTIVE = true:** the model was only skimmed, never cell-read → the
  figure is NOT quotable. Emit:
  ```json
  { "slide": 11, "claim": "CY26E Adj. EBITDA $34.7M",
    "source_doc_id": "71342cb8", "extract_tier": "headless_structural",
    "advisory": false,
    "suggested_fix": "not a verified cell read — replace with TBU, OR run `brain-kit xlsx enrich 71342cb8` (live Nobie read) to promote the source to verified, then re-verify" }
  ```
  `pass` cannot be true while this entry is non-advisory.
- **GATE_ACTIVE = false (today):** same entry but `"advisory": true` — reported,
  not failed.

## How to promote a source to `verified` (so a real figure can ship)

If the number is genuinely needed and the source is only `headless_structural`:
`brain-kit xlsx enrich <doc_id>` runs the live-Nobie cell read and stamps the
pointer `verified`; after an `index rebuild` the figure clears this gate. That is
the correct fix — not lowering the bar.
