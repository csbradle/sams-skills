---
name: onboard-deal
description: This skill should be used when the user asks to "onboard a deal", "/onboard-deal", "onboard UKI / Jedi / <deal> as a new project", "set up a new deal in the brain", "stand up a project from these files", or points at a group of deal files + an Outlook folder and wants the brain populated. Orchestrates a 5-phase per-deal onboarding for the TWC company brain — frames the deal via an interactive question round (parent context, gate 1), scaffolds Projects/<slug>/ from an authored CONTEXT_MASTER.md, ingests a pointed-to file group with per-file routing/meaning questions (subagent + gate 2), sweeps the deal's Outlook folder with important-conversation questions (subagent + gate 3), then lightly enriches People personas / opinions / decisions and rebuilds the index (subagent + spot-check). Reuses brain-kit CLIs (lonestar bootstrap/apply, ingest, graph backfill, file reclassify/accept); adds zero deal data to the committed skill.
version: 1.0.0
user-invocable: true
---

# /onboard-deal — Per-deal brain onboarding orchestrator

## Purpose

Stand up a new deal in the company brain end-to-end: scaffold the project, load a pointed-to file group, sweep the deal's Outlook folder, and lightly enrich the relational layer (People personas, deal opinions, decisions) — with **interactive question rounds** so the brain captures the context only the user knows (who's who, what each file is, which conversations matter).

