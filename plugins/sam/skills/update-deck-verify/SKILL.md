---
name: update-deck-verify
description: This skill should be used when the /update-deck orchestrator (or the user directly) asks to "verify the deck", "fact-check the deck", "source-check every figure", or "/update-deck-verify". Pass 2 of /update-deck. Walks every claim — every number, name, firm, date, and quote — in an IC HTML deck and confirms each traces to a source line in the context MD or corpus. Flags hallucinations (numbers from training data, firms guessed from a domain, paraphrased quotes that drifted), flags naked outputs (charts/tables without commentary), and runs the audience-register filter (strips internal owners, attribution, internal vendor names). Returns a gap report so the orchestrator can decide what to TBU-replace, what to ask the user about, and what to strip. Hard constraint:  does not edit the deck. Designed to run as an Agent-tool subagent spawned from /update-deck with a fresh context window so the parent context isn't polluted with corpus reads.
metadata:
  type: skill
  user-invocable: true
  disable-model-invocation: false
---

# /update-deck-verify — fact-check every claim against the corpus

Pass 2 of `/update-deck`. Walks the deck and emits a gap report listing every claim that isn't sourced, every output without commentary, and every internal-audience phrase that shouldn't ship to the IC.

This skill is read-only. It does NOT edit the deck. Fixing is `/update-deck-fix`'s job.

## Inputs

- `deck_path` — absolute path to the deck HTML to verify.
- `context_md_path` — optional. Path to a `_src_*.md` / context MD next to the deck. If present, the MD is the authoritative truth source.
- `corpus_root` — optional. Folder to sweep if no context MD is present (typically the deal root: Outlook exports, Slack canvases, source XLSX, transcripts, advisor notes).
- `changed_slides` — optional list of slide indices the user just touched. Verification focuses there first; the rest is a lighter audit.
- `presentation_date` — ISO yyyy-mm-dd. The date the IC will see this deck. **Required for tense reconciliation.** If absent, return a hard error to the orchestrator — do not guess from file mtime or "today." Memory rule: [[feedback-presentation-date-tense-check]].

## Output (returned to parent)

```json
{
  "deck_path": "...",
  "presentation_date": "2026-05-25",
  "unsourced_numbers": [
    { "slide": 13, "claim": "30-40% leverage", "suggested_fix": "replace with TBU box or ask user for returns-model line" }
  ],
  "unsourced_people": [
    { "slide": 9, "claim": "Brandon Dobel at Lincoln", "corpus_says": "Brandon Dobel at BGL", "suggested_fix": "correct to BGL" }
  ],
  "unsourced_quotes": [
    { "slide": 6, "claim": "\"40% of PM ops\"", "source_found": "Kevin Ortner 5/11 transcript line 137" }
  ],
  "unsourced_workstreams": [
    { "slide": 8, "claim": "Industry Advisor", "corpus_says_canonical": ["Market diligence", "Tech DD", "Commercial DD"], "suggested_fix": "rename to canonical workstream or drop" }
  ],
  "naked_outputs": [
    { "slide": 7, "issue": "image with no adjacent commentary", "fix_hint": "pull from 5/15 DD session transcript" }
  ],
  "internal_register_violations": [
    { "slide": 4, "phrase": "Sean to follow up", "suggested_fix": "strip per audience-register-filter" }
  ],
  "tone_violations": [
    { "slide": 6, "phrase": "not a turnaround", "suggested_fix": "rewrite even-keel per feedback-ic-even-keel-tone" }
  ],
  "weeds_violations": [
    { "slide": 7, "bullet": "98% occupancy ex-units-being-remodeled", "issue": "caveat references stat IC has not been shown", "suggested_fix": "introduce 98% portfolio occupancy first, then qualify" }
  ],
  "contradictions": [
    { "slide_a": 3, "claim_a": "investment contingent on Seattle deal", "slide_b": 14, "claim_b": "Seattle deal closing optional", "corpus_says": "contingent — per 5/15 mgmt call", "suggested_fix": "update slide 14 to reflect contingency" }
  ],
  "tense_reconciliations": [
    { "slide": 12, "original": "on site next week", "anchor_event": "Fri 5/15 transcript", "offset_to_presentation_date": "+3 business days", "corrected": "on site last week" }
  ],
  "whitelist_violations": [
    { "slide": 8, "category": "advisor", "claim": "SaxeCap", "corpus_says": "not mentioned in any canonical source", "suggested_fix": "drop reference" }
  ],
  "pass": false
}
```

