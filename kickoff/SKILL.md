---
name: kickoff
version: 2.1.0
description: |
  Product-level status briefing: plain-language summary of where the project stands,
  what phase we're in, what's left to do, and what to work on next. Written for
  a non-technical product manager — leads with context and goals, not git details.
  Use when: "kickoff", "what's going on", "where are we", "what's the status",
  "catch me up", "what's next", "wtf is going on", or at the start of any session.
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

# /kickoff — Where Are We?

One command. A plain-language briefing on the project: what we're building,
where we are, what's in flight, and what to do next. Written so a non-technical
product manager can read it and make prioritization decisions.

**The problem this solves:** You sit down and need to know what's going on.
Not git branches — the actual state of the product. What shipped, what's half-done,
what's waiting, and what matters most right now.

---

## Step 0: Full Project Scan

This is the most critical step. Run ALL of these — skip nothing.

### 0A: Repository basics

```bash
echo "=== REPO ==="
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
echo "Root: $REPO_ROOT"
echo "Name: $(basename "$REPO_ROOT")"
git remote get-url origin 2>/dev/null || echo "NO REMOTE"
echo "Default branch: $(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo 'unknown')"
echo "Current branch: $(git branch --show-current)"
```

### 0B: ALL branches (local and remote)

```bash
echo "=== ALL BRANCHES ==="
echo "--- Local ---"
git branch -vv

echo "--- Remote (not merged to default) ---"
DEFAULT=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
git fetch --all --prune 2>/dev/null
git branch -r --no-merged "origin/$DEFAULT" 2>/dev/null | head -20

echo "--- Branches with unpushed commits ---"
for branch in $(git branch --format='%(refname:short)'); do
  REMOTE=$(git rev-parse "origin/$branch" 2>/dev/null || echo "NONE")
  if [ "$REMOTE" = "NONE" ]; then
    echo "$branch: LOCAL ONLY (never pushed)"
  else
    AHEAD=$(git rev-list --count "origin/$branch..$branch" 2>/dev/null || echo "0")
    if [ "$AHEAD" != "0" ]; then
      echo "$branch: $AHEAD unpushed commits"
    fi
  fi
done
```

### 0C: EVERY open Pull Request (THIS IS CRITICAL — DO NOT SKIP)

```bash
echo "=== OPEN PULL REQUESTS ==="
gh pr list --state open --json number,title,headRefName,baseRefName,url,createdAt,isDraft,reviewDecision,statusCheckRollup,additions,deletions,changedFiles --limit 50 2>/dev/null || echo "gh CLI not available or no PRs"
```

For EACH open PR found, get full details:

```bash
# Run this for EACH PR number found above
gh pr view [NUMBER] --json title,body,headRefName,baseRefName,state,isDraft,reviewDecision,statusCheckRollup,comments,reviews,labels,milestone,url 2>/dev/null
```

Also check for recently closed/merged PRs (might have context):

```bash
echo "=== RECENTLY MERGED PRS (last 10) ==="
gh pr list --state merged --json number,title,headRefName,mergedAt,url --limit 10 2>/dev/null

echo "=== RECENTLY CLOSED (unmerged) PRS ==="
gh pr list --state closed --json number,title,headRefName,closedAt,url --limit 5 2>/dev/null | grep -v '"mergedAt"'
```

### 0D: Recent commit history

```bash
echo "=== RECENT COMMITS ON CURRENT BRANCH ==="
git log --oneline -20

echo "=== RECENT COMMITS ON DEFAULT BRANCH ==="
DEFAULT=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
git log --oneline "origin/$DEFAULT" -15

echo "=== COMMITS ON CURRENT BRANCH NOT IN DEFAULT ==="
git log --oneline "origin/$DEFAULT..HEAD" 2>/dev/null
```

### 0E: Working directory state

```bash
echo "=== WORKING DIRECTORY ==="
git status

echo "=== UNCOMMITTED CHANGES ==="
git diff --stat
git diff --cached --stat

echo "=== STASHED WORK ==="
git stash list
```

### 0F: Project documentation (current branch)

Read these files if they exist (use the Read tool for each):

1. **`progress.md`** — Running session progress log. **Read this FIRST.** It contains:
   - Prior session goals, progress, and outcomes
   - Outstanding TODOs carried forward from previous sessions
   - Decision history (tagged [USER]/[CLAUDE]/[JOINT])
   - Open questions and future ideas
   - Session logs with mistakes, corrections, and key learnings
   - Technical debt identified but not yet addressed
   This is the single most important context file for understanding where the project stands.
2. `.github/HANDOFF.md` — Previous session's handoff document
3. `CLAUDE.md` — Project instructions and context
4. `TODOS.md` — Outstanding tasks
5. `CHANGELOG.md` — Recent changes (last 50 lines)
6. `README.md` — Project overview (first 80 lines)
7. Any plan files found: `find . -maxdepth 3 -name "*.plan.md" -o -name "PLAN.md" | head -5`

