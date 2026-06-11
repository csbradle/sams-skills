# Session-state schema for `_ic_deck_session_state.json`

A small JSON file written to the deck working folder by the orchestrator + both sub-skills. Carries state across context boundaries so the orchestrator can resume a half-finished session, and so each sub-skill can pick up its inputs without re-asking the user.

## File location

`<deal-folder>/03. IC Collateral/<MM.DD update>/_ic_deck_session_state.json`

The leading underscore is intentional (sorts to top of folder listing, easy to spot as internal scratch state).

## Schema

```json
{
  "schema_version": 2,
  "deck_spec": {
    "project": "bungalow",
    "project_display_name": "Bungalow",
    "anchors_file": "C:/Users/SamBradley/.claude/skills/draft-IC-Deck/references/bungalow-anchors.md",
    "type": "update | vote",
    "cover_date": "5/25/2026",
    "deal_folder": "C:\\Users\\SamBradley\\TrueWindCapital Dropbox\\_Deal Team\\Deals (In Process)\\Property Management Targets\\01. Bungalow CC",
    "ic_subfolder": "03. IC Collateral/05.25 update"
  },
  "skeleton": [
    "Cover",
    "Page 1 — Exec Summary",
    "Page 2 — DD Workplan & Status",
    "Page 3 — Open Questions",
    "Page 4 — Combined P&L",
    "Page 5 — What Bungalow Has Built",
    "Page 6 — Haven Margin Bridge",
    "Page 7 — Haven Revenue Stack",
    "Page 8 — Transaction Terms",
    "Page 9 — Operating Plan",
    "Page 10 — Sensitivities",
    "Page 11 — Advisor Read",
    "Page 12 — M&A Pipeline",
    "Page 13 — Cleveland Deepening",
    "APPENDIX",
    "A1 — Pro-Forma Cap Table",
    "A2 — Seattle / Windermere",
    "A3 — Legacy Door Breakdown"
  ],
  "phase": "spec_approved | pass1_running | pass1_complete | md_approved | pass2_running | pass2_complete | iterating",
  "md_path": "<deal-folder>/03. IC Collateral/05.25 update/_ic_deck_context_2026-05-25.md",
  "html_versions": [
    {
      "version": "v01",
      "path": "<...>/Bungalow IC Update — 05.25 v01.html",
      "screenshot_dir": "<...>/v01-screenshots/",
      "verification": "pass | fail-page-N",
      "built_at": "2026-05-25T14:32:11Z"
    }
  ],
  "sam_redlines_pending": [
    "Page 6 commentary should mention Lori GL drop"
  ],
  "last_summary": "Pass 2 v01 complete. 17 pages built. All <13px font check passes. Verification screenshots in v01-screenshots/."
}
```

## Phase transitions

```
[start] → spec_approved → pass1_running → pass1_complete
                                              ↓
                                         md_approved → pass2_running → pass2_complete
                                                                            ↓
                                                                        iterating ⇄ pass2_running
                                                                            ↓
                                                                         [done]
```

The orchestrator advances `phase` at each transition. Sub-skills set `phase` to `pass1_running` / `pass2_running` on start and `pass1_complete` / `pass2_complete` on successful exit.

## Who reads / writes what

| Field | Written by | Read by |
|---|---|---|
| `deck_spec` (including `project`, `anchors_file`), `skeleton` | Orchestrator (Phase A) | Pass 1, Pass 2, orchestrator on resume |
| `phase` | Whoever's currently active | Orchestrator on resume |
| `md_path` | Pass 1 on completion | Orchestrator, Pass 2 |
| `html_versions[]` | Pass 2 on each version | Orchestrator |
| `sam_redlines_pending` | Orchestrator (Phase E) | Pass 2 next spawn (if redlines reach the data layer; usually they don't) |
| `last_summary` | Whoever last ran | Orchestrator on resume (one-line "what state am I in") |

## Resume protocol

When orchestrator (`/draft-IC-Deck`) is invoked, before asking the user anything:

1. Glob the working folder (or last-touched IC subfolder) for `_ic_deck_session_state.json`
2. If found: read it, print `last_summary` to user, ask "Resume from phase `<phase>`, or start fresh?"
3. If resume: jump to the next phase after `phase`. If start fresh: archive the old state file (rename to `_ic_deck_session_state.<timestamp>.json`) and start clean.

## Notes

- The schema is intentionally minimal. Heavy artifacts (the context MD, the HTML files, the screenshots) live as separate files; state file only tracks paths + lightweight metadata.
- Bump `schema_version` if the shape changes incompatibly. Sub-skills should check `schema_version == 2` on read and error if mismatched. (v1 lacked `project` + `anchors_file`; v2 adds them — any v1 state file should be migrated by adding those two fields.)
- The state file is local-only — never commits to Slack canvas, never shared with counterparties. It's deal-team scratch state.
