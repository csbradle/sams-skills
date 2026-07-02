---
name: onboard-deal
description: This skill should be used when the user asks to "onboard a deal", "/onboard-deal", "onboard <deal> as a new project", "set up a new deal in the brain", "catch up <deal>" / "finish onboarding <deal>" (half-onboarded or stale deals), "resume onboarding", "onboarding status for <deal>", or points at a group of deal files + an Outlook folder and wants the brain populated. v2 — ONE resumable command for brand-new deals AND catch-up of existing ones: 8 checkpointed stages spanning multiple sittings; entry status is machine-probed via `brain-kit project scorecard` (probes authoritative, state file a hint); resume grammar continue/jump/redo/skip/status; heavy stages (files, emails, enrich) run as fresh-context subagents; never reports "onboarded" unless Stage-8 live probes pass in-session. Zero deal data in committed files.
version: 2.0.0
user-invocable: true
---

# /onboard-deal v2 — probe-driven per-deal onboarding orchestrator

## How this works (read first)

Desired-state reconciliation, Terraform-style: the target state is "a fully onboarded deal"
(8 stages below); the ACTUAL state is measured by `brain-kit project scorecard <slug> --json`
(machine probes over the vault + index — authoritative); the state file at
`C:\brain\vault\Meta\onboarding\<slug>-state.json` holds interview answers + stage checkpoints
(a hint, never trusted over probes). Every invoke: probe → reconcile → print an honest
one-screen status → continue/jump/redo. A brand-new deal and a stale half-onboarded deal are
the same flow — catch-up is just "probes say thin/missing → those stages run."
Spec: `docs/design/samb-onboarding-skill-redesign-spec-2026-07-02.md`; plan (review record inside):
`docs/design/samb-onboard-deal-v2-plan-2026-07-02.md` (both in the My Brain repo).

## Version handshake

- Requires **brain-kit ≥ 0.8.0** (`project scorecard`, `deal-update enroll/resolve-folder`,
  `graph enroll-folder`, `file redistill/set-visibility`, `lonestar bootstrap --slug`).
- argparse `invalid choice: 'scorecard'` is a KNOWN state, not a mystery: "brain-kit on this
  machine predates the scorecard — `cd brain-kit && git pull && pip install -e .`, then re-invoke."
- Scorecard JSON `schema_version` major > **1** → render every probe `unknown` + tell the user
  this skill needs updating. Exit code 3 = same class (schema/version mismatch).
- Run every `brain-kit` command with `PYTHONUTF8=1` (two cp1252 console-crash precedents).

## Hard rules

1. **Probes over prose.** Every status claim ("wired", "enriched", "onboarded") is a machine
   probe printed verbatim — never LLM self-report. The words **"onboarded" / "ready" may only
   appear after the Stage-8 live probes pass in the CURRENT session.** A skipped stage is a
   named gap forever, never silence.
2. **Zero deal data in these committed files.** CONTEXT_MASTER.md, state files, and all deal
   specifics live in the local working dir / vault. Never `git add` vault content.
3. **Ask freely, bundled.** This is the sanctioned interview surface (the ≤3/day cap governs
   the nightly pipeline only) — but at most TWO themed bundles per framing round, and never
   ask what a probe / the corpus / 60s of web research can answer (self-verify first).
4. **Existence-check before every create; enrich, never duplicate. No TODO placeholders** —
   infer `sam_take`/lens/persona fields at write time from corpus + answers + web.
5. **Merge-not-replace on `Projects/<slug>/index.md` frontmatter**, diff shown before every
   write. brain-kit ≥0.7.0 union-preserves non-bootstrap keys on re-apply (C1 fix), but the
   skill still never regenerates a block it doesn't own.
6. **LLM-$ and config writes are dry-run first**: `file redistill`, `xlsx ground`,
   `set-visibility`, `deal-update enroll`, `graph enroll-folder` all default to dry-run —
   show the count/cost/diff, get approval, then `--apply`.
7. **Never call `brain-kit onboard`** — that is the colleague-seat setup tool, unrelated.
8. **Plain English to the user** (rendering table below). Stage numbers, piece keys, and CLI
   names are for this orchestrator and the state file; the user sees what each thing means.
   Raw scorecard table available on request.

## Entry protocol (EVERY invoke — status before questions)

