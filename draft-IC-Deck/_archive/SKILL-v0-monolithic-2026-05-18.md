---
name: draft-IC-Deck
description: Draft an IC update / IC vote / interim IC deck for an active deal. Two-pass build — Pass 1 sweeps every relevant source (Slack canvas, Outlook 5-10d back, live source Excel/data files, transcripts, prior decks) into a single context MD; Pass 2 starts a fresh context window that reads ONLY that MD and produces an HTML 16:9 deck. Every page has a header + subheader where the subheader is the page's punchline. Reuses outputs already produced rather than recreating them. Always renders in a browser before reporting done. Use when the user asks to "draft an IC deck", "/draft-IC-Deck", "build the IC update", "build the IC deck", "build the 5.25 deck" (or any dated update deck), or "draft the IC2 vote deck".
user-invocable: true
---

# /draft-IC-Deck — Draft an Investment Committee Deck

## Purpose

Build a 16:9 HTML IC deck (interim update OR vote deck) for an active TWC deal — first draft, ready for Sam's redlines. Two-pass build to avoid the failure mode of working from stale narrative summaries with a polluted context window.

Audience for the deck: TWC IC (Adam, Sean, Meki, Grady, Sam). Tone: factual, dense-but-legible, source-anchored.

## When to use

- "/draft-IC-Deck", "draft the IC deck", "build the IC update deck"
- "build the [date] update deck", "build the 5.25 update", etc.
- "draft the IC2 vote deck", "draft the IC1 deck"
- Any time the user wants an investment committee artifact composed from deal-folder state

## The two non-negotiable failure modes (read first)

Both came out of the 2026-05-18 Bungalow IC deck session (see retrospective at `Downloads/Bungalow-IC-Deck-Session-Retrospective-2026-05-18.md`). Both got caught only after the user pushed back. Don't repeat them.

1. **Skipping verification when the tool exists.** A 16:9 HTML deck MUST be opened in a real browser at 1920×1080 before reporting it done. Use `/browse` — it is one tool call away. "I can't verify visually" is false. The CLAUDE.md rule "start the dev server and use the feature in a browser before reporting" applies here literally.

2. **Working from narrative summaries instead of source.** Source-of-truth hierarchy (top = most authoritative):
   - **Live state** — Slack canvases (`#bungalow` canvas `F0B37J3G8G3`), Outlook last 5-10 days, calendar
   - **Source data files** — the Excel workbooks the prior decks were *rendered from* (e.g. `Bungalow Data Cuts v0.xlsx`, `M&A Deal Pipeline ...xlsx`, unit-count workbooks). Read via Nobie MCP, cell-for-cell.
   - **Existing finished outputs** — last week's Diligence Pack HTML, last update deck, Context_Master. Use for slide *structure* and to avoid recreating finished work, NEVER as a primary source for numbers.
   - **Narrative summaries** — Context_Master.md, planner descriptions, your own prior notes. Decay fast. Useful context only, never authoritative.

   Work the right way around: live → source data → finished outputs → narrative. NOT the other way around.

## Process (two-pass — DO NOT collapse to one pass)

### PASS 1 — Build the context MD (heavy-context, all sources)

Goal: produce a single comprehensive `_ic_deck_context_<YYYY-MM-DD>.md` that contains EVERYTHING the deck needs to say, in plain text, with sources noted. The deck-building pass (Pass 2) will read ONLY this MD plus the user-approved skeleton — no XLS, no PPT, no transcripts.

#### 1.1 — Confirm the deck spec with the user

Ask before sweeping:
- **What IC artifact?** Interim update (framing-heavy, qualitative exec summ, DD status front-and-center) vs. final vote deck (DCM-pattern: punchline subtitle, table-heavy, minimal prose, paired opp + risk per slide). These have **different jobs**. Don't default to the vote-deck pattern from CLAUDE.md if it's an interim update — and vice versa.
- **What date is on the deck cover?** ("5/25/2026 IC Update")
- **What is the user-approved skeleton?** Slide list. If the user hasn't provided one, propose one based on the deck type and the deal state, get sign-off before sweeping. Do not invent slides Sam didn't ask for.

Surface load-bearing ambiguity now. Don't guess scope.

#### 1.1b — IC audience register filter (HARD rule)

The IC is NOT the deal team. They want to know we're making progress, who we're talking to, that questions are being answered. They do NOT want operational granularity. Strip these before they ever enter the context MD:

