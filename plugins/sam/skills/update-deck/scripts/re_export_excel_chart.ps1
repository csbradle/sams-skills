[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$XlsxPath,
  [Parameter(Mandatory=$true)][string]$SheetName,
  [Parameter(Mandatory=$true)][string]$OutPng,
  [string]$ChartObjectName,
  [int]$ChartWidth = 1500,
  [int]$ChartHeight = 720,
  [int]$TitleFontSize = 36,
  [int]$DataLabelFontSize = 26,
  [int]$RangeAddress
)

# Re-exports a chart or used-range from a source XLSX to PNG with explicit font sizing.
# Operates on a COPY of the XLSX so it doesn't conflict with any Nobie/other open session.
#
# Modes:
#   - ChartObjectName provided -> export that chart object with the given fonts.
#   - ChartObjectName empty    -> CopyPicture of the used range (or RangeAddress if set),
#                                 paste into a temporary chart, export. View is forced to
#                                 Normal first so Page Break Preview watermarks don't bake in.

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $XlsxPath)) { Write-Error "XLSX not found: $XlsxPath"; exit 2 }
$outDir = Split-Path $OutPng -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# Operate on a copy so we don't lock the user's source file.
$tmp = Join-Path $env:TEMP ("xport_" + [Guid]::NewGuid().ToString("N") + ".xlsx")
Copy-Item $XlsxPath $tmp -Force

# Backup the existing PNG (if any) so we can revert if the re-export is worse.
if (Test-Path $OutPng) {
  $bk = $OutPng + ".bak"
  if (-not (Test-Path $bk)) { Copy-Item $OutPng $bk -Force }
}

$excel = $null
try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $wb = $excel.Workbooks.Open($tmp)

  # Force every sheet to Normal view so the "Page 1" Page-Break-Preview watermark
  # cannot bake into a CopyPicture/Export.
  foreach ($ws in $wb.Worksheets) {
    try { $ws.Activate() | Out-Null; $excel.ActiveWindow.View = 1 } catch {}
  }

  $ws = $wb.Worksheets.Item($SheetName)
  $ws.Activate() | Out-Null
  $excel.ActiveWindow.View = 1

  if ($ChartObjectName) {
    # Mode A: existing chart object.
    $co = $ws.ChartObjects($ChartObjectName)
    $ch = $co.Chart
    $co.Width = $ChartWidth
    $co.Height = $ChartHeight
    try { $ch.ChartTitle.Format.TextFrame2.TextRange.Font.Size = $TitleFontSize } catch {}
    # Set per-point data labels via TextFrame2 (whole-series font is unreliable).
    for ($i = 1; $i -le $ch.SeriesCollection().Count; $i++) {
      $s = $ch.SeriesCollection($i)
      try { $s.HasDataLabels = $true } catch {}
      for ($j = 1; $j -le $s.Points().Count; $j++) {
        try {
          $p = $s.Points($j)
          if ($p.HasDataLabel) {
            $p.DataLabel.Format.TextFrame2.TextRange.Font.Size = $DataLabelFontSize
            $p.DataLabel.Format.TextFrame2.TextRange.Font.Bold = $true
          }
        } catch {}
      }
    }
    $ch.Export($OutPng, "PNG") | Out-Null
  } else {
    # Mode B: range -> bitmap -> embedded chart -> PNG export.
    $range = if ($RangeAddress) { $ws.Range($RangeAddress) } else { $ws.UsedRange }
    $range.CopyPicture(1, 2) | Out-Null   # xlScreen=1, xlBitmap=2
    $w = [Math]::Min(2400, $range.Width + 20)
    $h = [Math]::Min(1600, $range.Height + 20)
    $co = $ws.ChartObjects().Add(0, 0, $w, $h)
    $co.Activate() | Out-Null
    $co.Chart.Paste()
    $co.Chart.Export($OutPng, "PNG") | Out-Null
    $co.Delete()
  }

  $wb.Close($false)
  Write-Output ("exported: " + $OutPng + " size=" + (Get-Item $OutPng).Length)
} catch {
  Write-Error ("re-export failed: " + $_.Exception.Message)
  exit 1
} finally {
  if ($excel) {
    try { $excel.Quit() } catch {}
    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null } catch {}
  }
  if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}
