---
name: founder-advisors
description: Pressure-test any founder problem against 7 expert personas (YC, Peter Thiel, Elon Musk, Brian Chesky, multi-time founder, Middle-America operator, PE MD-as-customer) running in independent context windows, then have 4 critic subagents (2 Claude + 2 Codex) review all 7 takes for blindspots, contradictions, and the strongest signal. Saves the full session to ~/founder-advisors-sessions/. Use when asked to "founder advisors", "advisor panel", "what would [Thiel/Musk/Chesky/YC] say", "pressure test this", or for any strategic founder decision worth a 360° take.
---

# /founder-advisors

A skill that runs a panel of seven founder advisors against a problem, then has four independent critics review all seven takes. Seven perspectives + four critiques + a synthesis = an 11-voice round-table on any decision.

## When to use

- Strategic founder decisions: vision, wedge, monopoly thesis, $100B framing, kill-vs-persist, pricing, fundraising, scope, market positioning
- Problems where one perspective is obviously insufficient
- When the user wants to stress-test their long-term thinking, not their 30-day plan
- When the user has already drafted a strategy and wants critical review from multiple lenses

## When NOT to use

- Small tactical decisions ("what color button?")
- Things that are objectively answerable ("what's 5+5?")
- Problems with clear domain-specific best practice that doesn't need a panel

---

## The seven advisors

| # | Persona | Voice | File |
|---|---------|-------|------|
| 1 | YC Advisor | Garry Tan + PG + Seibel + Dalton composite, current 2026 RFS thesis | `personas/yc-advisor.md` |
| 2 | Peter Thiel | Slow, philosophical, monopoly + contrarian-truth + secret | `personas/peter-thiel.md` |
| 3 | Elon Musk | Vision-first picker — civilizational scale, importance × probability, light of consciousness | `personas/elon-musk.md` |
| 4 | Brian Chesky | Designer-CEO, Founder Mode origin, 100-people-love + 11-star experience, taste over growth-hacking | `personas/brian-chesky.md` |
| 5 | Multi-time founder | Tired-but-not-bitter, runway-first, allergic to startup-speak | `personas/multi-time-founder.md` |
| 6 | Middle-America operator | Plainspoken Midwesterner, cash-flow brain, outside the AI bubble | `personas/middle-america-operator.md` |
| 7 | PE MD (the customer) | PE buyer of AI products — AI-curious, ROI-driven, allergic to buzzwords. NOT an investor — a target customer. | `personas/pe-md.md` |

---

## Orchestration

### Step 0: Get the problem statement

If the user invoked `/founder-advisors <problem>`, use that as the problem statement.

If the user invoked `/founder-advisors` with no argument or an empty string, use AskUserQuestion:

> "What problem do you want the advisors to weigh in on? Give me a sentence or three — what's the decision, what's the context, and what would 'good advice' look like."

Wait for the answer.

### Step 1: Load all 7 persona files + reviewer prompt

Read these files using the Read tool:

```
~/.claude/skills/founder-advisors/personas/yc-advisor.md
~/.claude/skills/founder-advisors/personas/peter-thiel.md
~/.claude/skills/founder-advisors/personas/elon-musk.md
~/.claude/skills/founder-advisors/personas/brian-chesky.md
~/.claude/skills/founder-advisors/personas/multi-time-founder.md
~/.claude/skills/founder-advisors/personas/middle-america-operator.md
~/.claude/skills/founder-advisors/personas/pe-md.md
~/.claude/skills/founder-advisors/reviewer-prompt.md
```

Hold the contents in working memory for Steps 2 and 4.

### Step 2: Spawn 7 advisor subagents in parallel

Send a SINGLE message with 7 parallel `Agent` tool calls. This is critical — they must run concurrently with fresh context per persona.

Each call:
- `subagent_type`: `general-purpose`
- `description`: e.g. "YC Advisor giving advice"
- `prompt`: the full persona file content (verbatim — do NOT paraphrase) + the section delimiter below + the user's problem statement + the closing instructions:

```
<paste full persona file content here, verbatim>

═══════════════════════════════════════════════════════════
A founder is asking you for advice on this problem:
═══════════════════════════════════════════════════════════

<paste user's problem statement here>

═══════════════════════════════════════════════════════════
INSTRUCTIONS:

Respond using the "Output Format When You Ask Me For Advice" section of your persona above. Stay in character throughout. Do not break the fourth wall — do not say "as the YC advisor would..." or "from this persona's perspective..." — speak as them, in first person.

Reply with your advice ONLY. No greeting, no signoff, no meta-commentary.

Length: 400-700 words.
```

**Note on the PE MD:** they are the user's *customer*, not investor. If the user's question is about whether to build a product / whether their wedge is real / what the $100B vision looks like, the PE MD should answer as the procurement-side buyer of that product, not as a sponsor underwriting the user's company. Their persona file makes this explicit.

Wait for all 7 to return. Each will give their structured advice.

### Step 3: Build the combined corpus

Compose a markdown blob holding all 7 advisor responses, formatted as:

```
# Seven Advisor Perspectives on: <user's problem>

## YC Advisor said:
<their full response>

## Peter Thiel said:
<their full response>

## Elon Musk said:
<their full response>

## Brian Chesky said:
<their full response>

## Multi-Time Founder said:
<their full response>

## Middle-America Operator said:
<their full response>

## PE Managing Director (the customer) said:
<their full response>
```

### Step 4: Spawn 4 critic subagents in parallel

Send a SINGLE message with 4 parallel tool calls. Mix of Agent and Bash:

**Critic 1 — Claude reviewer A** (Agent, general-purpose):
- prompt: full reviewer-prompt.md content + "═══" delimiter + the full 7-perspectives corpus from Step 3 + "Provide your critical review now using the exact output format above."

**Critic 2 — Claude reviewer B** (Agent, general-purpose):
- Same as Critic 1. The fresh-context spawn alone produces enough variance; identical prompts on identical inputs through different cold starts give independent reads.

**Critic 3 — Codex reviewer A** (Bash):
First check if codex is on PATH. If yes, write the full reviewer prompt + corpus to a temp file (`/tmp/founder-advisors-reviewer-input.md` on Unix; `$env:TEMP\founder-advisors-reviewer-input.md` on Windows) and call:

```bash
codex exec --model gpt-5.5 -- "$(cat <temp-file>)"
```

Capture stdout as the critic's response.

**Critic 4 — Codex reviewer B** (Bash):
Same as Critic 3. Run as a separate Bash call to get a fresh codex invocation. (Codex starts a new context per `codex exec` call.)

**Codex unavailability fallback:** If `command -v codex` returns nothing, replace Critics 3 and 4 with two more Agent (general-purpose) Claude reviewers — for a total of 4 Claude reviewers. Note this in the final summary so the user knows the codex critics didn't run.

Wait for all 4 to return.

### Step 5: Save the session file

Generate the slug:
- Take the user's problem statement
- Pull 3 meaningful words (skip articles / pronouns / fillers)
- Lowercase, hyphenate
- Example: problem "should I raise a seed round or bootstrap?" → slug `raise-vs-bootstrap`

Generate the path. On Unix:

```bash
DATE=$(date +%Y-%m-%d)
SLUG=<your-3-word-slug>
mkdir -p ~/founder-advisors-sessions
SESSION_FILE=~/founder-advisors-sessions/${DATE}-${SLUG}.md
```

On Windows, use the equivalent with `$HOME\founder-advisors-sessions\` and ensure the directory exists with the Bash tool's `mkdir -p` (it works on Git Bash / WSL).

Write the session file using the Write tool, with this structure:

```markdown
# Founder Advisors Session — <YYYY-MM-DD>

## Problem Statement

<user's problem statement>

---

## Seven Advisor Perspectives

### YC Advisor

<full response>

---

### Peter Thiel

<full response>

---

### Elon Musk

<full response>

---

### Brian Chesky

<full response>

---

### Multi-Time Founder

<full response>

---

### Middle-America Operator

<full response>

---

### PE Managing Director (the customer)

<full response>

---

## Four Critical Reviews

### Reviewer 1 (Claude) — <reviewer's "Headline takeaway" line>

<full critique>

---

### Reviewer 2 (Claude) — <reviewer's "Headline takeaway" line>

<full critique>

---

### Reviewer 3 (Codex) — <reviewer's "Headline takeaway" line>