`pass` is true only when every array above is empty.

## Procedure

### Step 0 — Validate presentation_date

If `presentation_date` is not in the inputs, return a hard error to the orchestrator immediately:

```json
{ "error": "presentation_date required for tense reconciliation; cannot proceed", "pass": false }
```

Do NOT guess from file mtime, "today," or the most recent transcript date. Memory rule: [[feedback-presentation-date-tense-check]].

### Step 1 — Load the truth source

If `context_md_path` is set and the file exists: Read it in full. This is the truth source.

Else: glob `corpus_root` for the standard truth-source filenames:
- `_src_*.md` next to the deck (most recent)
- `01. Context/`, `02. Comms/`, `08. Notes/` subfolders of the deal root
- Source XLSX files referenced by the deck's footer `Source:` lines

Read enough of each to ground the verification, but do not exceed ~30k tokens of corpus reading per run — that's a sign the deck is too unsourced and the orchestrator should escalate.

### Step 2 — Extract every claim from the deck

Read the deck HTML in full. Walk slide by slide. For each slide, extract:

- **Numbers**: dollar amounts, percentages, MOICs, multiples, dates, headcounts, door counts. Anything numeric.
- **Names + firms**: every `<b>Person Name</b>` or every `Firstname Lastname` pattern; every firm name that follows.
- **Quotes**: every `<i>"..."</i>` or stretch in quotation marks. These are direct attribution and must trace verbatim.
- **Outputs**: every `<img>`, `<table>`, big embedded `<pre>` or chart-style block. Note whether the slide has adjacent commentary.
- **Internal-register tells**: phrases like "Sean to schedule", "Tom asked", "in-flight", "Campfire", "QuickBooks", "next week", "owner: ".

