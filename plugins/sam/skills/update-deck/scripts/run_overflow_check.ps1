[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$DeckPath,
  [string]$OutDir,
  [switch]$ScreenshotEverySlide
)

# Runs the overflow probe against a deck HTML file. Returns JSON to stdout listing
# every slide's overflow measurements. Optionally screenshots each slide to OutDir.
#
# Exit 0 on success (probe ran); exit 1 if any slide_overflow > 0. The caller is
# responsible for parsing the JSON and routing fixes.

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $DeckPath)) {
  Write-Error "Deck not found: $DeckPath"
  exit 2
}
if (-not $OutDir) { $OutDir = Join-Path $env:TEMP "update-deck-shots" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) { $chrome = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" }
if (-not (Test-Path $chrome)) { $chrome = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" }
if (-not (Test-Path $chrome)) { Write-Error "Chrome/Edge not found"; exit 3 }

# Prepare the probe HTML with the deck URL substituted in
$probeTemplate = Join-Path $PSScriptRoot "overflow_probe.html"
if (-not (Test-Path $probeTemplate)) { Write-Error "probe template missing: $probeTemplate"; exit 4 }
$deckFileUrl = ([Uri]::new($DeckPath)).AbsoluteUri
$probe = Get-Content $probeTemplate -Raw -Encoding UTF8
$probe = $probe -replace '__DECK_URL__', [regex]::Escape($deckFileUrl).Replace('\\','\')
$probeOut = Join-Path $OutDir "probe.html"
[IO.File]::WriteAllText($probeOut, $probe, [System.Text.UTF8Encoding]::new($false))

$ud = Join-Path $env:TEMP "chrome_overflow_probe_ud"
$probeUrl = ([Uri]::new($probeOut)).AbsoluteUri

# Dump-DOM run: extracts the <pre id="result"> JSON
$dump = Join-Path $OutDir "probe_dump.html"
Start-Process -FilePath $chrome -ArgumentList @(
  "--headless=new","--disable-gpu","--window-size=2200,1300",
  "--allow-file-access-from-files","--user-data-dir=$ud",
  "--virtual-time-budget=8000","--run-all-compositor-stages-before-draw",
  "--dump-dom",$probeUrl
) -RedirectStandardOutput $dump -NoNewWindow -Wait

if (-not (Test-Path $dump) -or (Get-Item $dump).Length -lt 100) {
  Write-Error "Dump-DOM produced empty output. Chrome may not be allowing file access."
  exit 5
}

# Pull the JSON out of <pre id="result">...</pre>
$dumpText = Get-Content $dump -Raw -Encoding UTF8
$match = [regex]::Match($dumpText, '<pre id="result"[^>]*>([\s\S]*?)</pre>')
if (-not $match.Success) { Write-Error "Could not find probe result in dump"; exit 6 }
$json = $match.Groups[1].Value.Trim()
# unescape HTML entities so JSON parses cleanly
$json = $json -replace '&quot;','"' -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>'

# Emit the JSON to stdout for the caller
Write-Output $json

# Optional: screenshot each slide for visual review
if ($ScreenshotEverySlide) {
  try {
    $obj = $json | ConvertFrom-Json
    $count = if ($obj -is [array]) { $obj.Count } else { 0 }
  } catch { $count = 0 }
  if ($count -gt 0) {
    # Snapshot wrapper that scrolls to a specific slide
    $snap = Join-Path $OutDir "snap.html"
    $snapHtml = @"
<!DOCTYPE html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;width:1920px;background:#1a1a1a}</style></head>
<body><iframe id="f" src="$deckFileUrl" style="width:1920px;height:1080px;border:0;display:block"></iframe>
<script>
const p = parseInt(new URLSearchParams(location.search).get('p')||'1');
const f = document.getElementById('f');
f.addEventListener('load', () => setTimeout(() => {
  const sl = f.contentDocument.querySelectorAll('.slide');
  if (sl[p-1]) sl[p-1].scrollIntoView({behavior:'instant',block:'start'});
}, 800));
</script></body></html>
"@
    [IO.File]::WriteAllText($snap, $snapHtml, [System.Text.UTF8Encoding]::new($false))
    $snapUrlBase = ([Uri]::new($snap)).AbsoluteUri
    for ($p = 1; $p -le $count; $p++) {
      $u = $snapUrlBase + "?p=$p"
      $o = Join-Path $OutDir "slide_$p.png"
      Start-Process -FilePath $chrome -ArgumentList @(
        "--headless=new","--disable-gpu","--window-size=1920,1080",
        "--allow-file-access-from-files","--user-data-dir=$ud",
        "--virtual-time-budget=4000","--run-all-compositor-stages-before-draw",
        "--screenshot=$o",$u
      ) -NoNewWindow -Wait | Out-Null
    }
  }
}

# Exit code reflects whether any slide overflowed
try {
  $obj = $json | ConvertFrom-Json
  $bad = @($obj | Where-Object { $_.slide_overflow -gt 0 })
  if ($bad.Count -gt 0) { exit 1 } else { exit 0 }
} catch {
  exit 7
}
