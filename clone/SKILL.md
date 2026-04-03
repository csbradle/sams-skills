---
name: clone
version: 1.0.0
description: |
  Sync the current repo with GitHub: fetch latest, handle uncommitted work,
  update the working branch, and refresh dependencies. Works from whatever
  project you have open in VS Code or the terminal.
  Use when: "clone", "sync", "get latest", "update repo", "pull latest",
  "refresh from GitHub", or when starting work on an existing local repo.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# /clone — Sync Local Repo With GitHub

One command. Your local repo matches the latest remote state, with all your
local work preserved safely.

**The problem this solves:** You sit down to work and aren't sure if you have the
latest code. Maybe there are uncommitted changes, maybe the remote moved ahead,
maybe dependencies changed. /clone handles all of it so you start from a clean,
current state.

---

## Step 1: Verify We're in a Git Repo

```bash
git rev-parse --show-toplevel 2>/dev/null || echo "NOT_A_REPO"
```

If not in a repo, stop and tell the user:

> This directory isn't a git repository. Either `cd` into a project or clone one
> with `git clone <url>`.

---

## Step 2: Capture Current State

Run ALL of these to understand what we're working with:

```bash
echo "=== REPO ==="
REPO_ROOT=$(git rev-parse --show-toplevel)
echo "Root: $REPO_ROOT"
echo "Name: $(basename "$REPO_ROOT")"
echo "Remote: $(git remote get-url origin 2>/dev/null || echo 'NO REMOTE')"

echo "=== CURRENT BRANCH ==="
CURRENT_BRANCH=$(git branch --show-current)
echo "$CURRENT_BRANCH"

echo "=== DEFAULT BRANCH ==="
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
echo "$DEFAULT_BRANCH"

echo "=== WORKING DIRECTORY STATUS ==="
git status --short

echo "=== STASH LIST ==="
git stash list
```

---

## Step 3: Handle Uncommitted Work

Check for uncommitted changes (staged, unstaged, or untracked):

```bash
DIRTY=$(git status --porcelain)
echo "$DIRTY"
```

**If the working directory is dirty**, ask via AskUserQuestion:

> **You have uncommitted changes:**
>
> ```
> [show git status --short output]
> ```
>
> How should I handle these before syncing?
>
> A) **Stash them** — save to stash, sync, then re-apply (recommended)
> B) **Commit them** — quick WIP commit on the current branch, then sync
> C) **Discard them** — throw away all uncommitted changes (destructive)
> D) **Abort** — don't sync, I'll handle it myself

- If **A**: `git stash push -m "clone-sync: auto-stash before sync $(date +%Y-%m-%d-%H%M)"` (include untracked with `-u`)
- If **B**: `git add -A && git commit -m "wip: auto-commit before sync"` — note the commit hash so we can report it
- If **C**: Confirm once more ("This will permanently delete uncommitted changes. Are you sure?"), then `git checkout -- . && git clean -fd`
- If **D**: Stop and exit

**If the working directory is clean**, proceed silently.

---

## Step 4: Fetch Everything From Remote

```bash
echo "=== FETCHING ==="
git fetch --all --prune 2>&1
```

`--prune` removes local references to branches deleted on the remote.

---

## Step 5: Determine Sync Strategy

Check how the current branch relates to its remote:

```bash
echo "=== SYNC STATUS ==="
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "NO_REMOTE")

if [ "$REMOTE" = "NO_REMOTE" ]; then
  echo "STATUS: local-only branch (no remote tracking)"
elif [ "$LOCAL" = "$REMOTE" ]; then
  echo "STATUS: up to date"
else
  AHEAD=$(git rev-list --count "origin/$CURRENT_BRANCH..$CURRENT_BRANCH" 2>/dev/null || echo "0")
  BEHIND=$(git rev-list --count "$CURRENT_BRANCH..origin/$CURRENT_BRANCH" 2>/dev/null || echo "0")
  echo "STATUS: ahead $AHEAD / behind $BEHIND"
fi

echo "=== DEFAULT BRANCH STATUS ==="
DEFAULT_LOCAL=$(git rev-parse "$DEFAULT_BRANCH" 2>/dev/null || echo "NONE")
DEFAULT_REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH" 2>/dev/null || echo "NONE")
if [ "$DEFAULT_LOCAL" != "$DEFAULT_REMOTE" ]; then
  BEHIND_DEFAULT=$(git rev-list --count "$DEFAULT_BRANCH..origin/$DEFAULT_BRANCH" 2>/dev/null || echo "0")
  echo "Default branch ($DEFAULT_BRANCH) is $BEHIND_DEFAULT commits behind remote"
else
  echo "Default branch ($DEFAULT_BRANCH) is up to date"
fi
```

### If on the default branch (main/master):

Fast-forward to the remote:

```bash
git merge --ff-only "origin/$DEFAULT_BRANCH" 2>&1
```

If fast-forward fails (local has diverged), ask the user:

> Your local `main` has diverged from the remote. This is unusual.
>
> A) **Reset to remote** — match remote exactly (recommended if no local-only commits on main)
> B) **Merge** — merge remote into local
> C) **Abort** — I'll sort this out manually

### If on a feature branch:

1. First, update the default branch silently:
   ```bash
   git fetch origin "$DEFAULT_BRANCH":"$DEFAULT_BRANCH" 2>&1 || echo "Could not fast-forward $DEFAULT_BRANCH (might be checked out)"
   ```

