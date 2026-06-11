# 05.25 v03 IC deck retrospective — why each rule exists

The current rule structure across draft-IC-Deck (orchestrator), build-IC-Deck-context (Pass 1), and render-IC-Deck-html (Pass 2) is the product of Sam's 14-item feedback list on `Bungalow IC Update — 05.25 v03.html`. Each rule below maps to one or more v03 failures.

## The 14 v03 failures (Sam's redlines)

### 1. Exec summ over-detail
"Returns model still in flight" on a page IC would see when the model should be locked. ERP vendor names (Campfire/QuickBooks) on summary slide. "What we've done" too operational — owner names, version numbers.
→ **Rule:** IC audience register filter (orchestrator MD review + Pass 1 silent filter). See `audience-register-filter.md`.

### 2. Gating questions section too long
List mixed material questions with nitty data-request items. No prioritization.
→ **Rule:** Top 3 in a bullet, optional sub-bullets. See `audience-register-filter.md` "Gating questions" entry.

### 3. Banker firm hallucinated
v03 said "Brandon Dobel, Lincoln International — banker." Truth: BGL. The deal-folder file is literally named `BGL-Banker-Brandon-Dobel-Bungalow-*.md` and the prior skill anchors already said BGL. The build still hallucinated.
→ **Rule:** Hallucination guardrail (Pass 1 §5). Every external person needs a corpus `Source:` line. If unknown, ASK Sam — never infer. See `[[feedback-no-hallucination-ask-instead]]` memory and `[[project-bungalow-people-roster]]`.

### 4. Sub-letter pages (1b, 3b, 6b, 10b, 11b)
5 sub-letter pages across the deck. Sam wants each page to be its own discrete numbered page.
→ **Rule:** No sub-letter pages, EVER (render-IC-Deck-html §9). Density → next sequential number, or a 2-row same-page layout.

### 5. Diligence Workplan listed Chris Laurence as workstream owner
Per the 4/22 transcript, Chris intro'd Sam to Kevin Ortner but declined to advise (pursuing full-time home-services role). He should not appear in any workstream or advisor list. Also: internal owners ("Andrew/Kash/Zach/Lori") should not be in IC-facing columns.
→ **Rule:** Advisor-page composition — external advisors actively engaged ONLY (Pass 1 §7). Plus: audience-register strip of internal owners.

### 6. Open questions had attribution
"Mgmt 5/5+5/15 asked" inline. Internal email quotes in answer cells.
→ **Rule:** Audience register — strip "who asked" attribution and internal quotes (see `audience-register-filter.md`).

### 7. Consolidated P&L recreated instead of reused
Sam explicitly said use the same output from the DD agenda. The build redid it.
→ **Rule:** Reuse fidelity (render-IC-Deck-html §10). Same orientation, same column set, same period granularity. No "I'll improve it" redesigns.

### 8. "What Bungalow Has Built" included internal ERP
Page 5 listed Bungalow's accounting stack (QuickBooks/Campfire/Cloud9). The page is about PM operations tech, not internal finance.
→ **Rule:** PM operations tech only (Pass 1 §8). Strip internal ERP / GL / bookkeeping from this page.

### 9. Margin bridge rotated and commentary separated
The DD agenda had the bridge with rows = drivers, columns = periods. v03 rotated it AND put commentary on a separate page (6b). Both wrong.
→ **Rules:** (a) Reuse fidelity — reproduce identically (no rotation); (b) Commentary co-located on the SAME page as the output (render-IC-Deck-html §5). 2-row layout (output top, commentary bottom) on a single page.

### 10. Quarterly data dumped where annual was cleaner; no TBU callout for confounding event
12 quarterly columns on a P&L. No yellow callout for "redo this excl. the 300-door customer Haven lost pre-acquisition."
→ **Rules:** (a) Annual columns default; quarterly only when quarterly IS the story (render-IC-Deck-html §3); (b) TBU callouts for known confounding events (render-IC-Deck-html §8).

### 11. Andrew + Kash on the advisor page
They're CEO + CFO (founders). They get a mgmt page or inline reference, not an advisor column.
→ **Rule:** Advisor-page composition (Pass 1 §7).

### 12. M&A pipeline = just a table, no commentary
Mgmt calls had significant per-target color. IC shouldn't have to interpret raw data.
→ **Rule:** Spoon-feed commentary co-located (render-IC-Deck-html §5). For tables built from mgmt-call data, commentary MUST cite what mgmt told us about those numbers — per-target where applicable.

### 13. Cleveland deepening thesis page was confusing
No standalone framing — required prior context to understand.
→ **Rule:** Standalone-page test (render-IC-Deck-html §6). Read each page cold; if it doesn't explain itself in the first 2 lines, add framing.

### 14. Missing "APPENDIX" divider page
A1 read as "yet another slide." No visual break.
→ **Rule:** Dedicated appendix divider page (render-IC-Deck-html §7).

## Latest mgmt transcript not folded in (Sam's separate point)

Open questions list included things the 5/15 mgmt call had answered (per-door revenue trend, ERP transition cause, legacy churn rate).
→ **Rule:** Close open questions against the LATEST mgmt transcript before Pass 2 (Pass 1 §4). Newest file in `08. Notes/02. With Management/` is mandatory full-read.

## How to use this retro

When a future Pass 1 or Pass 2 subagent is uncertain about whether a particular treatment is correct, the answer is often in here. Search for the failure-mode keyword (banker, ERP, attribution, rotation, quarterly, advisor, divider, callout) — the corresponding rule + the v03 evidence are documented above.

When a NEW failure mode shows up in a future deck redline, append it here with a new section number, then add the corresponding rule to the right sub-skill SKILL.md. Keep the retro alive — it's the institutional memory for why each rule exists.
