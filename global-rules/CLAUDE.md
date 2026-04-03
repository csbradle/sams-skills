# Global Rules

## progress.md — Mandatory Session Tracking

Every project MUST have a `progress.md` file at the repository root. Update it at the **start** and **end** of every session, and after any major milestone within a session.

### When starting a session:
1. Read `progress.md` if it exists to restore context
2. Add a new session entry with today's date and session start time
3. Review outstanding TODOs from prior sessions and carry forward anything still relevant

### When ending a session (or when the user says "done", "stop", "wrap up", "handoff", etc.):
1. Update all sections below for the current session
2. Ensure the session log captures the full arc of work done

### Required Sections

```markdown
# Progress — [Project Name]

## Current Session — YYYY-MM-DD

### Session Goal
One-line summary of the primary objective for this session.

### Progress Made
- Bullet list of everything accomplished this session
- Include file paths and line numbers for code changes
- Note what was attempted vs what actually landed

### Outstanding TODOs
- [ ] Remaining work from this session
- [ ] Carried forward from prior sessions (note original date)
- [ ] Newly discovered work

### Decisions Log
Each decision should be tagged:
- **[USER]** — Explicit decision made by the user
- **[CLAUDE]** — Decision made autonomously by Claude (include reasoning)
- **[JOINT]** — Decision reached through discussion

Format:
- **[TAG] Decision description** — Context: why this was decided. Alternatives considered: X, Y. Trade-offs accepted: Z.

### Open Questions
- Questions that came up but weren't resolved
- Things that need user input in a future session
- Uncertainties about architecture, requirements, or approach

### Future Ideas & Aspirations
- Features or improvements mentioned but not yet planned
- "Wouldn't it be cool if..." ideas that surfaced during work
- Long-term architectural visions discussed

### Session Log
Chronological narrative of the session. Include:
- **Exploration & Discovery** — What we searched for, what we found, dead ends
- **Architectural Decisions** — Why we structured things a certain way
- **Mistakes & Corrections** — Claude errors (hallucinated APIs, wrong assumptions, overcomplicated solutions), user prompt corrections (ambiguous asks that needed clarification, scope changes mid-task)
- **Blockers Hit** — What stopped progress and how it was resolved (or not)
- **Key Back-and-Forth** — Significant disagreements or pivots in approach

Be honest and specific. Example entries:
- "Claude initially generated a REST endpoint but user clarified this should be a background job — wasted ~10 min"
- "User asked to 'fix the bug' without specifying which one — after clarification, it was the race condition in worker.ts"
- "Claude hallucinated a `prisma.upsertMany()` method that doesn't exist — switched to transaction with individual upserts"

### Technical Debt & Risks Identified
- Shortcuts taken that should be revisited
- Code that works but isn't ideal
- Performance concerns noticed but not addressed

### Files Changed
- List of files created, modified, or deleted this session
- Brief note on what changed in each

---
## Prior Sessions
(Previous session entries are kept below, most recent first)
```

### Rules for maintaining progress.md:
1. **Never delete prior session entries** — append new sessions above old ones
2. **Be brutally honest** in the session log — this is for learning, not PR
3. **Tag every decision** — no untagged decisions in the decisions log
4. **Convert relative dates to absolute** — "next week" becomes "2026-04-09"
5. **Keep it concise but complete** — each section should be scannable in 30 seconds
6. **If the session is very short** (< 5 minutes, single question), skip the full template and just add a one-line entry under the current date
