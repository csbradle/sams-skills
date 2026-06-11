---
name: draft-IC-Deck
description: This skill should be used when the user asks to "draft an IC deck", "/draft-IC-Deck", "build the IC update", "build the IC deck", "build the 5.25 deck" (or any dated update deck), "draft the IC2 vote deck", or "rebuild the IC deck". Orchestrates a 3-phase IC deck build for an active TWC deal — confirms spec + skeleton with user (parent context, approval gate 1), spawns /build-IC-Deck-context (Pass 1) as an Agent-tool subagent with fresh context to sweep every source into a context MD, presents MD to user for redlines (parent context, approval gate 2), spawns /render-IC-Deck-html (Pass 2) as a separate Agent-tool subagent with fresh context that reads ONLY the MD to build a 16:9 HTML deck, then iterates on user redlines. Subagent isolation is a structural guarantee (not honor system) that Pass 2 cannot see Pass 1's source reads; parent context stays under ~25K tokens across the full build.
version: 1.0.0
user-invocable: true
---

# /draft-IC-Deck — Orchestrator for IC Deck Builds

## Purpose

Orchestrate the build of an IC update / vote deck for an active deal. Two approval gates stay in parent context (so the user sees what they're approving); two heavy phases (Pass 1 source sweep, Pass 2 HTML render) run as **fresh-context Agent-tool subagents** so the parent context stays clean and Pass 2's "clean head" rule is structurally enforced.

Audience for the deck: TWC IC (Adam, Sean, Meki, Grady, Sam). Tone: factual, dense-but-legible, source-anchored.

## When to use

- "/draft-IC-Deck", "draft the IC deck", "build the IC update deck"
- "build the [date] update deck", "build the 5.25 update", etc.
- "draft the IC2 vote deck", "draft the IC1 deck"
- Any time the user wants an IC artifact composed from deal-folder state

## Architecture

```
~/.claude/skills/
├── draft-IC-Deck/                       (THIS skill — orchestrator, stays in parent context)
│   ├── SKILL.md
│   ├── scripts/
│   │   └── lint_deck.ps1                (deterministic hygiene gate — gap-tags, slop, provenance; fail-closed)
│   └── references/
│       ├── anchors-template.md          (per-deal anchors template + REQUIRED-FIELDS GATE + bootstrap dialogue)
│       ├── <deal>-anchors.md            (POINTERS ONLY — real anchors live in vault / deal folder)
│       ├── verify-gate.md               (gate profiles, decision table, ALL Sam-facing message templates)
│       ├── slop-lint.md                 (banned-phrase list, read by lint_deck.ps1)
│       ├── audience-register-filter.md  (long strip list — loaded for MD review)
│       ├── v03-retro.md                 (why each rule exists)
│       └── session-state-schema.md
│
├── build-IC-Deck-context/               (Pass 1 — Agent subagent, fresh context)
│   ├── SKILL.md
│   └── references/pass1-checklist.md
│
└── render-IC-Deck-html/                 (Pass 2 — Agent subagent, fresh context)
    ├── SKILL.md
    └── references/page-templates.md
```

All three skills share the same memories (`feedback_ic_deck_audience_register.md`, `project_bungalow_people_roster.md`, `feedback_no_hallucination_ask_instead.md`, etc.) — memories load automatically into subagent context.

## Phase A — Spec confirmation (parent context, approval gate 1)

Ask the user once, before any spawn:

- **Which project / deal?** Required first answer. Glob `references/*-anchors.md` to enumerate deals (these are POINTER files — follow each to the real anchors file, which lives data-side per `references/anchors-template.md`). If the user picks an existing one, the slug is locked. **ANCHORS GATE (hard, field-based):** the build may proceed only when the anchors file exists AND passes the required-fields check in `anchors-template.md` (corpus mode + reachable root + ≥1 source-of-truth + ≥1 sourced roster row). No anchors, or fields missing → STOP and run the two-phase bootstrap dialogue from `anchors-template.md` (≤7 plain-English questions total across bootstrap + Phase A; agent corpus-sweep seeds the roster — never fabricate a Source line). There is NO "proceed without anchors" option — that is how the 6.15 Lonestar deck shipped unguarded. If the corpus root is unreachable on this machine, switch to the named degraded mode (verify-gate.md template T6), never a generic stop.
- **What IC artifact?** Interim update (framing-heavy, qualitative exec summ, DD status front-and-center) vs. final vote deck (DCM-pattern: punchline subtitle, table-heavy, paired opp + risk per slide). Different jobs.
- **What date is on the deck cover?** ("5/25/2026 IC Update")
- **What is the user-approved skeleton?** Bulleted slide list. If the user hasn't provided one, propose one based on the deck type + deal state, get sign-off. Don't invent slides the user didn't ask for.
- **What's the deal folder + IC subfolder?** Pull from the project's anchors file if it exists; otherwise ask explicitly.

Surface load-bearing ambiguity now — don't guess scope. **Never assume the project is Bungalow** — Sam runs multiple deals (Bungalow, WES, Pak/Lonestar, future deals) and the same deck-build skill serves all of them.

**Resume protocol:** Before asking anything, glob the working folder for `_ic_deck_session_state.json`. If found: print `last_summary`, ask "Resume from phase `<phase>` or start fresh?" If resume, jump to the phase after the saved one. If fresh, archive the old state file (rename to `_ic_deck_session_state.<timestamp>.json`) and proceed. Schema: `references/session-state-schema.md`.

On approval, write initial `_ic_deck_session_state.json` with `phase: "spec_approved"`, deck_spec, skeleton.

## Phase B — Spawn Pass 1 (fresh subagent context)

Use the Agent tool with `subagent_type: "general-purpose"`. Prompt template:

```
Invoke the /build-IC-Deck-context skill against this deck.

Deck spec (user-approved):
  project: <project-slug, e.g. bungalow | wes | pak | <other>>
  anchors file: <absolute path to references/<project-slug>-anchors.md, OR "none — ask inline">
  type: <update | vote>
  cover date: <m/d/yyyy>
  skeleton:
    - Cover
    - Page 1 — Exec Summary
    - ... etc
  deal folder: <absolute path>
  IC subfolder: <e.g. 03. IC Collateral/<MM.DD update>>
  output MD path: <deal-folder>/<IC subfolder>/_ic_deck_context_<YYYY-MM-DD>.md
  session-state path: <deal-folder>/<IC subfolder>/_ic_deck_session_state.json

When done: write the MD to the output path AND update session-state with
phase="pass1_complete", md_path, sources_swept counts, audience_filter_stripped list.

Return a single message: "MD written to <path>. Sources: <summary>. Filter stripped: <count>. Open questions resolved: <N/M/K>. Next step: orchestrator presents MD to user for review."
```

The subagent operates in its own fresh context window. Parent only receives the return summary (~500 tokens). All the transcript reads, Excel reads, Outlook + Slack reads that would otherwise consume 200K+ tokens stay in the subagent's context.

**On Pass 1 return:**
- If "Missing source: X" — re-spawn Pass 1 with the gap noted, or ask user to supply.
- If success — present return summary to user. Update parent state. Move to Phase C.

## Phase C — MD review (parent context, approval gate 2)

Read the context MD into parent context (this is the ~5K-token cost we pay for the approval gate). Present its structure to the user:

```
Pass 1 produced the context MD at <path>.

Sources swept: <summary from return>
Audience-register filter stripped: <summary>
Open questions resolved against latest mgmt transcript: <N answered, M partial, K open>

The MD covers <count> slides per the approved skeleton.

Review the MD — redline directly or call out changes here. When approved, I'll spawn Pass 2.
```

If user redlines:
- **Small redlines** (a punchline tweak, a missing bullet, a swapped quote) → edit the MD directly in parent context. Update state, then proceed to Phase D.
- **Large redlines** (missing source, wrong unit of analysis, whole new slide) → re-spawn Pass 1 with the redlines as additional instructions.
- **Audience-register concerns** ("I see internal owner names left in") → consult `references/audience-register-filter.md`, apply filter to the MD in-parent, then proceed.

On approval, update state: `phase: "md_approved"`.

## Phase D — Spawn Pass 2 (fresh subagent context)

Use the Agent tool with `subagent_type: "general-purpose"`. Prompt template:

```
Invoke the /render-IC-Deck-html skill against this deck.

Inputs:
  project: <project-slug>
  anchors file: <absolute path to references/<project-slug>-anchors.md, OR "none">
  context MD path: <path>/_ic_deck_context_<YYYY-MM-DD>.md  (READ THIS ONLY for content)
  prior deck HTML path: <path>/<prior version>.html         (for structural reuse only, NOT content)
  output HTML path: <path>/<project display name> IC Update — <m.d> v<NN>.html
  session-state path: <path>/_ic_deck_session_state.json

HARD CONSTRAINTS (per /render-IC-Deck-html SKILL.md):
  - Read ONLY the MD for content. No Excel, no transcripts, no Outlook, no Slack.
  - If you find data missing from the MD, STOP and return "MD GAP: <what's missing>" — do not fabricate.
  - Render in /browse at 1920×1080 and screenshot every page before reporting done.

When done: write HTML, screenshot every page to <output>-screenshots/, update
session-state with phase="pass2_complete", append html_versions entry.

Return: "HTML written to <path>. Screenshots at <dir>. Verification: <pass/fail per page>. Outstanding: <any issues>."
```

The subagent reads ONLY the MD + prior deck HTML. It cannot see the source data Pass 1 ingested — this is the structural guarantee that prevents Pass 2 from "knowing" things the MD doesn't say.

**On Pass 2 return:**
- If "MD GAP: X" — go back to Phase C, fix the MD, re-spawn Pass 2.
- If success — proceed to Phase D2 (mandatory). Do NOT present the deck to the user before D2 passes or its findings are escalated.

## Phase D2 — Deck check (MANDATORY before any "done"; gate behavior per `references/verify-gate.md`)

Every build runs this after Pass 2, every time. Stage-1 profile until the claims ledger ships (see verify-gate.md "Gate profiles").

1. **Lint (deterministic, fail-closed):**
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_deck.ps1 -DeckPath <deck.html> [-LedgerPath <ledger.json>] -UpdateHash`
   Exit 1 → blocking findings; exit 2 → the check itself failed — the deck is NOT confirmed (tell the user plainly, offer retry). Gap-tags always block; orphan numbers flag-only at stage1; slop flag-only.
2. **Fact check:** spawn `/update-deck-verify` (fresh Agent context) against the deck + the context MD as truth source. Map the deck `cover date` → ISO `presentation_date` in the spawn prompt (verify hard-errors without it — never guess). Stage-1 strength is lexical; say so in the handoff with verify-gate.md template T7 (the "a right number with a wrong label would NOT have been caught" sentence). For decks >15 slides, batch per verify-gate.md once Stage 2 lands.
3. **Gate + escalation:** route findings per the verify-gate.md decision table. Blocking findings auto-route to a fix re-spawn (max 2 loops); whatever remains is escalated to the user as a NUMBERED plain-English list using the T1–T8 templates — attestation ("it's my number") offered at every unsourced item, waivers accepted by number or description and logged per-finding. Vocabulary layer is hard: no internal nouns in anything the user sees.
4. **Honest done language (never "verified"):** the handoff stamp follows verify-gate.md — "N numbers checked against source text (M shown as TBU, 0 unchecked). Checked as of <date>; email sync last ran <N> days ago." plus the corpus-boundary line (T8) when pipeline freshness is degraded, plus waiver list if any. Emit one progress line per check batch; state expected wall-clock up front.

## Phase E — User review of HTML; iterate

Show the user:
- HTML path + screenshot directory
- Verification summary from Pass 2 return
- Any outstanding flags

Accept redlines for v02. Each iteration:
- **Cosmetic / structural redlines** (font size, color, page split) → re-spawn Pass 2 only. Same MD, new version number. **Layout-only fast path is the DEFAULT** (verify-gate.md): if the redline touches no claim-bearing text, skip the fact-check, run lint flag-only, stamp "layout-only revision — content checks unchanged from v<N>."
- **Content redlines** (different number on a slide, wrong commentary) → check the MD first. If the MD has the right content and Pass 2 misrendered, re-spawn Pass 2. If the MD is wrong, go back to Phase C, fix, then re-spawn Pass 2. Content-touching iterations re-run Phase D2 (incremental once Stage 2 lands; full at stage1).
- **Net-new sources** (Sam learned something new in a meeting) → go back to Phase B, re-spawn Pass 1 (with the new source noted), then Phase C, then Phase D, then D2.
- A number the user supplies directly is recorded as user-attested (verify-gate.md "Override + attestation") — distinct stamp line, never silently absorbed.

Update state after each iteration: `phase: "iterating"`, append to `html_versions[]`.

## Failure handling

- **Pass 1 returns "Missing source: X"** → ask user for the source path, then re-spawn with it.
- **Pass 1 ASK** (e.g. "I have Brandon Dobel as banker but don't see his firm in the corpus — confirm BGL?") → relay to user, get answer, re-spawn with the confirmation.
- **Pass 2 returns "MD GAP"** → never silently fix. Go back to Phase C, fix the MD, re-spawn Pass 2.
- **Pass 2 returns verification failures** (overflow, font too small, etc.) → re-spawn Pass 2 with the specific fixes; same MD.
- **Subagent crash / interrupt** → state file persists. Resume protocol (Phase A opening) picks up where you left off.

## What stays in parent context

- The deck spec + skeleton (small)
- The context MD content (~5K tokens, only during Phase C)
- The session-state JSON (tiny)
- Return summaries from each subagent (~500 tokens each)
- The orchestrator skill itself (~1.5K tokens of SKILL.md)

What does NOT stay in parent context: transcripts, Excel reads, Outlook search results, Slack channel reads, raw advisor notes. All of that lives only in the subagent contexts.

Target parent context total at end of full build: <25K tokens.

## Anchors (loaded as needed)

- **`references/<project-slug>-anchors.md`** — POINTER files (real anchors live data-side; see `anchors-template.md`). Glob `references/*-anchors.md` in Phase A to enumerate deals, then follow each pointer and run the required-fields gate.
  - Currently exists: `bungalow-anchors.md` (→ Bungalow deal folder), `lonestar-anchors.md` (→ brain vault).
  - New deals: the Phase A anchors gate triggers the bootstrap dialogue in `anchors-template.md`.
- **`references/audience-register-filter.md`** — long strip list applied during Phase C MD review. Project-agnostic (applies to all IC artifacts).
- **`references/v03-retro.md`** — historical context for why each rule exists. Project-agnostic (lessons generalize across decks).
- **`references/session-state-schema.md`** — JSON shape for `_ic_deck_session_state.json`. Project-agnostic.

## Project anchors file convention

Moved to `references/anchors-template.md` — template, required-fields gate, data-side residency rule (anchors hold deal data → they live in the vault or deal folder; `references/` holds only the template + per-deal pointer files), and the two-phase bootstrap dialogue. The old "Pass 1 asks inline when no anchors file exists" path is DELETED.

## Read this first (per task — minimal read set)

- **Drafting a deck:** this file → `anchors-template.md` (gate) → the deal's anchors file.
- **Rendering:** `render-IC-Deck-html/SKILL.md` → `page-templates.md`.
- **Checking / gating / user messages:** `references/verify-gate.md` (owns gate behavior + every Sam-facing template).
- **Authority on conflict:** scripts → claims-ledger.md (Stage 2) → verify-gate.md → SKILL.md.

## Related memories

- `[[feedback-ic-deck-audience-register]]` — what to strip from any IC-facing artifact
- `[[project-bungalow-people-roster]]` — verified Bungalow people roster (Andrew/Kash, Brandon=BGL, Chris=intro)
- `[[feedback-no-hallucination-ask-instead]]` — every external person needs a corpus `Source:` line; ASK if unsure
- `[[feedback-latest-artifact-version]]` — use highest `_vN` on disk
- `[[feedback-html-to-pdf]]` — HTML → PDF (post-approval)
- `[[feedback-adam-email-style]]` — if any IC slide gets repurposed for Adam updates
- `[[feedback-workstream-separation]]` — tag every item by deal before folding into Bungalow context

## Related skills

- `[[build-IC-Deck-context]]` — Pass 1 (Phase B spawns this)
- `[[render-IC-Deck-html]]` — Pass 2 (Phase D spawns this)
- `[[updatebung]]` — keeps the Bungalow tracker canvas current (input to Pass 1)
- `[[emaildraft]]` — same corpus-first philosophy
- `[[browse]]` — render + verify (Pass 2 uses)
- `[[html-to-pdf]]` — convert to PDF after approval
