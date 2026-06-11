# Per-deal anchors file — template + bootstrap dialogue

Every deal that builds IC artifacts MUST have an anchors file before any deck skill runs. **No anchors file (or required fields missing) → hard STOP + offer the bootstrap below.** The old "proceed without anchors, ask inline" path is dead — that is exactly how the 6.15 Lonestar deck shipped a mislabeled chart with no grounding (see the "2026-06-10 — the Lonestar mislabel incident" entry in `v03-retro.md`).

## Where anchors files LIVE (data-side, never in the skill tree)

Anchors files contain deal data. Per the brain repo's rule #10 (deal data never in committable/skill files):

- **Brain-mode deals** (deal has a vault project): `C:\brain\vault\Projects\<slug>\artifacts\<slug>-anchors.md`
- **Folder-mode deals**: `<deal root>\_anchors\<slug>-anchors.md`
- The skill's `references/` folder holds ONLY this template plus tiny per-deal **pointer files** (`<slug>-anchors.md` containing just the real path). Glob `references/*-anchors.md` to enumerate deals, then follow the pointer.

## Required fields (the gate checks FIELDS, not file existence)

A deck build may proceed only when the anchors file has ALL of:
1. `corpus_mode: folder | brain`
2. Deal root path (folder mode) or vault project root (brain mode), and the path is **reachable on this machine** — if not, the named degraded mode applies (see verify-gate.md "Machine-reachability preflight")
3. ≥1 source-of-truth entry (workbook, or brain doc_id)
4. People roster with ≥1 row that carries a real corpus `Source:` line

**Missing any of the four REQUIRED fields above → hard STOP + bootstrap. No exceptions** (a skeleton that satisfies the letter of the fields but nothing else still passes — the gate is a floor, not a quality bar; the bootstrap corpus-sweep is what makes it useful). The **degraded stamp** applies only to the OPTIONAL sections (returns snapshot, conventions, last-artifact glob) being empty — the build proceeds but the handoff says so plainly (e.g. "heads up: this deal has no returns snapshot on file, so I couldn't sanity-check the returns page").

## Template (copy per deal, fill every section)

```markdown
# <Deal> anchors
as_of: YYYY-MM-DD
corpus_mode: folder | brain

> RULE: numbers in this file are snapshots for orientation ONLY. They are NEVER
> citable sources for a deck. Every deck figure re-verifies against the live
> corpus/model. Stale anchors must never become gospel.

## Identity
- Deal name + codename map (e.g. Lonestar = PakEnergy + W Energy Services merger; aliases: Pak, Pacer, Wizard)
- Vault project slug (brain mode) or n/a

## Working folders / corpus access
- folder mode: deal root, IC artifact subfolder pattern, Slack canvas + channel IDs, advisor/transcript folder paths
- brain mode: vault root; retrieval recipe (rank_project_files_for_question → Read pointer → cite doc_id + quote anchor + canonical_url); emails/ + notes/ paths

## Source-of-truth files
- Workbooks with canonical tabs (Nobie cell-for-cell reads), or key brain doc_ids with roles (latest model, latest PMR, CIM, board decks)
- "Latest version on disk wins" rule per [[feedback-latest-artifact-version]]

## Verified people roster (exact roles + firms — do NOT infer)
| Person | Role | Firm | Status | Source |
(every row needs a corpus Source line; deck MDs must still cite their own corpus source per [[feedback-no-hallucination-ask-instead]])

## Returns model snapshot
- Headline assumptions + output — snapshot only; re-verify against the latest model before quoting. Do not hardcode.

## Deck conventions
- 16:9 1920×1080; sequential pages (no sub-letters); APPENDIX divider; file naming

## Last finished IC artifact
- Glob guidance for the most recent prior deck (structural reference)
```

## Bootstrap dialogue (when the gate stops a new deal)

Two phases. Total cold-start question budget across bootstrap + Phase A: **≤7 questions**. Phase A must consume bootstrap answers — never re-ask the deal folder.

**Phase 1 — Sam answers (plain English only; infer before asking):**
1. *Infer first:* does `C:\brain\vault\Projects\<slug>\` exist? → corpus_mode: brain, no question needed. Otherwise ask: "Where do the deal files live — point me at the folder?"
2. "What's the deal actually called, and any codenames I should map?" (skip if inferable from the vault index)
3. "Which file is the source of truth for numbers right now — the model, a data pack?" — accept "I don't know"; then: "OK — I'll use the newest workbook in the deal folder and flag that choice on the deck."
4. Anything else inferable (Slack channel, IC subfolder) gets inferred and CONFIRMED in one line, not asked open-ended.

Every question must pass the plain-English test — never say corpus mode, anchors, ledger, roster. Say "deal files," "source of truth," "people on the deal."

**Phase 2 — agent sweeps (~5 min, no questions):** enumerate the corpus (advisor notes / vault People + emails), seed the people roster with REAL Source lines, list candidate source-of-truth files, stamp `as_of`, write the anchors file data-side + the pointer in references/. Tell Sam: "Set up <Deal> — found N people and M source files. You can correct anything by just telling me."

Phase 2 is what makes the roster satisfiable — never fabricate a Source line to pass the gate.