<full critique>

(or: Reviewer 3 (Claude — Codex unavailable))

---

### Reviewer 4 (Codex) — <reviewer's "Headline takeaway" line>

<full critique>

(or: Reviewer 4 (Claude — Codex unavailable))

---

## Synthesis

<YOUR meta-analysis as the orchestrating agent. 250-450 words. **Lead with vision/wedge/$100B-shape analysis, not 30-day execution plans.** The user is Sam Bradley — non-technical founder who has explicitly said he doesn't want tactical "ship by Friday" advice when he's asking strategy questions. Cover, in this order:>

- **The vision question:** Does this idea have a real wedge / monopoly / secret / network effect? Synthesize across advisors. If the panel converges on "no," say so. If it converges on "the wedge exists but you're describing it wrong," say what the right framing is.
- **The $100B-shape framing:** What does the most ambitious version of this look like? Which advisors saw a credible path; which didn't, and why?
- **Strongest convergence:** what 5+ advisors agreed on. Vision-level, not tactic-level.
- **Sharpest divergence:** the live debate that matters — and which side fits the founder's actual situation better.
- **Reviewer consensus blindspot:** what 3+ critics flagged that the panel missed.
- **Recommended action:** ONE sentence. The single most important thing to test, decide, or commit to. Strategic, not "talk to 30 customers this week."

Be direct. Sam prefers plain-English tradeoffs over balanced commentary.
```

### Step 6: Print summary to chat

After saving, print this summary block:

```
══════════════════════════════════════════════════════════
  FOUNDER ADVISORS — <slug>
══════════════════════════════════════════════════════════
  Saved: ~/founder-advisors-sessions/<date>-<slug>.md

  Each advisor's bottom line:
    YC:             <one sentence — extract from their "Bottom line">
    Thiel:          <one sentence>
    Musk:           <one sentence>
    Chesky:         <one sentence>
    Multi-time:     <one sentence>
    Middle-America: <one sentence>
    PE MD (cust.):  <one sentence>

  Reviewer signals:
    Strongest convergence:  <what 5+ advisors agreed on, vision-level>
    Sharpest divergence:    <where they split>
    Most-flagged blindspot: <consensus from reviewers>

  Recommended next move:
    <one sentence from your synthesis — strategic, not tactical>
══════════════════════════════════════════════════════════

Full session in the file above. Open it for the long read.
```

---

## Important implementation notes

- **Fresh context is non-negotiable.** Each persona Agent must be a separate `Agent` tool call. Each codex critic must be a separate `Bash` call. Do not call personas sequentially in your own context — that pollutes the persona's worldview with your conversation.
- **Pass persona files VERBATIM to the Agent prompts.** Do not paraphrase. The persona files were carefully crafted to be system prompts — preserve them exactly.
- **Save BEFORE printing.** Write the session file before printing the summary, in case the print fails or context drops.
- **The synthesis is YOUR contribution.** The 7 advisors and 4 critics each had their say. The synthesis section is the orchestrating agent's call — be opinionated, not neutral.
- **Weight vision over tactics in the synthesis.** Sam has been explicit: when he asks a strategy/wedge/$100B question, he is already selling and does not want a 30-day execution plan as the headline. The synthesis should answer the strategy question first; tactics are subordinate.
- **No backwards-compatibility shims, no defensive abstractions.** If a persona file is missing, fail loudly with a clear error. Don't try to fall back to a generic prompt — the user invoked this skill specifically to get the personas.

---

## Cost / time estimate

Per invocation:
- 7 persona Agents in parallel: ~30-60 seconds each → bottleneck is the slowest
- 4 critic subagents in parallel: ~30-60 seconds each
- Total wall-clock: ~2-4 minutes
- Token cost: ~60-180K tokens depending on persona response length
- Codex calls: 2x small charges per session (negligible)

---

## Dogfood reminder

The user (Sam Bradley) built this skill specifically because the PE MD persona is his future customer base. The PE MD persona is now framed as a *customer* (procurement decision-maker for AI products at a PE fund), not as a sponsor evaluating Sam's company as an LP investment. Pay attention to whether the PE MD's reads on Sam's actual product are sharp — that's the highest-leverage feedback loop in this skill.
