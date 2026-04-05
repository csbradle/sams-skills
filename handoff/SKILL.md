---
name: handoff
version: 3.0.0
description: |
  Checkpoint, sync, and document: captures current state of work, ensures all
  code/files are committed and pushed to GitHub, audits and updates all project
  documentation, and writes handoff docs. Safe to run multiple times per session
  — after planning, after implementation, after QA, or at end of session.
  Nothing gets lost.
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

# /handoff — Checkpoint, GitHub Sync & Documentation Update

One command. Everything gets saved, committed, pushed, documented, and audited.
Run it after each phase of work — planning, implementation, QA, or end of session.
The next session (or the next person) picks up with zero context loss.

**The problem this solves:** Claude sessions lose context between conversations.
Files get left uncommitted, branches go unpushed, documentation drifts from code,
and the next session rebuilds work that already exists. /handoff makes that impossible.

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
```

Also detect the platform and base branch for use in later steps:

**Platform detection:**
- `gh auth status 2>/dev/null` succeeds → platform is **GitHub**
- `glab auth status 2>/dev/null` succeeds → platform is **GitLab**
- Neither → **unknown** (use git-native commands only)

**Base branch detection:**
1. `gh pr view --json baseRefName -q .baseRefName` (GitHub) or `glab mr view -F json` and extract `target_branch` (GitLab)
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (GitHub) or `glab repo view -F json` and extract `default_branch` (GitLab)
3. Git-native fallback: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`
4. Try `origin/main`, then `origin/master`, then fall back to `main`

Store the detected base branch for use in Step 5 (Documentation Sync).

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

## Step 5: Documentation Sync

**Gate:** This step only runs if BOTH conditions are true:
1. The current branch is NOT the base branch (main/master)
2. Code changes exist on the branch (not docs-only)

If either condition fails, print "Documentation sync: skipped (on base branch or no code changes)" and proceed to Step 6.

This step ensures every documentation file in the project is accurate, up to date,
and consistent with the code changes on the branch.

**Automation rules — what to stop for vs what to do automatically:**

**Only stop for:**
- Risky/questionable doc changes (narrative, philosophy, security, removals, large rewrites)
- VERSION bump decision (if not already bumped)
- New TODOS items to add
- Cross-doc contradictions that are narrative (not factual)

**Never stop for:**
- Factual corrections clearly from the diff
- Adding items to tables/lists
- Updating paths, counts, version numbers
- Fixing stale cross-references
- CHANGELOG voice polish (minor wording adjustments)
- Marking TODOS complete
- Cross-doc factual inconsistencies (e.g., version number mismatch)

**NEVER do:**
- Overwrite, replace, or regenerate CHANGELOG entries — polish wording only, preserve all content
- Bump VERSION without asking — always use AskUserQuestion for version changes
- Use `Write` tool on CHANGELOG.md — always use `Edit` with exact `old_string` matches

---

### Step 5.1: Pre-flight & Diff Analysis

1. Gather context about what changed on the branch:

```bash
git diff <base>...HEAD --stat
git log <base>..HEAD --oneline
git diff <base>...HEAD --name-only
```

2. Discover all documentation files in the repo:

```bash
find . -maxdepth 2 -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.gstack/*" -not -path "./.context/*" | sort
```

3. Classify the changes into categories relevant to documentation:
   - **New features** — new files, new commands, new skills, new capabilities
   - **Changed behavior** — modified services, updated APIs, config changes
   - **Removed functionality** — deleted files, removed commands
   - **Infrastructure** — build system, test infrastructure, CI

4. Output a brief summary: "Analyzing N files changed across M commits. Found K documentation files to review."

---

### Step 5.2: Per-File Documentation Audit