2. Then sync the feature branch with its remote (if it has one):
   ```bash
   git merge --ff-only "origin/$CURRENT_BRANCH" 2>&1
   ```

3. If the feature branch is behind the default branch, ask:

   > Your branch `feature-x` is behind `main` by N commits. Want to incorporate the latest changes?
   >
   > A) **Rebase onto main** — replays your commits on top of latest main (cleaner history)
   > B) **Merge main in** — merge main into your branch (preserves exact history)
   > C) **Skip** — stay behind for now, I'll handle it later

   - If **A**: `git rebase "origin/$DEFAULT_BRANCH"`
   - If **B**: `git merge "$DEFAULT_BRANCH"`
   - If **C**: Note it in the summary

### If on a local-only branch (no remote):

Don't try to pull. Just note it in the summary. Optionally update the default
branch as above.

---

## Step 6: Handle Merge/Rebase Conflicts

If any merge or rebase produces conflicts:

```bash
echo "=== CONFLICTS ==="
git diff --name-only --diff-filter=U
```

Tell the user immediately:

> **Conflicts detected in [N] files:**
> ```
> [list conflicted files]
> ```
>
> I'll stop here so you can resolve them. After resolving:
> - If rebasing: `git rebase --continue`
> - If merging: `git add [files] && git commit`
>
> Or abort with `git rebase --abort` / `git merge --abort` to go back to where you were.

Do NOT attempt to auto-resolve conflicts.

---

## Step 7: Re-apply Stashed Changes

If we stashed in Step 3:

```bash
git stash pop 2>&1
```

If the stash pop conflicts, tell the user:

> Your stashed changes conflict with the updated code. The stash is still saved
> (not dropped). Resolve the conflicts, then run `git stash drop` to clean up.

---

## Step 8: Detect Changed Dependencies and Config

Check what changed between the old HEAD and the new HEAD:

```bash
OLD_HEAD="[hash captured before sync]"
NEW_HEAD=$(git rev-parse HEAD)

if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
  echo "=== FILES CHANGED SINCE LAST LOCAL STATE ==="
  git diff --name-only "$OLD_HEAD" "$NEW_HEAD" 2>/dev/null
fi
```

Look for specific changes that require action:

```bash
CHANGED=$(git diff --name-only "$OLD_HEAD" "$NEW_HEAD" 2>/dev/null)

# Dependency files
echo "$CHANGED" | grep -E '(package-lock\.json|yarn\.lock|pnpm-lock\.yaml)' && echo "ACTION: npm/yarn/pnpm install needed"
echo "$CHANGED" | grep -E '(Gemfile\.lock)' && echo "ACTION: bundle install needed"
echo "$CHANGED" | grep -E '(requirements\.txt|Pipfile\.lock|poetry\.lock)' && echo "ACTION: pip/pipenv/poetry install needed"
echo "$CHANGED" | grep -E '(go\.sum)' && echo "ACTION: go mod download needed"
echo "$CHANGED" | grep -E '(Cargo\.lock)' && echo "ACTION: cargo build needed"
echo "$CHANGED" | grep -E '(composer\.lock)' && echo "ACTION: composer install needed"

# Config files
echo "$CHANGED" | grep -E '(\.env\.example)' && echo "ACTION: check .env for new variables"
echo "$CHANGED" | grep -E '(docker-compose)' && echo "ACTION: docker compose config may have changed"

# Migrations
echo "$CHANGED" | grep -iE '(migration|migrate)' && echo "ACTION: new migrations detected — may need to run them"

# CI/CD
echo "$CHANGED" | grep -E '(\.github/workflows|\.gitlab-ci|Jenkinsfile|\.circleci)' && echo "ACTION: CI config changed"
```

**If dependency lock files changed**, ask:

> Dependencies changed since your last sync. Want me to install them?
>
> [list which package managers need updating]
>
> A) Yes, install all
> B) I'll handle it myself

If **A**, run the appropriate install commands.

---

## Step 9: Summary

Present the final state:

```markdown
## Sync Complete

**Repo:** [name]
**Branch:** [branch]
**Previous HEAD:** [old short hash] [old message]
**Current HEAD:** [new short hash] [new message]

### What happened:
- [Fetched N new commits from remote]
- [Fast-forwarded main from abc1234 to def5678]
- [Rebased/merged feature branch onto latest main] (if applicable)
- [Stashed and re-applied local changes] (if applicable)
- [Installed updated dependencies] (if applicable)

### Heads up:
- [New env vars in .env.example: VAR_X, VAR_Y] (if applicable)
- [New migrations detected — run `[migrate command]`] (if applicable)
- [N files changed since your last state] (if applicable)

### Ready to go.
```

If nothing changed (already up to date), keep it short:

> **Already up to date.** Branch `main` at `abc1234`. Working directory clean.

---

## Important Rules

- **Never force-push, reset, or delete branches without explicit user confirmation.**
  This skill is about syncing, not cleaning up.
- **Never auto-resolve merge conflicts.** Surface them and stop.
- **Always stash before syncing if dirty.** Don't risk losing uncommitted work.
- **Capture the old HEAD before any sync operation** so we can diff what changed.
- **Run real commands, don't guess.** Every claim in the summary must come from
  actual git output.
- **Don't run tests or builds automatically.** Just flag what changed and let
  the user decide. The exception is dependency installs, which are safe and
  commonly expected.
- **Respect the user's branch.** Don't switch branches unless asked. If they're
  on a feature branch, keep them there — just make sure it's current.
