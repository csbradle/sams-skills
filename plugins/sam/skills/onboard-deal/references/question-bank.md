# Onboarding question bank (v2)

The Stage-1 interview surface. **Do the homework FIRST** (memories + vault footprint + ~60s
web + filename scan) and present anything answerable as a pre-filled confirmation — never ask
what a probe or the corpus can answer. **At most TWO themed bundles.** Use structured
`AskUserQuestion` for enumerable choices, conversational asks for open-ended context.
Generic, zero deal data — specifics come from the user at run time. On a CATCH-UP deal, skip
every question whose answer already exists (state file answer-of-record, frontmatter, corpus)
— confirm only what's missing or contradicted.

## Bundle 1 — Identity, parties, plumbing

**Deal shape**
- What is this deal, in a sentence? (thesis)
- What stage? (sourcing / diligence / IC / signed / closed / portco)
- What structure? (buyout / growth / recap / merger / carve-out / financing)
- **Deal type** (drives which stages apply): buyside live / sellside / portco / watching.
- Codename(s) + real-world name(s) → **aliases** (load-bearing for routing). Confirm each;
  flag any <3 chars or substrings of other deals. Which are deal-UNIQUE (safe to route on)?
- Proposed **slug** (new deals): confirm.

**The parties** (per org found in files/research — confirm side, never assume):
- Is <Org> the counterparty, an advisor (to whom?), our side, or a portco? Role on the deal?
- (Structured AskUserQuestion: one question per org, options = the side categories.)

**Key people** (per person found):
- Who is <Name> — org, role? Your relationship/read? (drives the persona; keep it shareable —
  assume they read their own file)

**Plumbing**
- The exact **Outlook folder** name(s) for this deal (resolve-folder verifies IDs in Stage 2).
- Where is the **file group** and where did it come from? (data room / counsel / management / banker)
- How far back should the first email sweep go? (recent-first; deeper passes come later)

## Bundle 2 — History, workstreams, numbers

**Deal history / timeline** (→ `milestones:` + `## Deal timeline`)
- Walk me through the dated events: platform close, tuck-ins, refis/recaps, rescue
  financings, equity rounds — date, orgs + their roles, one line each.
- Which document is the **authoritative cap table**? (recorded as pointer + one-line summary,
  never a maintained ledger)

**Workstreams** (→ the deal board)
- What are this deal's workstreams, in your words? (live deals often QoE / legal-SPA /
  market work / lender / buyers-if-sellside; portco workstreams are bespoke)

**The underwriting case** (EVERY deal — load-bearing for variance-vs-underwrite)
- **Where is the underwriting case?** Which exact file/version is the IC-blessed pre-close
  model (vs the budget, lender model, paper LBO, post-close VCP)?
- → Stage 4 tags it `underwrite_case` + pins it canonical. Untagged = no baseline.

**The canonical cash source** (EVERY portco / held deal)
- Is there a recurring management cash-flow / liquidity forecast — who sends it, to which
  folder, on what cadence? (This is the canonical cash view — never a valuation memo's
  forward rows.) → tagged `cash_flow_forecast`; sender/folder recorded per-deal.

**Financial sources** (→ Stage 5 registration; skippable)
- Where do the budget and recurring actuals live (file / sender / folder / cadence)? Which
  tab is the summary P&L? (Stage 5 reads the workbook and builds the exact cell map with you.)

## Stage-3 gate — file routing

Per unassigned / low-confidence file: "`<title>` didn't auto-route — this deal, another deal,
or general reading?" (offer the classifier's candidates). For ambiguous ones, also ask what
the doc IS (enriches its distillation).

## Stage-4 gate — folder grounding (Pass 1, one per source folder)

"These N files came from `<folder>` — who produced them, what angle/incentive (seller / our
side / lender / advisor), which phase of the deal?" Auto-fill from known folder/sender
context; show assumptions; per-file questions only for Pass-2 residuals.

## Stage-6 gate — important conversations

- Which of these threads are the conversations that actually matter? (list top threads by
  participant/subject from the sweep tally)
- Per flagged thread: what's your read / what was really going on? → backfills `sam_take` +
  `lens` richly (no TODO placeholders).
- Any emails that landed in `_inbox` or under the wrong deal? Where do they belong?

## Stage-7 gate — enrichment spot-check

"Here's the persona I wrote for <Name> / the deal opinions / the progress narrative — anything
wrong?" (corrections apply same-turn and update inference rules per the correction loop)
