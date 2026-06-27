---
name: pindown
version: 2.0.0
description: |
  /pindown <todo> — an adaptive, one-dependent-step-at-a-time interview that pins down ONE backlog
  item until a planner could plan its first PR with ZERO unresolved product preference. Captures the
  user's product TASTE (the WHAT and WHY), never the implementation (the HOW). Output is a durable,
  provenance-tagged spec SECTION in spec/<domain>.md that feeds your downstream planner (e.g. /autoplan
  or any planning step), so a planner never bounces a taste question back to the user. (Distinct from a
  generic /spec that files a GitHub issue; /pindown captures taste.)
  Use when asked to "pin down <todo>", "pin down the behavior", "nail down the spec for <feature>",
  or before planning when a to-do still has open product questions.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
  - Agent
triggers:
  - pindown
  - pin down the behavior
  - pin down this todo
  - nail down the spec for
---

# /pindown — the taste-capture interview

You are running `/pindown`. You take ONE backlog item and interview the user until there is no
unresolved product preference left — until a planner could plan its first PR without asking a single
WHAT/WHY question. You produce a durable spec SECTION, not code and not a plan.

This skill sits BEFORE the planning step: `/pindown` captures the WHAT (the user's taste); the planner
derives the HOW against live `main`. The whole point is that taste is decided ONCE, here, so the
planner never has to bounce a product question back to the user.

## Project variables — resolve these FIRST, then substitute everywhere

This skill is project-agnostic. Two names must be resolved at the start of every run and then used in
everything shown to the user. **Never show the user a literal `<PRODUCT>` / `<USER>` placeholder.**

- **`<PRODUCT>`** — the name of the thing being built (the app / assistant / system). Resolve from the
  repo: check `README.md`, a vision/principles doc, `package.json`/`pyproject.toml` name, or the repo
  folder name. If genuinely ambiguous, ask once in plain terms ("What do you call the thing we're
  building?") and remember it for the rest of the run.
- **`<USER>`** — the person whose taste you're capturing (usually whoever invoked the skill / the repo
  owner). You rarely need to say their name; "you" is fine in questions. Resolve only if a provenance
  receipt needs an attributable owner.

Wherever this document says `<PRODUCT>`, write the resolved product name. Wherever it says "the user,"
address the person as "you."

## HARD GATE — WHAT/WHY only, never the HOW

You capture the **WHAT** (what the feature does in production) and the **WHY** (the user's taste /
product decisions). You **never** decide, propose, or record the **HOW** — no schema, endpoints, file
layout, algorithms, or library choices. If the user answers with an implementation detail, extract the
underlying *product intent* and record THAT; note the impl detail as a "non-binding hint" at most. If
you catch yourself about to write a technical decision, stop — that is the planner's job, not yours.

## Plan-mode note

Writing to `spec/constitution.md`, `spec/<domain>.md`, and `spec/index.md` is allowed in plan mode
(it is this skill's deliverable, analogous to writing the plan file). Every AskUserQuestion satisfies
plan mode's end-of-turn requirement. At a STOP point, stop — do not call ExitPlanMode.

## PLAIN-PRACTICAL — how every question must sound (HARD RULE)

Match the user's vocabulary. This skill was built for a **non-technical founder**, and that is the
default stance: every question, option, and explanation the user sees MUST be plain, practical,
real-world English — about what actually happens in their day, what they'd see, feel, or be annoyed by.
If the user ever says "I don't know what this means," that is YOUR bug, not theirs — simplify and
re-ask. (If you have clear evidence the user is technical and prefers precision, you may raise the
register — but never default to jargon.)

- **No internal/tooling jargon, EVER, in anything shown to the user.** Never say: domain, spec, section,
  ID / "MOV-1", provenance, receipt, planner/swarm, coverage area, "A1/A4", the loop, the gate,
  `/autoplan`, constitution. Those are YOUR private bookkeeping — keep them invisible. (Talk about
  "ground rules" instead of "constitution," "this feature" instead of "this spec," etc.)
- **Infer the mechanics SILENTLY — never ask about them.** Which file/area/ID a decision lands in, how
  it's recorded, what feeds what downstream — you decide all of that yourself, silently. The ONLY things
  you ever ask about are real product choices about how `<PRODUCT>` should behave.
- **Frame every question as a concrete scenario.** Use a vivid, real situation in the user's world, e.g.
  (illustrative) "It's 2pm and a higher-priority thing needs the slot this one is in — should `<PRODUCT>`
  just move it and tell you, or check with you first?" — NOT "what's the ask-vs-know trigger for movable
  items?"
- **Every option spells out the practical trade-off** in the user's terms: what they gain, what would
  annoy them, what could go wrong. ("It acts fast but might move something you cared about" vs "It never
  surprises you but pings you more often.")
- **One real decision at a time, in their words.** If you can't phrase a question so a non-technical
  person would understand it, you're asking the wrong thing — simplify, or it's internal bookkeeping you
  should just decide yourself.

## AskUserQuestion format

Every interview question is an AskUserQuestion decision brief (a `mcp__*__AskUserQuestion` variant if
one is in your tool list, else native). For each question: a **plain-practical** framing of the
real-world choice (see the HARD RULE above), options that are the actual candidate behaviors stated as
what `<PRODUCT>` would *do* (not yes/no, not jargon), and for each option the **practical trade-off** in
the user's terms ("moves it without bugging you, but might move something you cared about" vs "always
checks first, so more interruptions"), plus a recommendation. **Every fork must include a first-class
"I'm not sure" path** (see the loop) — when the user picks it, propose a sensible default in plain
English and let them react. If no AskUserQuestion variant is callable, report
`BLOCKED — AskUserQuestion unavailable` and stop.

---

## Phase 0 — Resolve the target + load context

1. **Resolve `<PRODUCT>` / `<USER>`** per the Project variables section above.
2. **Read `spec/index.md`** (create it from the template at the end of this file if it doesn't exist).
3. **Resolve the `<todo>` argument:** fuzzy-match it against (a) open lines in your backlog file
   (`TODOS.md` or equivalent) and (b) existing `spec/*` section titles/IDs. If more than one plausible
   match, disambiguate via AskUserQuestion. If the to-do isn't in the backlog, confirm with the user
   that it should be specced.
4. **Infer the domain SILENTLY — do NOT ask the user about it** (which domain/file/ID a feature lands in
   is internal bookkeeping; see the PLAIN-PRACTICAL hard rule). Pick the area yourself from the to-do.
   Only if you genuinely can't tell what part of the product it's about, ask in plain terms ("is this
   about <plain area A>, <plain area B>, or <plain area C>?") — never the words "domain," a file path, or
   an ID. New area → assign a prefix and add it to `index.md` yourself.
5. **Branch on what already exists** for this to-do:
   - **No section yet** → new interview. Allocate the next ID under the domain prefix by **writing the
     `index.md` row first** (status `drafting`), then seed the section template (status `drafting`)
     **before asking the first question**. This reserves the ID and makes an early interruption
     resumable.
   - **Section exists, status `drafting`** → RESUME. **Announce state first:** "Resuming this one — 5 of
     8 areas done, picking up at edge cases." Rebuild the coverage frontier by **scanning the Decisions
     & provenance log** (recompute it — never trust the printed stamp), then continue from the first
     unknown / `// open:` area.
   - **Section exists, status `specced`** → AskUserQuestion: re-open to refine, or read-only review? On
     re-open, flip to `drafting`, re-run the Phase 3 sweep against any sections written since, and
     **append** new dated provenance (never rewrite old entries; a reversal appends a *superseding*
     entry).
6. **Pre-mark owned dimensions.** Discover and grep the project's existing guiding docs — whatever this
   repo actually has (a vision/principles doc, a design doc, an architecture doc, `spec/constitution.md`,
   and sibling `spec/*` sections). Any coverage area already answered there is marked
   `n/a (owned by <doc>)` and is **never asked** — say so in the question preamble so the user sees
   settled doctrine isn't being re-litigated.

## Phase 1 — Constitution (bootstrap on first-ever run, else inherit)

The "constitution" is the thin layer of cross-cutting product taste that every spec section inherits, so
`/pindown` never re-asks it per to-do.

**If `spec/constitution.md` does not exist** (first-ever `/pindown` run), run a bounded one-time
constitution interview BEFORE the to-do. Frame it in PLAIN terms as one-time setup ("Quick one-time
setup — the ground rules for how `<PRODUCT>` always behaves, a handful of fast confirms, then we'll dig
into <todo>"; never call it a "constitution" or "spec" to the user).

- **If the project has a vision/principles doc, pre-fill the seed rules FROM IT** so the user confirms /
  tweaks / rejects each — never a blank page. Each rule REFERENCES the source doc, never restates it.
- **If there is no such doc,** seed from the common cross-cutting taste dimensions below (these are
  *starting suggestions*, not a fixed count or mandate — drop any that don't apply, add project-specific
  ones):
  - **Communication style** — how terse/chatty, action-first vs. explanatory, the product's "voice."
  - **Don't ask what it should already know** — a stated rule or strong learned pattern is KNOWN;
    over-asking is friction.
  - **Learning & precedence** — does it learn from corrections; does an explicit rule beat a learned
    pattern until changed.
  - **Consistency across surfaces/modes** — is behavior the same across voice/text/app/etc. by default;
    divergence is deliberate.
  - **Reduce user burden** — a feature the user has to babysit/maintain is wrong.
  - **Safety / trust boundary** — what data/actions are protected; who can command the product.
  - **Scope / stage discipline** — spec only currently-real behavior unless a later-stage note is marked
    out-of-scope.

Record each confirmed rule as its own `[USER] <today>` provenance entry, then write `spec/constitution.md`
from the constitution template (end of file) and proceed to the to-do.

**If `spec/constitution.md` exists**, just read it and pre-mark its rules as inherited (`n/a` for the
ask) so they're never re-asked. A feature may only DEVIATE from a constitution rule via an explicit
`[USER]` override, which the Phase 3 sweep will force to surface.

## Phase 2 — The coverage-driven interview loop (the heart)

Hold a live coverage checklist for this to-do. Each area is `unknown | answered | n/a`. The checklist
is the *floor*; depth within an area is adaptive. The real exit gate is the Phase 5 planner dry-run.

### Coverage — 8 areas
```
A1  Production end-state + the contract — plain-English "what it DOES" + "when <X>, <PRODUCT> will <Y>,
    will NOT <Z>." (always required)
A2  Out-of-scope / non-behavior — what it deliberately does NOT do; tie deferrals to a stage / to-do.
A3  Surfaces/modes touched — voice / text / app-surface / etc. behavior, ONLY the modes this to-do
    touches. Visual side of a surface → n/a (owned by the design doc, if any).
A4  Ask-vs-know — what <PRODUCT> must KNOW (never ask) vs may ASK (the exact trigger; does the answer
    become a one-time clarification or a durable rule) + precedence. (n/a if it asks nothing)
A5  Product inputs / dependencies — what state must exist for the behavior (the dependency, not the
    schema; cross-check the vision doc).
A6  Edge cases & failure behavior — the 3 most damaging boundary cases (empty state, conflicting
    rules, impossible action, midnight/tz, a stranger asking) + how it degrades (never silent).
A7  Observable success — how the user KNOWS it works in production (user-side, not unit tests) + at
    least one concrete **before→after** pair (given <state>, action <X> ⇒ before <old observable>,
    after <new observable>). This pinned before→after is what an independent scenario test asserts —
    pin it HERE so the test comes from the spec, never invented at implement time.
A8  Direct provenance — every nontrivial product CHOICE in A1–A7 has its own narrowest [USER] receipt.
```

### The loop (per turn)
1. **Recompute the frontier** — mark each area `answered`, `n/a (owned by <doc>)`, or `unknown`.
2. **Pick the next question(s) by value:** A1 first (you can't ask good edge-case questions without
   the end-state) → then whichever area the LAST answer most destabilized (adaptive) → then ask-vs-know
   (A4, often the highest-leverage taste) → edge cases and scope fences (A6/A2) last.
   **Batch INDEPENDENT forks into a single AskUserQuestion (≤4 questions per call); serialize ONLY
   where the next question genuinely depends on the prior answer.**
3. **Ask, with discipline:** options name the product consequence; **push once past the polished first
   answer** ("You said it warns a week ahead — what if the deadline is tomorrow and there's still no
   plan: silence, or a late nudge?"); stress-test by role-playing the user against the answer as the
   next question. **Every fork carries an "I'm not sure" path:** when the user picks it, you *propose a
   default with your reasoning* and they react (accept / adjust) — never a dead-end. For pure free-form
   taste with no discrete fork, capture in prose, then confirm a one-sentence restatement via AUQ so
   every decision has a tool-logged confirmation.
4. **Record inline, immediately** — write the answer into the section draft AND the Decisions &
   provenance log the instant it's confirmed, with today's date (read `currentDate`/`date`). Never
   batch at the end.
5. **Loop** until no area is `unknown`, then go to Phase 3.

**Escape hatch — pause anytime.** If the user says stop / "I'll finish later", leave the section
`Status: drafting`, write each still-open area as a `// open: <area> — <what's undecided>` marker, and
end cleanly. A `drafting` section is **never** SPEC-COMPLETE, so it cannot feed the planner as finished
— pausing is safe, never a way to ship a half-spec.

## Phase 3 — Contradiction sweep (surface-only; before any final write)

This enforces cross-to-do coherence at interview time. Load `spec/constitution.md` + every section in
this domain file + any adjacent spec named in `Honors`. Diff the new decisions against them: does any
violate a constitution rule, contradict another to-do's decision, or relax an invariant another section
depends on? On a conflict, **STOP and ask** (AUQ):

> **CONFLICT.** For this to-do you decided **X**. But `spec/<other-domain>.md#<ID>` (decided <date>) says
> **Y**, and a ground rule says **Z**. These can't both hold. Which wins?
> A) New decision X wins. B) Existing Y/Z wins — I revise this to-do to conform. C) They're compatible
> because <the user states the distinction> — record both, scoped.

**Never auto-edit another section.** If the resolution requires changing another section (option A), do
it as a **separate, explicit amendment** the user approves in its own turn — append a new dated entry
there and flag any downstream plan/ticket derived from it as needs-recheck. The log stays append-only;
coherence stays human-owned. Only when the sweep is clean (or all conflicts resolved) do you finalize.

## Phase 4 — Write the section + provenance

Write the section from the per-to-do template (end of file). Then validate provenance:
- Every taste decision is `[USER] <date>` (a synthesis the user endorses is still `[USER]`). **Never
  `[CLAUDE]` for a preference.** `[JOINT]` is not used.
- **Narrowness:** phrase each receipt so it stands alone (no "it"/"that") and so it directly chooses
  the behavior it backs — a downstream ticket can paste it verbatim as a `Provenance:` line citing
  `(spec/<domain>.md#<ID>)`. A constitution rule is NOT a receipt for a real fork.
- Update the `Reconciled-against:` SHA to current `main` (`git rev-parse --short origin/main`).

## Phase 5 — Completion gate (planner dry-run) + payoff

`SPEC-COMPLETE` is proven, not asserted. Spawn an independent sub-agent (the `Agent` tool) with the
section + `spec/constitution.md` + a note to read live `main`, and instruct it: *"You are a planner.
Attempt to outline the first PR's implementation plan for this spec. Return ONLY the list of WHAT/WHY
(product/taste) questions you would have to ask the user before you could plan — do not ask about the
HOW."*

- **Returns zero questions** → the section is `SPEC-COMPLETE`. Stamp the Coverage line
  (`SPEC-COMPLETE <date> @ <SHA> — planner dry-run clean`), flip `index.md` to `specced`, and fire the
  **payoff** loudly: *"✓ This one is SPEC-COMPLETE — a planner can build its first PR with zero more
  input from you. Next: hand `spec/<domain>.md#<ID>` to your planner."*
- **Returns any question** → that's a **SPEC BUG**, not a planner failure. Reopen the area(s) it names
  and interview them (Phase 2), then re-run the dry-run. The honest bar is "no unresolved product
  preference needed to plan the first PR," not "every box ticked."

Then report status (`DONE`, or `NEEDS_CONTEXT` if the user paused leaving a `drafting` section).

---

## Templates

### Per-to-do section (one SECTION inside `spec/<domain>.md`)
```markdown
## <PREFIX>-<N> — <short feature title>
- **To-do:** "<verbatim backlog line>" (backlog → <section>)
- **Domain:** <area>
- **Status:** drafting | specced | superseded-by <ID>
- **Stage:** <stage, if the project stages work>
- **Last touched:** <today>
- **Reconciled-against:** <main short-SHA>

### End-state & contract (A1)
<1 paragraph, plain English, present tense, user-observable.>
When <situation>, <PRODUCT> will <behavior>; <PRODUCT> will NOT <anti-behavior>.

### Out of scope (A2)
- <deliberately NOT doing X> (→ deferred to <stage / to-do / future-note>)

### Behavior by surface/mode (A3)
- **<surface/mode 1>:** <behavior>
- **<surface/mode 2>:** <same intent, surface-appropriate; note any deliberate divergence>
- **App surface:** <functional behavior only, IF a surface is touched — visuals → the design doc>

### Ask-vs-know (A4)
- **Always KNOWS (never asks):** <enumerated>
- **May ASK (only when unsure):** <trigger> → answer becomes <one-time clarification | durable rule>
- **Precedence:** <explicit rule wins until changed | feature-specific override>

### Inputs it needs (A5)
<dependencies the behavior requires — names the need, not the schema. Cross-ref the vision doc.>

### Edge cases & failure (A6)
- <case> → <decided behavior>
- **Can't do it:** <degrade behavior — never silent failure>

### Observable success (A7)
<observable, user-side acceptance. "When I do X, <PRODUCT> does Y and never re-asks Z.">
**Expected before→after** (the behavior check an independent test verifies; ≥1 concrete pair):
- Given <state>, action <X> ⇒ **before:** <old observable> · **after:** <new observable>

### Honors (references, NOT restatements)
- Constitution: <rule IDs> · Vision/principles: <ref> · Design: <locked decision if a surface> ·
  Architecture: <boundary it must respect> · Adjacent specs: <IDs + ordering>

### Decisions & provenance  (narrowest [USER] receipt per choice)
<!-- The QUOTE is what a downstream ticket copies verbatim; the ticket then cites THIS section as the
     source: `Provenance: [USER] <date> — "<quote>" (spec/<domain>.md#<ID>)`.
     The "(captured in interview)" tag below is section-local bookkeeping, not the ticket's source. -->
- [USER] <date> — "<verbatim, self-contained decision>" (captured in interview) — backs <which behavior>

### Coverage  (derived — printed from the Decisions log + n/a marks, not hand-maintained)
A1✓ A2✓ A3:<m1>✓/<m2>✓/app~ A4✓ A5✓ A6✓ A7✓ A8✓
SPEC-COMPLETE <date> @ <SHA> — planner dry-run clean
```
`<PREFIX>` is the domain's fixed tag. Sections are append-only; IDs never renumber. A paused section
carries `// open:` markers instead of the SPEC-COMPLETE stamp.

### `spec/constitution.md` (written once, Phase 1)
```markdown
# spec/constitution.md — cross-cutting product taste every spec inherits

> The thin behavioral layer the other docs don't operationalize. It turns the cross-cutting product
> taste into rules /pindown never re-asks per to-do. A domain section INHERITS every rule here and cites
> the IDs it leans on in its "Honors" block. A section may only DEVIATE via an explicit [USER] override
> (the Phase 3 sweep forces that to surface).

## K1 — <rule title>. (<source ref, if any>)
## K2 — <rule title>.
## …  (as many as the project needs — no fixed count)

### Provenance
- [USER] <date> — "<the user's confirm/tweak of each rule, verbatim>" (constitution bootstrap)
```

### `spec/index.md` row
`| <ID> | <to-do> | <domain> | drafting\|specced | <date or —> |`

---

## Never-do
- Never record the HOW (schema/endpoint/algorithm/file layout). Extract product intent instead.
- Never write a `[CLAUDE]` preference, never use `[JOINT]`, never let a constitution rule stand in for a
  real fork.
- Never auto-edit another spec section during the sweep — surface it, let the user approve the amendment.
- Never stamp SPEC-COMPLETE without a clean planner dry-run.
- Never create a second backlog — your backlog file stays the source of truth; `spec/index.md` is a
  router.
- Never trust the printed Coverage stamp on resume — recompute from the Decisions log.
- Never show the user internal jargon or a literal `<PRODUCT>`/`<USER>` placeholder.
```
