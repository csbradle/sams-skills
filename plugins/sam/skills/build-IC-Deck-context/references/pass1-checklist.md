# Pass 1 — per-source-type tactical checklist

Loaded on demand when the Pass 1 subagent needs a tactical reminder for a specific source type. Most of the time the SKILL.md's §1–§13 is enough; this file is the deeper dive when something is going wrong.

## Slack canvas + channel reads

- Canvas read via `mcp__claude_ai_Slack__slack_read_canvas` (canvas ID `F0B37J3G8G3` for Bungalow)
- Channel read via `mcp__claude_ai_Slack__slack_read_channel` (channel ID `C0B2E6LQ5NF` for Bungalow)
- Limit channel read to last 5–10 days unless something specifically older is needed
- If canvas mentions a workstream that isn't in current Outlook flow, surface it explicitly — canvas is more current than email for things the deal team controls

## Outlook reads (Graph API direct)

Per `[[feedback-use-graph-api-directly]]`, don't use the broken MCP search. Use `GraphAdapter` directly.

Multi-pass strategy (per `[[feedback-emails-slack-multiple-passes]]`):
1. Pass A: `participants:<name>` for each top external party
2. Pass B: `"<topic phrase>"` for each key thesis topic (e.g. "Cleveland", "Windermere", "margin bridge", "QofE")
3. Pass C: `from:<sender>` for advisors/counterparties who initiate threads (Brandon, Lori, BluePoint folks)

Date range: last 5–10 days for working state; extend to 30 days if the deck needs historical context on a specific decision.

## Calendar reads

`mcp__claude_ai_Microsoft_365__outlook_calendar_search` — pull 30 days forward. Categorize:
- DD sessions (mgmt calls, vendor kickoffs)
- Advisor calls
- IC dates + deal team syncs (these go in "Important Dates" section, NOT in the deck itself — they're orchestrator/canvas content)

## Excel reads (Nobie MCP)

Per `[[feedback-excel-formatting-preservation]]`, if you need to write anything: always `copy_from_range` to stamp styles first, then overwrite values. `insert_entire_row` produces unstyled rows.

For reads only (the common Pass 1 case):
1. `mcp__nobie__open_excel_file` on the latest version (per `[[feedback-latest-artifact-version]]`)
2. `mcp__nobie__list_sheets` to confirm tab names
3. `mcp__nobie__read_sheet` on each load-bearing tab
4. Write the actual cell values into the MD, NOT a paraphrase

## Transcript reads

Glob `08. Notes/` and subdirectories. Sort chronologically. Newest file = mandatory full-read.

For full-reads on long transcripts (>1000 lines), use Explore agent with "very thorough" thoroughness. Pull verbatim quotes on every load-bearing topic; cite line numbers where possible.

The v03 failure was reading only 300 of 1700 lines of the 5/5 mgmt session — caused a fabricated margin bridge and missed the entire ancillary-revenue narrative. Don't repeat.

## Advisor notes

Glob `08. Notes/03. Executive Advisors/` every time. New advisor notes appear weekly.

For each note file:
1. Note the advisor's name + firm (verify against bungalow-anchors.md roster)
2. Confirm engagement status (active / declined / intro-only). Per §7 of SKILL.md, only active advisors land on the advisor page.
3. Pull background (1–2 lines) + perspectives (3–6 bullets, verbatim where possible)
4. Cite the file path + dated transcript section as `Source:`

## Prior decks (for structural reuse)

Glob `03. IC Collateral/` subfolders. Pick the most recent finalized `<...> v<N>.html` per `[[feedback-latest-artifact-version]]`.

DO NOT read the prior deck as a content source — it's stale by definition. Read it ONLY for:
- Slide structure (header / subheader / table orientations)
- Reuse instructions (which outputs should be reproduced identically — note in MD)
- Style reference (font sizes, color palette, table treatments — for Pass 2)

If the prior deck has a P&L with annual columns + an inflection-point line, the MD instructs Pass 2 to reproduce identically.

## Worked MD example — financial-slide blocks

Filled examples of the per-slide block format from SKILL.md §12 (content is always source-derived per §0):

```
### Page 4 — Combined P&L
**Header:** Combined P&L
**Subheader:** <punchline>

[full table data — every cell, ANNUAL COLUMNS DEFAULT + LTM, quarterly only if quarterly is the story]

Source: Bungalow Data Cuts v<N>.xlsx / Bungalow Consolidated P&L
Reuse instruction: REPRODUCE IDENTICALLY from <prior artifact> Slide N (rows = X, cols = Y)
Same-page commentary: <what Sam wants the IC reader to see, what the mgmt 5/15 call discussed about these numbers>

### Page N — Haven Margin Bridge
**Header:** Haven CP Margin Bridge
**Subheader:** <punchline — driver attribution>

[bridge data — rows = drivers, cols = periods per DD agenda original]
TBU callout: redo this excl. <300-door customer lost pre-acquisition> to show normalized
Same-page commentary: <bucket-by-bucket from mgmt 5/15>

Source: Bungalow Data Cuts v<N>.xlsx / Haven CP Margin Bridge
Reuse instruction: REPRODUCE IDENTICALLY from DD Agenda (rows = drivers, cols = periods — do NOT rotate)
```

## Common Pass-1 traps

1. **Going to named files from a stale planner doc.** Always glob the directory first.
2. **Reading the rendered PDF instead of the source Excel.** PDFs are derivatives. Always read the source.
3. **Reading 300 of 1700 lines of a transcript.** Use Explore "very thorough" for long transcripts.
4. **Missing a new advisor file added since last week.** Re-glob `08. Notes/03. Executive Advisors/` every time.
5. **Trusting a local Context_Master.md over this-week's Outlook.** Live > saved-down.
6. **Inferring a firm from training data.** ASK Sam if the corpus doesn't say.
7. **Listing an intro source as an advisor.** Check engagement status (active / declined / intro-only) for every advisor-candidate.
8. **Treating the skeleton as content (SKILL.md §0).** A bullet is a question, not an answer. If a slide block could have been written from the outline without opening a source, you haven't done Pass 1 — go deep into the workbooks / transcripts / CIM / brain and fill it with real figures, quotes, and named facts.