1. **Resolve the deal**: `PYTHONUTF8=1 brain-kit project scorecard <name-or-slug> --json`
   (it alias-resolves and fuzzy-suggests). Exit 2 → print the env/config error + fix, stop.
   Exit 3 / invalid-choice → version handshake above.
2. **Cold start** (`"status": "new"`): no project exists. Present the candidate list (typo
   guard); if genuinely new, propose a slug (lowercase, `[a-z0-9_-]`, ≥3 chars, not a
   substring of another deal) and fold confirmation into the Stage-1 question bundle.
3. **Legacy state migration** (one-time): glob the working dir for `_onboard_deal_state.json`.
   If found: back it up, import its answer-of-record fields (file_group_dir, outlook_folder,
   aliases, flagged_threads, sweep_days) into the v2 state file, rename the old file
   `*.migrated`, and say so in the status line.
4. **Load state** `C:\brain\vault\Meta\onboarding\<slug>-state.json` (create the dir if
   missing; schema in `references/session-state-schema.md`). **Session guard**: if another
   `session_id` marked a stage `in_progress` with `touched_at` < 2h ago, WARN and ask before
   proceeding — never silently double-run.
5. **Reconcile** (probes win):
   | State says | Probes say | Verdict |
   |---|---|---|
   | done | ok | done |
   | done | thin/missing/blocked | **downgraded** — offer `redo` |
   | pending/absent | ok | `done (pre-existing)` — never re-run, never re-ask |
   | skipped/deferred | anything | named deferral (render it; `accepted_gaps` render "accepted (user, date)") |
   | anything | unknown | index stale or auth expired — run the probe's `fix` first |