### 0F2: Project documentation on unmerged branches (THIS IS CRITICAL — DO NOT SKIP)

An unmerged branch is in-flight work. Its docs are part of the project's current
state. For each unmerged remote branch found in Step 0B, check if it has newer
versions of key docs or significant new files:

```bash
echo "=== DOCS ON UNMERGED BRANCHES ==="
DEFAULT=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
for branch in $(git branch -r --no-merged "origin/$DEFAULT" 2>/dev/null | sed 's/^ *//' | head -10); do
  CHANGED=$(git diff --name-only "origin/$DEFAULT...$branch" 2>/dev/null)
  if echo "$CHANGED" | grep -qiE '(HANDOFF|TODO|progress|CHANGELOG|README|CLAUDE|\.plan\.md|PLAN\.md|DESIGN|WORKFLOW|ARCHITECTURE)'; then
    echo "--- $branch ---"
    echo "$CHANGED" | grep -iE '(HANDOFF|TODO|progress|CHANGELOG|README|CLAUDE|\.plan\.md|PLAN\.md|DESIGN|WORKFLOW|ARCHITECTURE)'
  fi
done
```

For each doc found, **read it with `git show <branch>:<path>`** and use the
latest version across all branches as your source of truth. Pay special
attention to:

- **HANDOFF.md** — may have a newer session handoff with different next steps
- **TODOS.md** — may have new tasks or priority changes
- **New doc files** (DESIGN, WORKFLOW, ARCHITECTURE, etc.) — may contain
  approved architecture decisions that reshape the project's direction

**Why this matters:** A session that writes docs and pushes to a branch but
doesn't merge to the default branch still produced real decisions and context.
If you only read docs from the default branch, you'll miss the most recent
session's work entirely — and your briefing will be incomplete.

### 0G: CI/CD and deploy status

```bash
echo "=== GITHUB ACTIONS ==="
gh run list --limit 5 --json status,conclusion,name,headBranch,url 2>/dev/null || echo "No GitHub Actions"

echo "=== DEPLOY STATUS ==="
# Check for common deploy configs
[ -f "fly.toml" ] && echo "Fly.io project detected"
[ -f "vercel.json" ] && echo "Vercel project detected"
[ -f "render.yaml" ] && echo "Render project detected"
[ -f "netlify.toml" ] && echo "Netlify project detected"
```

If CLAUDE.md has deploy commands, run the status check:
```bash
# Example: fly status --app [app-name]
# Parse from CLAUDE.md deploy configuration section
```

### 0H: GitHub Issues

```bash
echo "=== OPEN ISSUES ==="
gh issue list --state open --json number,title,labels,assignees,url --limit 15 2>/dev/null || echo "No issues or gh not available"
```

---

## Step 1: Synthesize Everything Into a Product-Level Picture

After gathering ALL data from Step 0, answer these questions before writing
anything. Do not present raw git output — translate everything into product terms.

1. **What is this project?** What are we building and why? What does the
   finished product look like? (Pull from README, CLAUDE.md, progress.md)

2. **Where are we in the arc of work?** Are we early (exploring/planning),
   mid-build (implementing), late-stage (reviewing/testing/polishing), or
   maintaining (shipped, doing incremental work)?

3. **What phase is the current work in?**
   - **Planning** — a plan exists but hasn't been implemented yet
   - **Implementation** — actively building, code is being written
   - **Review/QA** — built but needs review, testing, or fixes
   - **Ready to ship** — approved, tests passing, ready to merge/deploy
   - **Blocked** — waiting on something external
   - **Between tasks** — last thing wrapped up, nothing in progress

4. **What's in flight right now?** Open PRs, active branches, uncommitted work.
   Translate each into what it means for the product, not the codebase.

5. **What's deferred?** TODOs from progress.md, open questions, future ideas,
   technical debt. These are the backlog.

---

## Step 2: Present the Briefing

Write the briefing in plain language. A non-technical product manager should
be able to read this and understand everything without knowing git, branches,
or PRs. Use the exact format below.

```markdown
## [Project Name]

### The Goal
[2-3 sentences. What are we building? What does the end state look like?
What problem does it solve for users? This grounds every session in the
same shared vision. Pull from README, CLAUDE.md, progress.md, or infer
from the codebase if none of those exist.]

### Where We Are
[A practical, qualitative summary. Write this like you're catching up a
colleague over coffee. Use dates from progress.md to anchor the timeline
so the reader knows when things happened — not just what happened.

Examples:

"We've been building a customer payments system. On March 28 we finished
integrating Stripe for processing, and a PR is open with that work ready
to merge. The next piece is a finance dashboard so customers can see their
payment history."

"The authentication rewrite is about halfway done. We planned out the new
flow on March 25, implemented the login and signup endpoints on March 27,
and now we need to build the password reset flow and add tests. There's a
draft PR open with the work so far."

"We shipped the v2 API on March 30. Everything is deployed and stable.
There are a few cleanup items from the launch and one bug report that
came in yesterday."

Be specific about what's done (and when), what's in progress, and what's next.]

### Current Phase: [Planning / Building / Reviewing / Ready to Ship / Blocked / Between Tasks]
[1-2 sentences explaining what this means concretely. If we're mid-execution:

- **Planning**: "We have a plan for [feature] but haven't started coding yet.
  The plan is in [file/PR]."
- **Building**: "We're actively implementing [feature]. [N] of [M] pieces
  are done. The current work is on branch [branch]."
- **Reviewing**: "The [feature] implementation is complete and needs
  [review/testing/fixes]. PR #N is open."
- **Ready to Ship**: "PR #N is approved and CI is green. It just needs to
  be merged."
- **Blocked**: "We're waiting on [what] before we can continue."
- **Between Tasks**: "The last item wrapped up. Here's what's on deck."]
```

