# Stage playbooks — /onboard-deal v2

Per-stage mechanics. The orchestrator reads the relevant section before running a stage;
files/emails/enrich subagents are pointed at their section by absolute path. Every `brain-kit`
invocation: `PYTHONUTF8=1`. Vault: resolve from brain-kit config (live vault `C:\brain\vault`).
Zero deal data in this file — deal specifics come from the user + state file at run time.

---

## Stage 1 — Frame the deal (parent)

**Bar: the 4-part deal-status answer (deal / stage / workstreams / timeline) works after this sitting.**

1. **Homework first (self-verify before asking):** read memories (`project_<codename>*`, `org_*`,
   `feedback_research_new_entities`); check the vault footprint (`Organizations/<deal>.md`, an
   existing `Projects/<slug>/`, prior mentions); ~60s web research per named party; scan file-group
   filenames/folders for parties, dates, doc types. Pre-fill everything answerable; present
   pre-filled items as confirmations, not questions.
2. **Ask — at most TWO themed bundles** (`references/question-bank.md`):
   Bundle 1 = identity (deal in a sentence, stage, structure, **deal type**), parties & sides,
   key people, codename + aliases, Outlook folder(s), file-group location + provenance.
   Bundle 2 = deal history/timeline (dated financing/M&A events with orgs + roles), cap-table
   authoritative doc, workstreams, **the underwriting case** (which exact file/version), **the
   canonical cash source** (portco/held deals), financial-sources locations (feeds Stage 5).
3. **Author `<DEAL>-CONTEXT_MASTER.md`** in the local working dir (never committed) per
   `references/context-master-template.md` — including the `## Codename & Aliases` section
   (parsed since v0.7.0; no JSON patching, no hand-alias step). Show it for redlines.
4. **Scaffold:**
   ```
   brain-kit lonestar bootstrap <DEAL>-CONTEXT_MASTER.md --slug <slug> > <slug>-bootstrap.json
   brain-kit lonestar apply <slug>-bootstrap.json --vault-path C:\brain\vault --dry-run
   ```
   Show the dry-run diff → approval → re-run live. Aliases + deal_unique_aliases now propagate
   through apply automatically; verify they landed in `Projects/<slug>/index.md`. Alias rules:
   ≥3 chars, not a substring of another deal's names (matcher is case-insensitive substring).
   Re-apply is safe: since v0.7.0 the rewrite path union-preserves every frontmatter key the
   bootstrap payload doesn't own (deal_update, financial_sources, outlook_folders, status,
   milestones, pins) — but still diff before every write.
5. **Post-apply skill-authored blocks** (bootstrap does NOT own these — author as
   merge-not-replace frontmatter/body edits with a diff shown):
   - `deal_type: <buyside | sellside | portco | watching>`
   - `milestones:` — dated events from the history bundle. Kinds include
     `tuck_in_close`, `rescue_financing`, `equity_round`, `recapitalization` (+ the standard
     kinds). Topology rule: tuck-ins/refis/rescues live INSIDE the platform project as dated
     milestones; a transaction gets its own project only if run as a full separate deal process.
   - `## Deal timeline` body section — the same events as prose, plus a **cap-table line**:
     pointer to the authoritative cap-table doc + one-line summary. NEVER a maintained ledger.
6. `brain-kit index rebuild` (aliases take effect at the index).
7. **Scheduler restart** (alias cache is process-lifetime): kill the running
   `brain_kit … start` scheduler process if one is live (the scheduled task relaunches next
   tick) — execute this yourself where possible; otherwise print the breadcrumb. Until restart,
   NEW mail/files route without the new aliases.
8. **Gate:** `brain-kit project scorecard <slug> --gate stage-1` AND a live
   `mcp__brain-kit__get_project("<alias>")` returning the 4-part status from vault content.

## Stage 2 — Wire boards + ENROLL (parent)

**Frontmatter REGISTERS; config.toml ENROLLS. Both, or the board/corpus silently go stale.**

1. **Resolve the folder:** `brain-kit deal-update resolve-folder "<folder name>"` — returns
   candidates with stable IDs + parent paths. >1 match → show the list, ask; never guess.
   Graph 401 → named reauth breadcrumb, stop the stage.
2. **Author frontmatter** (merge-not-replace, diff first) on `Projects/<slug>/index.md`:
   - `deal_update:` block — `outlook_folder`, `outlook_folder_id` (from resolve), `workstreams:`
     (from Bundle 2; portco workstreams are bespoke — confirm with the user).
   - `outlook_folders:` list — the deal folder(s) for coverage tracking.
