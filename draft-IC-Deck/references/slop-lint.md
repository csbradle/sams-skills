# Slop lint — banned-phrase list (flag-only)

Read by `scripts/lint_deck.ps1` (it greps this file's `- ` bullet lines under each `## ` section — keep the format) and by writing/verify agents as a style reference. Flag-only: hits never block a deck, they get listed in the handoff for rewrite.

Scope: deck body text (claim-bearing prose + commentary zones). Excluded zones: source lines, footers, TBU callouts, code/CSS.

Relationship to `audience-register-filter.md`: that file strips *internal-audience leakage* (owners, "who asked", internal vendors); this file flags *writing quality*. Both run; don't merge them.

## Salesy / definitive framing (existing IC-voice bans — keep in sync with update-deck-verify Step 3b)
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

## Uncited superlatives (flag when no citation on the same line)
- only
- best
- first
- biggest
- fastest-growing
- unmatched

## Generic AI-slop markers
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

## Structural slop patterns (regex class — lint_deck.ps1 implements these as patterns, not literals)
- em-dash-chained triads ("fast — cheap — durable")
- arrow chains in prose ("A → B → fails") outside tables/figures
- three-adjective pileups ("robust, scalable, seamless")

## Context exclusions (lint_deck.ps1 must honor)
- "leverage" within 3 words of: debt, net, gross, turns, x, ratio, covenant → financial term, never flag
- Words inside direct quotes (`"…"`) → never flag (the quote is the quote)
- Words inside `class="tbu"` callouts, footers, source lines → never flag
