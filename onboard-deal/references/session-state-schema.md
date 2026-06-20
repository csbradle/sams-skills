# Session-state schema

`/onboard-deal` writes `_onboard_deal_state.json` to the working dir after each phase, so a long run resumes cleanly. On start, glob for it (resume protocol in SKILL.md).

```json
{
  "deal_name": "Ultimate Knowledge Institute",
  "slug": "uki",
  "codename": "Jedi",
  "aliases": ["UKI", "Jedi", "Ultimate Knowledge"],
  "file_group_dir": "<local path the user pointed at>",
  "outlook_folder": "<exact folder name>",
  "sweep_days": 180,
  "phase": "scaffold_applied",
  "context_master_path": "<local path to authored CONTEXT_MASTER.md>",
  "bootstrap_json_path": "<local path>",
  "unassigned_doc_ids": ["abc12345", "def67890"],
  "flagged_threads": ["<subject or note path>"],
  "last_summary": "Scaffolded Projects/uki, aliases set, 12 files ingested (3 reclassified). Next: email sweep.",
  "updated_at": "2026-06-20T00:00:00Z"
}
```

## `phase` values (in order)

- `framed` — Phase 0 done; CONTEXT_MASTER.md authored + approved.
- `scaffold_applied` — Phase 1 done; `Projects/<slug>/` exists, aliases set in index.md.
- `files_ingested` — Phase 2 done; pointers routed + enriched.
- `email_swept` — Phase 3 done; notes written + flagged threads backfilled.
- `enriched` — Phase 4 done; personas/opinions/decisions written, index rebuilt.
- `complete` — done criteria met; backlog + progress.md updated.

Resume jumps to the phase *after* the saved one. Do not re-run a completed CLI step (scaffold/ingest are idempotent but re-asking questions wastes the user's time).
