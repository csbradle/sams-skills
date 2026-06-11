---
name: render-IC-Deck-html
description: This skill should be used when the user (or the /draft-IC-Deck orchestrator) asks to "render the IC deck HTML", "rebuild the IC deck HTML", "re-render the deck from the MD", "Pass 2 only", or "/render-IC-Deck-html". Pass 2 of the IC deck pipeline — renders the HTML deck from an already-built context MD plus a prior-deck HTML used only for structural reference. Hard constraint: reads ONLY the MD for content; never touches source Excel, transcripts, Outlook, or Slack. If the MD is missing data, returns a gap report instead of fabricating. Always renders in /browse at 1920×1080 and screenshots every page before reporting done. Designed to run as an Agent-tool subagent spawned from /draft-IC-Deck with a fresh context window; also independently invocable to re-render after the MD has been redlined.
version: 1.0.0
user-invocable: true
---

# Pass 2 — Render IC Deck HTML

## Purpose

Build the 16:9 HTML deck from the context MD that Pass 1 produced. Pass 2's whole reason to exist is to work with a **clean head**: it has not seen the transcripts, Excel, Outlook, or Slack reads — only what Pass 1 distilled into the MD. This is the structural guarantee that prevents the failure mode where Pass 2 "knows" things from raw source reads and silently hallucinates around the MD.

## Inputs expected

If spawned by the `/draft-IC-Deck` orchestrator, inputs arrive in the Agent prompt:
- **Project slug** (e.g. `bungalow`, `wes`, `pak`) — required
- **Anchors file path** (e.g. `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/<project-slug>-anchors.md`) — or `none` if no anchors file exists
- Context MD path (READ ONLY for content)
- Prior deck HTML path (READ ONLY for structural reuse — NOT for content)
- Output HTML path
- Optional: list of redlines from Sam to apply on this version

If invoked standalone, read inputs from `<deal-folder>/<IC subfolder>/_ic_deck_session_state.json` (schema: `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/session-state-schema.md`). The state file carries the project slug + anchors path. If no state file exists, **ask the user which project + which MD to render against** first.

## Anchors

**Project-agnostic (always used):**
- HTML/CSS patterns: `C:/Users/SamBradley/.claude/skills/render-IC-Deck-html/references/page-templates.md`
- Why each rendering rule exists (v03 retro evidence): `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/v03-retro.md`

**Project-specific (from the anchors file passed in the prompt):**
- Deck size convention (usually 16:9 1920×1080 — same across projects)
- Returns formula (if the deck has a returns page that quotes a standing model)
- File naming convention for the HTML output (`<project display name> IC Update — <m.d> v<NN>.html`)

If `anchors file: none` was passed, use the project-agnostic defaults (16:9 1920×1080, file name uses project slug from the input).

## §1 — HARD READ CONSTRAINT

**Allowed reads:**
- Context MD (the file Pass 1 produced)
- Prior deck HTML (for structural / style reference ONLY)
- `references/page-templates.md` (HTML/CSS patterns)
- The project's anchors file at the path passed in the prompt (deck-size convention, returns formula, file-naming)
- Memories (load by default into subagent context)