Read each documentation file and cross-reference it against the diff. Use these generic heuristics
(adapt to whatever project you're in):

**README.md:**
- Does it describe all features and capabilities visible in the diff?
- Are install/setup instructions consistent with the changes?
- Are examples, demos, and usage descriptions still valid?
- Are troubleshooting steps still accurate?

**ARCHITECTURE.md:**
- Do ASCII diagrams and component descriptions match the current code?
- Are design decisions and "why" explanations still accurate?
- Be conservative — only update things clearly contradicted by the diff. Architecture docs
  describe things unlikely to change frequently.

**CONTRIBUTING.md — New contributor smoke test:**
- Walk through the setup instructions as if you are a brand new contributor.
- Are the listed commands accurate? Would each step succeed?
- Do test tier descriptions match the current test infrastructure?
- Are workflow descriptions (dev setup, operational learnings, etc.) current?
- Flag anything that would fail or confuse a first-time contributor.

**CLAUDE.md / project instructions:**
- Does the project structure section match the actual file tree?
- Are listed commands and scripts accurate?
- Do build/test instructions match what's in package.json (or equivalent)?

**Any other .md files:**
- Read the file, determine its purpose and audience.
- Cross-reference against the diff to check if it contradicts anything the file says.

For each file, classify needed updates as:
- **Auto-update** — Factual corrections clearly warranted by the diff: adding an item to a
  table, updating a file path, fixing a count, updating a project structure tree.
- **Ask user** — Narrative changes, section removal, security model changes, large rewrites
  (more than ~10 lines in one section), ambiguous relevance, adding entirely new sections.

---

### Step 5.3: Apply Auto-Updates

Make all clear, factual updates directly using the Edit tool.

For each file modified, output a one-line summary describing **what specifically changed** — not
just "Updated README.md" but "README.md: added /new-skill to skills table, updated skill count
from 9 to 10."

**Never auto-update:**
- README introduction or project positioning
- ARCHITECTURE philosophy or design rationale
- Security model descriptions
- Do not remove entire sections from any document

---

### Step 5.4: Ask About Risky/Questionable Changes

For each risky or questionable update identified in Step 5.2, use AskUserQuestion with:
- Context: project name, branch, which doc file, what we're reviewing
- The specific documentation decision
- `RECOMMENDATION: Choose [X] because [one-line reason]`
- Options including C) Skip — leave as-is

Apply approved changes immediately after each answer.

---

### Step 5.5: CHANGELOG Voice Polish

**CRITICAL — NEVER CLOBBER CHANGELOG ENTRIES.**

This step polishes voice. It does NOT rewrite, replace, or regenerate CHANGELOG content.

A real incident occurred where an agent replaced existing CHANGELOG entries when it should have
preserved them. This skill must NEVER do that.

**Rules:**
1. Read the entire CHANGELOG.md first. Understand what is already there.
2. Only modify wording within existing entries. Never delete, reorder, or replace entries.
3. Never regenerate a CHANGELOG entry from scratch. The entry was written from the
   actual diff and commit history. It is the source of truth. You are polishing prose, not
   rewriting history.
4. If an entry looks wrong or incomplete, use AskUserQuestion — do NOT silently fix it.
5. Use Edit tool with exact `old_string` matches — never use Write to overwrite CHANGELOG.md.

**If CHANGELOG was not modified on this branch:** skip this sub-step.

**If CHANGELOG was modified on this branch**, review the entry for voice:
- **Sell test:** Would a user reading each bullet think "oh nice, I want to try that"? If not,
  rewrite the wording (not the content).
- Lead with what the user can now **do** — not implementation details.
- "You can now..." not "Refactored the..."
- Flag and rewrite any entry that reads like a commit message.
- Internal/contributor changes belong in a separate "### For contributors" subsection.
- Auto-fix minor voice adjustments. Use AskUserQuestion if a rewrite would alter meaning.

---

### Step 5.6: Cross-Doc Consistency & Discoverability Check

After auditing each file individually, do a cross-doc consistency pass:

1. Does the README's feature/capability list match what CLAUDE.md (or project instructions) describes?
2. Does ARCHITECTURE's component list match CONTRIBUTING's project structure description?
3. Does CHANGELOG's latest version match the VERSION file?
4. **Discoverability:** Is every documentation file reachable from README.md or CLAUDE.md? If
   ARCHITECTURE.md exists but neither README nor CLAUDE.md links to it, flag it. Every doc
   should be discoverable from one of the two entry-point files.
