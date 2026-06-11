# /update-deck verify checklist

Three pillars must pass before declaring an /update-deck pass done. Skip any one and the deck ships with a defect the user has corrected before.

## Pillar 1 — Legibility

Every embedded chart, table, screenshot, or P&L output rendered at 1920×1080 must be legible *without zoom* and must be accompanied by bullets/commentary explaining what it shows.

### Visual legibility — image renders

For every `<img src="img/*.png">` in the deck:

1. **Read the PNG via the Read tool.** The harness returns the rendered image at its native resolution scaled to fit the chat. If the text in the image looks small at chat-display size, it WILL look small on the slide.
2. **For source-from-Excel images** with a "Page 1" / "Page 2" gray watermark in the middle: this is the Excel **Page Break Preview** view watermark. Re-export with Normal view (`Window.View = 1`). See `image-re-export-playbook.md` (Defect 1).
3. **For chart images** (waterfalls, bridges, bars): if axis labels or data labels look small, re-export with explicit font sizing (Title 32pt+, Data Labels 24pt bold, Tick Labels 22pt). Excel chart fonts auto-scale to chart size — bigger chart + bigger fonts both help. See playbook Defect 2.
4. **For table/P&L exports (range-copy-picture sourced)**: scan top and bottom rows for scaffold drag-in. Two patterns to FLAG and FIX:
   - **Top:** is the top row whitespace? Does any of the top 2 rows contain only period labels (e.g. `Q3-25 | Q4-25 | Q1-26`) that DUPLICATE column headers already shown in the main output? → re-export with a tighter range that starts at the title/anchor row.
   - **Bottom:** does any of the bottom 3 rows contain the literal word `Check` in column A? Does any have a row label but blank value cells across all periods? → re-export tightening the range to end at the last load-bearing total.
   - See playbook Defect 4 for the detection-then-fix range-tightening pattern. Do not ship a P&L with stray dates on top or `Check` / empty stubs on the bottom; the user has flagged this repeatedly.
5. **Never recreate charts as HTML/CSS.** Memory rule: [[feedback-use-exact-source-output-not-rebuilds]]. Re-export from source; do not redraw.

### Editorial legibility — commentary

For every slide that embeds an output:

- The slide MUST have a bullet block, callout, or commentary panel adjacent to or below the output.
- Commentary MUST be pulled from the corpus (mgmt-meeting transcripts, advisor notes, DD pack body text) — not invented captions.
- If the corpus has no commentary on the output, the output may not belong in the deck. Flag to the user rather than shipping a naked image.
- Memory rule: [[feedback-no-naked-outputs-in-ic]].

## Pillar 2 — Sourcing (no hallucinated facts)

Every number, name, firm, date, quote, and decision in a slide must trace to a source line in the context MD or corpus.

### Numbers

- Hard rule: **never invent numbers**. Plausible placeholders quoted back is the failure mode. [[feedback-never-fabricate-ic-numbers]].
- For each numeric claim added or edited in this revision: confirm the value appears in the context MD or in a corpus file with the source cited next to it.
- If a number can't be sourced: replace with a TBU box pointing to the source file. Example:
  ```html
  <div class="tbu">
    <div class="tbu-label">TBU — Pending Returns Model</div>
    <div class="tbu-title">5-yr Forward P&L Summary</div>
    <div class="tbu-sub">Insert from TWC returns model: doors / revenue / EBITDA by year. Numbers come straight from the model.</div>
  </div>
  ```

### People + firms

- Every external person added or edited needs a corpus `Source:` line citing the verified firm. [[feedback-no-hallucination-ask-instead]].
- Do NOT infer a firm from a domain, training data, or "this person was at X in 2024 so probably still is." Ask the user instead.
- Verified Bungalow roster lives at [[project-bungalow-people-roster]] for that deal.

### Quotes

- Every direct quote (`"…"` or `<i>"…"</i>`) must trace to a transcript line with timecode or a written corpus excerpt.
- Paraphrase that drifts from the source is a fabrication. Re-read the corpus to ground.

### Audience register

- IC artifacts strip internal owners ("Sean to follow up"), attribution ("Tom asked"), internal vendor names (Campfire, QuickBooks), and "in-flight" framing. [[feedback-ic-deck-audience-register]].
- Run audience-register filter on every revision pass — don't ship internal team-tracker language to the IC.
- **Tone is even-keel and factual.** No salesy adjectives ("only material open question", "not a turnaround", "transformation"). [[feedback-ic-even-keel-tone]].
- **Spoon-feed the IC.** IC has not been in the weeds. Every bullet must add value to a fresh reader. Don't caveat stats they've never seen; introduce the stat first. [[feedback-ic-spoon-feed-no-internal-context]].
- **Key takeaways follow the rubric:** what we learned / what is still open / what needs to be learned / how we'll close it. [[feedback-ic-key-takeaway-rubric]].

### Internal consistency (cross-slide)

The deck cannot contradict itself. The corpus check (above) is necessary but not sufficient — the verify pass must also cross-check claims across slides.

