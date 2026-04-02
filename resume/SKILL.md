---
name: resume
version: 1.0.0
description: |
  Start-of-session project status: reads all docs, PRs, branches, recent commits,
  and handoff docs to tell you exactly where the project stands and what to do next.
  Catches outstanding PRs so you never rebuild work that already exists.
  Use when: "resume", "where are we", "what's the status", "where did we leave off",
  "what should I work on", "catch me up", "what's next", or at the start of any session.
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

# /resume — Project Status & Session Start

One command. Know exactly where the project stands and what to do next.
Never rebuild work that already exists. Never miss an outstanding PR.

**The problem this solves:** Starting a new Claude session and asking "where are we?"
leads to incomplete answers — missed PRs, forgotten branches, rebuilt features.
/resume does a forensic scan of everything and gives you the real picture.

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

### 0F: Project documentation

Read these files if they exist (use the Read tool for each):

1. `.github/HANDOFF.md` — Previous session's handoff document
2. `CLAUDE.md` — Project instructions and context
3. `TODOS.md` — Outstanding tasks
4. `CHANGELOG.md` — Recent changes (last 50 lines)
5. `README.md` — Project overview (first 80 lines)
6. Any plan files found: `find . -maxdepth 3 -name "*.plan.md" -o -name "PLAN.md" | head -5`

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

## Step 1: Analyze and Classify

After gathering ALL data from Step 0, classify everything into these categories:

### Outstanding PRs Requiring Action
For each open PR, determine what it needs:
- **Needs review** — No reviews yet, or review requested
- **Needs QA** — Reviewed but not tested
- **Needs fixes** — Changes requested in review
- **Ready to merge** — Approved, CI passing, ready to go
- **Draft** — Work in progress
- **Blocked** — CI failing, merge conflicts, or waiting on something

### Branches With Unfinished Work
For each branch that's not merged:
- What does it contain? (read the commit messages)
- Is there a PR for it?
- Is there uncommitted/unpushed work?

### Current Branch Context
- What was the last thing done on this branch?
- Are there uncommitted changes?
- Is it behind the default branch?

---

## Step 2: Present the Status Report

Present everything to the user in this format:

```markdown
## Project Status: [Project Name]

**Date:** [today's date]
**Branch:** [current branch]
**Default branch:** [main/master]

---

### OUTSTANDING PULL REQUESTS
[This section is MANDATORY. If there are open PRs, this is the FIRST thing shown.]

[For EACH open PR:]
**PR #[N]: [title]** — [status emoji] [status]
- Branch: [head] → [base]
- What it does: [1-2 sentence summary from PR body/commits]
- CI: [passing/failing/pending]
- Reviews: [none/approved/changes requested]
- **Action needed:** [specific action — "merge it", "run /review", "run /qa", "fix CI", etc.]
- URL: [link]

[If NO open PRs: "No outstanding PRs."]

---

### UNCOMMITTED/UNPUSHED WORK
[List any uncommitted changes, unpushed branches, stashed work]
[If clean: "All work is committed and pushed."]

---

### RECENT ACTIVITY
[Summary of last 5-10 commits, what was shipped, what was merged]

---

### PROJECT HEALTH
- Tests: [status if known]
- CI: [last run status]
- Deploy: [status if known]
- Open issues: [count and top 3]

---

### RECOMMENDED NEXT STEPS (Priority Order)

[Number each step. Be extremely specific.]

1. **[HIGHEST PRIORITY]** [specific action]
   - Why: [reason]
   - How: [exact command or skill to run]

2. **[NEXT PRIORITY]** [specific action]
   - Why: [reason]
   - How: [exact command or skill to run]

3. [etc.]
```

---

## Priority Rules for Next Steps

When determining priority order:

1. **Merge-ready PRs first.** If a PR is approved and CI passing, the #1 next step
   is always "merge PR #X." Don't let approved work sit.

2. **PRs needing review second.** If a PR exists but hasn't been reviewed,
   the next step is "run /review on PR #X" or "run /qa on PR #X" — NOT
   "rebuild the feature."

3. **PRs needing fixes third.** If review requested changes, fix those changes.

4. **Uncommitted work fourth.** If there's local work not in GitHub, commit and push it.

5. **New work last.** Only suggest starting new features/tasks after all existing
   work is accounted for.

**CRITICAL RULE:** If an outstanding PR covers work that the user might ask about,
ALWAYS mention the PR. The sentence "PR #X already implements [feature]" prevents
the catastrophic failure of rebuilding existing work.

---

## Step 3: Ask What's Next

After presenting the status, ask via AskUserQuestion:

> **[Project name] on branch [branch].**
>
> [1-sentence summary of project state]
>
> Based on the status above, here's what I recommend:
>
> A) [Highest priority action from the report]
> B) [Second priority action]
> C) [Third priority action]
> D) Something else (tell me what you'd like to work on)

---

## Important Rules

- **NEVER suggest building something that has an open PR.** This is the #1 rule.
  If a PR exists for a feature, the next step is to review/QA/merge that PR.
  NEVER suggest reimplementing it.

- **Run real commands, don't guess.** Every claim in the status report must come
  from actual git/gh commands, not from conversation memory or assumptions.

- **Read the handoff doc if it exists.** `.github/HANDOFF.md` was written by
  /handoff specifically for this moment. Use it.

- **Check ALL branches, not just the current one.** Work might exist on other
  branches. A feature branch with 15 commits and no PR is important context.

- **Include PR details.** Don't just list PR numbers — summarize what each PR
  does so the user (and you) know whether it overlaps with requested work.

- **Be specific in next steps.** "Continue feature work" is useless.
  "Merge PR #12 (approved, CI green), then implement email notifications
  starting from src/services/notify.ts" is useful.

- **Check for stale branches.** If a branch hasn't been touched in weeks and
  has no PR, flag it — it might be abandoned work or a forgotten feature.

- **Read TODOS.md.** Outstanding tasks in TODOS.md are part of the project state.
  Include them in your prioritization.