- **Internal team names as owners** — no "Andrew/Kash/Zach/Lori owns X" columns in any DD workplan table. Workstreams are described by what they ARE, not who is internally driving them.
- **"Who asked" attribution on open questions** — questions are listed as questions, not as "Mgmt 5/5+5/15 asked" or "per Sean." If we have an answer or partial answer, bullet it as a fact; don't quote who said it on what date.
- **Internal vendor names for things adjacent to the diligence** — no "Bungalow ERP cutover from QuickBooks to Campfire" on an exec-summary page. The IC doesn't need to know the ERP vendor. If it's load-bearing to a finding, it goes in detail pages — never in summary or PM-tech pages.
- **Task ownership inside our team** — "Lori delivering full GL Mon 5/18" is deal-team-tracker copy. IC version: "Full GL transaction mapping arriving early next week."
- **Quotes from internal emails / Slack** — open-questions cells should not contain '"per Sean's 5/16 email"' or "[Andrew flagged 5/15]." State the fact.
- **"In flight" / "still being built" framing for things that WILL be done by IC date** — never say "returns model in flight" on a page IC will see on a date when the model should be locked. Either the model is in the deck by then, or the page is omitted / deferred.
- **Gating questions section is the TOP material questions, not the nitty data-request list** — name the top 3 in a bullet, optional sub-bullets. Don't make it a big section.
- **Advisor feedback in exec summ is the STRONGEST convergence + the main callouts**, not a per-advisor recap.

Apply this filter silently during Pass 1 context-MD build. In the post-build summary back to Sam, list what was stripped under "Audience-register filter applied — items stripped" so he can spot-check what got cut.

See `[[feedback-ic-deck-audience-register]]` memory for the generalizable form (same filter applies to Adam-facing emails + partner-visible canvases).

#### 1.2 — Enumerate, don't go to named files

For each source category, **Glob the directory** to see all of what's there. Especially in deal folders where new advisor notes / transcripts / data files appear daily. Don't go to a filename you remember from the planner doc — the directory will have new files the planner didn't know about.

Example mistake from the retrospective: went to Kevin Ortner + Chris Laurence notes by name; missed Brandon Dobel (banker) + Rob Greybar (former Vacasa CEO) files that had appeared in `08. Notes/03. Executive Advisors/` since the planner was written. Glob first, decide what to read second.

#### 1.3 — Sweep the live state FIRST

Before touching any local Excel or transcript, get current state:

**Slack canvas + channel** (deal command center). For Bungalow, that's canvas `F0B37J3G8G3` in `#bungalow` (`C0B2E6LQ5NF`). Read the canvas for: current DD workstream status, open questions, who's blocking what. Read the last 5-10 days of `#bungalow` channel for working context. Other deals — find the equivalent (a pinned canvas or a deal channel).

