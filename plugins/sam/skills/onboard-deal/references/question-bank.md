# Onboarding question bank

The standard question set for `/onboard-deal`. Adapt to the deal; do the homework (memories + vault + ~60s web) *before* asking so questions are sharp, not generic. Batch them. Use structured `AskUserQuestion` for enumerable choices, conversational for open-ended.

Generic, zero deal data — deal specifics come from the user's answers at run time.

## Gate 1 — Frame the deal (Phase 0)

**Deal shape**
- What is this deal, in a sentence? (thesis)
- What stage is it at? (sourcing / diligence / IC / signed / closed / portco)
- What's the structure? (buyout / growth / recap / merger / carve-out / financing)
- What codename(s) and real-world name(s) does it go by? → **project aliases** (load-bearing for routing). Confirm each; flag any < 3 chars or that are substrings of other deals.

**The parties** (for each org found in files/research — confirm side, don't assume):
- Is <Org> the counterparty, an advisor (to whom?), our side, or a portco?
- What's their role on the deal?
- _(structured AskUserQuestion works well here — one question per org, options = the side categories)_

**Key people** (for each person found):
- Who is <Name> — org, role?
- What's your relationship / read on them? (drives the persona; keep it shareable — assume they read their own file)

**The file group**
- Where did these files come from? (data room / counsel / management / banker)
- For each cluster of files: what is this, and where does it belong? (which deal, which doc type)

**The inbox**
- Confirm the exact Outlook folder name to sweep.
- How far back should the sweep go? (days)

## Gate 2 — File routing (Phase 2)

For each file the path-classifier left in `_inbox/files/_unassigned/` or flagged low-confidence:
- This file (`<title>`) didn't auto-route. Does it belong to <slug>, another deal, or is it a general reading? _(offer the classifier's candidates as options)_
- _(For ambiguous ones, also ask what the doc is, to enrich its distillation.)_

## Gate 3 — Important conversations (Phase 3)

After the email sweep:
- Which of these threads are the conversations that actually matter? _(list the top threads by participant/subject)_
- For each flagged thread: what's your read / what was really going on? → backfills `sam_take` + `lens` (no TODO placeholders).
- Any emails that landed in `_inbox` or under the wrong deal? Where do they belong?

## Gate 4 — Enrichment spot-check (Phase 4)

- Here's the persona I wrote for <Name> / the deal opinions / the project summary — anything wrong? _(corrections apply same-turn.)_