6. **Print the one-screen status** (plain-English rendering below) BEFORE asking anything.
7. **Await the verb** (map the user's plain English onto it; record the verb in the state file):
   - `continue` — next unfinished stage (default; "keep going", "resume", bare re-invoke)
   - `jump stage-N` — go there; if prerequisites unmet, print the named dependency, don't fail mid-interview
   - `redo stage-N` — invalidate that stage's checkpoint, re-probe, re-run ("redo the emails")
   - `skip stage-N --reason "…"` — persistent named deferral ("skip the numbers for now")
   - `status` — print the status screen and stop ("where are we on X?")

## The 8 stages

Full per-stage mechanics: `references/stage-playbooks.md` (read the relevant section before
running a stage; heavy-stage subagents are pointed at it too).

| # | Stage | Runs in | Gate check | Redo behavior |
|---|---|---|---|---|
| 1 | **Frame** — bundles → CONTEXT_MASTER → bootstrap `--slug` → apply → post-apply blocks (deal_type, milestones/timeline, cap-table pointer) → reindex → scheduler restart | parent | `scorecard --gate stage-1` + live `get_project(alias)` returns the 4-part status | safe-idempotent (re-apply union-preserves); re-asks only unanswered |
| 2 | **Wire boards + ENROLL** — `deal_update:` + `outlook_folders:` blocks; `deal-update enroll` + `graph enroll-folder` (config enrolls — frontmatter alone goes silently stale); rebuild board; offer install-task | parent | `scorecard --gate stage-2` | safe-idempotent (set-semantics enroll) |
| 3 | **File corpus** — drop-zone guard + `ingest plan` cost gate → subagent ingests (recent-first, LATEST versions only, never Archive/superseded) → parent routes + visibility sweep | **subagent: files** | files piece; zero UNEXPLAINED `personal` | resumes from processed-cursor; no re-billing |
| 4 | **File metadata + XLS funnel** — `xlsx worklist` → folder-level grounding (`xlsx ground`) → residual per-file questions → `xlsx extract` key models → tag UW (`file set-doc-role` + `project mark-canonical-underwrite`) | **subagent: files** (gates in parent) | xlsx + underwrite pieces; exactly ONE live canonical UW; blocked = named re-drop list | safe-idempotent (ground is byte-identical re-stamp) |
| 5 | **Financial scorecard** — interview + Nobie workbook read → author `financial_sources:` → loop `financial validate-map` to exit 0 → `capture` → full reindex | parent | financials piece; live `performance_vs_plan` returns real facts | re-asks the map; capture is conflict-aware |
| 6 | **Email history** — `graph backfill --folder` dry-run → tally gate → live, 2–3 passes recent-first → important-thread questions → `sam_take`/lens backfill → `_inbox` re-route | **subagent: emails** (gates in parent) | emails piece + `index coverage` honest | resumes (window pull, message-id dedup, cursor untouched) |
| 7 | **Enrichment + graph** — `file redistill` (dry-run cost → apply; IS the catch-up path); personas/opinions/Decisions/progress (existence-checked); `index rebuild --connectors-llm` + `connectors retry-pending` | **subagent: enrich** (spot-check in parent) | enrichment + entities pieces; graph edges reported as COUNTS + spot-check sample, never quality-green | redistill skips already-enriched unless `--all` |
| 8 | **Verify** — reindex + **Claude Desktop restart** (MCP reads a sqlite snapshot) → live decision-usefulness probes → final scorecard → close out docs | parent | `scorecard --gate stage-8` + ALL live probes below | always safe |

**Stage-8 live probes (A1 — decision-usefulness, not retrieval checks):** `get_project(alias)`
answers the 4-part deal status; "current thesis + top 3 risks, cited"; "what changed in the
last 30 days"; `performance_vs_plan` returns real facts (or the financials deferral is named);
`rank_project_files_for_question` returns the UW model for an underwriting question;
`get_deal_update` returns a fresh board. A failing probe distinguishes "stale serve snapshot"
(restart Desktop) from "data missing" (a real gap — name it).

**Deal-type routing:** portco → all stages incl. 5 + monthly-financials contact question;
buyside live → full set; sellside / watching → Stage 5 `n/a-by-type` (named, not a gap).
A zero-corpus watching deal renders "0 files (none provided)" as n/a, not failure.

## Subagent protocol (T1: exactly these three)

Heavy stages spawn ONE fresh-context `general-purpose` Agent each — **files** (stages 3+4),
**emails** (stage 6), **enrich** (stage 7). The prompt must include: the slug, the absolute
path to this skill's `references/stage-playbooks.md` + which section to read, the answer-of-
record fields it needs from the state file, and the instruction to **return structured
results** (routed/unassigned doc_ids, tallies, blocked lists, question candidates) — subagents
NEVER ask the user questions and NEVER write state; all gates + state writes stay in the
parent. Subagent CLI runs also use `PYTHONUTF8=1`.

## State discipline

After each stage (and each gate decision): write the state file — per-stage
`{status, completed_at, probe_summary}` where `probe_summary` is the FULL scorecard pieces
JSON at completion time (so "why did stage 4 read done 3 weeks ago" is reconstructable),
plus the answer-of-record fields and the verb log. Schema + field-by-field
probe-rebuildable-vs-must-persist annotations: `references/session-state-schema.md`.

## Plain-English rendering (status line for the user)

Bold one-line takeaway first ("**<Deal> is about 60% onboarded — files searchable, email
history loaded; the numbers scorecard and live board aren't wired yet.**"), then one line per
piece. Never say "Stage 6 thin" or piece keys; use the probe's counts:

| Piece | ok reads | thin/missing/blocked reads |
|---|---|---|
| frame | "deal framed (aliases, type, timeline set)" | "set up but missing its timeline/deal-type — quick Stage-1 fix" |
| files | "files loaded + searchable (N)" | "N files not yet searchable / N still marked private (list on request)" |
| enrichment | "file summaries enriched (N of M)" | "only N of M files have real summaries — catch-up pass available (~$X)" |
| xlsx | "spreadsheets readable (N of M)" | "N spreadsheets BLOCKED — need their source files re-dropped (list follows)" |
| underwrite | "underwriting model pinned" | "N candidate underwriting models — needs one pick" |
| financials | "budget-vs-actual scorecard wired" | "numbers scorecard not set up" / "deferred (user, date)" |
| board | "live deal board refreshing every 3h" | "no live board — deal-status answers will go stale" |
| mail_folders | "deal mail folder enrolled + swept" | "deal mail is NOT flowing in — new email won't reach the brain" |
| emails | "email history loaded (N notes)" | "email history partial (N loaded) — finishes next sitting" |
| graph_edges | "document links built (N edges — quality not asserted)" | "no document links yet" |
| entities | "people + opinions filled" | "people/opinions thin" |
| index | "search index fresh" | "search index STALE — status unknown until rebuild" |

Every non-ok line ends with what fixes it (from the probe's `fix` field), in plain words.

## Completion

Stage 8 green → say what passed (probe by probe), update `docs/design/TODOS.md` (the deal's
backlog anchors) + `progress.md`, save corrections to memory. If anything is deferred, the
final line names it. Then — and only then — the deal may be called onboarded.