**Outlook last 5-10 days** — filter by deal-relevant participants (for Bungalow: andrew@bungalow.com, kash@bungalow.com, Lori Parker, BluePoint, Proxet, WSGR, Samir Bakhru @ Orrick, Kevin O'Donnell, Rob Greybar, Brandon Dobel, plus the TWC team). Use Graph API directly via `GraphAdapter` per `feedback_use_graph_api_directly.md`. Multiple KQL passes: participants:<name>, "<topic phrase>", from:<sender>.

**Outlook calendar** — meetings scheduled in the next 30 days (DD sessions, mgmt calls, advisor calls). These feed the "Important Dates" / "Outstanding Workstreams" sections.

If a stale local note says "BluePoint kickoff TBD" but the canvas + Outlook say BluePoint kickoff happened Tue 5/12 with Lori Parker looped in — the canvas wins.

#### 1.4 — Read the source data files (Nobie MCP, cell-for-cell)

For every financial output the deck shows, go to the **source Excel** the prior deck was rendered from. Not the rendered HTML. Not the prior deck PDF. Not the narrative summary.

Bungalow source files to know:
- `Bungalow Data Cuts v0.xlsx` — tabs: "Bungalow Consolidated P&L", "Haven Simplified P&L", "Haven Revenue", "Haven Expenses", **"Haven CP Margin Bridge"** (the actual cell-for-cell margin waterfall). Pick the LATEST version on disk (`_v0`, `_v1`, ...) per `feedback_latest_artifact_version.md`.
- `M&A Deal Pipeline <date>.xlsx` — tab "Output" — active pipeline with doors/rev/EBITDA/margin/entry mult/post-syn mult/cost/status.
- `SB Bungalow Unit Count <date> (excl Haven).xlsx` — Legacy door breakdown.
- `Q10 AI M&A sourcing output for <market>.md` — Cleveland / next-city sourcing funnel.

For each table that goes in the deck, write the actual numbers into the context MD with a `Source: <workbook>.xlsx / <tab>` line. So the Pass-2 build can drop the table in without re-reading the workbook.

#### 1.5 — Read transcripts and advisor notes FULLY

Per the retrospective: only reading the first 300 of 1700 lines of the 5/5 mgmt session caused a fabricated margin bridge (Mgmt Wages at +9pp when the actual is +16pp) and missed the entire ancillary-revenue narrative (RBP / HGPM / NCP / LAIC / Renter's Insurance).

If a transcript is in scope, **read it fully** — or use Agent (Explore agent, "very thorough") to pull every quote on every load-bearing topic. Same for advisor notes — every advisor in scope gets their own block in the context MD: background (1-2 lines) + perspectives (3-6 bullets, verbatim where possible).

#### 1.5b — Close open questions against the LATEST mgmt transcript

Before any "Open Questions" section gets a row, cross-reference it against the most recent management call transcript. If the question was answered, the deck shows the answer — not the question. Stale open-question lists are a tell that Pass 1 was working from older transcripts (IC4/20 + IC5/4 list) and didn't read the newest mgmt transcript through.

Concretely:
1. Glob `08. Notes/02. With Management/` and sort by date — the newest file is mandatory full-read (Explore "very thorough").
2. Every entry in any draft open-questions list is judged answered / partially answered / open against that newest transcript.
3. Answered questions → migrate to "What we learned" or the relevant analytical page; do NOT leave as open.
4. Partially answered → state what we know, then frame the residual question precisely.

A v03-style failure mode: the deck listed "what is the per-door revenue trend?" as open when the 5/15 mgmt call had a 30-minute decomposition of it. That's the symptom this rule prevents.

#### 1.5c — Hallucination guardrail: name + firm + title verification (HARD rule)

Person names, firm names, titles, and source attributions are **load-bearing for IC trust**. A hallucinated firm name (e.g. "Brandon Dobel from Lincoln International" when he's at BGL) is the kind of error that, if Sam doesn't catch it, lands in front of Adam — career-damaging.

Rules:
- For every external person mentioned by name in the deck (advisor, banker, counsel, counterparty), the context MD must include a `Source:` line citing where their firm + title comes from (file path + line, email subject, calendar event title). **No `Source:` line → not in the deck.**
- Never infer firm from training data, "what makes sense given context," or imaginary domains. If you SEE `@bgl.com` in an actual email signature in the corpus, that's a corpus source. If you don't see a domain, don't invent one.
- The Bungalow-specific anchors people-roster table (below) lists known players' firms — but the Pass 1 context MD must still cite a corpus source for each, not just point to the anchors list.
- **If you can't find the firm in the corpus, ASK Sam in a single line BEFORE writing it.** Example: "I have Brandon Dobel as banker but don't see his firm in the corpus — can you confirm BGL?" Don't guess, even a "reasonable guess." See `[[feedback-no-hallucination-ask-instead]]`.

Apply the same rule for any factual claim about an external party (their company history, their prior roles, their tenure at a firm). If the corpus doesn't say it, don't write it.

#### 1.6 — Cross-reference saved-down info with live email

When a local note says X and an Outlook thread from this week says Y, the email wins. Examples:
- Local Context_Master: "Proxet engaged, code review in progress"
- Outlook 5/15: Andrew + Kash flagged Proxet code-level access as IP risk; Sean concurred 5/16
- Live wins. The deck reflects the IP-risk flag, not the rosier saved-down version.

Apply this corroboration step systematically. For every claim the deck will make, check: is there an Outlook thread or Slack message from the last 7 days that updates or contradicts this?

#### 1.7 — Reuse existing outputs; don't recreate (fidelity clause)

If last week's Diligence Pack already has a finalized combined P&L slide, the IC update deck pulls the SAME table (refreshed if data has updated). It does not redo it from scratch with new formatting choices. Same for the margin bridge, the M&A pipeline table, the legacy door breakdown.

**Fidelity clause (HARD):** If Sam says "use the same output we already had in [prior artifact]," the Pass-2 build reproduces it **structurally identically**:
- Same orientation (rows = X, columns = Y — do NOT rotate)
- Same column set (same periods, same metrics, same order)
- Same period granularity (if the original was annual + LTM, don't expand to 12 quarters)
- Same inflection-point annotations (e.g. "acquisition closed Q4-24" line)
- Same supporting commentary structure on the page

The only allowed change is a data refresh (numbers update if the source workbook updated).

If Pass-2 thinks it can improve on the prior output ("this would be cleaner rotated," "this would read better as a chart"), **STOP** — that's a redesign Sam didn't authorize. Reproduce, don't redesign. The 05.25 v03 margin bridge failure was exactly this: the DD agenda's bridge got rotated in the IC deck, making it harder to follow.

Note in the context MD which prior artifact each output came from: `Source: 05.02 DD Agenda Pack HTML, Slide N — reproduce identically (rows = drivers, columns = periods); refresh values from Bungalow Data Cuts v0.xlsx "Bungalow Consolidated P&L"`. Pass 2 will reproduce it.

#### 1.8 — Right unit of analysis (decide BEFORE writing)

For each multi-entity slide, decide the natural unit of analysis FIRST:
- Advisor slide → rows = advisor, columns = (Background, Perspectives). NOT columns = theme.
- Tech / agentic workflow slide → rows = workflow, columns = (Before / In-house vs 3P / Status with hard metrics). NOT columns = stack layer.
- DD workstream slide → rows = workstream, columns = (Status / Owner / Next Milestone / Blockers).
- M&A pipeline → rows = target.

If you're tempted to group by *theme* across multiple entities, that's almost always the wrong call. Pick the entity as the row.

#### 1.8b — Advisor-page composition: external advisors only (HARD rule)

The advisor page is **external operators actively advising us on this deal**. It does NOT include:
- **Company management (CEO/CFO/Controller)** — they're a mgmt page (or referenced inline as data sources). NOT on the advisor page. Putting founders on the advisor page is the v03 failure mode (Andrew Collins + Kash Mathur in the advisor column).
- **Intro sources who declined to advise** — e.g. Chris Laurence intro'd Sam to Kevin Ortner; Sean asked Chris to advise on 4/22, he declined (pursuing a full-time home-services role). Chris is NOT on the advisor page and NOT on any workstream tracker.
- **Counterparties** — the sell-side banker (BGL / Brandon Dobel) gets the banker mention they need elsewhere; do not frame as advisor.
- **Counsel** — Orrick (TWC counsel), WSGR (Bungalow counsel) — counsel page or footnotes only.

Pass 1 produces the advisor list by:
1. Glob `08. Notes/03. Executive Advisors/`.
2. For each person in that folder, check: have they actively engaged in advising us? (signed engagement letter, multiple recurring calls, explicit "yes I'll advise" in a transcript)
3. If yes → advisor page. If declined or never confirmed → omit. If introduced us to advisors but didn't engage themselves → optionally a mgmt-network footnote, otherwise omit.

See `[[project-bungalow-people-roster]]` memory for the verified Bungalow roster (who is + isn't an advisor).

#### 1.8c — "What Bungalow Has Built" page scope: PM operations tech only

This page is "how Bungalow is improving PM operations with technology." Scope:
- **IN:** AppFolio integration, maintenance-triage automation, R&M coordinator workflow, leasing-ops automation, resident-services automation, anything Bungalow has built/bought that improves the PM-economics-per-door story.
- **OUT:** Bungalow's own internal ERP, GL, finance stack (e.g. QuickBooks → Campfire transitions), bookkeeping vendor names (Cloud9), internal accounting tooling, HR systems.

The IC is evaluating "do their tech investments improve PM economics?" — not "what's their accounting system?" Strip the internal finance stack rows from the workflow table.

#### 1.9 — Write the context MD

Output one file: `_ic_deck_context_<YYYY-MM-DD>.md` in the deck's working folder.

Structure:
```
# IC Deck Context — <deal> <date>

## Deck spec
- Type: <update | vote>
- Cover date: <m/d/yyyy>
- Skeleton (user-approved):
  - Cover
  - Page 1 — Exec Summary
  - Page 2 — DD Workplan & Status
  - ... etc
  - Appendix A1, A2, A3

## Sources swept
- Slack canvas <ID> @ <timestamp>
- Outlook <date range>, participants: <list>
- Calendar <date range>
- Source workbooks: <list with versions>
- Transcripts: <list with line counts read>
- Advisor notes: <list>
- Prior decks reused: <list>

## Per-slide content

### Page 1 — Exec Summary
**Header:** Exec Summary
**Subheader (punchline):** <the one most important thing the IC needs to take away from this whole deck>

Where we are: <bullets>
What we've done: <bullets>
Outstanding: <bullets>
Advisor read: <bullets>
Recommendation: <one sentence>

### Page 2 — DD Workplan & Status
**Header:** DD Workplan & Status
**Subheader:** <punchline — e.g. "Round 2 VDR live 5/14; BluePoint + Proxet kickoffs done; Friday 5/15 session surfaced revenue-model + margin-bridge follow-ups">

| Workstream | Status | Owner | Next milestone | Notes |
|---|---|---|---|---|
| ...data... |

Source: canvas <ID> + Outlook 5/11-5/18

### Page 4 — Combined P&L
**Header:** Combined P&L
**Subheader:** <punchline — e.g. "Haven margin recovering 13% → 35% Q3-25 → Q1-26; legacy book stable">

[full table data here, every cell]

Source: Bungalow Data Cuts v0.xlsx / Bungalow Consolidated P&L

### ... etc for every slide
```

Every slide block has: header, subheader (the punchline — single most important thing on the page), content (tables with actual numbers, prose with verbatim quotes, etc.), source line.

**Exec summary block writes itself last** — once all other slide blocks are drafted, the exec summary is a synthesis of them. The IC reads it first; it should tell them generally everything they need to know, then the deck drills into details.

#### 1.10 — Pause; show the context MD to the user

Before Pass 2. Sam reviews → flags missing sources, missing slides, wrong unit of analysis. Cheaper to fix here than after the HTML is built.

---

### PASS 2 — Build the HTML deck (fresh context window, MD-only)

The point of two-pass is that Pass 2 builds with a clean head. It reads ONLY:
1. The approved `_ic_deck_context_<YYYY-MM-DD>.md`
2. The prior deck HTML (for structural patterns / style reuse — not for content)
3. Any DESIGN.md or `CLAUDE.md` style guidance for the project

It does NOT re-open the source Excel, transcripts, Outlook, Slack, or anything else. All the numbers and quotes are already in the MD. This keeps the build context window focused and removes the temptation to re-derive things differently.

If Pass 2 finds it needs data that isn't in the MD, STOP and go back to Pass 1 — add the missing data to the MD, then resume Pass 2. Do not silently sneak in a new Excel read.

#### 2.1 — Page template (universal)

Every page (cover excluded) has:
- **Header** — slide title, ~28-32px, top-left or top-centered per project style
- **Subheader** — single line, ~18-20px, italic or muted-color. **This is the page's punchline — the one thing a skim-reader takes away.** Not a description of the page; the *insight*.
- **Body** — the data. Tables, charts, prose blocks.
- **Footer / page number** — bottom-right.

Examples of subheader = punchline (good):
- "Haven margin recovering 13% → 35% Q3-25 → Q1-26; Mgmt Wages +16pp is the single biggest driver"
- "BluePoint + Proxet both kicked off; Proxet code-level access flagged as IP risk 5/15"
- "12 active targets; 8x platform / 5x add-on entry math gets us to 3.0x MOIC under WYNTB assumptions"

Examples of subheader = description (BAD — fix these):
- "Margin bridge for Haven Q3-25 through Q1-26"
- "Status of due diligence workstreams"
- "Active M&A pipeline targets"

#### 2.2 — Density: legibility > information density

Native resolution is 1920×1080. The deck will be read at fit-to-width on a 13-15" laptop. Defaults:
- **Body font: 17-18px minimum.** NOT 13-14px.
- **Single column** for dense content. Don't halve column width by going two-column unless the content is genuinely two narrow lists.
- **Table cells: 14-16px minimum.** Generous padding (10-12px).
- **Split a slide before you compress.** If a table has 12 rows and won't fit at 16px, split to two slides — "Page 3a / Page 3b" — rather than dropping the font to 12px.
- **Financial output tables are non-negotiable for legibility.** P&Ls, margin bridges, returns tables — every cell must be readable at fit-to-width on a laptop. If the table has many columns, consider splitting by period (e.g., Q3-24-Q1-25 on slide A, Q2-25-Q1-26 on slide B) rather than shrinking.
- **Annual columns by default; quarterly only when quarterly IS the story.** Financial tables (P&L, revenue waterfalls, door progression) default to **annual columns** with one or two LTM snapshots. Quarterly columns are reserved for slides where the *quarterly trend itself* is the punchline (e.g. a margin recovery curve over the last 3 quarters). 12 quarterly columns on a P&L is always wrong for IC. When reusing a prior DD-agenda output that had annual columns + an inflection-point line (e.g. "acquisition closed Q4-24"), reproduce it identically — never expand to quarterly under the guise of "more detail."

#### 2.3 — Tables: rows-by-entity, real cells

Per Pass 1 §1.8 — the row dimension is the entity (advisor, workflow, workstream, target). Each row has real data from the context MD, not placeholders.

NO `<TBU>` cells unless Sam explicitly flagged that slide as TBU. If a cell is empty, that's a Pass-1 gap — go back, fill it, then come forward.

#### 2.3b — Spoon-feed: commentary co-located with output, on every analytical page (HARD rule)

The IC's job is to decide; the deal team's job is to interpret. Every analytical page (financial table, bridge, pipeline, sensitivities, market sourcing) MUST have commentary on the SAME page as the output, telling the reader: what to look at, what we learned, what it means for the thesis. Not on the next page. Not implicit. Spelled out.

If a page is "just a table," it's wrong. Add commentary.

If the commentary won't fit alongside the output, **the page is structured as a 2-row layout on the same slide** (top row = output, bottom row = commentary) — NOT output-on-page-A + commentary-on-page-B. The v03 margin bridge had output on page 6 and commentary on page 6b; that's the failure mode this rule prevents.

For tables built from mgmt-call data (M&A pipeline, P&L, margin bridge), the commentary MUST reflect what the most recent mgmt call discussed about those numbers — including specific deals named, target context, what mgmt told us about each line item. Not just generic "the table shows X." If a pipeline page has 12 targets and the 5/15 mgmt call gave color on 4 of them, the page commentary names that color per-target.

#### 2.3c — Standalone-page test

Before any page ships, read it as if you'd opened the PDF to that page cold. Can you understand: (a) what this page is about, (b) why we made it, (c) the punchline — **without referencing any other page**? If not, add the missing framing.

This is especially load-bearing for sourcing / pipeline / thesis pages where context lives in our heads but not on the page (e.g. "Cleveland deepening thesis — 50 AI-sourced targets" needs to explain *what the page is doing*, where the 50 came from, and why it supports the thesis — in the first 2 lines of the page, not assumed). The v03 Cleveland page failed this test.

#### 2.3d — Appendix divider page (HARD rule)

The first appendix slide is always a dedicated divider — full bleed, large centered text: "APPENDIX." Optionally below it: a 1-line index of what's in the appendix ("A1 cap table · A2 Windermere · A3 legacy doors"). Then A1 starts on the next page.

This is a visual signal to IC readers that the main deck has ended. Without it, A1 reads as "yet another slide" and the natural attention break is lost.

#### 2.3e — TBU callouts for known confounding events

When an analytical output (margin bridge, growth metric, revenue trajectory, customer-cohort analysis) is meaningfully affected by a known confounding event (e.g. Haven lost a 300-door institutional customer right before acquisition; an ERP cutover obscures Q1-26 data quality; a pricing change happened mid-period), the page MUST include a yellow callout box: "**TBU:** redo this analysis excluding [event] to show normalized [metric]."

This signals to IC: we've already thought about this and the next version will address it. Without the callout, IC has to ask the question themselves, which feels like a gap.

#### 2.4 — Exec summary slide

Built LAST in Pass 2 even though it's Page 1. Why: it's a synthesis of every other slide's subheader/punchline. After all slides are built, read your own subheaders back, and the exec summary writes itself.

Structure (interim-update flavor):
- **Where we are** — 4-6 bullets, factual state
- **What we've done** — 4-6 bullets, last week / since last IC
- **Outstanding** — 3-5 bullets, what we're still working
- **Advisor read** — 1-2 bullets per advisor, name them
- **Recommendation** — one sentence; what the IC should take away

The IC reads only the exec summary on a busy day. It should give them everything they need to know in one screen. The rest of the deck is detail.

#### 2.5 — Render in a browser. Actually.

Once the HTML is written, **before reporting back to Sam**:
1. Load `/browse` (one of the most-used gstack tools — it's right there).
2. Open the deck at 1920×1080.
3. Page through every slide. Screenshot a sample (cover, page 1, the densest data slide, the advisor slide, the appendix).
4. Check: no overflow, no text below the fold, no <13px body fonts, no two-narrow-columns where they shouldn't be, every table renders cleanly.
5. Fix issues → re-render → re-verify.

Only after this verification, write the "here's what changed against each of your items" report.

NEVER ship a "saved at [path], open in Chrome to review" response when `/browse` is available. That's the lazy pattern from the retrospective. The user will (rightly) call it out.

#### 2.6 — Versioning

Save versioned files in the deck folder:
- `<deal> IC Update — <m.d> v01.html` — first build
- `<deal> IC Update — <m.d> v02.html` — after feedback round 1
- `<deal> IC Update — <m.d> v03.html` — after feedback round 2

Don't overwrite. The user can diff.

Co-locate the context MD: `_ic_deck_context_<YYYY-MM-DD>.md`.

#### 2.7 — Page numbering: every page is its own page (HARD rule)

**NO `1b`, `3b`, `6b`, `10b`, `11b` sub-letter pages.** If density forces a split, the split becomes the next sequential page number (Page 3 and Page 4). Sub-letter suffixes signal "this is half a thought" — Sam doesn't want half-thoughts; he wants discrete pages, each with its own punchline.

The v03 deck had 5 sub-letter pages (1b exec summ part 2, 3b open questions part 2, 6b bridge commentary, 10b advisor part 2, 11b Cleveland) — every one is a v04 fix.

Side-effects:
- An exec summary that wants to be "1 of 2 / 2 of 2" should instead be **one** page with tighter writing. The audience-register filter (§1.1b) usually cuts enough fat to make it fit. If after tightening it still doesn't fit, the split is Page 1 (Exec Summ) → Page 2 (Advisor Read & Recommendation) — separate punchlines, separate sequential numbers.
- A bridge + commentary split (v03 pattern: 6 + 6b) becomes a single page with a 2-row layout — output top, commentary bottom — per §2.3b.
- An "advisor part 1 / part 2" split becomes either one advisor page (tighter) or two advisor pages with separate sub-punchlines, sequentially numbered.

---

## Rules — load-bearing

**From 05.25 v03 retro — read these FIRST:**

- **IC audience register (§1.1b):** no internal team owners, no "who asked" attribution, no internal vendor names (Campfire/QuickBooks/Cloud9), no "in flight" framing for IC-date things.
- **No sub-letter pages (§2.7):** no `1b`, `3b`, `6b`. Density → next sequential number, or a 2-row same-page layout.
- **Annual columns default; quarterly only when quarterly IS the story (§2.2 last bullet).**
- **Reuse = identical reproduction (§1.7):** same orientation, same column set, same period granularity. No "I'll improve it" redesigns.
- **Latest mgmt transcript closes the open-questions list (§1.5b)** before any open-questions section is drafted.
- **Advisor page = external advisors actively engaged (§1.8b).** NOT mgmt (founders), NOT intro sources who declined, NOT counsel/counterparties.
- **Person + firm + title needs a corpus `Source:` line (§1.5c). If unknown, ASK** — never infer from training data or domain.
- **Every analytical page has commentary co-located (§2.3b).** "Just a table" is wrong. Commentary cites what mgmt told us about those numbers.
- **Every page passes the standalone-page test (§2.3c).**
- **Appendix gets a dedicated divider page (§2.3d).**
- **TBU callout box for known confounding events (§2.3e)** — e.g. lost large customer pre-acquisition, ERP cutover.
- **"What Bungalow Has Built" = PM operations tech only (§1.8c).** Strip internal ERP / GL / bookkeeping.

**Foundational (from prior retros):**

- **Two passes. Don't collapse.** Pass 1 sweeps everything into MD; Pass 2 reads only the MD. This is the whole point.
- **Live > source data > finished outputs > narrative.** Always work in that order.
- **Glob directories; don't go to remembered filenames.** New advisor notes / transcripts appear daily.
- **Every page: header + subheader, subheader is the punchline.** Not a description.
- **Body fonts 17-18px+ for prose, 14-16px+ for tables.** Split slides before compressing.
- **Exec summary is a synthesis of every other slide's punchline.** Build it last.
- **Reuse finished outputs from prior decks. Don't recreate.**
- **Read transcripts and advisor notes FULLY, not the first 300 lines.**
- **Corroborate every saved-down claim against this week's Outlook + Slack.**
- **Right unit of analysis = entity (advisor, workflow, workstream), not theme.**
- **Render in `/browse` at 1920×1080 BEFORE reporting done.** Always.
- **Verify entity names against literal corpus forms.** Per `feedback_verify_entity_names_no_acronym_inference.md`.
- **Use the latest version on disk per `feedback_latest_artifact_version.md`** — glob the folder, pick highest `_vN`.
- **Use Nobie MCP for Excel reads per `feedback_excel_formatting_preservation.md`** — and write actual cell values into the context MD so Pass 2 doesn't re-read.

## What NOT to do

**From 05.25 v03 retro:**

- Don't ship `1b` / `3b` / `6b` sub-pages.
- Don't put internal team owner names ("Andrew/Kash/Zach/Lori") in any IC-facing column.
- Don't attribute open questions to who asked or quote internal emails inline.
- Don't disclose internal vendor names (QuickBooks, Campfire, Cloud9) on exec summary or PM-tech pages.
- Don't say "returns model still in flight" on a page IC will see on a date when the model SHOULD be done.
- Don't put founders / counsel / counterparties on the advisor page. Don't put intro sources who declined to advise either.
- Don't infer a person's firm from training data or domain. If the corpus doesn't say, **ASK** before writing.
- Don't redesign a prior approved output (rotate a bridge, expand annual → quarterly, change column order). Reproduce identically; the only allowed delta is a data refresh.
- Don't ship an analytical page without same-page commentary. "Just a table" pages are wrong.
- Don't ship the first appendix slide without a dedicated "APPENDIX" divider before it.
- Don't ship a confounded analysis (lost customer pre-acquisition, ERP cutover etc.) without a yellow TBU callout for the normalization version.
- Don't list answered questions as "open" — the latest mgmt transcript closes them first.

**Foundational:**

- Don't skip Pass 1 and start building HTML directly from Excel + transcripts + Outlook in one polluted context window.
- Don't write `<TBU>` cells in slides Sam expected populated.
- Don't draw a freehand "approximate" waterfall from narrative percentages when the source Excel has the actual cell-for-cell bridge.
- Don't read 300 of 1700 lines of a transcript and hope you got the load-bearing content.
- Don't go to named files when you should be globbing the directory.
- Don't pick "themes" as columns when "advisors" or "workflows" are the natural row.
- Don't ship at 13-14px body font in two narrow columns and hope it's "fine on a big monitor."
- Don't write a subheader that describes the page ("Margin bridge for Q3-25 → Q1-26"). Write the punchline ("Mgmt Wages +16pp is the single biggest driver of the 22pp recovery").
- Don't write an exec summary first and then build the rest of the deck to match it. Build slides → harvest punchlines → write exec summary as synthesis.
- Don't report "saved at [path], open in Chrome to review" without rendering in `/browse` yourself. That's the lazy pattern.
- Don't recreate finished outputs the prior deck already has. Reuse.
- Don't use stale local notes as the source of truth when this week's Outlook + Slack supersede them.

## Bungalow-specific anchors

For Bungalow IC decks specifically (other deals: substitute the equivalents):

- **Working folder:** `C:\Users\SamBradley\TrueWindCapital Dropbox\_Deal Team\Deals (In Process)\Property Management Targets\01. Bungalow CC\`
- **IC artifact subfolder:** `03. IC Collateral/<MM.DD update or IC vote>/`
- **Slack canvas (DD command center):** `F0B37J3G8G3` in `#bungalow` (`C0B2E6LQ5NF`) — see `[[updatebung]]` for canvas mechanics
- **Source workbooks to know:**
  - `Bungalow Data Cuts v<N>.xlsx` — P&L, Haven revenue/expenses, **Haven CP Margin Bridge** (cell-for-cell waterfall)
  - `M&A Deal Pipeline <date>.xlsx` tab "Output" — 12 active targets
  - `SB Bungalow Unit Count <date> (excl Haven).xlsx` — legacy door breakdown
  - `Q10 AI M&A sourcing output for cleveland.md` — Cleveland sourcing funnel (50 targets, A-D tiers)
- **Advisor notes folder:** `08. Notes/03. Executive Advisors/` — enumerate every time
- **Mgmt + advisor transcripts folder:** `08. Notes/` and subdirectories — enumerate every time
- **Verified people roster — USE THESE EXACT ROLES + FIRMS, do NOT infer** (see `[[project-bungalow-people-roster]]` memory):

| Person | Role | Firm | Status | Source |
|---|---|---|---|---|
| Andrew Collins | Co-founder + CEO | Bungalow | **Mgmt — NOT advisor page** | `Glossary.md` |
| Kash Mathur | Co-founder + CFO | Bungalow | **Mgmt — NOT advisor page** | `Glossary.md` |
| Lori Parker | Controller | Bungalow | Mgmt extension | calendar + Slack |
| Kevin Ortner | External advisor (industry) | ex-CEO Renters Warehouse | Engaged, consulting agreement executed | `08. Notes/03. Executive Advisors/Kevin-Ortner-*` |
| Brandon Dobel | Banker (sell-side) | **BGL** (NOT "Lincoln International" — v03 hallucination) | Banker-of-record | `08. Notes/03. Executive Advisors/BGL-Banker-Brandon-Dobel-Bungalow-*.md` |
| Rob Greybar | External advisor (industry) | Former Vacasa CEO | Engaged | `08. Notes/03. Executive Advisors/Rob-Greybar-*` |
| Chris Laurence | **Intro source ONLY — NOT advising** | ex-CEO Renters Warehouse | Intro'd Sam to Kevin; declined Sean's 4/22 ask to advise (pursuing full-time home-services role) | `08. Notes/03. Executive Advisors/2026-04-22 — Chris Laurence Call — Transcript.md` lines 213–238 |
| BluePoint (Stephin Janis, Paul Ochoa, Rick Kappes) | QofE counterparty | BluePoint | In books | calendar + Outlook |
| Proxet | Tech DD counterparty | Proxet | IP scope being negotiated | Outlook 5/15–5/16 |
| WSGR | Bungalow's counsel | WSGR | Counterparty | Outlook |
| Samir Bakhru | TWC's counsel | Orrick | Engaged | calendar |

- **Last finished IC artifact to reuse for structure:** look for the most recent `<...> v<N>.html` in `03. IC Collateral/` subfolders — Diligence Packs, prior update decks, IC vote decks. Glob the folder.
- **Deck size convention:** 16:9 native, target 1920×1080. Cover + 10-20 sequentially numbered slides + 2-4 appendix (preceded by a dedicated "APPENDIX" divider per §2.3d). Splits → next sequential page number, NOT sub-letter suffixes (per §2.7).
- **Returns model:** "What you need to believe" — 1 platform + 1 add-on per year, +5% growth, +15pp margin uplift, 8x platform / 5x add-on entry, 10-14x exit, 30-40% leverage → 3.0x MOIC (Grady's v1; verify current against latest model on disk before quoting)

## Related feedback memories

- `feedback_latest_artifact_version.md` — use the highest `_vN` on disk, not the version named in narrative docs
- `feedback_html_to_pdf.md` — convert deck HTML → PDF for the user; don't hand back instructions
- `project_dd_pack_print_format.md` — strip the script + inject print CSS before Chrome headless on DD-pack HTML for counter-parties
- `feedback_workstream_separation.md` — tag every item by deal before folding into Bungalow context
- `feedback_excel_formatting_preservation.md` — Nobie: copy_from_range to stamp styles before overwriting values
- `feedback_adam_email_style.md` — Adam-facing communication register (relevant if any IC slide will be repurposed for Adam updates)
- `feedback_use_graph_api_directly.md` — Outlook reads via Graph, not the broken MCP search
- `feedback_emails_slack_multiple_passes.md` — multi-pass corpus search in Pass 1.3
- `feedback_verify_entity_names_no_acronym_inference.md` — no expanding "BGL" or inferring from domains
- `feedback_ic_deck_audience_register.md` — what to strip from any IC-facing artifact (team owners, attribution, internal vendor names, in-flight framing)
- `feedback_no_hallucination_ask_instead.md` — every external person needs a corpus `Source:` line; ASK if unsure (generalizable)
- `project_bungalow_people_roster.md` — verified Bungalow people roster (Andrew/Kash = founders not advisors, Brandon = BGL not Lincoln, Chris Laurence = intro not advisor)

## Related skills

- `[[updatebung]]` — keeps the Bungalow tracker canvas current (input to Pass 1.3)
- `[[emaildraft]]` — same corpus-first philosophy, different output (email vs deck)
- `[[browse]]` — render + screenshot the deck before declaring done (Pass 2.5)
- `[[html-to-pdf]]` — if the user wants the deck as a PDF after approval
- `[[market-analysis]]` — relevant if the deck includes a sourcing-funnel / market-segmentation slide
