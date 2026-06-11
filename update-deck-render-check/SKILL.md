---
name: update-deck-render-check
description: This skill should be used when the /update-deck orchestrator (or the user directly) asks to "render-check the deck", "overflow check the deck", "verify slides at 1920×1080", or "/update-deck-render-check". Pass 3 of /update-deck. Runs the headless 1920×1080 overflow probe across every slide in an IC HTML deck, screenshots every slide, and Reads each PNG to spot-check legibility. Returns a JSON gap report — overflow indices + image-legibility flags — so the parent orchestrator can route fixes to /update-deck-fix. Hard constraint:  does not edit the deck. Designed to run as an Agent-tool subagent spawned from /update-deck with a fresh context window so the parent context isn't polluted with screenshot bytes.
metadata:
  type: skill
  user-invocable: true
  disable-model-invocation: false
---

# /update-deck-render-check — headless 1920×1080 render + overflow probe

Pass 3 of `/update-deck`. Takes an existing deck HTML and reports back what's wrong with it visually, without editing.

This skill is read-only. It NEVER edits the deck. Routing fixes is the orchestrator's job.

## Inputs

- `deck_path` — absolute path to the deck HTML file to check.
- `output_dir` — optional. Where to drop the probe JSON + screenshots. Defaults to `$env:TEMP\update-deck-shots\<deckname>\`.
- `screenshot_every_slide` — boolean. Default true. Screenshots every slide so the skill can Read them and audit image legibility. Set false for a fast overflow-only check.

## Output (returned to parent)

JSON with this shape, plus a one-paragraph natural-language summary:

```json
{
  "deck_path": "...",
  "slide_count": 17,
  "overflow_failures": [
    { "idx": 6, "title": "...", "slide_overflow": 42, "body_overflow": 42 }
  ],
  "legibility_flags": [
    { "idx": 7, "img_path": "img/X.png", "issue": "page-break-preview watermark", "fix_hint": "re-export via re_export_excel_chart.ps1 in Normal view" }
  ],
  "screenshots_dir": "...",
  "pass": false
}
```

`pass` is true only when `overflow_failures` AND `legibility_flags` are both empty.

## Procedure

### Step 1 — Locate Chrome / Edge

Use `scripts/run_overflow_check.ps1` from the parent `/update-deck` skill folder. It auto-detects Chrome → Edge fallback.

### Step 2 — Run the overflow probe

```powershell
& "C:\Users\<user>\.claude\skills\update-deck\scripts\run_overflow_check.ps1" `
    -DeckPath "<deck_path>" `
    -OutDir "<output_dir>" `
    -ScreenshotEverySlide:$true
```

The probe loads the deck in an iframe at 1920×1080, measures every `.slide`, and emits JSON. Exit 1 means at least one slide overflowed.

Read the JSON output line by line. Any slide where `slide_overflow > 0` (or `body_overflow > 0` if there is meaningful body overflow) goes into `overflow_failures`.

### Step 3 — Audit image legibility

For every PNG referenced by an `<img>` tag in the deck:

1. Resolve the relative `src` to an absolute path (deck folder + `src` value).
2. Read the PNG via the Read tool — the harness will render it inline.
3. Check for the legibility defects in `~/.claude/skills/update-deck/references/image-re-export-playbook.md`:
   - "Page 1" / "Page 2" gray watermark overlaying the data (Page Break Preview view bug). → Defect 1
   - Axis labels or data labels too small to read at chat-display size (will be unreadable at slide scale too). → Defect 2
   - PNG natural resolution < 2× slide display width (image will appear blurry when scaled). → Defect 3
   - **For P&L / table images: range-export scaffold drag-in (Defect 4).** Scan the top 2 rows: any look like whitespace OR a stray dates row (e.g. `Q3-25 | Q4-25 | Q1-26`) that duplicates the column header below it? Scan the bottom 3 rows: any contain the literal word `Check` in column A? Any contain a row label but blank value cells across periods? If yes → flag with `fix_hint: "tighten export range per playbook Defect 4"`.
4. Add an entry to `legibility_flags` for each defect, with a `fix_hint` pointing at the playbook section.

If `screenshot_every_slide` is true, ALSO Read each per-slide screenshot (`slide_1.png`, `slide_2.png`, …) and confirm:
- Body content is not clipped at the bottom edge.
- Text is not extending under the footer's border.
- Right-column content is not running off the right edge.

These visual checks catch overflows the JSON probe missed (e.g., absolute-positioned content rendering off-canvas).

### Step 4 — Return the gap report

Emit the JSON + a one-paragraph summary back to the parent orchestrator. Example summary:

