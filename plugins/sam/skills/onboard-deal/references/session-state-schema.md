# Session-state schema v2

Location: **`C:\brain\vault\Meta\onboarding\<slug>-state.json`** (keyed by slug — survives
across sittings, machines see it via the vault; the v1 working-dir location broke resume).
Written by the PARENT after every stage completion and every gate decision. Subagents never
write it. **The state file is a HINT — probes (`project scorecard`) are authoritative.**
Its irreplaceable job is the **answer-of-record**: interview answers probes cannot rebuild.

Legacy migration (one-time, on invoke): a working-dir `_onboard_deal_state.json` is backed up,
its answer-of-record fields imported, the old file renamed `*.migrated`, and the status line
says so.

```json
{
  "schema_version": 2,
  "slug": "exampledeal",
  "session_id": "<uuid of the Claude session currently holding it>",
  "touched_at": "2026-07-02T21:00:00Z",

  "deal_name": "Example Deal Co",
  "codename": "Falcon",
  "aliases_as_answered": ["Falcon", "Example Deal", "EDC"],
  "deal_type": "portco",
  "file_group_dir": "<local path the user pointed at>",
  "file_group_provenance": "data room via counsel",
  "outlook_folder": "<exact display name>",
  "outlook_folder_id": "<stable AAMk... id from resolve-folder>",
  "sweep_days": 180,
  "workstreams": ["<as the user named them>"],
  "flagged_threads": ["<subject or note path>"],
  "context_master_path": "<local path>",
  "bootstrap_json_path": "<local path>",
  "financial_sources_status": "registered | deferred | n_a_by_type",

  "stages": {
    "1": { "status": "done", "completed_at": "…", "probe_summary": { "<full scorecard pieces JSON at completion>": "…" } },
    "2": { "status": "done", "completed_at": "…", "probe_summary": {} },
    "3": { "status": "in_progress", "completed_at": null, "probe_summary": null },
    "4": { "status": "pending" },
    "5": { "status": "skipped", "reason": "<user's words>", "skipped_at": "…" },
    "6": { "status": "pending" },
    "7": { "status": "pending" },
    "8": { "status": "pending" }
  },

  "verb_log": [
    { "at": "…", "verb": "continue" },
    { "at": "…", "verb": "redo stage-3", "said": "redo the file load" }
  ],
  "accepted_gaps": [
    { "piece": "graph_edges", "accepted_by": "user", "at": "2026-07-02", "note": "seed later" }
  ],
  "last_summary": "<one plain-English line for the next sitting's status screen>",
  "updated_at": "2026-07-02T21:00:00Z"
}
```

## Stage `status` values

`pending` · `in_progress` · `done` · `done (pre-existing)` (probes ok but this run never
executed it — hand work; never re-run, never re-ask) · `skipped` (user deferral — named gap
forever) · `deferred` (blocked on an external, e.g. re-drop needed).

## Probe-rebuildable vs must-persist

| Field | Probes can rebuild? | Notes |
|---|---|---|
| stages[*].status | YES (mostly) | reconcile table in SKILL.md; probes win on conflict |
| probe_summary | YES (current), NO (historical) | kept for "why did this read done then" |
| deal_name / codename / aliases_as_answered | PARTIAL | index carries applied aliases; the ANSWER (incl. rejected candidates) only lives here |
| deal_type / workstreams | NO | interview answers — must persist |
| file_group_dir / provenance / sweep_days | NO | must persist |
| outlook_folder(+id) | PARTIAL | frontmatter carries it once Stage 2 ran; keep the answer anyway |
| flagged_threads / verb_log / accepted_gaps | NO | must persist |

## Concurrency

`session_id` + `touched_at` implement the guard: another session's `in_progress` stage with
`touched_at` < 2h ago → WARN + ask before proceeding. Update `touched_at` on every write.
