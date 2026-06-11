---
name: build-IC-Deck-context
description: This skill should be used when the user (or the /draft-IC-Deck orchestrator) asks to "build the IC deck context MD", "rebuild the context MD", "refresh Pass 1", "re-sweep sources for the IC deck", or "/build-IC-Deck-context". Pass 1 of the IC deck pipeline — sweep every relevant source (Slack canvas, Outlook 5-10d back, source Excel via Nobie, transcripts, advisor notes, prior decks) into a single comprehensive context MD with sources cited. Applies the IC audience-register filter. Designed to run as an Agent-tool subagent spawned from /draft-IC-Deck with a fresh context window, but also independently invocable to refresh just the MD without rebuilding the HTML.
version: 1.0.0
user-invocable: true
---

# Pass 1 — Build IC Deck Context MD

## Purpose

Sweep every relevant source into a single `_ic_deck_context_<YYYY-MM-DD>.md` that contains everything the deck needs to say, in plain text, with corpus sources cited per claim. Pass 2 (`/render-IC-Deck-html`) reads this MD as its ONLY content source — so the MD must be complete, source-anchored, and audience-register-filtered before it ships.

**The skeleton is the deck's shape, not its content** — this skill fills the shape in by going deep into the sources; a thin MD that restates the skeleton is the failure this Pass exists to prevent (see §0).

## Inputs expected

If spawned by the `/draft-IC-Deck` orchestrator, inputs arrive in the Agent prompt:
- **Project slug** (e.g. `bungalow`, `wes`, `pak`) — required
- **Anchors file path** — REQUIRED. May be a pointer file under `references/` (follow it to the real data-side anchors file). `none` is no longer a legal value: the orchestrator's Phase A anchors gate guarantees a field-complete anchors file exists before this Pass spawns.
- Deck type (`update | vote`)
- Cover date (`m/d/yyyy`)
- User-approved skeleton (bulleted slide list)
- Deal folder path
- Output MD path

If invoked standalone, read inputs from `<deal-folder>/<IC subfolder>/_ic_deck_session_state.json` (schema: `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/session-state-schema.md`). If no state file exists, **ask the user which project + deal folder** first, then proceed.

## Anchors

**Project-specific anchors (paths, people roster, source workbooks):** read the anchors file path passed in the Agent prompt (e.g. `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/<project-slug>-anchors.md`). This is the canonical source for: deal folder structure, Slack canvas + channel IDs, advisor folder paths, source workbook names + tabs, verified people roster with firms + sources.

**If the anchors file is missing, unreadable, or fails the required-fields check** (`anchors-template.md` in draft-IC-Deck/references/): STOP immediately and return to the orchestrator — `"ANCHORS GATE: <what's missing>. Run the bootstrap dialogue before re-spawning Pass 1."` Do NOT ask the user inline for source paths, do NOT assume any project's defaults, do NOT proceed with a partial sweep. (The old inline-ask path is how a deck once ran with no grounding at all — see the 2026-06-10 incident in `verify-gate.md`.) If the anchors file's corpus root is unreachable on this machine, return the same way with the machine-reachability note so the orchestrator can use verify-gate.md template T6.

**Project-agnostic references (apply to all projects):**
- Audience-register filter: `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/audience-register-filter.md`
- v03 retro context: `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/v03-retro.md`

## Process

### §0 — The skeleton is a shape, not the content (HARD — read first)

The skeleton (or any outline / sticky-note draft) is a **structural list only** — which slides exist, in what order. It does NOT say what goes on them. The default failure, and why first drafts come back "too light": treating each bullet as finished content, so the deck just restates the outline. For **every** item:

- **Read the bullet as a question, not an answer** — "Market opportunity" = *go size the market from the study and build the page*, not paste the phrase.
- **Go deep into the sources to determine what's right** — open the latest workbooks cell-for-cell, read transcripts / CIM / advisor notes / prior decks fully, query the brain; pull the real figures, verbatim quotes, and named facts. When sources disagree, cross-check to decide which is correct.
- **Expand each bullet into a dense, source-anchored block.** Test: *if a block could have been written from the skeleton alone — no source opened — it isn't done.*

Discover content from sources first; only then fit it to the skeleton. §1–§12 are how; §0 is why.

### §1 — Enumerate, don't go to remembered filenames

For each source category, glob the directory to see all of what's there. Deal folders get new advisor notes / transcripts / data files daily. Don't go to a filename remembered from a planner doc — the directory will have newer files.