- **Build a claim ledger.** As Pillar 2 walks each slide, record every load-bearing claim with `{ slide, claim_type, normalized_value }` — e.g., `{ slide: 3, type: "deal_structure", normalized: "investment contingent on Seattle deal" }` and `{ slide: 14, type: "next_step", normalized: "Seattle deal closing optional" }`.
- **Diff the ledger.** Any two claims of the same `claim_type` whose `normalized_value` conflicts go on a `contradictions[]` list returned to the orchestrator.
- **Common contradiction shapes Sam has flagged:** deal-structure contingencies (Seattle deal mandatory vs. optional); workstream status (one slide says "decided", another says "open"); date claims (this week vs. next week — see tense check below); advisor scope (one slide says external advisor sought, another says we're not sourcing one).
- A `contradictions[]` non-empty list is a hard fail. Do not declare verify pass green with internal contradictions outstanding.

### Tense reconciliation against the presentation date

Every date claim ("this week", "last week", "next week", "yesterday", "on site this week", "we will present...") in a deck slide is read by the IC against the **planned presentation date**, not the model's "today" or the transcript date.

- The orchestrator passes `presentation_date` (ISO yyyy-mm-dd) to the verify pass. If absent, **escalate** — do not guess.
- For every date phrase or relative-tense claim in a revised slide:
  1. Anchor: find the underlying event in the corpus (transcript line, calendar invite, email date).
  2. Compute the offset from that event to the `presentation_date`.
  3. Rewrite the phrase from the IC's perspective on the presentation date. Friday transcript saying "on site next week" → if presentation is Monday following, the slide must read "on site last week" (the trip is now in the past from the IC's seat).
- Mark each tense rewrite in the verify report; the user should be able to scan tense fixes at a glance. Memory rule: [[feedback-presentation-date-tense-check]].

### Workstream + advisor enumeration whitelist

Sam has twice now flagged hallucinated workstream names and hallucinated advisor mentions (SaxeCap when never discussed; "Industry Advisor" and "Other Advisor" presented as workstreams; "external advisor for biz/commercial DD" when the team never said that). Honor-system "don't hallucinate" isn't holding for these two categories — needs structural enforcement.

- **Build the whitelist from the corpus first.** Before walking the deck, the verify subagent parses the most recent workstream summary (Slack canvas, IC notes, DD plan) and emits two lists:
  - `workstream_whitelist[]` — canonical workstream names actually used by the team this week
  - `advisor_whitelist[]` — every advisor / firm actually engaged on this deal, with role
- **Compare deck to whitelist.** Any workstream-style label in the deck that's not on `workstream_whitelist[]`, or any advisor/firm name that's not on `advisor_whitelist[]`, becomes a `whitelist_violation[]` entry.
- **Treat as hallucination.** Whitelist violations are reported under `unsourced_people` (advisors) or as a new `unsourced_workstreams[]` field — fix is either drop, rename to canonical, or escalate to user.

## Pillar 3 — No overflow at 1920×1080

Every slide must satisfy `slide.scrollHeight ≤ slide.clientHeight` when rendered headless at the target resolution. [[feedback-verify-slide-overflow-before-done]].

### Mechanical check

1. Run `scripts/overflow_probe.html` against the deck via `scripts/run_overflow_check.ps1`.
2. The probe loads the deck in an iframe at 1920×1080, measures every `.slide` element, and dumps the JSON measurements via `--dump-dom`.
3. Any `slide_overflow > 0` is a hard fail. Most common causes:
   - Body content too tall for `calc(var(--slide-h) - 200px - 52px)` — header + footer.
   - Image with `max-height` too generous combined with text below.
   - Three-column bullet block with too many items per column.

### Visual check

After overflow probe passes, screenshot every slide via headless Chrome `--screenshot` and Read each PNG. Spot-check:
- Body content not clipped at the bottom.
- Text not extending under the footer's `border-top`.
- Right-column content not running off the right edge.

## Failure routing

| Failure | Fix path |
|---|---|
| Image text illegible | Re-export from source per `image-re-export-playbook.md` (Defects 1-3) — fix dimensions/fonts, never just height |
| P&L / table top has stray dates row or whitespace | Tighten export range per playbook Defect 4 |
| P&L / table bottom has `Check` row or empty row-label stubs | Tighten export range per playbook Defect 4 |
| Naked output (no commentary) | Either add corpus-sourced commentary or remove the slide |
| Unsourced number | Replace with TBU box; ask user for source |
| Unsourced person/firm | Ask user; do not infer |
| Unsourced quote | Drop the quote or re-pull from transcript |
| Internal-audience language | Strip per audience-register-filter |
| Salesy adjectives ("only material", "not a turnaround", "transformation") | Rewrite even-keel per [[feedback-ic-even-keel-tone]] |
| Bullet doesn't add value to an out-of-the-weeds IC reader | Rewrite per spoon-feed rule, or remove the bullet |
| Caveat references a stat the IC has not been shown | Introduce the stat first, then qualify — or drop |
| Internal contradiction (slide N vs. slide M) | Reconcile against corpus; whichever is wrong gets fixed |
| Tense wrong vs. presentation date | Rewrite from IC's perspective on the presentation date |
| Workstream/advisor not in whitelist | Drop, rename to canonical, or escalate to user |
| Slide overflow | Reduce font sizes, trim content, or split the slide |

## Done criteria

All three pillars green:
- [ ] Every image re-Read post-fix; text legible at chat-display size.
- [ ] Every embedded output has adjacent commentary block.
- [ ] Every number/name/quote in the revised slides traces to a corpus line.
- [ ] Audience-register filter run; no internal-tracker language present.
- [ ] Tone is even-keel; no salesy adjectives in any revised slide.
- [ ] Spoon-feed rule applied; no caveats reference stats the IC hasn't seen.
- [ ] Key takeaways follow the learned / open / to-learn / closing rubric.
- [ ] Claim ledger built and `contradictions[]` empty.
- [ ] `presentation_date` was passed in and every tense claim reconciled.
- [ ] Workstream + advisor whitelists built; no `whitelist_violations[]`.
- [ ] Headless 1920×1080 overflow probe returns `slide_overflow: 0` on every slide.
- [ ] Screenshots of every revised slide reviewed by the model before handoff to user.
