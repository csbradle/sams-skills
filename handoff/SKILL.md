---
name: handoff
version: 2.0.0
description: |
  Checkpoint and sync: captures current state of work, ensures all code/files
  are committed and pushed to GitHub, and updates project docs. Safe to run
  multiple times per session — after planning, after implementation, after QA,
  or at end of session. Nothing gets lost.
  Use when: "handoff", "checkpoint", "save", "push", "sync", "end session",
  "save state", "wrap up", "I'm done for now", "switching to another project",
  "closing out", after completing a phase of work, or before ending any session.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# /handoff — Checkpoint & GitHub Sync

One command. Everything gets saved, committed, pushed, and documented.
Run it after each phase of work — planning, implementation, QA, or end of session.
The next session (or the next person) picks up with zero context loss.

**The problem this solves:** Claude sessions lose context between conversations.
Files get left uncommitted, branches go unpushed, and the next session rebuilds
work that already exists. /handoff makes that impossible.

**Safe to run multiple times per session.** Each run updates the existing session
entry in progress.md (accumulates, never duplicates) and overwrites HANDOFF.md
with the latest snapshot.

---

## Step 0: Gather Complete Project State

Run ALL of these in sequence to build a full picture:

```bash
echo "=== REPO INFO ==="
basename "$(git rev-parse --show-toplevel 2>/dev/null)"
git remote get-url origin 2>/dev/null || echo "NO REMOTE"

echo "=== CURRENT BRANCH ==="
git branch --show-current

echo "=== ALL LOCAL BRANCHES ==="
git branch -vv

echo "=== GIT STATUS (full) ==="
git status

echo "=== UNCOMMITTED CHANGES ==="
git diff --stat
git diff --cached --stat

echo "=== UNTRACKED FILES ==="
git ls-files --others --exclude-standard

echo "=== STASHED CHANGES ==="
git stash list

echo "=== RECENT COMMITS (last 20) ==="
git log --oneline -20

echo "=== REMOTE SYNC STATUS ==="
git fetch --all 2>/dev/null
for branch in $(git branch --format='%(refname:short)'); do
  LOCAL=$(git rev-parse "$branch" 2>/dev/null)
  REMOTE=$(git rev-parse "origin/$branch" 2>/dev/null || echo "NO_REMOTE")
  if [ "$REMOTE" = "NO_REMOTE" ]; then
    echo "$branch: NOT PUSHED (no remote tracking)"
  elif [ "$LOCAL" = "$REMOTE" ]; then
    echo "$branch: UP TO DATE"
  else
    AHEAD=$(git rev-list --count "origin/$branch..$branch" 2>/dev/null || echo "?")
    BEHIND=$(git rev-list --count "$branch..origin/$branch" 2>/dev/null || echo "?")
    echo "$branch: AHEAD $AHEAD / BEHIND $BEHIND"
  fi
done
```

Then check for open PRs:

```bash
echo "=== OPEN PULL REQUESTS ==="
gh pr list --state open --json number,title,headRefName,baseRefName,url,createdAt,isDraft --limit 20 2>/dev/null || echo "gh CLI not available"
```

Then check for key project files:

```bash
echo "=== KEY FILES ==="
for f in CLAUDE.md TODOS.md README.md CHANGELOG.md VERSION .env.example; do
  [ -f "$f" ] && echo "EXISTS: $f" || echo "MISSING: $f"
done

echo "=== PLAN FILES ==="
find . -maxdepth 3 -name "*.plan.md" -o -name "*-plan-*.md" -o -name "PLAN.md" 2>/dev/null | head -10

echo "=== GSTACK ARTIFACTS ==="
SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
ls -lt ~/.gstack/projects/$SLUG/ 2>/dev/null | head -15
```

---

## Step 1: Ensure Everything Is Committed

Check if there are uncommitted changes. If there are:

1. Show the user exactly what's uncommitted (files + brief diff summary)
2. Ask via AskUserQuestion:

> **Session handoff for [project] on branch [branch].**
>
> You have uncommitted changes in [N] files. For a clean handoff, these should
> be committed so the next session sees them.
>
> A) Commit all changes with a handoff message (recommended)
> B) Commit specific files only (I'll tell you which)
> C) Leave uncommitted (I'll note them in the handoff doc)

If A: Stage all changes and commit:
```bash
git add -A
git commit -m "wip: session handoff — [brief description of changes]"
```

If B: Ask which files, stage those, commit. Note the rest in the handoff doc.

If C: Proceed but add a **WARNING** section to the handoff doc listing every
uncommitted file and what it contains.

---

## Step 2: Ensure Everything Is Pushed

For EVERY local branch that has commits not on the remote:

```bash
CURRENT=$(git branch --show-current)
for branch in $(git branch --format='%(refname:short)'); do
  LOCAL=$(git rev-parse "$branch" 2>/dev/null)
  REMOTE=$(git rev-parse "origin/$branch" 2>/dev/null || echo "NONE")
  if [ "$REMOTE" = "NONE" ] || [ "$LOCAL" != "$REMOTE" ]; then
    echo "NEEDS PUSH: $branch"
  fi
done
```

If branches need pushing, ask via AskUserQuestion:

> These branches have unpushed commits:
> [list each branch with commit count]
>
> A) Push all of them (recommended)
> B) Push only the current branch
> C) Don't push (I'll note this in the handoff doc)

Push as directed. For new branches without a remote:
```bash
git push -u origin [branch-name]
```

---

## Step 3: Verify GitHub Has Everything

After pushing, verify:

```bash
echo "=== VERIFICATION ==="
for branch in $(git branch --format='%(refname:short)'); do
  LOCAL=$(git rev-parse "$branch" 2>/dev/null)
  REMOTE=$(git rev-parse "origin/$branch" 2>/dev/null || echo "NONE")
  if [ "$LOCAL" = "$REMOTE" ]; then
    echo "OK: $branch (synced)"
  elif [ "$REMOTE" = "NONE" ]; then
    echo "WARNING: $branch (not on remote)"
  else
    echo "WARNING: $branch (out of sync)"
  fi
done

echo "=== OPEN PRS AFTER SYNC ==="
gh pr list --state open --json number,title,headRefName,url 2>/dev/null
```

If any branch is still not synced, flag it with a WARNING in the handoff doc.

---

## Step 4: Check for Hidden/Missed Files

Look for files that might be gitignored but contain important work:

```bash
echo "=== GITIGNORED BUT POSSIBLY IMPORTANT ==="
git ls-files --others --ignored --exclude-standard | grep -iE '\.(md|txt|json|yaml|yml|toml|env|sql|sh|plan)$' | grep -viE '(node_modules|\.next|dist|build|vendor|__pycache__|\.cache)' | head -30

echo "=== LARGE UNTRACKED FILES ==="
git ls-files --others --exclude-standard --directory | head -20
```

If important-looking files are gitignored (plans, configs, docs, SQL migrations):
- Flag each one to the user
- Ask if they should be committed (may need .gitignore update)
- If not committed, copy their contents into the handoff doc

---

## Step 5: Update progress.md

progress.md is the **running story** of the project. It owns the narrative:
decisions, reasoning, mistakes, open questions, ideas, and technical debt.
It does NOT need to duplicate state that HANDOFF.md covers (branch status,
PR status, next steps, blockers).

The project MUST have a `progress.md` at the repo root. This is a **running
document** — never delete prior session entries.

### If progress.md does not exist, create it with this structure:

```markdown
# Progress — [Project Name]
```

### Check if today's session entry already exists:

Read progress.md and look for `## Session — [today's date]`.

