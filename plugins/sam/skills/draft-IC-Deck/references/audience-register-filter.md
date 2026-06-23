# IC audience register filter

Applied during Pass 1 (build-IC-Deck-context) AND by the orchestrator when reviewing the context MD before approving for Pass 2. Cross-reference: `[[feedback-ic-deck-audience-register]]` memory.

## The principle

The IC is NOT the deal team. They want to know we're making progress, who we're talking to, that questions are being answered. They do NOT want operational granularity. Strip everything below before it enters the context MD.

## Strip list

**Internal team names as owners**
No "Andrew/Kash/Zach/Lori owns X" columns in any DD workplan table. Workstreams are described by what they ARE, not who is internally driving them.
- ❌ "Returns model | Owner: Grady | Status: in flight"
- ✅ "Returns model | Status: pressure-testing v1 assumptions"

**"Who asked" attribution on open questions**
Questions are listed as questions, not as "Mgmt 5/5+5/15 asked" or "per Sean."
- ❌ "Per Sean 5/16: what's the playbook for Windermere integration?"
- ✅ "What's the playbook for Windermere integration?"

If we have an answer or partial answer, bullet it as a fact; don't quote who said it on what date.

**Internal vendor names adjacent to diligence**
No "Bungalow ERP cutover from QuickBooks to Campfire" on an exec-summary or PM-tech page. The IC doesn't need to know the ERP vendor. If it's load-bearing to a finding, it goes in detail pages — never in summary or PM-tech pages.
- ❌ Page 5 row: "New ERP / finance — Replaces QuickBooks + Cloud9 bookkeeper"
- ✅ (Row omitted entirely — not PM operations tech)

**Task ownership inside our team**
- ❌ "Lori delivering full GL transaction mapping Mon 5/18"
- ✅ "Full GL transaction mapping arriving early next week"

**Quotes from internal emails / Slack**
Open-questions cells should not contain "per Sean's 5/16 email" or "[Andrew flagged 5/15]." State the fact.
- ❌ "Per Sean's 5/16 deal team sync: 'doesn't seem heroic, but math needs more pressure'"
- ✅ "Returns model assumptions pressure-tested — within reasonable range; deeper sensitivity work in progress"

**"In flight" / "still being built" framing for IC-date deliverables**
Never say "returns model in flight" on a page IC will see on a date when the model should be locked. Either the model is in the deck by then, or the page is omitted / deferred.
- ❌ "Returns model in flight: Grady's 'what you need to believe' v1"
- ✅ (Page included with model, OR page omitted with note in deck spec)

**Gating questions = TOP material questions only**
Not the nitty data-request list. Name the top 3 in a bullet, optional sub-bullets. Don't make it a big section.
- ❌ 12-bullet list mixing "HC→P&L reconciliation" with "What's the new ERP vendor"
- ✅ Top 3: (1) Margin attribution PE-101 vs. tech, (2) Playbook portability to non-Cleveland metros, (3) Downside case at 2.0x MOIC floor

**Advisor feedback in exec summ = strongest convergence + main callouts**
Not a per-advisor recap. Synthesize.
- ❌ "Kevin Ortner said X. Brandon said Y. Rob said Z. Chris said W."
- ✅ "All 3 external advisors converge on tech-driven margin lift; Brandon flags concentration risk in Cleveland as the main pushback"

## Application contract

Pass 1 (build-IC-Deck-context) applies this filter silently during the MD build. In its return summary to the orchestrator, it lists what was stripped under:

```
Audience-register filter applied — items stripped:
  - Internal owner columns: <count> (workstreams: ...)
  - "Who asked" attributions: <count>
  - Internal vendor mentions: <list>
  - In-flight framing: <count>
  - Internal quotes: <count>
```

This lets Sam (via the orchestrator) spot-check what got cut at the MD-review gate. If something stripped was load-bearing, Sam re-adds it to the MD directly before Pass 2 spawn.

## Generalization

Same filter applies to:
- `[[emaildraft]]` for Adam-facing emails (see `[[feedback-adam-email-style]]`)
- `[[updatebung]]` for partner-visible canvas updates
- Any IC/partner-facing artifact
