# Slop lint — banned-phrase list (flag-only)

Read by `scripts/lint_deck.ps1` AND by writing/verify agents as a style reference. Flag-only: hits never block a deck, they get listed in the handoff for rewrite.

**Honest split of who enforces what (keep this accurate — the doc claiming un-implemented mechanics is itself a review finding):**
- **Mechanical (lint_deck.ps1):** literal phrases from the two sections marked [MECHANICAL] below (parser reads `- ` bullets from "## Salesy" up to "## Structural"); quoted text (`"…"`) excluded; "leverage" excluded near financial terms; em-dash-chained triads and arrow chains (pattern-based). If this file is missing, the script reports `slop_check: skipped` — it does NOT silently pass.
- **Agent rubric only (NOT mechanical):** citation-aware superlatives (bare `only/best/first/biggest` are skipped by the script entirely; `fastest-growing`/`unmatched` flag regardless of citation — writers/verifiers apply the citation judgment), three-adjective pileups, and any context judgment beyond the exclusions above.

Scope: deck body text (claim-bearing prose + commentary zones). Excluded zones: source lines, footers, TBU callouts, code/CSS.

Relationship to `audience-register-filter.md`: that file strips *internal-audience leakage* (owners, "who asked", internal vendors); this file flags *writing quality*. Both run; don't merge them.

## Salesy / definitive framing [MECHANICAL] (existing IC-voice bans — keep in sync with update-deck-verify Step 3b)
- transformation
- transformational
- de-risked
- clear winner
- proven
- massive opportunity
- only material
- not a turnaround
- best-in-class
- category leader
- game-changing
- compelling opportunity

## Uncited superlatives [MECHANICAL for multi-word terms; bare single words are agent-rubric]
- only
- best
- first
- biggest
- fastest-growing
- unmatched

## Generic AI-slop markers [MECHANICAL]
- delve
- robust
- seamless
- seamlessly
- holistic
- synergistic
- cutting-edge
- state-of-the-art
- leverage (as a verb — "leverages the platform"; the noun "leverage" in a capital-structure sense is fine and excluded by the financial-context rule below)
- it's worth noting
- it is worth noting
- in today's landscape
- in the current environment
- needless to say
- at the end of the day
- paradigm

## Structural slop patterns (parser stops HERE — bullets below are not literal phrases)
- em-dash-chained triads ("fast — cheap — durable") — MECHANICAL (pattern in lint_deck.ps1)
- arrow chains in prose ("A → B → fails") outside tables/figures — MECHANICAL
- three-adjective pileups ("robust, scalable, seamless") — AGENT RUBRIC (not implemented mechanically)

## Context exclusions (implemented in lint_deck.ps1)
- "leverage" within ~40 chars of: debt, net, gross, turns, x, ratio, covenant → financial term, never flag
- Text inside direct quotes (`"…"`, up to ~300 chars) → never flag (the quote is the quote)
- Text inside `class="tbu"` callouts, footers, source lines → never flag (zone mask)