5. Flag any contradictions between documents. Auto-fix clear factual inconsistencies (e.g., a
   version mismatch). Use AskUserQuestion for narrative contradictions.

---

### Step 5.7: TODOS.md Cleanup

If TODOS.md does not exist, skip this sub-step.

1. **Completed items not yet marked:** Cross-reference the diff against open TODO items. If a
   TODO is clearly completed by the changes in this branch, move it to the Completed section
   with `**Completed:** vX.Y.Z (YYYY-MM-DD)`. Be conservative — only mark items with clear
   evidence in the diff.

2. **Items needing description updates:** If a TODO references files or components that were
   significantly changed, its description may be stale. Use AskUserQuestion to confirm whether
   the TODO should be updated, completed, or left as-is.

3. **New deferred work:** Check the diff for `TODO`, `FIXME`, `HACK`, and `XXX` comments. For
   each one that represents meaningful deferred work (not a trivial inline note), use
   AskUserQuestion to ask whether it should be captured in TODOS.md.

---

### Step 5.8: VERSION Bump Question

**CRITICAL — NEVER BUMP VERSION WITHOUT ASKING.**

1. **If VERSION does not exist:** Skip silently.

2. Check if VERSION was already modified on this branch:

```bash
git diff <base>...HEAD -- VERSION
```

3. **If VERSION was NOT bumped:** Use AskUserQuestion:
   - RECOMMENDATION: Choose C (Skip) because this is a checkpoint, not a release
   - A) Bump PATCH (X.Y.Z+1) — if doc changes ship alongside code changes
   - B) Bump MINOR (X.Y+1.0) — if this is a significant standalone release
   - C) Skip — no version bump needed

4. **If VERSION was already bumped:** Check whether the bump still covers the full scope:
   a. Read the CHANGELOG entry for the current VERSION
   b. Read the full diff — are there significant changes NOT in the CHANGELOG?
   c. If covered: "VERSION: Already bumped to vX.Y.Z, covers all changes."
   d. If uncovered: Use AskUserQuestion explaining what's new vs what's covered

---

### Step 5.9: Stage Documentation & Summarize

**Empty check first:** Run `git status` (never use `-uall`). If no documentation files were
modified by any previous sub-step, output "All documentation is up to date." and proceed to Step 6.

**If documentation files were modified:**

1. Stage modified documentation files by name (never `git add -A` or `git add .`).

2. Output a scannable doc health summary:

```
Documentation health:
  README.md       [status] ([details])
  ARCHITECTURE.md [status] ([details])
  CONTRIBUTING.md [status] ([details])
  CLAUDE.md       [status] ([details])
  CHANGELOG.md    [status] ([details])
  TODOS.md        [status] ([details])
  VERSION         [status] ([details])
```

Where status is one of:
- Updated — with description of what changed
- Current — no changes needed
- Voice polished — wording adjusted
- Not bumped — user chose to skip
- Already bumped — version was set earlier
- Skipped — file does not exist

Store this summary for inclusion in HANDOFF.md (Step 7) and the final commit (Step 8).

---

## Step 6: Update progress.md

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
- (YYYY-MM-DD) Bullet list of everything accomplished this session
- (YYYY-MM-DD) Include file paths and line numbers for code changes
- (YYYY-MM-DD) Note what was attempted vs what actually landed

### Outstanding TODOs
- [ ] (added YYYY-MM-DD) Remaining work from this session
- [ ] (added YYYY-MM-DD) Carried forward from prior sessions
- [ ] (added YYYY-MM-DD) Newly discovered work

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
- **Date-stamp every entry** — every bullet in Progress Made, every TODO, every decision, every open question gets a `(YYYY-MM-DD)` or `(added YYYY-MM-DD)` prefix
- **One entry per session per day** — multiple handoffs in a day UPDATE the same entry
- **New sessions go at the top** (most recent first, below the title)
- **Be brutally honest** in the session log — this is for learning, not PR
- **Tag every decision** — no untagged decisions
- **Convert relative dates to absolute** — "next week" becomes "2026-04-09"
- **Populate from real data** — run `git log`, `git diff`, review conversation history; don't guess
- **Don't duplicate HANDOFF.md content** — progress.md does NOT need branch status, PR status, next steps, or blockers. Those live in HANDOFF.md.
- **Commit progress.md** as part of the handoff commit
- **Include doc sync results** — if Step 5 ran, add the doc health summary to the session log

