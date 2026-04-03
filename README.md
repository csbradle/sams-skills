# Sam's Skills

Custom [Claude Code](https://claude.ai/claude-code) skills for managing multi-project workflows. Built to solve the problem of losing context between sessions.

## Skills

### `/handoff` — End-of-Session Handoff

**When to use:** End of every session, before switching projects, or anytime you're done working.

**What it does:**
1. Scans your entire repo state — uncommitted changes, unpushed branches, stashed work, gitignored files
2. Commits and pushes everything to GitHub (with your approval)
3. Checks for hidden/gitignored files that might contain important work
4. **Updates `progress.md`** — the running session log (never deletes prior entries):
   - Progress made, outstanding TODOs, decisions tagged `[USER]`/`[CLAUDE]`/`[JOINT]`
   - Open questions, future ideas, session narrative with mistakes & corrections
   - Technical debt identified, files changed
5. Writes a comprehensive handoff document (`.github/HANDOFF.md`) covering:
   - What was done this session
   - Current state of all branches
   - Every outstanding PR with status and next actions
   - Known issues and blockers
   - Prioritized next steps
   - Key files modified and context for the next session
6. Commits and pushes everything (progress.md + handoff doc)

**The problem it solves:** Files left uncommitted, branches unpushed, context lost between sessions. The next Claude session starts blind and rebuilds work that already exists.

**Usage:**
```
/handoff
```

---

### `/kickoff` — WTF Is Going On

**When to use:** Start of every session, when switching back to a project, or anytime you need a status briefing.

**What it does:**
1. **Reads `progress.md` FIRST** — the running session log with prior decisions, outstanding TODOs, open questions, and session history
2. Forensic scan of the entire project:
   - All local and remote branches
   - **Every open PR** with full details (status, CI, reviews, what it does)
   - Recently merged and closed PRs
   - Uncommitted and unpushed work
   - Stashed changes
   - Recent commit history
   - CI/CD and deploy status
   - Open GitHub issues
3. Reads all project docs (HANDOFF.md, CLAUDE.md, TODOS.md, plans, changelogs)
4. Classifies every PR by what action it needs (merge, review, QA, fix)
5. Presents a structured status report with prioritized next steps
6. Asks what you'd like to work on

**The problem it solves:** You ask "where are we?" and get told to rebuild a feature that already has an outstanding PR. Missing branches, forgotten work, incomplete status checks.

**Priority rules:**
1. Merge-ready PRs first (approved + CI green = merge it)
2. PRs needing review second (run `/review` or `/qa`, don't rebuild)
3. PRs needing fixes third
4. Uncommitted work fourth
5. New work last

**Critical rule:** If an open PR covers work you might ask about, `/kickoff` will tell you "PR #X already implements this" instead of letting you rebuild it.

**Usage:**
```
/kickoff
```

---

## Global Rules

### `progress.md` — Mandatory Session Tracking

Located in [`global-rules/CLAUDE.md`](global-rules/CLAUDE.md). Copy this to `~/.claude/CLAUDE.md` to enforce across all repos.

**What it does:** Requires every project to have a `progress.md` at the repo root, updated every session. This is a running, append-only document — prior sessions are never deleted.

**Sections tracked:**
- **Session Goal** — one-line objective
- **Progress Made** — what landed (with file paths), what was attempted
- **Outstanding TODOs** — carried forward from prior sessions with dates
- **Decisions Log** — tagged `[USER]`, `[CLAUDE]`, or `[JOINT]` with reasoning and alternatives
- **Open Questions** — unresolved items needing future input
- **Future Ideas & Aspirations** — long-term visions, "wouldn't it be cool if..." ideas
- **Session Log** — honest narrative: exploration, dead ends, Claude mistakes, user prompt corrections, blockers, pivots
- **Technical Debt & Risks** — shortcuts taken, performance concerns
- **Files Changed** — what was touched and why

**Why decision tagging matters:** Every decision gets attributed so you can distinguish "I chose this" from "Claude auto-decided this" when reviewing history. The `[JOINT]` tag captures decisions reached through discussion.

**Install:**
```bash
cp global-rules/CLAUDE.md ~/.claude/CLAUDE.md
```

---

## Installation

### Option 1: Copy to your Claude skills directory

```bash
# Clone this repo
git clone https://github.com/csbradle/sams-skills.git

# Copy skills to your Claude Code skills directory
cp -r sams-skills/handoff ~/.claude/skills/handoff
cp -r sams-skills/kickoff ~/.claude/skills/kickoff

# Copy global rules
cp sams-skills/global-rules/CLAUDE.md ~/.claude/CLAUDE.md
```

### Option 2: Symlink (stays updated with git pull)

```bash
git clone https://github.com/csbradle/sams-skills.git ~/sams-skills

ln -s ~/sams-skills/handoff ~/.claude/skills/handoff
ln -s ~/sams-skills/kickoff ~/.claude/skills/kickoff
cp ~/sams-skills/global-rules/CLAUDE.md ~/.claude/CLAUDE.md
```

### Verify installation

Open Claude Code and type `/handoff` or `/kickoff` — they should appear in the skill list.

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- `git` and `gh` (GitHub CLI) installed and authenticated
- A GitHub repository to work with

## Workflow

The ideal workflow across sessions:

```
Session 1:  ... do work ... → /handoff (end of session)
Session 2:  /kickoff (start) → ... do work ... → /handoff (end)
Session 3:  /kickoff (start) → ... do work ... → /handoff (end)
```

Every session starts informed and ends clean. Nothing gets lost.

`progress.md` builds up across sessions as an honest, running record of everything — decisions, mistakes, ideas, and debt. It's the project's memory.