> "17 slides probed at 1920×1080. Page 6 overflows by 42px (chart + 3-col commentary too tall). Page 7 image has a 'Page 1' watermark from Excel Page Break Preview view. Fix routing: page 6 → trim a bullet from each commentary column or shrink the chart by 60px; page 7 → re-export `img/Haven_Revenue_Detail.png` via re_export_excel_chart.ps1 with $ChartObjectName empty."

Do NOT auto-fix. Return the report. The orchestrator decides whether to spawn `/update-deck-fix`.

## Reading the probe JSON

Every entry has:

- `idx` — 1-indexed slide position.
- `title` — first 80 chars of the slide's `<h1.slide-title>` for human-readable failure reports.
- `slide_scroll` / `slide_client` — full slide element. These should be equal at 1080px when no overflow.
- `slide_overflow` — `max(0, slide_scroll - slide_client)`. Anything > 0 is a hard fail.
- `body_scroll` / `body_client` / `body_overflow` — inner `.slide-body`. Mostly redundant with the slide-level numbers, but useful when the failure is body-content vs. header/footer chrome.

An overflow of 1-3px usually indicates a sub-pixel rounding issue (e.g., `border-top: 1px` on the footer); not worth fixing. Overflow ≥ 20px is the threshold to route to `/update-deck-fix`.

## Tuning the probe for slow-loading decks

If `slide_scroll == slide_client == 0` for any slide, layout hadn't completed by the time the JS measurement ran. Bump the `setTimeout` in `overflow_probe.html` from 1800ms to 3000ms+, OR raise `--virtual-time-budget` in `run_overflow_check.ps1` from 8000ms to 12000ms+. The probe defaults are tuned for decks with ≤20 image embeds; very image-heavy decks (chart-per-slide) may need more.

If a slide has a remote-fetched font (Google Fonts, etc.), the probe may run before the font finishes loading — and the layout shifts post-load. Pass `--virtual-time-budget=15000` for first-pass deck probes, then a faster check on iterations.

## Failure modes

- **Chrome refuses `file:///` access.** Pass `--allow-file-access-from-files`. The probe script does this; if you call Chrome directly, you must too.
- **`--virtual-time-budget` too short.** Slides with many `<img>` tags need 5+ seconds to layout post-decode. Default is 8000ms; bump higher if measurements come back with `slide_scroll == slide_client == 0` (a tell that layout hadn't run yet).
- **Dump-DOM returns empty.** Chrome is being launched with the wrong user-data-dir (race with another headless instance). Use a fresh `--user-data-dir` per run.
- **Image Read returns "file not found".** The `<img src>` is using a path that doesn't exist on disk. Flag this as a defect — the slide will render broken.
- **PNG so large it busts the harness's image read.** Skip and flag — recommend running this slide's audit manually.
- **Body content reports 0 overflow but visual screenshot shows clipping.** Happens when a child element is `position: absolute` with a large `top` value; it doesn't push the parent's `scrollHeight` even though it visually overflows. Catch via the visual screenshot audit (Step 3, last paragraph) — the JSON probe alone misses this.
- **Chart image is the wrong source.** Sometimes the `<img src>` points at an outdated PNG that was supposed to be replaced but wasn't (e.g., a `.png.bak` rename was skipped). Spot-check: confirm the PNG modification timestamp is recent for any image touched in this revision.

## Why this skill runs in fresh context

Screenshots and image-Read calls consume a lot of token budget — even at 1024px wide a slide PNG can be ~50KB which encodes to many tokens. Running the visual audit in a fresh subagent context keeps the orchestrator's context clean for higher-value decisions (which redlines to apply, which questions to ask the user). Subagent isolation is structural, not honor-system — the orchestrator never sees the raw screenshot bytes, only this skill's distilled JSON gap report.

## References

- `~/.claude/skills/update-deck/references/verify-checklist.md` — Pillar 1 (legibility) and Pillar 3 (overflow) definitions.
- `~/.claude/skills/update-deck/references/image-re-export-playbook.md` — how `update-deck-fix` will respond to the legibility flags this skill emits.
- `~/.claude/skills/update-deck/scripts/run_overflow_check.ps1` — the headless probe.

## Memories enforced

- [[feedback-verify-slide-overflow-before-done]] — the reason this skill exists. Hard rule, no exceptions.
- [[feedback-use-exact-source-output-not-rebuilds]] — informs the legibility flag's `fix_hint`: re-export from source, don't recreate as HTML/CSS.

## Related

- [[update-deck]] — parent orchestrator.
- [[update-deck-fix]] — sibling. Receives this skill's gap report and applies fixes.
- [[update-deck-verify]] — sibling. Fact-checks; runs in parallel with this skill.
- [[render-IC-Deck-html]] — Pass 2 of `/draft-IC-Deck`. Same headless-render pattern; reused here.
