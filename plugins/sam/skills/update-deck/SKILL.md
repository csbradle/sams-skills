---
name: update-deck
description: This skill should be used when the user asks to "update the deck", "apply these redlines to the deck", "fix slides X/Y/Z in the deck", "iterate the IC update", "rev the deck", or "/update-deck". Iterative revision pipeline for an existing IC HTML deck (1920×1080 16:9). Each pass guarantees three things — outputs are legible, every fact/figure has a corpus source (no hallucinations), and no slide overflows. Orchestrates three sub-skills with fresh-context isolation — /update-deck-verify (fact-checks every claim), /update-deck-fix (applies edits + re-exports images from source XLSX), /update-deck-render-check (headless 1920×1080 overflow + legibility audit). Always writes a new vN+1 on disk; never overwrites the source. Designed for the redline-and-revise loop the user runs on every IC update deck, not for cold-start deck builds (use /draft-IC-Deck for that).
metadata:
  type: skill
  user-invocable: true
  disable-model-invocation: false
---

# /update-deck — apply revisions to an IC deck with structural guardrails

Iterates an existing IC HTML deck against user redlines. Every pass mechanically enforces three guarantees the user has had to ask for, version after version:

1. **Outputs are legible.** Every embedded chart/table/screenshot is readable at 1920×1080 AND has adjacent commentary explaining the takeaway. No naked images. No Excel Page-Break-Preview watermarks. No micro-text.
2. **Every fact has a source.** Every number, name, firm, date, and quote in the deck traces to a line in the context MD or corpus. Numbers without a source become TBU boxes. Firms without a source become user-escalation questions. Quotes that drift become re-pulls or get dropped.
3. **No slide overflows.** Headless render at 1920×1080 confirms `slide.scrollHeight ≤ slide.clientHeight` for every slide. Visual audit confirms no clipping under the footer.

This skill exists because the same three failure modes have shown up across every IC update pass — the user has had to call them out five-plus times. Memory rules: [[feedback-no-naked-outputs-in-ic]], [[feedback-never-fabricate-ic-numbers]], [[feedback-no-hallucination-ask-instead]], [[feedback-use-exact-source-output-not-rebuilds]], [[feedback-verify-slide-overflow-before-done]].

Beyond the three structural pillars, the skill must also enforce **IC voice** on every revised slide. The IC has not been in the weeds. The voice they expect:

- **Even-keel, factual.** No salesy adjectives. [[feedback-ic-even-keel-tone]].
- **Spoon-fed.** Introduce stats before caveating; no accounting asides; every bullet adds value to a fresh reader. [[feedback-ic-spoon-feed-no-internal-context]].
- **Stripped of deal-team mechanics.** No internal owners, no "who asked," no in-flight framing. [[feedback-ic-deck-audience-register]].
- **Key takeaways follow the rubric:** learned / open / to-learn / closing. [[feedback-ic-key-takeaway-rubric]].
- **Tenses reconciled against the presentation date** — not the transcript date, not the model's "today." [[feedback-presentation-date-tense-check]].
- **Internally consistent.** No slide may contradict another in the same deck.

## When NOT to use

- **Cold-start deck builds** — use `[[draft-IC-Deck]]` instead. /update-deck assumes a deck already exists on disk.
- **Slack canvas updates** — use `[[updatebung]]` or `[[WESupdate]]`. /update-deck is HTML-only.
- **PDF export from finished deck** — chain to `[[html-to-pdf]]` after /update-deck declares done.

## Inputs

The user invokes with redline text, often pasted with the deck path:

```
file:///.../<deck>.html sensitivities slide needs to go back to v1 with 4 TBU boxes.
Page 11 is useless, remove. Bridge text on page 6 is hard to read. Consolidated
P&L says "page 1" in the middle.
```