The user runs this once per deal. The *process* is identical for every deal; only the *content* (the deal's files, folder, and answers) differs — that is the repeatability bar this skill is held to.

## Operating principles

- **Ask freely — this is the sanctioned interview surface.** The brain's ≤3-questions/day cap governs the *autonomous nightly* pipeline. This skill is a **user-initiated deep onboarding**; the user explicitly wants to be asked. Batch questions sensibly, but don't ration them. (This is NOT a pivot violation — the nightly auto-infer stays capped.)
- **LLM infers at write time; no TODO placeholders.** Every `sam_take` / `lens` / persona / opinion field gets filled from corpus + the user's answers + ~60s web research. Never write `sam_take: null` or "TODO: voice-dictate". (Per the 2026-05-12 inference pivot.)
- **Existence-check before every create.** Before scaffolding a Person / Org / Decision / Opinion, look it up; if it exists, enrich it — never duplicate.
- **Zero deal data in this skill.** The authored CONTEXT_MASTER.md and all deal specifics live in the local working dir / vault, never in these committed files (repo may go open-source — rule #10).
- **Heavy phases run as fresh-context Agent subagents; gates stay in parent.** Keeps the parent context clean across a long run.
- **Vault is not git-tracked.** Never `git add` vault content. Only the skill files are version-controlled (synced to the `sams-skills` repo).

## Inputs to collect up front

1. **Deal name + codename** (e.g. "UKI" / "Jedi") → drives the project `slug`.
2. **File-group path** — the folder/files the user is pointing at, and **where they came from** (data room? counsel? management?).
3. **Outlook folder name** — the dedicated deal folder to sweep.

If any is missing, ask before starting. Resolve the vault path from `brain-kit` config (the live vault is `C:\brain\vault`).

## Resume protocol

Before anything, glob the working folder for `_onboard_deal_state.json`. If found: print `last_summary`, ask "Resume from phase `<phase>` or start fresh?" Resume → jump to the phase after the saved one. Fresh → archive (rename to `_onboard_deal_state.<timestamp>.json`) and proceed. Schema: `references/session-state-schema.md`. Write the state file after each phase completes.

---

## Phase 0 — Frame the deal (parent context, question gate 1)

**Prep before asking (do the homework first):**
- Read relevant memories (`project_<codename>*`, `org_*`, `feedback_research_new_entities`, `feedback_codename_alias_resolution`).
- Check the vault for any existing footprint: `Organizations/<deal>.md`, prior mentions, an existing `Projects/<slug>/`.
- ~60s web research on the deal target + each named party (type, focus, who they are).
- Scan the file-group filenames + folder names for parties, dates, doc types.

**Then ask** (use `references/question-bank.md` as the checklist). Use structured `AskUserQuestion` for enumerable choices (which party is counterparty vs. advisor vs. our side; confirm the Outlook folder; confirm aliases), conversational asks for open-ended context (deal thesis, stage, the user's read on key people). Cover, at minimum:
- **Parties & sides** — for each org: counterparty / advisor (whose?) / our side / portco. Which side of the deal.
- **Key people + roles** — name, org, role, and the user's relationship/read.
- **Codename + aliases** — every real-world name + codename the deal goes by (e.g. Jedi / UKI / Ultimate Knowledge / Cyberstar). **Load-bearing** — these become the project `aliases:` that auto-route files and email in Phases 2–3. Avoid aliases < 3 chars or substrings of other deals (substring matcher).
- **Per-file-cluster meaning** — for each cluster of the pointed-to files: what is this, where did it come from, where does it belong.

**Output:** author `<DEAL>-CONTEXT_MASTER.md` in the working dir (local, uncommitted) from research + answers, in the format `references/context-master-template.md` defines (which is exactly what `brain-kit lonestar bootstrap` parses). Show it to the user for redlines before Phase 1.

---

## Phase 1 — Scaffold the project (parent context, runs CLI)

`lonestar` is just the (legacy) command name — the parser/apply path is deal-generic. **Two gotchas the code forces you to handle:**

**1. Set the slug — the bootstrap CLI hardcodes it to `lonestar`.** `run_bootstrap` does not read a slug from the MD; the emitted JSON always says `"project_slug": "lonestar"`. So bootstrap to a file, then patch the slug before apply:

```
brain-kit lonestar bootstrap <DEAL>-CONTEXT_MASTER.md > <slug>-bootstrap.json
```
Edit `<slug>-bootstrap.json` → set `project.project_slug` to the deal slug (e.g. `"uki"`). Then:
```
brain-kit lonestar apply <slug>-bootstrap.json --vault-path C:\brain\vault --dry-run
```

Show the dry-run diff. On approval, re-run without `--dry-run` (add `--yes` only if it prompts on migrating a pre-existing index).

Result: `Projects/<slug>/` with `index.md`, `opinions.md`, and People/Org/Glossary stubs.

**2. Add the project `aliases:` by hand — `apply` does NOT propagate them.** `_apply_project_index` writes only `slug` + `codename`; the routing-critical project-level aliases are dropped. After apply, edit `Projects/<slug>/index.md` frontmatter to add:
```
aliases: [<Real Deal Name>, <Codename>, <Other Names>]
```
These are **load-bearing**: file classification (Phase 2) and email routing + `get_project` alias-resolution (Phase 3) match the file path / title against `slug` / `codename` / `aliases`. Choose names that appear in the file-group folder names and likely email subjects. Avoid aliases < 3 chars or substrings of other deals (the matcher is case-insensitive substring). They take effect on the next `index rebuild` (Phase 4).

---

## Phase 2 — Ingest the file group (Agent subagent + question gate 2)

**Cost gate (parent):** `brain-kit ingest plan <file-group-dir>` → show the page count + estimated cost. Proceed on approval.

**Spawn a `general-purpose` Agent subagent** to run the ingest (`brain-kit ingest <file...>` or a bash loop, vault from config). The subagent returns: which files auto-routed to `Projects/<slug>/file-pointers/`, and which landed in `_inbox/files/_unassigned/` (with their `doc_id` + routing candidates).

**Back in parent — routing questions (gate 2):** for each unassigned / low-confidence file, ask the user where it belongs (offer the candidates). Then route:

```
brain-kit file reclassify <doc_id> --project <slug>
brain-kit file accept <doc_id>
```

**Enrich:** for the deal's pointers, fill the `## Distillation` + lens from the user's per-file answers + corpus (no TODO slots). `.xlsx` stay pointer-only (no body) — flag that limitation, never fabricate a body.

---

## Phase 3 — Sweep the Outlook folder (Agent subagent + question gate 3)

**Spawn a subagent** to run, dry-run first:

```
brain-kit graph backfill --days <N> --folder "<UKI folder>" --dry-run
```

Show the kept/rejected tally. On approval, the subagent re-runs live (drop `--dry-run`). Notes write to `Projects/<slug>/emails/`. Do **2–3 passes** (`feedback_emails_slack_multiple_passes`): pass 1 sweeps, pass 2 checks downstream replies/threads, pass 3 spot-checks.

**Back in parent — conversation questions (gate 3):** the email pipeline writes `sam_take: null` + TODO placeholders. Close that interactively:
- Ask which threads are the **important conversations** and the user's read on key exchanges → backfill `sam_take` / `lens` richly on those notes.
- Surface emails that landed in `_inbox` or low-confidence → ask where they belong, re-route.

---

## Phase 4 — Light enrichment + index (Agent subagent + parent spot-check)

**Spawn a subagent** to, from the file + email corpus + the user's answers:
- Populate **People personas** (role, tone, relationship, history). **No unshareable content** — assume each person reads their own file (`feedback_persona_no_unshareable_content`): no promotion-advocacy, deal-performance judgments, or health.
- Write **deal opinions** into `Projects/<slug>/opinions.md`.
- Capture key **Decisions** (`Decisions/*.md`) surfaced by the corpus.
- Existence-check every entity before creating.

Then rebuild search:

```
brain-kit index rebuild
```

**Parent spot-check:** show the user a few enriched People + opinions + the project summary. Correct in-session (corrections update the entry same-turn).

---

## Done criteria

- `mcp__brain-kit__get_project("<slug>")` resolves (alias-aware).
- File pointers live under `Projects/<slug>/file-pointers/` with real distillations.
- Email notes under `Projects/<slug>/emails/` with backfilled `sam_take`/`lens` on flagged threads.
- `mcp__brain-kit__rank_project_files_for_question("<slug>", <a real deal question>, concept_terms=[...])` returns the right pointers ranked.
- People/opinions/decisions enriched; index rebuilt.

After the run, update `docs/design/TODOS.md` (the UKI onboard backlog item) and `progress.md`, and save any corrections to memory.
