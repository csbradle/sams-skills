# Image re-export playbook

When `update-deck-render-check` flags an image as illegible — small text, low resolution, or with a "Page 1" watermark — fix at the source rather than the slide.

Never re-create the chart as HTML/CSS. Memory rule: [[feedback-use-exact-source-output-not-rebuilds]]. Re-export from the source XLSX.

## Common defects and fixes

### Defect 1 — "Page 1" / "Page 2" gray watermark across the rendered table

**Root cause:** the source XLSX was rendered while in **Page Break Preview** view. Excel overlays a "Page 1" watermark in that view, which gets baked into the exported PNG.

**Fix:** open the source XLSX in a separate Excel COM instance, set `ActiveWindow.View = 1` (xlNormalView) on the relevant sheet, then re-export via `Range.CopyPicture` + Chart paste + `Chart.Export`.

**Important:** if the source XLSX is already open in another session (e.g. Nobie's session), Excel will refuse to open it from a second instance with write access. Copy the XLSX to `$env:TEMP` first and operate on the copy.

PowerShell pattern (Windows, run from outside Nobie's session):

```powershell
$src = "C:\path\to\Source.xlsx"
$tmp = "$env:TEMP\Source_export.xlsx"
Copy-Item $src $tmp -Force

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($tmp)

foreach ($ws in $wb.Worksheets) {
  try { $ws.Activate() | Out-Null; $excel.ActiveWindow.View = 1 } catch {}
}

$ws = $wb.Worksheets.Item("Sheet Name")
$ws.Activate() | Out-Null
$excel.ActiveWindow.View = 1
$range = $ws.UsedRange
$range.CopyPicture(1, 2) | Out-Null   # xlScreen=1, xlBitmap=2

$w = [Math]::Min(2400, $range.Width + 20)
$h = [Math]::Min(1600, $range.Height + 20)
$ch = $ws.ChartObjects().Add(0, 0, $w, $h)
$ch.Activate() | Out-Null
$ch.Chart.Paste()
$ch.Chart.Export("C:\path\to\img\Output.png", "PNG") | Out-Null
$ch.Delete()

$wb.Close($false)
$excel.Quit()
```

### Defect 2 — Chart axis labels / data labels are too small

**Root cause:** chart was exported at native chart size (~600px wide); when scaled into a 1920px slide, text shrinks to unreadable.

**Fix:** before exporting, resize the chart object and set explicit font sizes on title + data labels per-point. Then `Chart.Export(...)` renders at high resolution where the fonts are appropriate.

**Wider, not taller** — Sam has flagged this twice now. When chart text is illegible, the instinct to "make the chart bigger" by raising `$co.Height` is wrong. Taller doesn't fix text rendering; it squishes the surrounding slide content (commentary, footer) without giving Excel more horizontal pixels to lay out tick labels. The fix is:
1. **Raise `$co.Width` first** (more pixels for the x-axis, which is where most legibility problems live).
2. **Raise font sizes explicitly** (title 32-36pt, data labels 24-28pt bold, tick labels via increased width since `TickLabels.Font.Size` is unreliable).
3. **Keep `$co.Height` the same or smaller** unless the slide layout has obvious vertical headroom.
4. **Re-Read the exported PNG and verify x-axis tick labels are legible at chat-display scale** before declaring the chart fixed. If the tick labels are still squashed, the chart is still broken — iterate on width and font, not height.

```powershell
$co = $ws.ChartObjects("Chart 5")
$ch = $co.Chart
$co.Width = 1500
$co.Height = 720
$ch.ChartTitle.Format.TextFrame2.TextRange.Font.Size = 36

# Data labels — iterate per point. Whole-series font assignment is unreliable.
for ($i = 1; $i -le $ch.SeriesCollection().Count; $i++) {
  $s = $ch.SeriesCollection($i)
  $s.HasDataLabels = $true
  for ($j = 1; $j -le $s.Points().Count; $j++) {
    try {
      $p = $s.Points($j)
      if ($p.HasDataLabel) {
        $p.DataLabel.Format.TextFrame2.TextRange.Font.Size = 26
        $p.DataLabel.Format.TextFrame2.TextRange.Font.Bold = $true
      }
    } catch {}
  }
}
$ch.Export("C:\path\to\img\Chart.png", "PNG") | Out-Null
```

**Note on x-axis tick labels:** `Axes(1, 1).TickLabels.Font.Size = 22` raises `The property 'Size' cannot be found on this object` on some Excel chart shapes. If it fails, accept the smaller tick labels — the high-resolution PNG (Excel exports at ~2.6× the chart-object size) keeps them readable when displayed at full slide width. If you must enlarge them, increase `$co.Width` further so the export resolution rises proportionally.

### Defect 3 — Image embeds at lower resolution than the slide displays

**Root cause:** PNG is e.g. 954×520, displayed at slide-body width ~1800px → 1.9× upscale, blurry.

**Fix:** re-export with `$co.Width` set higher; Excel's chart export is roughly `pixels = points × 2.6`. A 1500-point-wide chart exports at ~3900px wide PNG; downsampled to 1800px in the slide it stays sharp.

### Defect 4 — Range-export drag-in: stray top header + bottom scaffold rows

**Root cause:** when exporting a P&L or table via `Range.CopyPicture` from `UsedRange` or a hard-coded big range, Excel grabs adjacent scaffold rows that the model-builder left in the worksheet but that don't belong on the IC view. Two patterns to detect:

1. **Top defect — stray dates / whitespace header.** A row above the main output that contains period labels (`Q3-25 | Q4-25 | Q1-26 | …`) which DUPLICATE the column headers already in the main output. Often the very-top row is blank (whitespace) and the second row is a stray date strip the modeller used for cross-referencing.
2. **Bottom defect — "Check" row + empty row-title stubs.** Below the last load-bearing total, a `Check` row (formula sanity check, usually `=Σ(parts) - Total`, value 0 if model ties) plus 1-2 rows that have row-label cells (e.g. `Legacy CP`, `Haven CP`) but EMPTY value cells across all periods. These are formula scaffolds the modeller built for future use.

**Why this matters:** the IC reader sees garbage rows at the top and bottom of an otherwise clean P&L. User has flagged this 2× across IC update passes.

**Detection (do this before exporting — and on re-Read after export):**

After re-exporting an XLSX-sourced output, Read the resulting PNG and scan top and bottom rows:
- Top 2 rows: does any row contain only period labels (Q-1, Q-2, etc.) AND there's a more prominent header row below it? → top defect.
- Bottom 3 rows: any row contain the literal word "Check" in column A? → bottom defect. Any row contain a label in column A but blank value cells across the period columns? → bottom defect.

If either fires, re-export with a tighter range.

**Fix — tighten the export range explicitly. Do NOT rely on `UsedRange`:**

```powershell
# Option A: discover the tight range by scanning column A for the first/last load-bearing label
$ws = $wb.Worksheets.Item("PF Consolidated P&L")
$ws.Activate() | Out-Null
$excel.ActiveWindow.View = 1   # xlNormalView — kills Page Break watermark

# Find the first row whose column-A label is the title row (e.g. starts with "Bungalow", "PF", or a known anchor).
$firstRow = 1
for ($r = 1; $r -le 100; $r++) {
  $v = [string]$ws.Cells.Item($r, 1).Value2
  if ($v -and ($v -match '^(Bungalow|PF|Haven|Legacy|Revenue|Doors)')) { $firstRow = $r; break }
}

# Find the last row whose column-A label is a real total (NOT "Check", NOT blank).
$lastRow = $ws.UsedRange.Rows.Count
for ($r = $lastRow; $r -ge $firstRow; $r--) {
  $label = [string]$ws.Cells.Item($r, 1).Value2
  $v = $ws.Cells.Item($r, 2).Value2
  if ($label -and $label -notmatch '^Check$' -and $v -ne $null -and $v -ne '') { $lastRow = $r; break }
}

# Find last col used in this row block.
$lastCol = $ws.UsedRange.Columns.Count

$range = $ws.Range($ws.Cells.Item($firstRow, 1), $ws.Cells.Item($lastRow, $lastCol))
$range.CopyPicture(1, 2) | Out-Null

# Paste into Chart for high-res export (defect-2 pattern).
$w = [Math]::Min(2400, $range.Width + 20)
$h = [Math]::Min(1800, $range.Height + 20)
$ch = $ws.ChartObjects().Add(0, 0, $w, $h)
$ch.Activate() | Out-Null
$ch.Chart.Paste()
$ch.Chart.Export("C:\path\to\img\Output.png", "PNG") | Out-Null
$ch.Delete()
```

**Option B — when row labels are unpredictable:** ask the user which named range to use, or hardcode a known-good range (`$ws.Range("A4:N42")`). Then bake it into the deck's source-cell-reference comment so future passes know where to look.

**After fix:** Read the new PNG. Top row should be the title row (or first true header). Bottom row should be the lowest load-bearing total (`% Margin` or `Contribution Profit`), NOT `Check`, NOT empty stub labels.

## When to fix versus when to ask

Fix automatically:
- Page-break watermark in source PNG.
- Chart font sizes obviously too small (data labels < 12pt at slide scale).
- PNG resolution < 2× slide display width.
- Stray top dates row + bottom Check/empty-stub rows (defect 4 above) — once detected, tighten the export range and re-export without asking.

Ask the user first:
- Source XLSX path is ambiguous (multiple candidates).
- The "source" is itself a screenshot of an artifact you don't have access to (e.g. a screenshot of a PDF page).
- Re-export would change the chart data (e.g. underlying numbers have changed in the XLSX since last export). The user may want the historical snapshot, not the live version.

## Locating the source

If the slide HTML has a `Source:` line in the footer or a `<!-- Source: ... -->` comment, follow that. Otherwise:

1. Glob the deal folder for `*.xlsx`; rank by recency.
2. Open via Nobie `list_sheets` and look for a sheet name matching the chart title (e.g. `Haven CP Margin Bridge` → sheet `Haven CP Margin Bridge`).
3. If the XLSX has a chart of the same name, that's the source chart.
4. If not, the PNG was hand-pasted — ask the user where it came from.

## After re-export

Re-Read the PNG to confirm:
- Watermark gone (if defect 1).
- Text readable at chat-display size (if defect 2).
- Resolution at least 2× slide width (if defect 3).

If still bad, increase chart dimensions and re-export. If still bad after a third pass, ask the user.