Parse this for:
- **Deck path** (file:// URL or absolute path)
- **Redline list** (specific slide-level changes)
- **Implicit guardrails** ("page 1 in the middle" → image legibility defect; "useless" → remove slide)
- **Presentation date** (ISO yyyy-mm-dd) — the date the IC will see this deck. Required input; controls tense reconciliation. **If the user hasn't given one, ASK before spawning any subagent.** Don't guess from "today" or the file mtime — Sam has flagged tense errors when the model used the transcript date instead of the planned presentation date. Memory rule: [[feedback-presentation-date-tense-check]].

## Procedure

### Step 1 — Confirm the target file (always pick the latest)

Memory rule: [[feedback-latest-artifact-version]]. The user may name `v04`, but `v06` may exist on disk.

```bash
ls "<deck folder>" | grep -E ' v[0-9]+\.html$' | sort -V | tail -1
```

If the latest on disk is newer than the file the user named, ASK: "I see v06 on disk — did you mean to revise v06, or revert to v04 and re-apply?" Default to the latest unless the user explicitly says otherwise.

**Anchors + reachability preflight (after target confirm):** resolve the deal's anchors file (pointer under `draft-IC-Deck/references/`, real file data-side) and run the required-fields check per `draft-IC-Deck/references/anchors-template.md`. Missing/incomplete → run the bootstrap dialogue before any subagent spawns. Corpus root unreachable on this machine → switch to the named degraded mode (verify-gate.md template T6: layout fixes + user-attested numbers only) — do NOT run per-claim checks that would all fail and manufacture a block storm.

**Routing profile (default = cheapest honest path), per `draft-IC-Deck/references/verify-gate.md`:**
- Redlines touch NO claim-bearing text (font, color, page split — mechanically checkable) → **layout-only fast path**: skip Step 2 verify entirely; run Step 3 render-check + lint flag-only; stamp "layout-only revision — content checks unchanged from v<N>."
- Pre-ledger ("legacy") deck → stage1/legacy profile: gap-tags block, orphan numbers flag-only, lexical verification with the T7 degradation sentence in the handoff.
- Content-touching redlines on a checked deck → incremental re-check of touched claims (Stage 2); full pass otherwise.

### Step 2 — Spawn /update-deck-verify (Agent subagent, fresh context)

Run in parallel with Step 3's render-check. Subagent prompt:

```
You are /update-deck-verify. Verify every claim in this deck against the
corpus AND run the IC voice + temporal checks.

deck_path: <abs path to latest>
context_md_path: <abs path to _src_*.md if present>
corpus_root: <abs path to deal root if no context MD>
changed_slides: <indices the user touched in this redline, plus any slide
                 mentioned by number in the redline text>
presentation_date: <ISO yyyy-mm-dd the IC will see this deck>

Run the full pillar-2 sweep PLUS:
  - tone_violations[]     — salesy adjectives, definitive framings
  - weeds_violations[]    — bullets that assume context the IC doesn't have
  - contradictions[]      — claim ledger diff across slides
  - tense_reconciliations[] — every relative-date phrase rewritten from
                              the IC's seat on presentation_date
  - whitelist_violations[]  — workstream/advisor names not in canonical
                              corpus enumeration

Return JSON per your SKILL.md spec.
```

### Step 3 — Spawn /update-deck-render-check (Agent subagent, fresh context)

Parallel with Step 2:

```
You are /update-deck-render-check. Probe this deck at 1920×1080.

deck_path: <abs path to latest>
screenshot_every_slide: true

Return JSON per your SKILL.md spec.
```

### Step 4 — Reconcile both reports

Wait for both sub-skills to return. Build a unified fix-routing plan:

| Issue | Source | Fix routing |
|---|---|---|
| Slide overflow | render-check | trim content / shrink images |
| Image illegible | render-check | re-export from source XLSX — wider/font, not taller |
| Unsourced number | verify | TBU box or escalate |
| Wrong firm | verify | correct from corpus or escalate |
| Drifted quote | verify | re-pull or drop |
| Naked output | verify | add corpus commentary or remove slide |
| Internal-register | verify | strip per audience-register-filter |
| Salesy adjective | verify | rewrite even-keel per [[feedback-ic-even-keel-tone]] |
| Weeds violation (bullet assumes context IC doesn't have) | verify | rewrite spoon-fed or remove |
| Contradiction (slide N vs. slide M) | verify | reconcile against corpus; whichever is wrong gets fixed |
| Tense wrong vs. presentation date | verify | rewrite from IC's seat |
| Whitelist violation (workstream/advisor not in corpus) | verify | drop, rename to canonical, or escalate |

Merge with the user's explicit redlines into a single instruction list for `/update-deck-fix`.

### Step 5 — Approval gate (if any user escalations)

If the reconciled plan has any escalations the user needs to resolve before the fix can proceed (unverifiable claims, ambiguous firms, "this slide has no corpus commentary — should I remove it?"), ask the user via `AskUserQuestion` BEFORE spawning the fix subagent. Don't burn a fix pass on a question that needs the user.

If no escalations, proceed automatically.

### Step 6 — Spawn /update-deck-fix (Agent subagent, fresh context)

```
You are /update-deck-fix. Apply these revisions and produce a new vN+1.

deck_path: <abs path to current latest>
revision_instructions: <user's redlines + reconciled fix plan from Step 4>
verify_report: <JSON from Step 2>
render_check_report: <JSON from Step 3>
context_md_path: <abs path to _src_*.md if present>
presentation_date: <ISO yyyy-mm-dd>

When rewriting tone_violations / weeds_violations / takeaway blocks, apply
the IC voice memories: [[feedback-ic-even-keel-tone]],
[[feedback-ic-spoon-feed-no-internal-context]],
[[feedback-ic-key-takeaway-rubric]].

When fixing image illegibility, the rule is wider/bigger-font, NOT taller —
see references/image-re-export-playbook.md Defect 2.

Return path to new file + summary per your SKILL.md spec.
```

### Step 7 — Re-run /update-deck-render-check on the new vN+1

Confirm the fix didn't introduce new overflows. Repeat Step 6 with the new overflow report if needed (max 2 fix-then-recheck iterations before escalating to user).

### Step 8 — Screenshot the touched slides for user review

For every slide that changed (deletes don't count — they removed a slide), Read the per-slide screenshot from render-check's output dir. Present to user inline so they can see the new state before declaring done.

### Step 8.5 — Lint gate (deterministic, fail-closed; MANDATORY before any "done")

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<draft-IC-Deck>/scripts/lint_deck.ps1" -DeckPath "<vN+1>.html" [-LedgerPath <ledger>] -UpdateHash
```

Exit 1 → blocking findings (gap-tags always; ledger mismatches when full profile): route to fix or escalate with the verify-gate.md templates. Exit 2 → the check itself failed; the deck is NOT confirmed — say so plainly and offer retry. Hash drift since the last check (deck hand-edited outside the pipeline) → template T4: offer to re-check just the changed parts; never silently trust.

### Step 9 — Handoff

Return to the user (vocabulary layer per verify-gate.md — no internal nouns):
- **Path to new vN+1** (absolute).
- **Per-slide change summary** ("Page X: …; Page Y: …").
- **Honest check stamp** — "N numbers checked against source text (M shown as TBU, 0 unchecked). Checked as of <date>; email sync last ran <N> days ago." Never the word "verified". Legacy/lexical runs append the T7 degradation sentence. Waivers listed individually ("shipped with K waived items — your call, logged").
- **TBU boxes added** with source-file pointers; user-attested values called out distinctly ("2 values from you, not corpus-sourced").
- **Blocked items as a numbered plain-English list** (override by number/description; attestation offered on every unsourced item).

Numeric deck defects hard-block "done" (per verify-gate.md decision table). Environment staleness never blocks by itself — it prints the corpus-boundary caveat (T8). The user must see everything unresolved.

## Loops + iteration

The user will redline again. Each /update-deck invocation is a single pass. Successive passes bump the version (vN → vN+1 → vN+2). Backup PNGs are kept side-by-side with `.bak` suffix per `references/version-and-handoff.md`.

If after 3 passes the same redline keeps surfacing, that's a signal the context MD is stale — re-route to `[[build-IC-Deck-context]]` to refresh the truth source before continuing.

## Failure modes

- **No context MD next to the deck.** /update-deck-verify will fall back to a full corpus sweep, which is slow and pollutes context. Recommend the user run `[[build-IC-Deck-context]]` first if iterating heavily.
- **Source XLSX locked by another Excel session.** The image re-export scripts copy to `$env:TEMP` first specifically to avoid this. If it still fails, ask the user to close the workbook in Nobie/Excel and retry.
- **User redline contradicts the corpus.** "Page X should say 30-40% leverage" but the corpus says 20-30%. ASK the user; don't silently follow the redline over the corpus, but don't silently override the user either. They may have a source the model doesn't see.
- **Overflow keeps coming back after 2 fix passes.** The slide is over-stuffed. Recommend splitting it into two slides rather than micro-tuning fonts forever.

## References

- `references/verify-checklist.md` — the three pillars in detail.
- `references/image-re-export-playbook.md` — Excel COM patterns for chart/table re-export.
- `references/version-and-handoff.md` — version-bump + backup + handoff conventions.
- `scripts/run_overflow_check.ps1` — headless probe (used by /update-deck-render-check).
- `scripts/re_export_excel_chart.ps1` — Excel COM re-exporter (used by /update-deck-fix).

## Memories enforced

- [[feedback-no-naked-outputs-in-ic]]
- [[feedback-never-fabricate-ic-numbers]]
- [[feedback-no-hallucination-ask-instead]]
- [[feedback-use-exact-source-output-not-rebuilds]]
- [[feedback-verify-slide-overflow-before-done]]
- [[feedback-latest-artifact-version]]
- [[feedback-ic-deck-audience-register]]
- [[feedback-workstream-separation]]
- [[feedback-ic-even-keel-tone]]
- [[feedback-ic-spoon-feed-no-internal-context]]
- [[feedback-ic-key-takeaway-rubric]]
- [[feedback-presentation-date-tense-check]]

## Related

- [[update-deck-fix]] — sub-skill that writes the new vN+1. The only sub-skill with write access.
- [[update-deck-verify]] — sub-skill that fact-checks every claim against the corpus.
- [[update-deck-render-check]] — sub-skill that runs the headless 1920×1080 probe + screenshots.
- [[draft-IC-Deck]] — cold-start deck pipeline; this skill is its iterative cousin.
- [[build-IC-Deck-context]] — refresh the context MD when the corpus has moved.
- [[render-IC-Deck-html]] — Pass 2 of /draft-IC-Deck. Same headless-render pattern.
- [[html-to-pdf]] — chain after /update-deck declares done if PDF export is needed.
- [[nobie-mcp]] — for cell-level XLSX reads when a redline requires data refresh.