3. **Enroll (both; dry-run diff → approval → `--apply`; idempotent set-semantics; `--remove` reverses):**
   ```
   brain-kit deal-update enroll <slug> --apply          # 3h board-rebuild task picks the deal up
   brain-kit graph enroll-folder "<name>" --id <folder_id> --apply   # live mail sweep
   ```
   If the user vetoes folder enrollment, record a standing named gap ("live sweep: NOT
   enrolled") — silence is the only wrong option.
4. **Build the board:** `brain-kit deal-update rebuild --project <slug>` (the `--dry-run` print
   path needs PYTHONUTF8=1). Then `brain-kit deal-update status`. If no scheduled task exists on
   this machine, offer `brain-kit deal-update install-task` (logged-on-only, no admin needed).
5. `brain-kit index coverage --project <slug>` — print the honest coverage line verbatim.
6. **Gate:** `brain-kit project scorecard <slug> --gate stage-2`.

## Stage 3 — File corpus (SUBAGENT: files; guard + cost gate + routing gates in PARENT)

**Recent-first. LATEST versions only — never `Archive/`/`Old/` subfolders or superseded copies.**

**Parent, BEFORE spawning — drop-zone backlog guard (unchanged from v1, it saved real money):**
`brain-kit ingest <file>` is NOT a direct parse — it stages into the SHARED `C:\brain\drop-zone`
and each tick drains ~20–25 files FIFO, so a per-file loop drains the WHOLE firm backlog first
(LlamaParse bills on every out-of-scope file; hit live 2026-06-20 with a ~900-file backlog).
Check: `ls C:\brain\drop-zone | wc -l` (depth), its composition (mostly this deal's files or
not?), and whether a scheduler is draining it
(`Get-CimInstance Win32_Process | Where CommandLine -match 'brain_kit.*(start|ingest)'`).
Large shared backlog → do NOT loop; options: (a) defer bulk ingest and continue with staged
`_inbox` pointers, (b) knowingly drain (only if small/in-scope), (c) isolate — risky on shared
infra. Progress = `Meta/files-processed.jsonl` line count (the billed-parse counter); pointer
`canonical_url` holds the drop-zone path, so grepping source-folder names measures nothing.
Halt a runaway loop by killing the bash-loop trees AND their `brain-kit.exe` children (the MCP
server is a separate `python.exe` — leave it).

**Parent — cost gate:** `brain-kit ingest plan <file-group-dir>` → show pages + estimated cost
→ approval. Order the staging newest-first so the deal is usable if the sitting ends early.

**Subagent (files):** run the ingest; existence-check skips already-ingested files (no
re-billing — the processed cursor handles resume). Return structured: routed doc_ids,
`_unassigned`/low-confidence doc_ids with candidates, parse failures.

**Parent — routing gate:** for each unassigned/low-confidence file, ask (offer candidates), then:
```
brain-kit file reclassify <doc_id> --project <slug>
brain-kit file accept <doc_id>          # reclassify alone leaves it unindexed
```

**Parent — visibility sweep:** `brain-kit file set-visibility --project <slug>` (dry-run) →
review → `--apply` (snapshot-first built in). Gate bar: zero UNEXPLAINED `personal` — each
remaining `personal` pointer individually justified (lock-derived, enumerated).

**Gate:** `brain-kit project scorecard <slug> --gate stage-3`; residue named.

## Stage 4 — File metadata + XLS funnel (SUBAGENT: files; questions in PARENT)

1. `brain-kit xlsx worklist --project <slug> --json` (add `--key-only` for the key-file cut).
2. **Pass 1 — folder-level grounding:** group the worklist by source folder; for each folder ask
   ONE source/bias/lens block (who produced these, what angle, which deal phase) — auto-fill
   from known folder/sender context, show assumptions. Then
   `brain-kit xlsx ground --project <slug>` (dry-run) → `--apply` (idempotent, byte-identical
   re-stamp; writes CONTEXT.md + cascade-stamps `document_context`).
3. **Pass 2 — residual per-file questions** only where Pass 1 couldn't place a file.
4. **Extract key models:** `brain-kit xlsx extract <doc_id>` per key workbook. A missing source
   binary is reported `blocked` with the re-drop breadcrumb (file + canonical_url + drop-zone
   path) — report the blocked list honestly, never skip silently. Named-range workbooks that
   need a live-Excel read (Nobie `xlsx enrich`) → flag for a live session.
5. **Tag the underwriting case** (from Bundle 2):
   ```
   brain-kit file set-doc-role <doc_id> underwrite_case
   brain-kit project mark-canonical-underwrite <slug> <doc_id>
   ```
   The Stage-4 gate requires EXACTLY ONE live canonical UW doc — supersede or pin ambiguity away.
   Also tag the recurring cash forecast pointers `doc_role: cash_flow_forecast` (canonical cash
   view — never a valuation memo's forward rows).
6. **Gate:** `brain-kit project scorecard <slug> --gate stage-4`; worklist deltas quoted.

## Stage 5 — Financial scorecard (parent; SKIPPABLE — a named deferral forever, never silence)

Deal-type: portco + buyside live → run; sellside/watching → `n/a-by-type`.

1. From Bundle 2 + the tagged UW model: identify the underwrite / budget / actuals workbooks.
2. **Read the workbook(s) via Nobie** (`list_sheets` first, then `read_sheet` on the summary
   tab) to find the exact tab names, label column, header row, and the ~8 summary lines
   (Revenue / Gross Profit / EBITDA / cash lines).
3. **Author `financial_sources:`** on `Projects/<slug>/index.md` per
   `docs/design/financial-sources-frontmatter-spec.md` (My Brain repo): per-source `doc_id`,
   `workbook`, `tabs[].sheet/header_row/label_col/rows/columns` with EXPLICIT
   scenario/grain/period per column. An actuals source without a stable map registers
   sender/folder/cadence as a human-capture reminder instead. Merge-not-replace, diff first.
4. **Validate to green:** loop `brain-kit financial validate-map --project <slug>` until exit 0
   — nonzero means workbook-missing / sheet-renamed / cell-unreadable (typed; fix the map);
   a valid partial registration exits 0.
5. `brain-kit financial capture --project <slug>` → `brain-kit index rebuild --full`.
6. **Gate:** scorecard financials piece + a live `mcp__brain-kit__performance_vs_plan` call
   returning real numbers (restart-to-see semantics apply — if the MCP snapshot is stale, note
   it and re-verify at Stage 8). Skipped → state `skipped` + reason; renders as a named gap.

## Stage 6 — Email history (SUBAGENT: emails; tally + thread gates in PARENT)

**Everything-staged, recent-first: sweep ALL threads, newest window first; deep history drains
in later sittings.**

1. **Subagent — dry-run:** `brain-kit graph backfill --days <N> --folder "<name>" --dry-run`
   (PYTHONUTF8=1 mandatory — the staging print crashes on cp1252). Return the kept/rejected
   tally + thread list. Safe alongside the live scheduler: `backfill_folder` is a read-only
   window pull that never touches `graph-cursor.json` and dedups by message id.
2. **Parent — tally gate:** show tally + cost/scope; choose the window (recent pass first;
   older passes in later sittings). Approval → subagent runs live (drop `--dry-run`),
   2–3 passes (sweep / downstream replies / spot-check). Notes land in `Projects/<slug>/emails/`.
   ⚠️ The note writer overwrites unconditionally — on a CATCH-UP deal whose notes were already
   cleaned, use gap-only windows (last_swept → today), never a wide re-sweep.
3. **Parent — conversation gate:** list the top threads; ask which are the important
   conversations + the user's read → backfill `sam_take`/`lens` richly on those notes (no
   TODO placeholders). Surface `_inbox`/low-confidence emails → re-route per answers.
4. **Gate:** `brain-kit project scorecard <slug> --gate stage-6` + `index coverage` line.

## Stage 7 — Enrichment + graph (SUBAGENT: enrich; spot-check in PARENT)

1. **Redistill thin pointers — the catch-up workhorse:**
   `brain-kit file redistill --project <slug>` (dry-run prints count + cost) → parent approves
   → `--apply` (add `--include-xlsx` for headless xlsx hubs; `--limit N` to validate first).
   Preserves identity/visibility/below-boundary hand edits; skips enriched unless `--all`.
2. **Relational layer** (existence-check EVERYTHING; enrich, never duplicate):
   - **People personas** — role, tone, relationship, history. NO unshareable content (assume
     each person reads their own file): no promotion-advocacy, performance judgments, health.
   - **Deal opinions** → `Projects/<slug>/opinions.md` body.
   - **Decisions** (`Decisions/*.md`) surfaced by the corpus — materiality-gated, not activity noise.
   - **Progress narrative** → `Projects/<slug>/progress.md` — sourced from the corpus/board,
     never fabricated history.
3. **Graph edges (per the user's standing 6/22 directive):**
   `brain-kit index rebuild --connectors-llm` (budget-gated) + `brain-kit connectors
   retry-pending`. Report edge/mention COUNTS as facts + a spot-check sample (open 2–3 edges,
   say what they connect) — NEVER color the graph "good" on existence alone (~30% recall known).
4. **Parent spot-check:** show 2–3 personas + opinions + the progress narrative; corrections
   apply same-turn.
5. **Gate:** `brain-kit project scorecard <slug> --gate stage-7`.

## Stage 8 — Verify (parent; live-fire)

1. **Preamble:** `brain-kit index rebuild`, then **restart Claude Desktop** (the MCP serve
   process reads a sqlite snapshot — without a restart, live probes can fail on STALE data
   that is actually fine). Distinguish explicitly: "stale serve snapshot" (restart, retry)
   vs "data missing" (a real gap — name it).
2. **Live decision-usefulness probes** (ALL must pass, in the current session):
   - `get_project("<alias>")` → the 4-part deal status (deal / stage / workstreams / timeline).
   - "What's the current thesis + top 3 risks?" → cited answer from the corpus.
   - "What changed in the last 30 days?" → grounded in email notes/board, not invented.
   - `performance_vs_plan("<slug>")` → real facts (or the Stage-5 deferral named).
   - `rank_project_files_for_question("<slug>", <an underwriting question>)` → returns the UW model.
   - `get_deal_update("<slug>")` → fresh board (not `run_status` degraded).
3. **Final scorecard:** `brain-kit project scorecard <slug> --strict` — render the full
   plain-English table; every non-ok piece gets its fix line or its accepted-deferral line.
4. **Close out:** update `docs/design/TODOS.md` (the deal's anchors) + `progress.md`; save
   corrections/learnings to memory. Only now may the deal be called **onboarded** — and only
   if the probes above actually passed this session.