After updating progress.md, stage it:
```bash
git add progress.md
```

Then continue to write the handoff document.

---

## Step 7: Write the Handoff Document

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

## Documentation Status
[Include the doc health summary from Step 5.9 if doc sync ran.
If doc sync was skipped, write "Documentation sync: skipped (on base branch)"]

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

## Step 8: Commit, Push & Update PR

### Commit the handoff:

```bash
git add .github/HANDOFF.md progress.md
git commit -m "docs: checkpoint after [phase] — [date]"
git push
```

Use the actual phase in the commit message: "planning", "implementation", "QA",
or "end of session".

If documentation files were modified in Step 5, include them in the commit:
```bash
git add [each modified doc file by name]
git add .github/HANDOFF.md progress.md
git commit -m "docs: checkpoint after [phase] — [date]"
git push
```

### Update PR body (if a PR exists):

If an open PR exists for the current branch AND Step 5 modified documentation:

1. Read the existing PR body:

**If GitHub:**
```bash
gh pr view --json body -q .body > /tmp/pr-body-$$.md
```

**If GitLab:**
```bash
glab mr view -F json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))" > /tmp/pr-body-$$.md
```

2. If the body already contains a `## Documentation` section, replace it. Otherwise append it.

3. The Documentation section should include a **doc diff preview** — for each file modified,
   describe what specifically changed.

4. Write the updated body back:

**If GitHub:**
```bash
gh pr edit --body-file /tmp/pr-body-$$.md
```

**If GitLab:**
```bash
glab mr update -d "$(cat <<'MRBODY'
<paste the file contents here>
MRBODY
)"
```

5. Clean up: `rm -f /tmp/pr-body-$$.md`

6. If no PR/MR exists: skip with "No PR/MR found — skipping body update."
7. If update fails: warn "Could not update PR/MR body — documentation changes are in the commit." and continue.

---

## Step 9: Final Verification

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
> - Documentation: [sync status — updated N files / skipped / all current]
> - Handoff doc: .github/HANDOFF.md
> - [Any warnings about uncommitted/unpushed work]
>
> The next session should run `/resume` to pick up where you left off.

---

## Important Rules

### Git & State
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
- **Stage files by name, never `git add -A`.** Except in Step 1 where the user
  explicitly chose to commit all changes.

### Documentation
- **Read before editing.** Always read the full content of a file before modifying it.
- **Never clobber CHANGELOG.** Polish wording only. Never delete, replace, or regenerate entries.
- **Never bump VERSION silently.** Always ask. Even if already bumped, check scope coverage.
- **Be explicit about what changed.** Every edit gets a one-line summary.
- **Generic heuristics, not project-specific.** The audit checks work on any repo.
- **Discoverability matters.** Every doc file should be reachable from README or CLAUDE.md.
- **Voice: friendly, user-forward, not obscure.** Write like you're explaining to a smart person
  who hasn't seen the code.
- **Doc sync is lightweight.** Prefer speed over exhaustiveness. Skip ambiguous changes.
- **Batch AskUserQuestion calls where possible.** Don't ask 10 questions one at a time.

### Handoff Structure
- **Never duplicate between files.** progress.md owns the story (decisions,
  narrative, mistakes, ideas, debt). HANDOFF.md owns the snapshot (state, PRs,
  blockers, next steps). If information belongs in one, don't put it in the other.
- **One session entry per day in progress.md.** Multiple handoffs in the same
  session UPDATE the existing entry — they never create duplicates. Use phase
  markers (`#### After Planning`, `#### After Implementation`, etc.) to show
  progression within the entry.
- **HANDOFF.md is always overwritten.** It's a snapshot, not a log. The log is
  progress.md.