**FORBIDDEN reads (across all projects):**
- Source Excel workbooks (any project's data files)
- Transcripts (mgmt, advisor)
- Outlook / Graph API
- Slack canvas / channel
- Any raw source folder in the deal directory (e.g. `08. Notes/`, `07. From Company/`, `Questions/`, etc.)

**If the MD is missing data** (e.g. a slide's table is empty, a person's source line is absent, a punchline isn't drafted), STOP. Return a gap report:

```
MD GAP: <what's missing, specifically — slide name, field, what the renderer expected>
Examples:
- "Page 4 Combined P&L: MD has no Source: line for the Q1-26 LTM column"
- "Page 11 M&A Pipeline: MD has 11 targets but Pass 1 says 12 — one missing"
- "Page 1 Exec Summary: subheader/punchline missing"

Recommendation: orchestrator should re-spawn Pass 1 to fill the gap, or user should patch the MD directly at the MD-review gate.
```

Do NOT fabricate. Do NOT re-open Excel "just to fill the gap." The constraint is structural — violating it defeats the whole reason Pass 2 exists in its own context.

## §2 — Page template (universal)

Every page (cover excluded) has:
- **Header** — slide title, ~28–32px, top-left or top-centered per project style
- **Subheader** — single line, ~18–20px, italic or muted color. **This is the punchline.** Not a description of the page; the *insight*.
- **Body** — the data. Tables, charts, prose blocks.
- **Footer / page number** — bottom-right.

Subheader = punchline (good):
- "Haven margin recovering 13% → 35% Q3-25 → Q1-26; Mgmt Wages +16pp is the single biggest driver"
- "BluePoint + Proxet kickoffs both done; Proxet code-level access flagged as IP risk 5/15"
- "12 active targets; 8x platform / 5x add-on entry gets us to 3.0x MOIC under WYNTB assumptions"

Subheader = description (BAD — fix):
- "Margin bridge for Haven Q3-25 through Q1-26"
- "Status of due diligence workstreams"
- "Active M&A pipeline targets"

## §3 — Density: legibility > information density (annual default)

Native resolution: 1920×1080. Read at fit-to-width on 13–15" laptop.

- **Body font: 17–18px minimum.** NOT 13–14px.
- **Single column** for dense content. Don't halve column width by going two-column unless content is genuinely two narrow lists.
- **Table cells: 14–16px minimum.** Generous padding (10–12px).
- **Split a slide before you compress.** If a table has 12 rows and won't fit at 16px, split to two slides — Page 3 and Page 4 — rather than dropping to 12px. **NO sub-letter (3a/3b) suffixes ever.**
- **Annual columns DEFAULT for financial tables.** Quarterly columns reserved for slides where the *quarterly trend itself* is the punchline (e.g. a margin recovery curve over 3 quarters). 12 quarterly columns on a P&L is always wrong for IC.
- When reusing a prior DD-agenda output that had annual columns + inflection-point line (e.g. "acquisition closed Q4-24"), reproduce it identically.

## §4 — Tables: rows-by-entity, real cells, no placeholders

The row dimension is the entity (advisor, workflow, workstream, target). Each row has real data from the MD, not placeholders.

NO `<TBU>` cells unless the MD explicitly flagged that slide TBU. If a cell is empty, that's an MD gap — STOP per §1.

## §5 — Spoon-feed: commentary co-located with output (HARD)

Every analytical page (financial table, bridge, pipeline, sensitivities, market sourcing) MUST have commentary on the SAME page as the output. Not on the next page. Not implicit. Spelled out.

If the page is "just a table," it's wrong.

If commentary won't fit alongside the output, the page becomes a **2-row layout on the same slide** (top row = output, bottom row = commentary) — NOT output-on-page-A + commentary-on-page-B.

For tables built from mgmt-call data (M&A pipeline, P&L, margin bridge), the commentary cites what the latest mgmt call discussed about those numbers — per-target detail where applicable. (The MD will have this content from Pass 1 §4.)

## §6 — Standalone-page test

Before any page ships, read it as if you'd opened the PDF cold to that page. Can you understand: (a) what this page is about, (b) why we made it, (c) the punchline — **without referencing any other page**? If not, add framing.

Especially load-bearing for sourcing / pipeline / thesis pages (e.g. "Cleveland deepening thesis — 50 AI-sourced targets" needs to explain *what the page is doing* + where the 50 came from + why it supports the thesis in the first 2 lines).

## §7 — Appendix divider page (HARD)

The first appendix slide is always a dedicated divider — full bleed, large centered text: "APPENDIX." Optionally below: a 1-line index of what's in the appendix ("A1 cap table · A2 Windermere · A3 legacy doors"). Then A1 starts on the NEXT page.

This is a visual signal that the main deck has ended. Without it, A1 reads as "yet another slide."

## §8 — TBU callouts for known confounding events

When an analytical output is materially affected by a known confounding event (the MD will flag these — e.g. "Haven lost 300-door institutional customer pre-acquisition," "ERP cutover obscures Q1-26 data quality"), the page MUST include a yellow callout box:

> **TBU:** redo this analysis excluding [event] to show normalized [metric].

Signals to IC: we've thought about this; next version will address it.

## §9 — Sequential page numbers; NO sub-letter pages (HARD)

**Never:** `1b`, `3b`, `6b`, `10b`, `11b`, etc.

If density forces a split, the split becomes the next sequential page number (Page 3 → Page 4). Sub-letter suffixes signal "this is half a thought."

Side-effects:
- Exec summary that wants "1 of 2 / 2 of 2" → tighten until it's one page. The audience-register filter applied in Pass 1 usually cuts enough fat. If still doesn't fit, split as Page 1 (Exec Summ) → Page 2 (Advisor Read & Recommendation) — separate punchlines, sequential numbers.
- Bridge + commentary that wants "6 + 6b" → single page with 2-row layout (per §5).
- Advisor "part 1 / part 2" → one tighter advisor page, OR two advisor pages with separate sub-punchlines.

## §10 — Reuse fidelity

If the MD says `Reuse instruction: REPRODUCE IDENTICALLY from <prior artifact> Slide N (rows = X, cols = Y)`, reproduce it **structurally identically**:
- Same orientation (rows = X, cols = Y — do NOT rotate)
- Same column set, same order, same period granularity
- Same inflection-point annotations
- Same supporting commentary structure

Only allowed change: data refresh (if MD updates the numbers).

If tempted to "improve" the prior output (e.g. "this would be cleaner rotated"), STOP. That's a redesign the user didn't authorize.

## §11 — Exec summary built LAST

Even though it's Page 1, build it last. The exec summary is a synthesis of every other slide's subheader/punchline. After all other slides are built, read your own subheaders back; the exec summary writes itself.

Structure (interim-update flavor):
- **Where we are** — 4–6 bullets, factual state
- **What we've done** — 4–6 bullets (filter-stripped per Pass 1's audience-register pass)
- **Outstanding gating questions (top 3)** — 3 bullets, optional sub-bullets
- **Advisor read** — strongest convergence + main callouts (NOT per-advisor recap)
- **Recommendation** — one sentence

IC reads only the exec summary on a busy day. One screen, everything they need.

## §12 — Render in /browse at 1920×1080; screenshot every page

Once HTML is written, BEFORE reporting back:

1. Load `[[browse]]`.
2. Open the deck at 1920×1080.
3. Screenshot every slide (cover, every page, every appendix).
4. Check each:
   - No overflow
   - No text below the fold
   - No <13px body fonts
   - No two-narrow-columns where they shouldn't be
   - Every table renders cleanly
   - Punchline visible without scroll
5. If issues → fix HTML → re-render → re-screenshot.

This is non-negotiable. **NEVER ship a "saved at [path], open in Chrome to review" response.** Use `/browse`. The user will call it out.

Save screenshots to `<deck-folder>/<MM.DD update>/<vNN>-screenshots/`.

## §13 — Versioning + session-state update

Save HTML to the path specified in the prompt (or derive: `Bungalow IC Update — <m.d> v<NN>.html`).

Don't overwrite prior versions — increment. v01 → v02 → v03.

Update `_ic_deck_session_state.json`:
```
phase: "pass2_complete"
html_versions: append { version, path, screenshot_dir, verification, built_at }
last_summary: <one-line>
```

## Return contract

Return a SINGLE message to the caller:

```
HTML written to <path>.
Screenshots at <screenshot_dir>/.

Verification:
- All <N> pages rendered cleanly
- No overflow, no <13px body, no sub-letter pages
- Annual columns used on P&L, Revenue Stack; quarterly used on margin bridge (per MD spec)
- Appendix divider present
- TBU callouts present on: <list>

[OR if any issues:]
Verification ISSUES:
- Page N: <issue>
- Page M: <issue>
Recommend re-render after fix.

Outstanding (for orchestrator/user):
- <any MD gaps surfaced during build that didn't STOP but should be flagged>
- <any reuse-instruction ambiguities>

Next step: orchestrator presents HTML + screenshots to user for review at iteration gate.
```

Parent context grows by the return message + screenshot file paths only. Parent never sees the HTML body text directly unless the user asks.

## Failure handling

- **MD gap.** STOP per §1, return MD GAP report. Don't fabricate.
- **Browse render fails.** Report the specific error (port conflict, HTML syntax issue, etc.). Don't ship without verification.
- **Prior deck HTML missing.** Continue without structural reference; flag in return ("No prior deck found at <path>; built from scratch following Anthropic + audience-register conventions"). User may have moved/renamed.
- **Reuse instruction ambiguous.** If MD says "reproduce identically" but doesn't specify orientation/columns, look at the prior HTML for the answer. If still ambiguous, flag in return.

## Related memories

- `[[feedback-ic-deck-audience-register]]` — filter rationale (Pass 1 applies; Pass 2 enforces in commentary tone)
- `[[feedback-no-hallucination-ask-instead]]` — STOP and return MD GAP, don't fabricate
- `[[feedback-latest-artifact-version]]` — picking the right prior-deck HTML for reuse
- `[[feedback-html-to-pdf]]` — HTML → PDF conversion (post-render; orchestrator usually handles)
- `[[project-dd-pack-print-format]]` — strip script + inject print CSS for counter-party renders

## Related skills

- `[[draft-IC-Deck]]` — parent orchestrator (Phase D spawns this skill)
- `[[build-IC-Deck-context]]` — Pass 1 (produces the MD this skill reads)
- `[[browse]]` — render + screenshot deck before declaring done (§12)
- `[[html-to-pdf]]` — convert HTML → PDF if user wants the deck as a PDF after approval
