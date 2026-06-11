# Versioning and handoff

`/update-deck` always works on a NEW version on disk. It never overwrites the file the user opened. This protects against the failure mode where the user gives a revision against `v04`, the model edits `v04` in place, and the user loses the ability to compare or revert.

## Version detection

Memory rule: [[feedback-latest-artifact-version]] — glob the folder, pick the highest `_vN`. Do NOT trust Context_Master or Timeline docs to name the current version; they lag the file system on hot-iteration days.

```bash
ls "<deck folder>" | grep -E ' v[0-9]+\.html$' | sort -V | tail -1
```

The file the user named in the prompt may or may not be the latest. If the user says "fix v04" but `v06` exists on disk, ask: "I see v06 on disk — did you mean to revise v06, or revert to v04 and re-apply?"

## Naming

Base name + ` v0N.html` where N is the next integer above the current max. Keep the existing prefix verbatim (em-dashes, spaces, the works) — file collisions are caused by sloppy renaming.

Example: input `Bungalow IC Update — 05.25 v04.html` → output `Bungalow IC Update — 05.25 v05.html`.

## Copy, then edit

```powershell
Copy-Item "<deck folder>\<base> v<N>.html" "<deck folder>\<base> v<N+1>.html" -Force
```

Always copy first, then edit the copy. Never edit-then-rename — partial-write failure modes leave the source in an inconsistent state.

## Title bump

Update the `<title>` tag inside the new file to match the new version: `<title>… v05</title>`. The `<title>` is the only in-file place where the version is durably stamped; everything else (headers, footers, eyebrows) is template-driven.

## Image backups

When `update-deck-fix` re-exports a PNG in `img/`, back up the prior version side-by-side: `Output.png` → `Output.png.v<previous-deck-version>bak`. Keeps a revert path if the new export turned out worse.

```powershell
if (Test-Path $outFile) {
  $bk = $outFile + ".v" + $previousDeckVersion + "bak"
  if (-not (Test-Path $bk)) { Copy-Item $outFile $bk -Force }
}
```

## Page renumbering after slide deletion

When a slide is removed:
1. Update `<div class="page-num">` on every subsequent slide.
2. Update `<div class="eyebrow">Page N · …</div>` on every subsequent slide.
3. Grep the deck body for `Page \d+` text references and update where they pointed to the deleted slide or to a slide that has since renumbered.
4. The `<!-- ============== PAGE N — TITLE ============== -->` comments above each `<section>` are not user-visible and don't need updating (but updating them keeps the file readable for the next pass).

## Handoff message

After all three verify pillars pass and the new vN+1 is on disk, return to the user:
- **Path to new file** (full absolute path, so they can open it).
- **One-line summary per revision** ("Page X: did Y; Page Z: did W").
- **Anything that became TBU** (i.e., couldn't be sourced, replaced with placeholder pointing to source file).
- **Anything escalated to user** (unverifiable claims that couldn't be auto-resolved).

Do not declare "done" if any of those escalations are unresolved. The user needs to see them, not have them buried.
