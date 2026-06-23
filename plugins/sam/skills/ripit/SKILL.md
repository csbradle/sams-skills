---
name: ripit
version: 0.3.0
description: |
  End-to-end feature pipeline: plan, implement, ship, QA, deploy, document, and
  hand off — all in one command. Chains gstack skills automatically, pauses for
  approval after planning, parallelizes implementation when possible. Smart plan
  detection: skips reviews already completed, fills in missing ones (eng review
  if only CEO exists, design review for frontend changes). Resumable — picks up
  where it left off if interrupted. Use when asked to "ripit", "rip it",
  "build this feature end to end", "plan and ship", or "take this from idea to
  production".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - Skill
  - AskUserQuestion
  - WebSearch
  - EnterPlanMode
  - ExitPlanMode
---

# /ripit — End-to-End Feature Pipeline

Run a complete feature lifecycle: plan, approve, implement, ship, QA, deploy,
document, hand off. One command, one approval gate, everything else automatic.

## Overview

You provide a feature description. The skill:
1. Validates the environment (pre-flight)
2. Plans the feature — **smart gap-filling: only runs reviews that haven't been done yet**
3. Shows you the FULL plan and asks for approval
4. Implements the feature (parallel agents in worktrees when possible)
5. Ships (PR with review), QAs, deploys, documents, and hands off
6. Offers to start the next feature from TODOS.md

Every phase has auto-resume on failure. You stay in control at the approval gate.
Everything after approval is automatic unless a downstream skill surfaces a question.

**Resumable:** If interrupted mid-pipeline, the next /ripit invocation detects
the in-progress session and offers to resume from the exact phase that was running.

## Error Handling — Auto-Resume

This applies to ALL phases (1 through 9). If a phase fails:

**Failure signals:**
- Bash command: non-zero exit code
- Skill tool invocation: error response or tool output containing STATUS: BLOCKED/ERROR
- Agent subagent: result text containing "failed", "error", or "could not"

When a failure is detected, use AskUserQuestion:

> "Phase [name] failed: [error summary, 1-2 sentences]"

Options:
- A) Retry this phase
- B) Skip to next phase
- C) Stop pipeline (jump to session summary)

If A: Re-run the same phase from the top.
If B: Note the skip and continue. Skipped phases appear in the session summary.
If C: Jump to Phase 10 (session summary) and exit.

Phases 10-11 (summary + chaining) are non-critical and do NOT get error handling.
Phase 9.5 (auto-TODO) is a sub-phase of 9 and included in the error handling scope.

---

## Phase 0: Resume Detection

Before anything else, check if there's an in-progress /ripit session:

```bash
if [ -f /tmp/ripit_state ]; then
  echo "EXISTING_SESSION=true"
  cat /tmp/ripit_state
else
  echo "EXISTING_SESSION=false"
fi
```

If EXISTING_SESSION=true, the state file contains two lines:
- Line 1: the phase number (e.g., "4" or "5")
- Line 2: the feature description

Use AskUserQuestion:

> "Found an in-progress /ripit session. Last phase: [phase name from number].
> Feature: [feature description from line 2].
>
> Resume from where it left off?"

Options:
- A) Resume from Phase [N]
- B) Start fresh (discard previous session)

**If A:** Set the feature description from line 2. Skip to the phase on line 1.
The start time stays from the previous session (already in /tmp/ripit_start).
**If B:** Remove the state file (`rm -f /tmp/ripit_state`) and proceed to Phase 1.

### State tracking

At the START of every phase (1 through 9), write the current state:

```bash
printf '%s\n%s\n' "PHASE_NUMBER" "FEATURE_DESCRIPTION" > /tmp/ripit_state
```

Replace PHASE_NUMBER with the numeric phase (1, 2, 3, 4, 5, 6, 7, 8, 9).
Replace FEATURE_DESCRIPTION with the one-line feature description.

At the END of Phase 10 (session summary), clean up:
```bash
rm -f /tmp/ripit_state 2>/dev/null
```