Example failure mode: going to "Kevin Ortner + Chris Laurence notes by name" and missing "Brandon Dobel (banker) + Rob Greybar (former Vacasa CEO) files" that appeared in `08. Notes/03. Executive Advisors/` since. Glob first, decide what to read second.

### §2 — Sweep the live state FIRST

Before touching any local Excel or transcript, get current state. All paths + IDs come from the project's anchors file — DO NOT hardcode any one project's values here:

- **Slack canvas + channel** — read the deal's command-center canvas + last 5–10 days of channel for working context. Canvas ID + channel ID come from the project anchors file (or ask inline if no anchors file).
- **Outlook last 5–10 days** — filter by deal-relevant participants (counterparties, advisors, counsel, deal team). Participant list comes from the project anchors file's people roster. Use Graph API directly via `GraphAdapter` per `[[feedback-use-graph-api-directly]]`. Multi-pass: `participants:<name>`, `"<topic phrase>"`, `from:<sender>`.
- **Outlook calendar** — meetings in the next 30 days (DD sessions, mgmt calls, advisor calls).

If a stale local note disagrees with this-week's canvas + Outlook — **the canvas wins.**

### §3 — Read the source data files (Nobie MCP, cell-for-cell)

For every financial output the deck shows, go to the **source Excel** the prior deck was rendered from. Not the rendered HTML. Not the prior deck PDF. Not a narrative summary.

Pick the LATEST version on disk (`_v0`, `_v1`, ...) per `[[feedback-latest-artifact-version]]`. Source workbook list + canonical tab names come from the project anchors file. If no anchors file, ask the user inline which workbooks to read.

For each table that goes in the deck, write the actual numbers into the context MD with a `Source: <workbook>.xlsx / <tab>` line. So Pass 2 can drop the table in without re-reading the workbook.

Apply `[[feedback-excel-formatting-preservation]]` if any workbook needs to be modified (copy_from_range to stamp styles before overwriting values).

### §4 — Read transcripts + advisor notes FULLY; close open questions against the LATEST mgmt transcript

If a transcript is in scope, **read it fully** — or use Explore agent ("very thorough") to pull every quote on every load-bearing topic. Same for advisor notes — every advisor in scope gets their own block in the context MD: background (1–2 lines) + perspectives (3–6 bullets, verbatim where possible).

**Latest mgmt transcript is mandatory full-read.** Glob `08. Notes/02. With Management/` chronologically; the newest file gets a "very thorough" pass. Every entry in any draft open-questions list is judged answered / partially answered / open against that newest transcript.

Answered questions → migrate to "What we learned" or the relevant analytical page; do NOT leave as open. Partially answered → state what we know, then frame the residual question precisely. This is the v03 fix for stale open-question lists.

### §5 — Hallucination guardrail (HARD)