**If today's entry ALREADY exists** (this is a mid-session checkpoint):
- **UPDATE the existing entry in-place** — do NOT create a duplicate
- Append new bullets to Progress Made, Outstanding TODOs, Decisions Log, etc.
- Add a phase marker to the Session Log (e.g., `#### After Planning`, `#### After Implementation`, `#### After QA`)
- Update Files Changed to include any new files since last checkpoint
- Preserve everything already written — only add, never remove

**If today's entry does NOT exist** (first handoff of the session):
- Add a new session entry at the top (below the title, above any prior sessions)

### Session entry template:

```markdown
## Session — [YYYY-MM-DD]

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
Each decision MUST be tagged:
- **[USER]** — Explicit decision made by the user
- **[CLAUDE]** — Decision made autonomously by Claude (include reasoning)
- **[JOINT]** — Decision reached through discussion

Format: **[TAG] Decision** — Context, alternatives considered, trade-offs.

### Open Questions
- Questions that came up but weren't resolved
- Things that need user input in a future session
- Uncertainties about architecture, requirements, or approach

### Future Ideas & Aspirations
- Features or improvements mentioned but not yet planned
- "Wouldn't it be cool if..." ideas that surfaced during work
- Long-term architectural visions discussed

### Session Log
Chronological narrative of the session. Use phase markers when running
multiple checkpoints per session:

#### After Planning
- What was explored, what approach was chosen, what was rejected

#### After Implementation
- What was built, what changed from the plan, surprises encountered

#### After QA
- What was tested, what broke, what was fixed

Each phase section should include:
- **Exploration & Discovery** — What we searched for, what we found, dead ends
- **Architectural Decisions** — Why we structured things a certain way
- **Mistakes & Corrections** — Claude errors, user prompt corrections
- **Blockers Hit** — What stopped progress and how it was resolved
- **Key Back-and-Forth** — Significant disagreements or pivots

Be honest and specific. Examples:
- "Claude initially generated a REST endpoint but user clarified this should be a background job — wasted ~10 min"
- "User asked to 'fix the bug' without specifying which one — after clarification, it was the race condition in worker.ts"
- "Claude hallucinated a prisma.upsertMany() method that doesn't exist — switched to transaction with individual upserts"

### Technical Debt & Risks Identified
- Shortcuts taken that should be revisited
- Code that works but isn't ideal
- Performance concerns noticed but not addressed

### Files Changed
- List of files created, modified, or deleted this session
- Brief note on what changed in each

---
```

### Rules for progress.md:
- **NEVER delete prior session entries** — this is an append-only running document
- **One entry per session per day** — multiple handoffs in a day UPDATE the same entry
- **New sessions go at the top** (most recent first, below the title)
- **Be brutally honest** in the session log — this is for learning, not PR
- **Tag every decision** — no untagged decisions
- **Convert relative dates to absolute** — "next week" becomes "2026-04-09"
- **Populate from real data** — run `git log`, `git diff`, review conversation history; don't guess
- **Don't duplicate HANDOFF.md content** — progress.md does NOT need branch status, PR status, next steps, or blockers. Those live in HANDOFF.md.
- **Commit progress.md** as part of the handoff commit

After updating progress.md, commit it:
```bash
git add progress.md
```

Then continue to write the handoff document.

---

## Step 6: Write the Handoff Document

HANDOFF.md is the **current state snapshot** — a status board for the next session
to pick up immediately. It owns: branch status, PR status, blockers, and next steps.
It does NOT need to duplicate the narrative, decisions, or session log from progress.md.

**This file is overwritten each run.** That's intentional — it's a snapshot, not a log.
The history lives in progress.md.

Create or overwrite `.github/HANDOFF.md`:

```markdown
# Handoff — [Project Name]

**Last updated:** [YYYY-MM-DD HH:MM]
**Phase:** [Planning / Implementation / QA / End of session]
**Branch:** [current branch]
**Last commit:** [short hash + message]

## Current State
- **Branch:** [branch] — [what this branch is for]
- **Last commit:** [hash] [message]
- **Tests:** [passing/failing/not run — actually run them if possible]
- **Build:** [passing/failing/not checked]
- **Deploy status:** [deployed/not deployed/N/A]

## Outstanding Pull Requests
[For EACH open PR:]
- **PR #[N]: [title]** — [url]
  - Branch: [head] → [base]
  - Status: [draft/ready/reviewed/changes requested]
  - CI: [passing/failing/pending]
  - What it does: [1-2 sentence summary]
  - What's needed: [review/QA/fixes/merge]

[If no open PRs: "No outstanding PRs."]

## Uncommitted/Unpushed Work
[List anything that didn't make it to GitHub, with details on what it is
and why it wasn't committed. If everything is pushed, say "All work is in GitHub."]

## Known Issues & Blockers
[Anything broken, blocked, or waiting on external input.
If none: "No known blockers."]

## Next Steps (Priority Order)
1. [Most important next action — be specific]
2. [Second priority]
3. [Third priority]
[Include: merge outstanding PRs, address review feedback, continue feature work, etc.]

## Quick Context
[2-3 sentences max. Only things the next session needs that aren't obvious
from the code or progress.md. Gotchas, environment quirks, "don't forget to X."
For the full story — decisions, reasoning, mistakes — see progress.md.]
```

---

## Step 7: Commit and Push the Handoff Doc

```bash
git add .github/HANDOFF.md progress.md
git commit -m "docs: checkpoint after [phase] — [date]"
git push
```

Use the actual phase in the commit message: "planning", "implementation", "QA",
or "end of session".

---

## Step 8: Final Verification

Run one final check:

```bash
echo "=== FINAL STATE ==="
echo "Branch: $(git branch --show-current)"
echo "Last commit: $(git log --oneline -1)"
echo "Remote sync: $(git rev-parse HEAD) vs $(git rev-parse origin/$(git branch --show-current) 2>/dev/null || echo 'NO REMOTE')"
echo ""
echo "Open PRs:"
gh pr list --state open --json number,title,url --jq '.[] | "  #\(.number): \(.title) — \(.url)"' 2>/dev/null || echo "  (gh not available)"
echo ""
echo "Handoff doc:"
[ -f .github/HANDOFF.md ] && echo "  .github/HANDOFF.md — COMMITTED" || echo "  WARNING: handoff doc not found"
```

Present the final summary to the user:

> **Handoff complete.**
>
> - [N] commits pushed across [N] branches
> - [N] open PRs documented
> - Handoff doc: .github/HANDOFF.md
> - [Any warnings about uncommitted/unpushed work]
>
> The next session should run `/resume` to pick up where you left off.

---

## Important Rules

- **Trust nothing to memory.** Every claim in the handoff doc must come from
  actual git commands, not from conversation context. Run `git log`, `git diff`,
  `gh pr list` — don't summarize from what you "remember."
- **Flag gitignored files.** The #1 failure mode is important files being
  gitignored and silently lost. Always check.
- **Push everything.** Unpushed branches are invisible to the next session.
  The default should always be "push it."
- **Be specific in next steps.** "Continue working on the feature" is useless.
  "Merge PR #12, then implement the email notification handler in
  src/services/notifications.ts" is useful.
- **Include PR context.** The next session MUST know about every open PR so it
  doesn't rebuild work that already exists.
- **Actually run tests/build if possible.** Don't write "tests: not checked" if
  you can run them in 30 seconds.
- **Never duplicate between files.** progress.md owns the story (decisions,
  narrative, mistakes, ideas, debt). HANDOFF.md owns the snapshot (state, PRs,
  blockers, next steps). If information belongs in one, don't put it in the other.
- **One session entry per day in progress.md.** Multiple handoffs in the same
  session UPDATE the existing entry — they never create duplicates. Use phase
  markers (`#### After Planning`, `#### After Implementation`, etc.) to show
  progression within the entry.
- **HANDOFF.md is always overwritten.** It's a snapshot, not a log. The log is
  progress.md.