This is how the pipeline becomes resumable. If the user interrupts with commentary
or questions and the pipeline loses its place, the next /ripit invocation picks up
exactly where it stopped.

---

## Phase 1: Pre-Flight Checks

### Input validation

If the user did not provide a feature description (invoked /ripit with no argument
or an empty string), use AskUserQuestion:

> "What feature should I build? Describe it in a sentence or two."

Options:
- A) I'll type the description now

Wait for the response. Use it as the feature description for all subsequent phases.

### Environment checks

```bash
echo "=== RIPIT PRE-FLIGHT ==="

# Record start time to a FIXED temp file path (not $$, which changes per bash call)
date +%s > /tmp/ripit_start
echo "START_TIME=$(cat /tmp/ripit_start)"

# 1. Git working directory clean
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "FAIL: Working directory not clean. Commit or stash changes first."
else
  echo "OK: Working directory clean"
fi

# 2. Current branch
BRANCH=$(git branch --show-current 2>/dev/null)
echo "BRANCH: $BRANCH"

# 3. Remote accessible
if git fetch --dry-run origin 2>/dev/null; then
  echo "OK: Remote accessible"
else
  echo "FAIL: Cannot reach remote 'origin'"
fi

# 4. Key skill files exist
for SKILL_NAME in autoplan ship qa land-and-deploy learn document-release; do
  if [ -f "$HOME/.claude/skills/gstack/$SKILL_NAME/SKILL.md" ] || [ -f "$HOME/.claude/skills/$SKILL_NAME/SKILL.md" ]; then
    echo "OK: $SKILL_NAME"
  else
    echo "FAIL: Missing skill: $SKILL_NAME"
  fi
done

echo "=== PRE-FLIGHT COMPLETE ==="
```

If any FAIL appears, tell the user what to fix and stop. Do not proceed with failures.

---

## Phase 2: Smart Planning — Gap Detection & Fill

Instead of always running the full /autoplan pipeline, detect which reviews have
already been completed and only run what's missing.

### Step 2a: Detect existing reviews

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)" 2>/dev/null || true
SLUG=${SLUG:-unknown}
BRANCH=$(git branch --show-current 2>/dev/null)

echo "=== PLAN GAP DETECTION ==="