If there are open PRs, add:

```markdown
### Work in Progress
[For each open PR, describe it in product terms:]
- **[What it does in plain English]** — [status: ready to merge / needs review /
  needs fixes / draft]. [One sentence on what's needed to move it forward.]
  (PR #N)

[For branches with no PR but significant work:]
- **[What it does]** — code exists but no PR yet. [What needs to happen.]
```

Always include:

```markdown
### To-Do List
[Compiled from progress.md outstanding TODOs, HANDOFF.md next steps,
TODOS.md, open GitHub issues, and anything inferred from the codebase.
Group by priority, not by source. Preserve the dates from progress.md
so the reader can see when each item was added and how long it's been open.]

**Finish current work:**
- [ ] (added YYYY-MM-DD) [Specific next action to complete in-progress work]
- [ ] (added YYYY-MM-DD) [etc.]

**Up next:**
- [ ] (added YYYY-MM-DD) [Next feature/task after current work is done]
- [ ] (added YYYY-MM-DD) [etc.]

**Deferred / Backlog:**
- [ ] (added YYYY-MM-DD) [Items noted but not yet prioritized]
- [ ] (added YYYY-MM-DD) [Open questions that need answers before they can move forward]
- [ ] (added YYYY-MM-DD) [Technical debt / cleanup items]
- [ ] (added YYYY-MM-DD) [Future ideas and aspirations from progress.md]

### Decisions Needed
[Surface any open questions from progress.md, unresolved blockers,
or prioritization choices that need human input. If none: omit this section.]
```

---

## Step 3: Recommend What to Do Next

After the briefing, ask via AskUserQuestion:

> **Here's what I'd recommend working on:**
>
> A) [Highest priority — usually finishing in-progress work or merging
>    a ready PR. Describe in product terms, not git terms.]
> B) [Second priority]
> C) [Third priority]
> D) Something else — tell me what you'd like to focus on
>
> [If there's a merge-ready PR: "Note: there's finished work ready to
> ship (PR #N). I'd recommend merging that first before starting anything new."]

---

## Priority Rules

When determining what to recommend:

1. **Ship finished work first.** If a PR is approved and passing, the #1 action
   is always to merge it. Don't let done work sit.

2. **Finish in-progress work second.** If we're mid-build or mid-review,
   continue that — don't start something new.

3. **Unblock blocked work third.** If something is waiting on a decision,
   fix, or external input, surface it.

4. **New work last.** Only suggest starting fresh features after existing
   work is accounted for.

**CRITICAL RULE:** If an outstanding PR covers work that the user might ask about,
ALWAYS mention it. The sentence "that's already built — PR #X has it ready to
merge" prevents the catastrophic failure of rebuilding existing work.

---

## Important Rules

- **Lead with the product, not the plumbing.** The first thing the user reads
  should be what we're building and where we are — not branch names, commit
  hashes, or git status. Technical details support the narrative; they don't
  lead it.

- **Write for a non-technical product manager.** If you catch yourself writing
  "the feature branch is 3 commits ahead of main," rewrite it as "the feature
  is built and ready for review." PR numbers go in parentheses at the end of
  a line, not as the headline.

- **NEVER suggest building something that has an open PR.** If a PR exists for
  a feature, the next step is to review/merge it — NEVER reimplement it.

- **Run real commands, don't guess.** Every claim must come from actual git/gh
  commands. But present the *meaning*, not the raw output.

- **Read progress.md FIRST.** This is the running session log. It has the
  project vision, outstanding TODOs, open questions, decision history, and
  future ideas. Surface all of these in the briefing. If progress.md doesn't
  exist, note that and suggest creating one.

- **Read HANDOFF.md if it exists.** It has the latest snapshot: current state,
  blockers, and next steps from the last checkpoint.

- **Surface deferred work.** TODOs, open questions, future ideas, and technical
  debt from progress.md are the backlog. Don't bury them — they're how the
  user decides what to prioritize.

- **Be specific in recommendations.** "Continue feature work" is useless.
  "Finish the password reset flow — the login and signup endpoints are done,
  this is the last piece before we can ship auth" is useful.

- **Check ALL branches, not just the current one.** Work might exist on other
  branches. Translate what you find into product terms.
