---
name: update-deck-fix
description: This skill should be used when the /update-deck orchestrator (or the user directly) asks to "apply deck revisions", "fix the deck slides", "apply redlines to the deck", or "/update-deck-fix". Pass 1 of /update-deck. Takes a deck HTML, a list of user revision instructions, and a gap report from /update-deck-verify or /update-deck-render-check, and applies the edits — slide deletions with page renumbering, slide rewrites, image re-exports from source XLSX via Excel COM (drops Page Break Preview watermarks, bumps chart font sizes), and TBU replacements for any unsourced claims flagged by verify. Writes to a new vN+1 of the deck (never overwrites the source). Designed to run as an Agent-tool subagent spawned from /update-deck with a fresh context window so the parent context stays clean.
metadata:
  type: skill
  user-invocable: true
  disable-model-invocation: false
---

# /update-deck-fix — apply revisions to an IC HTML deck

Pass 1 of `/update-deck`. The only sub-skill that writes to disk. Takes redlines + gap reports and produces a new vN+1 of the deck.

## Inputs

- `deck_path` — absolute path to the prior version (the file the user named, or the highest `_vN` on disk if newer).
- `revision_instructions` — natural-language list of the user's redlines for this pass. Example:
  > "Page 14 needs to go back to v01 with 4 TBU boxes. Page 11 is useless, delete. Page 6 bridge text is hard to read. P&L says 'page 1' in the middle."
- `verify_report` — optional JSON from `/update-deck-verify` listing unsourced claims, naked outputs, register violations.
- `render_check_report` — optional JSON from `/update-deck-render-check` listing overflow indices + image-legibility flags.
- `context_md_path` — optional truth source for any new commentary the fix needs to pull from.

## Output

- A new file at `<deck_folder>/<base> v<N+1>.html` containing all applied revisions.
- A one-paragraph summary of what changed, what became TBU, and what escalated to the user.

## Procedure

### Step 1 — Version bump

Per `~/.claude/skills/update-deck/references/version-and-handoff.md`:

```powershell
Copy-Item "<deck_path>" "<deck_folder>/<base> v<N+1>.html" -Force
```

Edit only the copy from here on. Update the `<title>` tag to match the new version.

### Step 2 — Parse the revision list

Walk `revision_instructions` and identify each discrete edit. Common shapes:

- **Slide delete** — "Page X is useless, remove" → delete the `<section class="slide">` block. Renumber every `page-num` and `eyebrow` after it. Update any in-body `Page \d+` text references that pointed at the deleted slide.
- **Slide rewrite** — "Page X needs to go back to v01" → load the prior version (v01 or whichever) from disk; copy its layout for that slide; merge with any newer content the current version added that's still valid.
- **Image legibility** — "Page X chart text is hard to read" or "P&L says page 1 in the middle" → route to image re-export per `image-re-export-playbook.md`.
- **Commentary add** — "Page X is a naked image, add takeaways" → pull commentary from `context_md_path` or corpus; never invent.
- **Number / fact change** — "Page X says Y, should be Z" → verify Z against corpus before applying; if Z isn't in corpus, ask the user to confirm before writing it.

### Step 3 — Apply edits

Use Edit (preferred) or Write (for full-section rewrites) to apply each change to the new vN+1 file.

For slide deletions:
1. Edit out the full `<section class="slide">...</section>` block, including leading HTML comment.
2. Update every `<div class="page-num">N</div>` after the deletion point: N → N-1.
3. Update every `<div class="eyebrow">Page N · ...</div>` after the deletion point.
4. Grep the body for `Page \d+` text references that need updating (look in `<li>`, `<td>`, `<p>`, `<callout>`).
5. The `<!-- ============== PAGE N — TITLE ============== -->` comments are not user-visible; updating them is optional but recommended for the next pass's readability.

For image re-exports — see Step 5.

For commentary adds — pull from the context MD or corpus. NEVER invent. If the source has no commentary, escalate to the user.

For number/fact edits — verify against context MD or corpus before writing. If unsourced, write a TBU box instead:

```html
<div class="tbu">
  <div class="tbu-label">TBU — Pending <source-name></div>
  <div class="tbu-title"><claim category></div>
  <div class="tbu-sub">Insert from <source-path>. Numbers come straight from the model — no recreation here.</div>
</div>
```

### Step 4 — Process the verify report

For each entry in `verify_report.unsourced_numbers` / `unsourced_people` / `unsourced_quotes` / `naked_outputs` / `internal_register_violations`:

- **Unsourced number** → replace with TBU box; do not write the number.
- **Wrong firm** → if `corpus_says` is set, correct in place; if not, leave a comment for the user and don't write the wrong firm.
- **Drifted quote** → drop the quote OR re-pull the verbatim text from the source line in the report.
- **Naked output** → add a commentary block adjacent to the output (pulled from context MD); if no commentary exists in the corpus, escalate to user — the slide may not belong in the deck.
- **Internal register** → strip the phrase or rephrase per audience-register filter.

### Step 5 — Image re-exports

For each entry in `render_check_report.legibility_flags`, follow `~/.claude/skills/update-deck/references/image-re-export-playbook.md`.

For P&L / table image flags with `fix_hint: "tighten export range per playbook Defect 4"` (stray top dates row, bottom `Check` / empty-stub rows): use Range.CopyPicture with an explicit narrowed range — discover the first/last load-bearing row by scanning column A for the title anchor and rejecting `Check` / blank-value rows. See playbook Defect 4 for the discovery loop. Do not export `UsedRange` blindly on P&L sheets — it almost always pulls scaffold.

Common case (Page Break Preview watermark, chart fonts too small):

```powershell
& "C:\Users\<user>\.claude\skills\update-deck\scripts\re_export_excel_chart.ps1" `
    -XlsxPath "<source.xlsx>" `
    -SheetName "<sheet name>" `
    -OutPng "<deck_folder>/img/<file>.png" `
    -ChartObjectName "<chart name or empty>" `
    -ChartWidth 1500 -ChartHeight 720 `
    -TitleFontSize 36 -DataLabelFontSize 26
```

The script copies the XLSX to `$env:TEMP` first (so it doesn't conflict with any Nobie/other session that has the original open), forces every sheet to Normal view, exports at high resolution, and backs up the prior PNG as `.bak`.

After re-export, Read the new PNG to confirm:
- Watermark gone (if it had one).
- Text readable at chat-display size.

If still bad, increase `$ChartWidth` / `$ChartHeight` and re-export. If still bad after a third pass, escalate to the user.

### Step 6 — Re-route to /update-deck-render-check

After all edits applied, the orchestrator will spawn `/update-deck-render-check` against the new vN+1. Any overflow it reports comes back here as a follow-up pass. Common causes + fixes:

- Body content too tall → trim a bullet from each column.
- Image max-height too generous → reduce by 60-80px.
- Three-column commentary too dense → reduce to two columns or shrink font from 13.5px to 13px.

### Step 7 — Return summary to orchestrator

Return:
1. **Path to new file** (absolute).
2. **One-line summary per revision** ("Page X: deleted; renumbered Pages X+1 → end." / "Page Y: re-exported chart with title 36pt + data labels 26pt bold." / "Page Z: replaced fabricated 30-40% leverage with TBU box pointing at returns model.").
3. **TBU boxes added** — list each, with the source-file pointer.
4. **Escalations** — any redline the skill could not auto-resolve (unverifiable claims, ambiguous source XLSX, etc.). The orchestrator decides whether to ask the user or punt.

## What this skill does NOT do

- It does not invent numbers or paraphrase quotes. Per [[feedback-never-fabricate-ic-numbers]] and [[feedback-no-hallucination-ask-instead]] — when in doubt, TBU box or escalate.
- It does not recreate charts as HTML/CSS. Per [[feedback-use-exact-source-output-not-rebuilds]] — re-export from source XLSX.
- It does not run the overflow probe. That's `/update-deck-render-check`.
- It does not declare the deck "done". The orchestrator reconciles all three passes.

## References

- `~/.claude/skills/update-deck/references/verify-checklist.md` — the three pillars this fix must satisfy.
- `~/.claude/skills/update-deck/references/image-re-export-playbook.md` — Excel COM patterns.
- `~/.claude/skills/update-deck/references/version-and-handoff.md` — version-bump + backup conventions.
- `~/.claude/skills/update-deck/scripts/re_export_excel_chart.ps1` — the re-export tool.

## Memories enforced

- [[feedback-never-fabricate-ic-numbers]]
- [[feedback-no-hallucination-ask-instead]]
- [[feedback-no-naked-outputs-in-ic]]
- [[feedback-use-exact-source-output-not-rebuilds]]
- [[feedback-latest-artifact-version]]
- [[feedback-ic-deck-audience-register]]

## Related

- [[update-deck]] — parent orchestrator.
- [[update-deck-verify]] — produces the gap report this skill processes.
- [[update-deck-render-check]] — runs after this skill to catch overflows the fix introduced.
- [[nobie-mcp]] — for cell-level XLSX reads when the redline requires data refresh, not just re-export.