Person names, firm names, titles, source attributions are load-bearing for IC trust. A hallucinated firm name (e.g. "Brandon Dobel from Lincoln International" when he's at BGL) is the kind of error that, if Sam doesn't catch, lands in front of Adam.

**Rules:**
- For every external person mentioned, the context MD must include a `Source:` line citing where their firm + title comes from (file path + line, email subject, calendar event title). **No `Source:` line → not in the MD.**
- Never infer firm from training data, "what makes sense given context," or imaginary domains. If a domain like `@bgl.com` is actually visible in a corpus email signature, that's a corpus source. Inventing a domain is not.
- The project anchors file's people roster table lists known players' firms — but each MD entry must still cite a corpus source, not just point to the anchors list.
- If the corpus doesn't say the firm, **ASK the user in a single line** before writing: e.g. "I have <Person> as banker but don't see his firm in the corpus — can you confirm <Firm>?" Single line. Don't ship a guess.

See `[[feedback-no-hallucination-ask-instead]]`. For Bungalow specifically, `[[project-bungalow-people-roster]]` memory has the verified list (and the anchors file mirrors it). For other projects, the anchors file is the per-project equivalent.

### §6 — Right unit of analysis (decide BEFORE writing)

For each multi-entity slide, pick the entity as the row:
- Advisor slide → rows = advisor, cols = (Background, Perspectives)
- Tech / workflow slide → rows = workflow, cols = (Before / In-house vs 3P / Status with hard metrics)
- DD workstream slide → rows = workstream, cols = (Status / Next Milestone / Blockers) — NO internal-owner column
- M&A pipeline → rows = target

If tempted to group by *theme* across multiple entities, that's almost always wrong. Pick the entity as the row.

### §7 — Advisor-page composition (HARD)

The advisor page is **external operators actively advising us**. It does NOT include:
- Company management (CEO/CFO/Controller) — they're mgmt; not advisor page.
- Intro sources who declined to advise (e.g. Chris Laurence declined Sean's 4/22 ask).
- Counterparties (banker = banker mention elsewhere, not advisor framing).
- Counsel (Orrick, WSGR — counsel page or footnotes only).

To build the advisor list:
1. Glob the project's advisor notes folder (path from anchors file; for Bungalow: `08. Notes/03. Executive Advisors/`).
2. For each person, check: have they actively engaged? (signed engagement letter, multiple recurring calls, explicit "yes I'll advise")
3. Yes → advisor page. Declined or never confirmed → omit. Network/intro only → optionally a footnote, otherwise omit.

The project anchors file's people roster has the verified active-advisor list — use it. If no anchors file, build the list inline from the advisor notes folder + confirm with the user.

### §8 — Tech / operations workflow scope (HARD)

If the deck has a "what the company has built" or "tech/workflow" page, scope is **core-product / operations technology only** — NOT the company's internal back-office stack. Example for a PM-software company like Bungalow:
- **IN:** PMS integrations (AppFolio etc.), maintenance-triage automation, R&M coordinator workflow, leasing-ops automation, resident-services automation
- **OUT:** Internal ERP, GL, finance stack (e.g. QuickBooks → Campfire), bookkeeping vendors, HR systems

The IC is evaluating "does the company's tech improve unit economics on their core product?" — not "what's their accounting system?" Strip internal back-office rows.

Generalize: for any deal, the scope is the tech that drives the thesis (e.g. for a logistics company → routing + warehouse automation IN; their CRM OUT). The project anchors file should specify the IN/OUT boundary for that deal.

### §9 — Apply the IC audience register filter

Read the full strip list at `C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/audience-register-filter.md` and apply it silently to the MD as it's written.

Track what's stripped (counts + examples) for the return summary so Sam can spot-check at the MD-review gate.

### §10 — Cross-reference saved-down info with live email

When a local note says X and this week's Outlook thread says Y, the email wins. For every claim the MD will make, check: is there an Outlook thread or Slack message from the last 7 days that updates or contradicts this? See `[[feedback-emails-slack-multiple-passes]]` for multi-pass corpus search.

### §11 — Reuse existing outputs; don't recreate (fidelity)

If a prior artifact (Diligence Pack HTML, prior IC update deck) already has a finalized output (combined P&L, margin bridge, M&A pipeline table), the MD notes: `Source: <prior artifact>, Slide N — reproduce identically (rows = X, cols = Y); refresh values from <workbook>`. Pass 2 will reproduce it structurally identically.

If you think the prior output could be improved (e.g. "this would be cleaner rotated"), STOP — that's a Pass 2 redesign Sam didn't authorize. The MD instructs Pass 2 to reproduce, not redesign.

### §12 — Write the context MD

The MD's *structure* mirrors the skeleton; its *content* is entirely source-derived (per §0). A skeleton line "Management team background" means you write a Management section whose bios, backgrounds, and perspectives come from transcripts / advisor notes / emails — never from the skeleton text. Every bullet, table, and commentary line traces to a `Source:`.

Structure:

```
# IC Deck Context — <deal> <date>

## Deck spec
- Type: <update | vote>
- Cover date: <m/d/yyyy>
- Skeleton (user-approved):
  - Cover
  - Page 1 — Exec Summary
  - ... (etc.)
  - APPENDIX
  - A1, A2, A3

## Sources swept
- Slack canvas <ID> @ <timestamp>
- Outlook <date range>, participants: <list>
- Calendar <date range>
- Source workbooks: <list with versions>
- Transcripts: <list with line counts read; newest = full-read>
- Advisor notes: <list>
- Prior decks reused (for structure): <list>

## Audience-register filter applied — items stripped
- Internal owner columns: <count> (workstreams: ...)
- "Who asked" attributions: <count>
- Internal vendor mentions: <list>
- In-flight framing: <count>
- Internal quotes: <count>

## People mentioned (with corpus sources)
- Andrew Collins | Co-founder + CEO | Bungalow | Source: Glossary.md line 27
- Kash Mathur | Co-founder + CFO | Bungalow | Source: Glossary.md line 28
- Brandon Dobel | Banker | BGL | Source: 08. Notes/03. Executive Advisors/BGL-Banker-Brandon-Dobel-Bungalow-93d340a2-0f17.md (filename + 5/11 call transcript)
- ... (every external person in the deck)

## Per-slide content

### Page 1 — Exec Summary
**Header:** Exec Summary
**Subheader (punchline):** <single most important takeaway from the whole deck>

Where we are: <bullets — no internal owners, no in-flight framing>
What we've done: <bullets — strategic-shaped, no task-tracker tone>
Outstanding gating questions (top 3): <bullets>
Advisor read (strongest convergence + main callouts): <bullets>
Recommendation: <one sentence>

### Page 2 — DD Workplan & Status
**Header:** DD Workplan & Status
**Subheader:** <punchline>

| Workstream | Status | Next milestone | Notes |
|---|---|---|---|
| ... data, NO internal-owner column ... |

Source: canvas <ID> + Outlook 5/11-5/18

### Page N — financial / data slides (Combined P&L, margin bridge, etc.)
**Header / Subheader / [full table data — every cell, source-derived] / Source: <workbook>.xlsx / <tab> / Reuse instruction (reproduce identically if a prior output exists) / Same-page commentary / TBU callouts.**
(Fully filled worked examples of financial-slide blocks live in `references/pass1-checklist.md` → "Worked MD example.")

### ... etc for every slide (incl. APPENDIX divider + appendix slides — same block format)
```

Every slide block has: header, subheader (the punchline — single most important thing on the page), content with actual numbers + verbatim quotes, source line, reuse instructions if applicable, same-page commentary spec, TBU callouts if confounded.

**Exec summary block writes itself last** — once all other slide blocks are drafted, the exec summary is a synthesis of them.

### §13 — Update session-state and return

Write `_ic_deck_session_state.json` (or update existing) with:
- `phase: "pass1_complete"`
- `md_path: <output path>`
- `last_summary: <one-line summary>`

Return to caller a SINGLE message:

```
MD written to <path>.

Sources swept:
- <N> Slack canvas reads
- <N> Outlook threads (participants: <list>)
- <N> source workbooks (latest versions)
- <N> transcripts (newest 5/15 mgmt = full-read)
- <N> advisor notes

Audience-register filter applied — items stripped:
- Internal owner columns: <count>
- "Who asked" attributions: <count>
- Internal vendor mentions: <list>
- In-flight framing: <count>
- Internal quotes: <count>

Open questions resolved against 5/15 mgmt transcript: <N answered, M partially, K open>

People with corpus sources: <N> (all external persons cited)

Ambiguities surfaced to user for ASK: <none | list>

Next step: orchestrator presents MD to user for review at the MD approval gate.
```

This is the entire return value. Parent context grows by ~500 tokens, not 200K.

## Failure handling

- **Missing source.** If you can't find a source the skeleton implies (e.g. "Windermere standalone P&L" but no Windermere workbook in the folder), STOP and return: `"Missing source: <what's missing>. Need user input before continuing."` Don't fabricate.
- **Person without corpus source.** Per §5, ASK Sam in a single line. Single line. Don't ship a guess.
- **Stale local note vs. live email contradiction.** Live wins. Note the contradiction in the MD's "Sources swept" block.

## Related memories

- `[[feedback-ic-deck-audience-register]]` — strip list rationale
- `[[project-bungalow-people-roster]]` — verified people roster
- `[[feedback-no-hallucination-ask-instead]]` — ASK if corpus doesn't say
- `[[feedback-latest-artifact-version]]` — pick highest `_vN` on disk
- `[[feedback-use-graph-api-directly]]` — Outlook via Graph, not broken MCP
- `[[feedback-emails-slack-multiple-passes]]` — multi-pass corpus search
- `[[feedback-excel-formatting-preservation]]` — Nobie style preservation
- `[[feedback-verify-entity-names-no-acronym-inference]]` — no acronym expansion / domain inference
- `[[feedback-workstream-separation]]` — tag every item by deal before folding

## Related skills

- `[[draft-IC-Deck]]` — parent orchestrator (Phase B spawns this skill)
- `[[render-IC-Deck-html]]` — Pass 2 (reads the MD this skill produces)
- `[[updatebung]]` — keeps the Bungalow tracker canvas current (input to §2)
- `[[emaildraft]]` — same corpus-first philosophy