If `changed_slides` is set, walk those slides first and tag any claim added in this revision (compare against the prior version if it's discoverable on disk).

### Step 3 — Match each claim against the truth source

For each claim:

1. **Numbers** — grep the context MD / corpus for the literal number (or a tight variant). Match required. If not found, add to `unsourced_numbers`. Memory rule: [[feedback-never-fabricate-ic-numbers]].
2. **People + firms** — grep the corpus for the person's name, confirm the firm matches what the slide says. Verified roster lives at [[project-bungalow-people-roster]] for Bungalow. If the deck names a firm the corpus doesn't, add to `unsourced_people` with `corpus_says` set if there's a different firm in the corpus. Memory rule: [[feedback-no-hallucination-ask-instead]] — NEVER infer a firm from a domain or training data.
3. **Quotes** — grep the corpus for a substring of the quote. If found, capture the source line for the report. If not found verbatim, add to `unsourced_quotes`.
4. **Outputs** — for each `<img>`/`<table>`, check whether the same `.slide` contains a `<ul>`, `<callout>`, or `<p>` of commentary. If not, add to `naked_outputs`. Memory rule: [[feedback-no-naked-outputs-in-ic]].
5. **Internal-register** — match against the patterns in `~/.claude/skills/draft-IC-Deck/references/audience-register-filter.md`. Add hits to `internal_register_violations`. Memory rule: [[feedback-ic-deck-audience-register]].

### Step 3b — IC voice checks (run after Pillar 2)

These checks enforce the IC voice memories. They are separate from sourcing because a sourced claim can still violate IC voice.

6. **Tone violations.** For each revised slide, scan prose for salesy adjectives and definitive framings. Flag any of: "only material", "not a turnaround", "transformation", "clear winner", "proven", "de-risked", "massive opportunity", and any superlative ("only", "best", "first", "biggest") without a corpus citation. Add to `tone_violations[]`. Memory rule: [[feedback-ic-even-keel-tone]].
7. **Weeds violations.** For each bullet, test: "would an IC member who has not been on a deal-team call understand this and learn something useful from it?" Specifically flag (a) caveats that reference a stat not yet shown on this slide or earlier; (b) accounting/methodology asides; (c) bullets that don't change an IC member's understanding. Add to `weeds_violations[]`. Memory rule: [[feedback-ic-spoon-feed-no-internal-context]].
8. **Workstream + advisor whitelist.** Before walking the deck, parse the most recent canonical workstream summary from the corpus (Slack canvas / IC notes / DD plan) and build two whitelists: `workstream_whitelist[]` and `advisor_whitelist[]`. Then for every workstream-style label and every advisor/firm mention in the deck, confirm it's on the corresponding whitelist. Misses go to `unsourced_workstreams[]` and `whitelist_violations[]`.

### Step 3c — Cross-slide consistency check

Build a claim ledger as Step 3 walks each slide: `{ slide, claim_type, normalized_value }` for every load-bearing claim (deal-structure contingencies, workstream status, date claims, advisor scope). After all slides have been processed, diff the ledger:

- Any two claims of the same `claim_type` with conflicting `normalized_value` → entry in `contradictions[]` with both slide numbers, both claims, and (if available) the corpus reading.
- This catches Sam's flagged failure: slide 3 said "investment contingent on Seattle deal" / slide 14 said "Seattle deal closing optional." Verify pass must reject this combination.

### Step 3d — Tense reconciliation against presentation_date

For every relative-date phrase in a revised slide ("this week", "next week", "yesterday", "going on site", "we will present", "in flight"):

1. **Anchor** — find the underlying event in the corpus (transcript timestamp, calendar invite, email date).
2. **Compute offset** — business-day delta from the anchor to `presentation_date`.
3. **Rewrite from IC's seat** — emit the corrected phrase in `tense_reconciliations[]` with `{ slide, original, anchor_event, offset, corrected }`.

Memory rule: [[feedback-presentation-date-tense-check]]. Example: Friday transcript "on site next week" + Monday presentation → "on site last week" (the trip is now in the IC's past).

### Step 4 — Build the gap report

Aggregate the findings into the JSON shape above. For each finding, include a `suggested_fix` the orchestrator can route:

- Unsourced number → "replace with TBU box pointing at <source file>"
- Wrong firm → "correct to <X> per corpus" or "ask user for verified firm"
- Drifted quote → "drop the quote OR re-pull from <transcript line>"
- Naked output → "add commentary from <source>" or "remove the slide"
- Internal register → "strip phrase" or "rephrase in IC voice"

### Step 5 — Return the report

Emit JSON + a one-paragraph summary. The orchestrator decides next steps; this skill does not act on its own findings.

## Hallucination guardrails

These are the failure modes this skill is designed to catch. Be paranoid about each:

- **Plausible numbers.** "30-40% leverage" SOUNDS right for a PM rollup, but if it's not in the model, it's a hallucination. Treat every number as guilty until sourced.
- **Inferred firms.** Someone @example.com is at "Example Corp" — except they left two years ago. ASK; don't infer.
- **Paraphrased quotes.** The model drifts during paraphrase. If a quote isn't a verbatim corpus substring, treat it as paraphrase and either re-pull the verbatim text or drop the quote.
- **Cross-deal contamination.** This is the Bungalow deal; quotes from the W Energy or Pak workstreams are out of scope. Memory rule: [[feedback-workstream-separation]].

## What this skill does NOT do

- It does not propose new commentary. If `naked_outputs` flags a slide, the orchestrator routes to `/update-deck-fix` which pulls commentary from the corpus.
- It does not re-export images. That's a legibility concern handled by `/update-deck-render-check`.
- It does not measure overflow. That's `/update-deck-render-check` too.
- It does not write to the deck. Read-only.

## References

- `~/.claude/skills/update-deck/references/verify-checklist.md` — Pillar 2 (sourcing) definition.
- `~/.claude/skills/draft-IC-Deck/references/audience-register-filter.md` — internal-register patterns.

## Memories enforced

- [[feedback-never-fabricate-ic-numbers]]
- [[feedback-no-hallucination-ask-instead]]
- [[feedback-no-naked-outputs-in-ic]]
- [[feedback-ic-deck-audience-register]]
- [[feedback-workstream-separation]]
- [[feedback-ic-even-keel-tone]]
- [[feedback-ic-spoon-feed-no-internal-context]]
- [[feedback-ic-key-takeaway-rubric]]
- [[feedback-presentation-date-tense-check]]
- [[project-bungalow-people-roster]] (for the Bungalow deal; other deals will have their own roster memory)

## Related

- [[update-deck]] — parent orchestrator.
- [[update-deck-fix]] — receives this skill's gap report and replaces unsourced claims with TBU boxes or pulls corpus commentary.
- [[update-deck-render-check]] — sibling. Visual / overflow checks; runs in parallel.
- [[build-IC-Deck-context]] — if no context MD exists and the corpus is dense, the orchestrator may invoke build-IC-Deck-context to build one rather than have this skill sweep raw sources every run.