# 1. Check for CEO plan file
CEO_PLAN=$(ls -t ~/.gstack/projects/$SLUG/ceo-plans/*.md 2>/dev/null | head -1)
if [ -n "$CEO_PLAN" ]; then
  echo "CEO_PLAN=$CEO_PLAN"
  PLAN_MTIME=$(stat -f %m "$CEO_PLAN" 2>/dev/null || stat -c %Y "$CEO_PLAN" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  AGE_HOURS=$(( (NOW - PLAN_MTIME) / 3600 ))
  echo "CEO_PLAN_AGE_HOURS=$AGE_HOURS"
else
  echo "CEO_PLAN=MISSING"
fi

# 2. Parse review JSONL for completed reviews on this branch
REVIEW_FILE="$HOME/.gstack/projects/$SLUG/$BRANCH-reviews.jsonl"
if [ -f "$REVIEW_FILE" ]; then
  echo "REVIEW_FILE=$REVIEW_FILE"
  # Get the LATEST entry for each review type (last one wins)
  for REVIEW_TYPE in plan-ceo-review plan-eng-review plan-design-review; do
    LATEST=$(grep "\"skill\":\"$REVIEW_TYPE\"" "$REVIEW_FILE" 2>/dev/null | tail -1)
    if [ -n "$LATEST" ]; then
      echo "HAS_${REVIEW_TYPE}=true"
      echo "LATEST_${REVIEW_TYPE}=$LATEST"
    else
      echo "HAS_${REVIEW_TYPE}=false"
    fi
  done
else
  echo "REVIEW_FILE=MISSING"
  echo "HAS_plan-ceo-review=false"
  echo "HAS_plan-eng-review=false"
  echo "HAS_plan-design-review=false"
fi

echo "=== GAP DETECTION COMPLETE ==="
```

### Step 2b: Determine what's needed

Parse the output from Step 2a. Build a list of MISSING reviews:

**Decision tree:**

1. **No CEO plan exists** (`CEO_PLAN=MISSING` AND `HAS_plan-ceo-review=false`):
   → Run full /autoplan (all three reviews). Skip to Step 2c.

2. **CEO plan exists but no eng review** (`HAS_plan-ceo-review=true` AND `HAS_plan-eng-review=false`):
   → Run /plan-eng-review only. Skip to Step 2d.

3. **CEO + eng exist, no design review** (`HAS_plan-ceo-review=true` AND `HAS_plan-eng-review=true` AND `HAS_plan-design-review=false`):
   → Check if the feature involves frontend/UI changes. Determine this by:
   - Reading the CEO plan file and checking for mentions of UI, frontend, CSS,
     components, pages, layouts, design, visual, or user-facing changes
   - Checking the feature description for similar terms
   → If frontend change detected: run /plan-design-review only. Skip to Step 2e.
   → If NOT a frontend change: all needed reviews are done. Skip to Phase 3.

4. **All three reviews exist** (`HAS_plan-ceo-review=true` AND `HAS_plan-eng-review=true` AND `HAS_plan-design-review=true`):
   → Planning is complete. Skip to Phase 3 (approval gate).

Print what was detected and what will be run:

```
══════════════════════════════════════════════════════
PLANNING STATUS
══════════════════════════════════════════════════════
CEO Review:    [✓ done / ✗ missing]
Eng Review:    [✓ done / ✗ missing]
Design Review: [✓ done / ✗ missing / — not needed (backend only)]

Action: [Running full /autoplan | Running /plan-eng-review | Running /plan-design-review | Skipping to approval — all reviews done]
══════════════════════════════════════════════════════
```

### Step 2c: Run full /autoplan (when no reviews exist)

**Why inline instead of Skill tool:** /autoplan must run inline (read the SKILL.md
and follow its instructions) because this agent needs the planning context for the
approval gate in Phase 3. The Skill tool would run in a separate context and the
plan details would be lost.

Read the /autoplan skill file:

```bash
AUTOPLAN=$(ls ~/.claude/skills/gstack/autoplan/SKILL.md ~/.claude/skills/autoplan/SKILL.md 2>/dev/null | head -1)
echo "AUTOPLAN_PATH=$AUTOPLAN"
```

Read that file using the Read tool. Follow its instructions from top to bottom,
**skipping any sections that handle session lifecycle** (starting/ending sessions,
status reporting, telemetry — /ripit owns the session lifecycle). Specifically skip:
- Preamble (run first)
- AskUserQuestion Format
- Completeness Principle — Boil the Lake
- Search Before Building
- Completion Status Protocol
- Telemetry (run last)

If /autoplan adds new sections in the future, apply the same principle: skip
lifecycle management, execute everything related to planning and review.

Execute all planning and review sections at full depth. Pass the user's feature
description as the input.

When /autoplan completes, proceed to Phase 3.

### Step 2d: Run /plan-eng-review only (when CEO done, eng missing)

Read the CEO plan file found in Step 2a. Then invoke /plan-eng-review:

```
Skill: "plan-eng-review"
```

The eng review skill will read the existing plan and add its technical analysis.
When complete, proceed to Phase 3.

### Step 2e: Run /plan-design-review only (when CEO + eng done, design missing)

Read the CEO plan file found in Step 2a. Then invoke /plan-design-review:

```
Skill: "plan-design-review"
```

The design review skill will evaluate the plan from a design perspective.
When complete, proceed to Phase 3.

---

## Phase 3: Plan Approval Gate

This is the ONE place where the pipeline blocks for explicit user approval.

### Step 3a: Find the plan

If the plan was already found in Phase 2a, use that file. Otherwise, search:

1. CEO plan: find the most recent .md file in the ceo-plans directory:
```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)" 2>/dev/null || true
SLUG=${SLUG:-unknown}
ls -t ~/.gstack/projects/$SLUG/ceo-plans/*.md 2>/dev/null | head -1
```

2. Plan file in working directory (created after the ripit start time):
```bash
RIPIT_START=$(cat /tmp/ripit_start 2>/dev/null || echo "0")
find . -maxdepth 3 -name "*.md" -not -name "README.md" -not -name "CHANGELOG.md" -not -name "LICENSE.md" -not -name "TODOS.md" -not -name "progress.md" 2>/dev/null | while read f; do
  MTIME=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo "0")
  [ "$MTIME" -gt "$RIPIT_START" ] && echo "$f"
done | head -5
```

3. If a plan mode file was active, check that path.

Read the plan file in FULL using the Read tool.

### Step 3b: Read review status

```bash
~/.claude/skills/gstack/bin/gstack-review-read 2>/dev/null || echo "NO_REVIEWS"
```

This outputs the review readiness dashboard: which reviews ran (CEO, design, eng)
and their status (clean, issues found, etc).

### Step 3c: Present to user

Print the FULL plan text. Do not summarize. Do not truncate. The user wants to
read the whole plan.

After the plan, print a decision summary:

```
══════════════════════════════════════════════════════
REVIEW SUMMARY
══════════════════════════════════════════════════════
CEO Review:    [status from review-read output]
Design Review: [status or "not run" or "skipped (backend only)"]
Eng Review:    [status from review-read output]

Key decisions made during planning:
  • [list each decision: who decided, what was chosen, why]
══════════════════════════════════════════════════════
```

### Step 3d: Ask for approval

Use AskUserQuestion:

> "The full plan is above. How do you want to proceed?"

Options:
- A) Approve — start implementation
- B) Give feedback (I'll type what to change)
- C) Reject — stop pipeline

**If B:** Capture the user's feedback. Run a focused planning session to update
the plan: re-read the plan file, apply the feedback, write the updated plan back.
Then re-present the updated plan and re-ask. Loop until approved or rejected.

**If C:** Stop. Jump to Phase 10 (session summary).

**If A:** Proceed to Phase 3e.

### Step 3e: Context management after approval

The planning phase consumes significant context. Before implementation:

1. Mentally retain these key facts (they survive context compression):
   - The approved plan file path on disk
   - The feature description (one sentence)
   - The branch name
   - The 3-5 most important implementation decisions from the plan

2. The full plan text does NOT need to stay in active context. It is on disk and
   can be re-read using the Read tool whenever specific sections are needed.

3. Proceed to Phase 4. If context feels tight, re-read only the relevant plan
   section for each implementation step rather than loading the whole thing.

---

## Phase 4: Implementation

### Step 4a: Assess parallelism

Re-read the approved plan file from disk. Determine if there are clearly
independent workstreams that could be implemented in parallel:

- Different files/directories with no cross-dependencies
- Independent features that don't share data structures or interfaces
- Frontend vs backend splits where neither blocks the other

**Default to serial implementation.** Only parallelize if the workstreams are
obviously independent (different directories, no shared types, no import chains).
When in doubt, go serial.

### Step 4b: Serial implementation (default)

Implement the feature as described in the approved plan. Work through it
systematically. Commit when done.

### Step 4c: Parallel implementation (when clearly independent workstreams exist)

**Step 1: Create worktrees.** Each agent needs an isolated git checkout to avoid
index.lock contention and merge conflicts.

```bash
BRANCH=$(git branch --show-current)
echo "BRANCH=$BRANCH"
# Create worktrees with fixed names (not $$)
git worktree add /tmp/ripit-ws-1 -b ripit-ws-1-$BRANCH 2>/dev/null && echo "WS1: /tmp/ripit-ws-1"
git worktree add /tmp/ripit-ws-2 -b ripit-ws-2-$BRANCH 2>/dev/null && echo "WS2: /tmp/ripit-ws-2"
```

Record the worktree paths and branch names from the output. Add more worktrees
if more than 2 workstreams.

**Step 2: Dispatch agents.** For each workstream, dispatch an Agent subagent.
Launch ALL agents in a single message for parallel execution.

Each agent's prompt must include:
- The specific workstream scope (which files, which feature area)
- The relevant plan sections (extract from the plan, include inline)
- The worktree path: "Your working directory is /tmp/ripit-ws-N. Run all bash
  commands with that as the cwd. Commit your work when done. Do not push."

**Step 3: Merge results.** After all agents complete:
- Check each result for success/failure
- If any failed: use AskUserQuestion with Retry / Continue without / Stop
- For successful worktrees, merge commits back:

```bash
BRANCH=$(git branch --show-current)
git merge ripit-ws-1-$BRANCH --no-edit 2>&1
git merge ripit-ws-2-$BRANCH --no-edit 2>&1
```

If merge conflicts occur, surface the conflict file list via AskUserQuestion
and ask the user how to resolve.

**Step 4: Clean up.**

```bash
BRANCH=$(git branch --show-current)
git worktree remove /tmp/ripit-ws-1 2>/dev/null; git branch -d ripit-ws-1-$BRANCH 2>/dev/null
git worktree remove /tmp/ripit-ws-2 2>/dev/null; git branch -d ripit-ws-2-$BRANCH 2>/dev/null
```

---

## Phase 5: Ship (/ship)

Invoke using the Skill tool:

```
Skill: "ship"
```

/ship handles: run tests, structured review, adversarial review, Codex review,
VERSION bump, CHANGELOG update, commit, push, and PR creation.

After /ship completes, note the PR URL from its output for the session summary.

---

## Phase 6: QA (/qa)

Invoke using the Skill tool:

```
Skill: "qa"
```

/qa tests the shipped branch and fixes bugs found. Each fix is committed
atomically and re-verified.

---

## Phase 7: Deploy (/land-and-deploy)

Invoke using the Skill tool:

```
Skill: "land-and-deploy"
```

Merges the PR, waits for CI, verifies production health.

### Post-deploy verification

After /land-and-deploy succeeds, check for /canary availability:

```bash
[ -f "$HOME/.claude/skills/gstack/canary/SKILL.md" ] || [ -f "$HOME/.claude/skills/canary/SKILL.md" ]
echo "CANARY: $?"
```

If /canary exists (exit code 0), invoke it via the Skill tool to take screenshots
and verify no visual regressions. /land-and-deploy already checks basic production
health (HTTP status, CI green). The canary adds visual regression detection.

If /canary doesn't exist, skip with: "No canary configured — skipping visual check."

---

## Phase 8: Learn + Document

### /learn
Invoke using the Skill tool:
```
Skill: "learn"
```

### /document-release
Invoke using the Skill tool:
```
Skill: "document-release"
```

/document-release audits all project documentation against the shipped diff,
polishes CHANGELOG voice, cleans up TODOS.md, and bumps VERSION if needed.

---

## Phase 9: Handoff

Commit any remaining uncommitted changes, push to remote, and capture session state.

Run these steps directly (there is no separate /handoff SKILL.md file):

1. Check for uncommitted changes:
```bash
git status --short
```

2. If changes exist, stage and commit them. Stage specific files if possible,
   or use `git add -A` only for cleanup commits where all changes are intentional:
```bash
git add -A && git commit -m "chore: ripit session cleanup"
```

3. Push to remote:
```bash
git push origin HEAD
```

4. If a /checkpoint skill exists, invoke it to save session state:
```bash
[ -f "$HOME/.claude/skills/gstack/checkpoint/SKILL.md" ] || [ -f "$HOME/.claude/skills/checkpoint/SKILL.md" ]
echo "CHECKPOINT: $?"
```

If checkpoint exists (exit code 0), invoke it via Skill tool. Otherwise skip.

### Phase 9.5: Auto-TODO Evaluation

Before the session summary, offer to handle simple TODOs.

Use AskUserQuestion:

> "Feature is shipped and deployed. Want me to scan TODOS.md for quick, low-risk
> items I can knock out automatically?"

Options:
- A) Yes, auto-clear simple TODOs
- B) No, skip to summary

**If B:** Skip to Phase 10.

**If A:** Read TODOS.md. For each incomplete item, evaluate against these safety
criteria. Only auto-execute items that meet ALL of:

- No database migrations or schema changes
- No API endpoint changes (new routes, changed parameters, removed endpoints)
- No dependency additions, removals, or version changes
- No file deletions
- No changes to auth, security, or access control
- No changes to CI/CD or deploy configuration
- Change is contained within 1-2 files
- Change is mechanical (rename, copy tweak, config value, comment)

For each qualifying TODO:
1. Implement the change
2. Run the project's test suite to verify nothing broke
3. If tests pass: commit with message `chore: auto-clear TODO — [description]`
4. If tests fail: `git checkout .` to revert immediately, skip this TODO

Report what was done and what was skipped.

---

## Phase 10: Session Summary

```bash
RIPIT_START=$(cat /tmp/ripit_start 2>/dev/null || echo "0")
RIPIT_END=$(date +%s)
if [ "$RIPIT_START" != "0" ]; then
  RIPIT_DURATION=$(( RIPIT_END - RIPIT_START ))
  RIPIT_MINUTES=$(( RIPIT_DURATION / 60 ))
  echo "DURATION: ${RIPIT_MINUTES}m"
else
  echo "DURATION: unknown"
fi
rm -f /tmp/ripit_start /tmp/ripit_state 2>/dev/null
```

Print the completion summary:

```
══════════════════════════════════════════════════════
  /ripit COMPLETE
══════════════════════════════════════════════════════
  Feature:       [feature description]
  Duration:      [X]m
  Phases:        [N]/11 completed ([list any skipped])
  Branch:        [branch name]
  PR:            [PR URL if created]

  Files changed: [count from git diff --stat]
  Lines:         +[added] / -[removed]

  Planning:      [full /autoplan | eng review only | design review only | skipped (all done)]

  Decisions:
    [N] auto-decided during planning
    [N] surfaced to user

  TODOs auto-cleared: [N] (or "skipped")
══════════════════════════════════════════════════════
```

Gather file stats:
```bash
BASE=$(git merge-base HEAD origin/master 2>/dev/null || echo "HEAD~10")
git diff --stat $BASE..HEAD 2>/dev/null | tail -1
```

---

## Phase 11: Feature Chaining

Check if there's more work to do.

First, assess context window health. If the conversation has been running for a
long time (many tool calls, large outputs), recommend a fresh session:

> "Pipeline complete. Context is getting heavy — recommend starting a fresh
> /ripit session for the next feature."

Otherwise, read TODOS.md (if it exists). Find the highest-priority incomplete item.

If a TODO exists, use AskUserQuestion:

> "Pipeline complete! Next TODO from the backlog:
>
> **[TODO title]** (Priority: [P1/P2/P3])
> [TODO description, first 2 lines]
>
> Want to start a new /ripit cycle?"

Options:
- A) Yes, start /ripit for this TODO
- B) No, I'm done for now

If A: Loop back to Phase 1 (pre-flight) with the TODO as the feature description.
If B: Exit cleanly.

---

## Important Notes

- **Daemon code is separate.** /ripit is a parallel path using native CC primitives.
  The daemon stays for future multi-project concurrency work.

- **User sovereignty.** The approval gate (Phase 3) is sacred. Never skip it.
  Never auto-approve. Everything after approval is automatic unless a downstream
  skill surfaces a genuine question that requires user judgment.

- **Context discipline.** After the approval gate, the plan is on disk. Don't hold
  the full plan text in context. Re-read from disk when specific sections are needed.
